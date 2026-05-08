from __future__ import annotations

from difflib import SequenceMatcher
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, Field, model_validator
from sqlalchemy import func, or_, select, text
from sqlalchemy.ext.asyncio import AsyncSession

from app.dependencies import get_current_user, get_db
from app.models.music import Playlist, PlaylistTrack, PlaylistVisibility, TrackCache
from app.models.user import User
from app.services import firebase as firebase_svc
from app.services.security import are_friends

router = APIRouter()


class PlaylistCreateRequest(BaseModel):
    title: Optional[str] = Field(default=None, min_length=1, max_length=255)
    name: Optional[str] = Field(default=None, min_length=1, max_length=255)
    description: Optional[str] = Field(default=None, max_length=500)
    cover_url: Optional[str] = Field(default=None)
    source_playlist_id: Optional[int] = None
    visibility: PlaylistVisibility = PlaylistVisibility.private
    is_collaborative: bool = False
    collab_user_id: Optional[int] = None

    @model_validator(mode="after")
    def resolve_title(self) -> "PlaylistCreateRequest":
        if not self.title and self.name:
            self.title = self.name
        if not self.title:
            raise ValueError("title (or name) is required")
        return self


class PlaylistUpdateRequest(BaseModel):
    title: Optional[str] = Field(default=None, min_length=1, max_length=255)
    description: Optional[str] = Field(default=None, max_length=500)
    cover_url: Optional[str] = Field(default=None)
    visibility: Optional[PlaylistVisibility] = None
    is_collaborative: Optional[bool] = None
    collab_user_id: Optional[int] = None


class AddTrackRequest(BaseModel):
    spotify_track_id: str
    title: str
    artist: str
    album: Optional[str] = None
    genre: Optional[str] = None
    cover_url: Optional[str] = None
    preview_url: Optional[str] = None
    duration_ms: Optional[int] = None


class CollaborateRequest(BaseModel):
    collab_user_id: int


def _score_playlist_match(query: str, title: str, description: Optional[str]) -> float:
    q = query.lower().strip()
    best = 0.0
    for candidate in (title or "", description or ""):
        value = candidate.lower().strip()
        if not value:
            continue
        if value == q:
            score = 100.0
        elif value.startswith(q):
            score = 80.0
        elif q in value:
            score = 60.0
        else:
            ratio = SequenceMatcher(None, q, value).ratio()
            if ratio < 0.55:
                continue
            score = 30.0 + ratio * 20.0
        best = max(best, score)
    return best


def _playlist_payload(playlist: Playlist, track_count: int = 0) -> dict:
    return {
        "id": playlist.id,
        "owner_id": playlist.owner_id,
        "source_playlist_id": playlist.source_playlist_id,
        "title": playlist.title,
        "description": playlist.description,
        "cover_url": playlist.cover_url,
        "visibility": playlist.visibility.value,
        "is_collaborative": playlist.is_collaborative,
        "collab_user_id": playlist.collab_user_id,
        "track_count": track_count,
        "created_at": playlist.created_at.isoformat(),
        "updated_at": playlist.updated_at.isoformat(),
    }


def _apply_source_snapshot(payload: dict, source_playlist: Playlist) -> dict:
    payload["title"] = source_playlist.title
    payload["description"] = source_playlist.description
    payload["cover_url"] = source_playlist.cover_url
    payload["source_updated_at"] = source_playlist.updated_at.isoformat()
    return payload


async def _saved_copy_metadata(
    db: AsyncSession,
    *,
    playlist: Playlist,
    current_user: User,
) -> tuple[int, bool, int | None]:
    root_id = playlist.source_playlist_id or playlist.id
    saved_count = int(
        await db.scalar(
            select(func.count(Playlist.id)).where(
                Playlist.visibility == PlaylistVisibility.saved,
                Playlist.source_playlist_id == root_id,
            )
        )
        or 0
    )

    if playlist.visibility == PlaylistVisibility.saved and playlist.owner_id == current_user.id:
        return saved_count, True, playlist.id

    saved_copy_id = await db.scalar(
        select(Playlist.id).where(
            Playlist.owner_id == current_user.id,
            Playlist.visibility == PlaylistVisibility.saved,
            Playlist.source_playlist_id == root_id,
        )
    )
    return saved_count, saved_copy_id is not None, int(saved_copy_id) if saved_copy_id else None


async def _attach_owner_metadata(
    payload: dict,
    db: AsyncSession,
    *,
    playlist: Playlist,
) -> dict:
    owner = await db.get(User, playlist.owner_id)
    payload["owner_username"] = owner.username if owner else None
    payload["owner_display_name"] = (owner.first_name or owner.username) if owner else None
    payload["owner_avatar_url"] = owner.avatar_url if owner else None

    source_playlist = None
    if playlist.source_playlist_id:
        source_playlist = await db.get(Playlist, playlist.source_playlist_id)
    source_owner = await db.get(User, source_playlist.owner_id) if source_playlist else owner
    payload["saved_from_owner_id"] = source_owner.id if source_owner else None
    payload["saved_from_username"] = source_owner.username if source_owner else None
    payload["saved_from_display_name"] = (
        (source_owner.first_name or source_owner.username) if source_owner else None
    )
    payload["saved_from_avatar_url"] = source_owner.avatar_url if source_owner else None
    return payload


def _has_playlist_access(playlist: Playlist, user_id: int) -> bool:
    if playlist.owner_id == user_id:
        return True
    if playlist.is_collaborative and playlist.collab_user_id == user_id:
        return True
    return False


async def _can_view_playlist(
    db: AsyncSession,
    *,
    playlist: Playlist,
    current_user: User,
) -> bool:
    if _has_playlist_access(playlist, current_user.id):
        return True
    if playlist.visibility == PlaylistVisibility.public:
        return True
    if playlist.visibility == PlaylistVisibility.friends:
        return await are_friends(db, playlist.owner_id, current_user.id)
    return False


async def _get_visible_source_playlist(
    db: AsyncSession,
    *,
    playlist: Playlist,
    current_user: User,
    cleanup_unavailable: bool = False,
) -> Playlist | None:
    if not playlist.source_playlist_id:
        return None
    source_playlist = await db.get(Playlist, playlist.source_playlist_id)
    if source_playlist and await _can_view_playlist(
        db,
        playlist=source_playlist,
        current_user=current_user,
    ):
        return source_playlist

    if cleanup_unavailable and playlist.visibility == PlaylistVisibility.saved:
        await db.delete(playlist)
        await db.commit()
    return None


async def _track_payloads_for_playlist(
    db: AsyncSession,
    *,
    playlist: Playlist,
) -> list[dict]:
    await db.refresh(playlist, ["tracks"])
    track_ids = [t.spotify_track_id for t in playlist.tracks]
    cache_rows = []
    if track_ids:
        cache_rows = (
            await db.execute(
                select(TrackCache).where(TrackCache.spotify_id.in_(track_ids))
            )
        ).scalars().all()
    cache_map = {row.spotify_id: row for row in cache_rows}
    sorted_tracks = sorted(playlist.tracks, key=lambda t: t.position)
    return [
        {
            "spotify_id": t.spotify_track_id,
            "deezer_id": t.spotify_track_id,
            "position": t.position,
            "added_at": t.added_at.isoformat(),
            "title": cache_map[t.spotify_track_id].title if t.spotify_track_id in cache_map else "Unknown",
            "artist": cache_map[t.spotify_track_id].artist if t.spotify_track_id in cache_map else "",
            "cover_url": cache_map[t.spotify_track_id].cover_url if t.spotify_track_id in cache_map else None,
            "preview_url": cache_map[t.spotify_track_id].preview_url if t.spotify_track_id in cache_map else None,
            "duration_ms": cache_map[t.spotify_track_id].duration_ms if t.spotify_track_id in cache_map else 0,
        }
        for t in sorted_tracks
    ]


@router.get(
    "",
    summary="List my playlists",
    description="Returns playlists owned by the current user or shared with them as a collaborator.",
)
@router.get(
    "/",
    summary="List my playlists",
    description="Returns playlists owned by the current user or shared with them as a collaborator.",
)
async def list_playlists(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    rows = (
        await db.execute(
            select(Playlist, func.count(PlaylistTrack.id))
            .outerjoin(PlaylistTrack, PlaylistTrack.playlist_id == Playlist.id)
            .where(
                or_(
                    Playlist.owner_id == current_user.id,
                    Playlist.collab_user_id == current_user.id,
                )
            )
            .group_by(Playlist.id)
            .order_by(Playlist.created_at.desc())
        )
    ).all()
    items: list[dict] = []
    for playlist, count in rows:
        effective_playlist = playlist
        effective_count = int(count or 0)
        if playlist.visibility == PlaylistVisibility.saved and playlist.source_playlist_id:
            source_playlist = await _get_visible_source_playlist(
                db,
                playlist=playlist,
                current_user=current_user,
                cleanup_unavailable=True,
            )
            if source_playlist is None:
                continue
            effective_playlist = source_playlist
            effective_count = int(
                await db.scalar(
                    select(func.count(PlaylistTrack.id)).where(
                        PlaylistTrack.playlist_id == source_playlist.id
                    )
                )
                or 0
            )
        payload = _playlist_payload(playlist, track_count=effective_count)
        if effective_playlist.id != playlist.id:
            payload = _apply_source_snapshot(payload, effective_playlist)
        payload = await _attach_owner_metadata(payload, db, playlist=playlist)
        saved_count, is_saved_by_me, saved_copy_id = await _saved_copy_metadata(
            db,
            playlist=playlist,
            current_user=current_user,
        )
        payload["saved_count"] = saved_count
        payload["is_saved_by_me"] = is_saved_by_me
        payload["saved_copy_id"] = saved_copy_id
        items.append(payload)
    return {"playlists": items}


@router.get(
    "/search",
    summary="Search public playlists",
    description="Searches public playlists with full-text search and a lightweight ranking score.",
)
async def search_playlists(
    q: str = Query(default=""),
    limit: int = Query(default=20, ge=1, le=50),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    query = q.strip()
    if len(query) < 2:
        return {"playlists": []}

    # Uses GIN index created by migration.
    fts = text(
        "to_tsvector('english', coalesce(title,'') || ' ' || coalesce(description,'')) "
        "@@ plainto_tsquery('english', :query)"
    )
    rows = (
        await db.execute(
            select(Playlist, func.count(PlaylistTrack.id))
            .outerjoin(PlaylistTrack, PlaylistTrack.playlist_id == Playlist.id)
            .where(Playlist.visibility == PlaylistVisibility.public, fts)
            .group_by(Playlist.id)
            .limit(limit * 3),
            {"query": query},
        )
    ).all()

    ranked = sorted(
        (
            {
                **_playlist_payload(playlist, track_count=track_count),
                "score": _score_playlist_match(query, playlist.title, playlist.description),
            }
            for playlist, track_count in rows
        ),
        key=lambda item: item["score"],
        reverse=True,
    )
    result_items: list[dict] = []
    for item in ranked[:limit]:
        if item["score"] <= 0:
            continue
        playlist = await db.get(Playlist, item["id"])
        if playlist is None:
            continue
        payload = {k: v for k, v in item.items() if k != "score"}
        payload = await _attach_owner_metadata(payload, db, playlist=playlist)
        saved_count, is_saved_by_me, saved_copy_id = await _saved_copy_metadata(
            db,
            playlist=playlist,
            current_user=current_user,
        )
        payload["saved_count"] = saved_count
        payload["is_saved_by_me"] = is_saved_by_me
        payload["saved_copy_id"] = saved_copy_id
        result_items.append(payload)
    return {"playlists": result_items}


@router.post(
    "",
    status_code=201,
    summary="Create playlist",
    description="Creates a new playlist for the authenticated user with the requested visibility and collaboration settings.",
)
@router.post(
    "/",
    status_code=201,
    summary="Create playlist",
    description="Creates a new playlist for the authenticated user with the requested visibility and collaboration settings.",
)
async def create_playlist(
    body: PlaylistCreateRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if body.is_collaborative and body.collab_user_id is None:
        raise HTTPException(status_code=422, detail="collab_user_id is required for collaborative playlists")

    playlist = Playlist(
        owner_id=current_user.id,
        source_playlist_id=body.source_playlist_id,
        collab_user_id=body.collab_user_id if body.is_collaborative else None,
        title=body.title.strip(),
        description=body.description,
        cover_url=body.cover_url,
        visibility=body.visibility,
        is_collaborative=body.is_collaborative,
    )
    db.add(playlist)
    await db.commit()
    await db.refresh(playlist)
    payload = _playlist_payload(playlist, track_count=0)
    payload = await _attach_owner_metadata(payload, db, playlist=playlist)
    saved_count, is_saved_by_me, saved_copy_id = await _saved_copy_metadata(
        db,
        playlist=playlist,
        current_user=current_user,
    )
    payload["saved_count"] = saved_count
    payload["is_saved_by_me"] = is_saved_by_me
    payload["saved_copy_id"] = saved_copy_id
    return payload


@router.get(
    "/{playlist_id}",
    summary="Get playlist details",
    description="Returns playlist metadata and track entries when the requester has permission to view the playlist.",
)
async def get_playlist(
    playlist_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    playlist = await db.get(Playlist, playlist_id)
    if not playlist:
        raise HTTPException(status_code=404, detail="Playlist not found")

    effective_playlist = playlist
    if playlist.visibility == PlaylistVisibility.saved and playlist.source_playlist_id:
        source_playlist = await _get_visible_source_playlist(
            db,
            playlist=playlist,
            current_user=current_user,
            cleanup_unavailable=playlist.owner_id == current_user.id,
        )
        if source_playlist is None:
            raise HTTPException(status_code=404, detail="Playlist not found")
        effective_playlist = source_playlist
    elif not await _can_view_playlist(
        db,
        playlist=playlist,
        current_user=current_user,
    ):
        raise HTTPException(status_code=403, detail="Access denied")

    track_payloads = await _track_payloads_for_playlist(
        db,
        playlist=effective_playlist,
    )
    payload = _playlist_payload(playlist, track_count=len(track_payloads))
    if effective_playlist.id != playlist.id:
        payload = _apply_source_snapshot(payload, effective_playlist)
    payload = await _attach_owner_metadata(payload, db, playlist=playlist)
    saved_count, is_saved_by_me, saved_copy_id = await _saved_copy_metadata(
        db,
        playlist=playlist,
        current_user=current_user,
    )
    payload["saved_count"] = saved_count
    payload["is_saved_by_me"] = is_saved_by_me
    payload["saved_copy_id"] = saved_copy_id
    payload["tracks"] = track_payloads
    return payload


@router.put(
    "/{playlist_id}",
    summary="Update playlist",
    description="Updates playlist metadata such as title, description, visibility, and collaboration settings.",
)
async def update_playlist(
    playlist_id: int,
    body: PlaylistUpdateRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    playlist = await db.get(Playlist, playlist_id)
    if not playlist:
        raise HTTPException(status_code=404, detail="Playlist not found")
    if playlist.owner_id != current_user.id:
        raise HTTPException(status_code=403, detail="Only owner can update playlist")

    update_data = body.model_dump(exclude_none=True)
    if "is_collaborative" in update_data and not update_data["is_collaborative"]:
        update_data["collab_user_id"] = None
    for field, value in update_data.items():
        setattr(playlist, field, value)

    await db.commit()
    await db.refresh(playlist)
    track_count = await db.scalar(
        select(func.count(PlaylistTrack.id)).where(PlaylistTrack.playlist_id == playlist.id)
    )
    payload = _playlist_payload(playlist, track_count=track_count or 0)
    payload = await _attach_owner_metadata(payload, db, playlist=playlist)
    saved_count, is_saved_by_me, saved_copy_id = await _saved_copy_metadata(
        db,
        playlist=playlist,
        current_user=current_user,
    )
    payload["saved_count"] = saved_count
    payload["is_saved_by_me"] = is_saved_by_me
    payload["saved_copy_id"] = saved_copy_id
    return payload


@router.delete(
    "/{playlist_id}",
    status_code=204,
    summary="Delete playlist",
    description="Deletes a playlist owned by the authenticated user.",
)
async def delete_playlist(
    playlist_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    playlist = await db.get(Playlist, playlist_id)
    if not playlist:
        raise HTTPException(status_code=404, detail="Playlist not found")
    if playlist.owner_id != current_user.id:
        raise HTTPException(status_code=403, detail="Only owner can delete playlist")
    await db.delete(playlist)
    await db.commit()


@router.post(
    "/{playlist_id}/tracks",
    status_code=201,
    summary="Add track to playlist",
    description="Adds a track to a playlist, caching track metadata if needed and notifying collaborators when relevant.",
)
async def add_track_to_playlist(
    playlist_id: int,
    body: AddTrackRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    playlist = await db.get(Playlist, playlist_id)
    if not playlist:
        raise HTTPException(status_code=404, detail="Playlist not found")
    if not _has_playlist_access(playlist, current_user.id):
        raise HTTPException(status_code=403, detail="No access to this playlist")

    duplicate = await db.scalar(
        select(PlaylistTrack).where(
            PlaylistTrack.playlist_id == playlist_id,
            PlaylistTrack.spotify_track_id == body.spotify_track_id,
        )
    )
    if duplicate:
        raise HTTPException(status_code=400, detail="Track already in playlist")

    cached_track = await db.scalar(select(TrackCache).where(TrackCache.spotify_id == body.spotify_track_id))
    if not cached_track:
        db.add(
            TrackCache(
                spotify_id=body.spotify_track_id,
                title=body.title,
                artist=body.artist,
                album=body.album,
                cover_url=body.cover_url,
                preview_url=body.preview_url,
                duration_ms=body.duration_ms,
                genres=[body.genre] if body.genre else [],
                audio_features={},
            )
        )

    track_count = await db.scalar(
        select(func.count(PlaylistTrack.id)).where(PlaylistTrack.playlist_id == playlist_id)
    )
    db.add(
        PlaylistTrack(
            playlist_id=playlist_id,
            spotify_track_id=body.spotify_track_id,
            position=int(track_count or 0),
        )
    )
    await db.commit()

    # Collaborative notification to partner.
    if playlist.is_collaborative and playlist.collab_user_id and playlist.collab_user_id != current_user.id:
        partner = await db.get(User, playlist.collab_user_id)
        await firebase_svc.send_push_notification(
            token=partner.fcm_token if partner else None,
            title="Track added",
            body=f"{current_user.username} added a track to {playlist.title}",
            data={"event": "collab_track_added", "playlist_id": playlist.id},
        )

    return {"ok": True}


@router.delete(
    "/{playlist_id}/tracks/{spotify_track_id}",
    status_code=204,
    summary="Remove track from playlist",
    description="Removes a track from a playlist when the requester has playlist access.",
)
async def remove_track_from_playlist(
    playlist_id: int,
    spotify_track_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    playlist = await db.get(Playlist, playlist_id)
    if not playlist:
        raise HTTPException(status_code=404, detail="Playlist not found")
    if not _has_playlist_access(playlist, current_user.id):
        raise HTTPException(status_code=403, detail="No access to this playlist")

    playlist_track = await db.scalar(
        select(PlaylistTrack).where(
            PlaylistTrack.playlist_id == playlist_id,
            PlaylistTrack.spotify_track_id == spotify_track_id,
        )
    )
    if not playlist_track:
        raise HTTPException(status_code=404, detail="Track not found in playlist")

    await db.delete(playlist_track)
    await db.commit()


@router.post(
    "/{playlist_id}/collaborate",
    summary="Add playlist collaborator",
    description="Enables collaboration on a playlist and sends a push notification to the invited user.",
)
async def set_collaborator(
    playlist_id: int,
    body: CollaborateRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    playlist = await db.get(Playlist, playlist_id)
    if not playlist:
        raise HTTPException(status_code=404, detail="Playlist not found")
    if playlist.owner_id != current_user.id:
        raise HTTPException(status_code=403, detail="Only owner can update collaborator")
    if body.collab_user_id == current_user.id:
        raise HTTPException(status_code=400, detail="Owner cannot be collaborator")

    partner = await db.get(User, body.collab_user_id)
    if not partner:
        raise HTTPException(status_code=404, detail="Collaborator not found")

    playlist.is_collaborative = True
    playlist.collab_user_id = body.collab_user_id
    await db.commit()
    await db.refresh(playlist)

    await firebase_svc.send_push_notification(
        token=partner.fcm_token,
        title="Playlist collaboration",
        body=f"{current_user.username} invited you to collaborate on {playlist.title}",
        data={"event": "playlist_collaboration", "playlist_id": playlist.id},
    )
    track_count = await db.scalar(
        select(func.count(PlaylistTrack.id)).where(PlaylistTrack.playlist_id == playlist.id)
    )
    return _playlist_payload(playlist, track_count=track_count or 0)
