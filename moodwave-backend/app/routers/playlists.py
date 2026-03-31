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

router = APIRouter()


class PlaylistCreateRequest(BaseModel):
    title: Optional[str] = Field(default=None, min_length=1, max_length=255)
    name: Optional[str] = Field(default=None, min_length=1, max_length=255)
    description: Optional[str] = Field(default=None, max_length=500)
    cover_url: Optional[str] = Field(default=None, max_length=2000)
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
    cover_url: Optional[str] = Field(default=None, max_length=2000)
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
        "title": playlist.title,
        "description": playlist.description,
        "cover_url": playlist.cover_url,
        "visibility": playlist.visibility.value,
        "is_collaborative": playlist.is_collaborative,
        "collab_user_id": playlist.collab_user_id,
        "track_count": track_count,
        "created_at": playlist.created_at.isoformat(),
    }


def _has_playlist_access(playlist: Playlist, user_id: int) -> bool:
    if playlist.owner_id == user_id:
        return True
    if playlist.is_collaborative and playlist.collab_user_id == user_id:
        return True
    return False


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
    return {"playlists": [_playlist_payload(pl, track_count=count) for pl, count in rows]}


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
    return {"playlists": [{k: v for k, v in item.items() if k != "score"} for item in ranked[:limit] if item["score"] > 0]}


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
    return _playlist_payload(playlist, track_count=0)


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

    if not _has_playlist_access(playlist, current_user.id):
        if playlist.visibility == PlaylistVisibility.private:
            raise HTTPException(status_code=403, detail="Access denied")

    await db.refresh(playlist, ["tracks"])
    payload = _playlist_payload(playlist, track_count=len(playlist.tracks))
    payload["tracks"] = [
        {
            "spotify_track_id": track.spotify_track_id,
            "position": track.position,
            "added_at": track.added_at.isoformat(),
        }
        for track in playlist.tracks
    ]
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
    return _playlist_payload(playlist, track_count=track_count or 0)


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
