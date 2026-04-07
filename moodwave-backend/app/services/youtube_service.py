import httpx
import logging

from app.config import settings

logger = logging.getLogger(__name__)


async def search_video_id(title: str, artist: str) -> str | None:
    """Find YouTube video ID for a track. Returns video_id or None."""
    if not settings.YOUTUBE_API_KEY:
        return None
    query = f"{title} {artist} official audio"
    try:
        async with httpx.AsyncClient(timeout=8) as client:
            resp = await client.get(
                "https://www.googleapis.com/youtube/v3/search",
                params={
                    "part": "snippet",
                    "q": query,
                    "type": "video",
                    "videoCategoryId": "10",  # Music category
                    "maxResults": 1,
                    "key": settings.YOUTUBE_API_KEY,
                },
            )
        if resp.status_code == 200:
            items = resp.json().get("items", [])
            if items:
                return items[0]["id"]["videoId"]
    except Exception as e:
        logger.error("YouTube search error: %s", e)
    return None
