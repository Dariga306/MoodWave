import base64
import hashlib
import hmac
import json
import logging
import os
import urllib.parse
from datetime import datetime, timedelta
from typing import Optional

import httpx
from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import RedirectResponse
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.dependencies import get_current_user, get_db
from app.models.user import User

logger = logging.getLogger(__name__)
router = APIRouter()

_AUTHORIZE_URL = "https://accounts.spotify.com/authorize"
_TOKEN_URL = "https://accounts.spotify.com/api/token"
_SCOPES = (
    "streaming "
    "user-read-email "
    "user-read-private "
    "user-modify-playback-state "
    "user-read-playback-state "
    "user-library-read "
    "user-library-modify"
)

# Path for the shared "one Premium account for all" token file.
# When running: cd moodwave-backend && uvicorn app.main:app ...
# this resolves to moodwave-backend/tokens.json
_TOKENS_FILE = os.path.join(os.getcwd(), "tokens.json")


# ── state helpers ────────────────────────────────────────────────────────────

def _make_state(user_id: int) -> str:
    payload = json.dumps({"uid": user_id}).encode()
    sig = hmac.new(settings.SECRET_KEY.encode(), payload, hashlib.sha256).digest()
    return base64.urlsafe_b64encode(payload + b"|" + sig).decode().rstrip("=")


def _verify_state(state: str) -> int:
    try:
        raw = base64.urlsafe_b64decode(state + "==")
        payload, sig = raw.rsplit(b"|", 1)
        expected = hmac.new(settings.SECRET_KEY.encode(), payload, hashlib.sha256).digest()
        if not hmac.compare_digest(sig, expected):
            raise ValueError("bad sig")
        return json.loads(payload)["uid"]
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid OAuth state")


# ── token refresh helper ─────────────────────────────────────────────────────

async def _refresh_if_needed(user: User, db: AsyncSession) -> str:
    """Return a valid Spotify access token, refreshing if close to expiry."""
    expires = user.spotify_token_expires_at
    if expires and datetime.utcnow() < expires - timedelta(minutes=5):
        return user.spotify_access_token  # type: ignore[return-value]

    if not user.spotify_refresh_token:
        raise HTTPException(status_code=401, detail="Spotify token expired — please reconnect")

    async with httpx.AsyncClient(timeout=10) as client:
        resp = await client.post(
            _TOKEN_URL,
            data={"grant_type": "refresh_token", "refresh_token": user.spotify_refresh_token},
            auth=(settings.SPOTIFY_CLIENT_ID, settings.SPOTIFY_CLIENT_SECRET),
        )
    if resp.status_code != 200:
        raise HTTPException(status_code=401, detail="Failed to refresh Spotify token")

    data = resp.json()
    user.spotify_access_token = data["access_token"]
    user.spotify_token_expires_at = datetime.utcnow() + timedelta(seconds=data.get("expires_in", 3600))
    if "refresh_token" in data:
        user.spotify_refresh_token = data["refresh_token"]
    db.add(user)
    await db.commit()
    return user.spotify_access_token  # type: ignore[return-value]


# ── endpoints ────────────────────────────────────────────────────────────────

@router.get("/auth/spotify/login", summary="Get Spotify OAuth URL (no auth required)")
async def spotify_login_url():
    """Return the Spotify authorization URL for one-time setup (no MoodWave login required).

    Use this to connect a shared Spotify Premium account. Tokens will be stored
    in tokens.json and shared across all users for playback.
    Open the returned URL in a browser, log in with the Premium account, allow
    access, and the tokens will be saved automatically.
    """
    if not settings.SPOTIFY_CLIENT_ID:
        raise HTTPException(status_code=503, detail="Spotify not configured")

    params = {
        "client_id": settings.SPOTIFY_CLIENT_ID,
        "response_type": "code",
        "redirect_uri": settings.SPOTIFY_REDIRECT_URI,
        "scope": _SCOPES,
        "show_dialog": "false",
    }
    return {"url": _AUTHORIZE_URL + "?" + urllib.parse.urlencode(params)}


@router.get("/auth/spotify", summary="Get Spotify OAuth URL (requires MoodWave login)")
async def spotify_auth_url(current_user: User = Depends(get_current_user)):
    """Return the Spotify authorization URL the frontend should redirect to.
    Tokens are stored per-user in the database.
    """
    if not settings.SPOTIFY_CLIENT_ID:
        raise HTTPException(status_code=503, detail="Spotify not configured")

    params = {
        "client_id": settings.SPOTIFY_CLIENT_ID,
        "response_type": "code",
        "redirect_uri": settings.SPOTIFY_REDIRECT_URI,
        "scope": _SCOPES,
        "state": _make_state(current_user.id),
        "show_dialog": "false",
    }
    return {"url": _AUTHORIZE_URL + "?" + urllib.parse.urlencode(params)}


@router.get("/auth/spotify/callback", summary="Spotify OAuth callback")
async def spotify_callback(
    code: str,
    state: Optional[str] = None,
    db: AsyncSession = Depends(get_db),
):
    """Handle redirect from Spotify after the user grants permission.

    - With state → per-user flow: stores tokens in the user's DB record.
    - Without state → shared flow: stores tokens in tokens.json.
    """
    async with httpx.AsyncClient(timeout=10) as client:
        resp = await client.post(
            _TOKEN_URL,
            data={
                "grant_type": "authorization_code",
                "code": code,
                "redirect_uri": settings.SPOTIFY_REDIRECT_URI,
            },
            auth=(settings.SPOTIFY_CLIENT_ID, settings.SPOTIFY_CLIENT_SECRET),
        )

    if resp.status_code != 200:
        logger.error("Spotify token exchange failed: %s %s", resp.status_code, resp.text)
        return RedirectResponse(url=settings.FRONTEND_URL + "?spotify=error")

    data = resp.json()
    import time as _time
    import json as _json

    if state:
        # Per-user flow: store tokens in DB
        user_id = _verify_state(state)
        user: User | None = await db.get(User, user_id)
        if not user:
            raise HTTPException(status_code=404, detail="User not found")
        user.spotify_access_token = data["access_token"]
        user.spotify_refresh_token = data.get("refresh_token")
        user.spotify_token_expires_at = datetime.utcnow() + timedelta(seconds=data.get("expires_in", 3600))
        db.add(user)
        await db.commit()
        logger.info("Spotify connected for user %d", user_id)
    else:
        # Shared flow: store tokens in tokens.json
        tokens = {
            "access_token": data["access_token"],
            "refresh_token": data.get("refresh_token"),
            "expires_at": _time.time() + data.get("expires_in", 3600),
        }
        with open(_TOKENS_FILE, "w") as f:
            _json.dump(tokens, f)
        logger.info("Spotify shared token saved to tokens.json")

    return RedirectResponse(url=settings.FRONTEND_URL + "?spotify=connected")


@router.get("/spotify/token", summary="Get current Spotify access token")
async def get_spotify_token(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Return a valid Spotify access token for the Web Playback SDK.

    Tries per-user token first; falls back to shared tokens.json.
    """
    import json as _json
    import time as _time

    # 1. Try per-user token from DB
    if current_user.spotify_access_token:
        token = await _refresh_if_needed(current_user, db)
        expires = current_user.spotify_token_expires_at
        seconds_left = int((expires - datetime.utcnow()).total_seconds()) if expires else 3600
        return {"access_token": token, "expires_in": max(seconds_left, 0)}

    # 2. Fall back to shared tokens.json
    if os.path.exists(_TOKENS_FILE):
        with open(_TOKENS_FILE) as f:
            tokens = _json.load(f)
        access_token = tokens.get("access_token")
        expires_at = tokens.get("expires_at", 0)
        refresh_token = tokens.get("refresh_token")

        # Refresh if expired
        if _time.time() >= expires_at - 60 and refresh_token:
            async with httpx.AsyncClient(timeout=10) as client:
                resp = await client.post(
                    _TOKEN_URL,
                    data={"grant_type": "refresh_token", "refresh_token": refresh_token},
                    auth=(settings.SPOTIFY_CLIENT_ID, settings.SPOTIFY_CLIENT_SECRET),
                )
            if resp.status_code == 200:
                data = resp.json()
                access_token = data["access_token"]
                expires_at = _time.time() + data.get("expires_in", 3600)
                tokens["access_token"] = access_token
                tokens["expires_at"] = expires_at
                if "refresh_token" in data:
                    tokens["refresh_token"] = data["refresh_token"]
                with open(_TOKENS_FILE, "w") as f:
                    _json.dump(tokens, f)

        if access_token:
            seconds_left = int(expires_at - _time.time())
            return {"access_token": access_token, "expires_in": max(seconds_left, 0)}

    raise HTTPException(status_code=404, detail="Spotify not connected")


@router.delete("/spotify/disconnect", summary="Disconnect Spotify")
async def disconnect_spotify(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    current_user.spotify_access_token = None
    current_user.spotify_refresh_token = None
    current_user.spotify_token_expires_at = None
    db.add(current_user)
    await db.commit()
    return {"detail": "Spotify disconnected"}
