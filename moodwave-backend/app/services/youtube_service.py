import httpx
import logging

from app.config import settings

logger = logging.getLogger(__name__)


async def search_video_id(title: str, artist: str) -> str | None:
    """Find YouTube video ID for a track. Tries multiple query strategies."""
    if not settings.YOUTUBE_API_KEY:
        return None

    queries = [
        f"{title} {artist} official audio",
        f"{title} {artist} audio",
        f"{title} {artist}",
        f"{artist} {title}",  # reversed order helps for some CIS artists
    ]

    async with httpx.AsyncClient(timeout=8) as client:
        for query in queries:
            try:
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
                        video_id = items[0]["id"]["videoId"]
                        logger.debug(
                            "YouTube found videoId=%s via query=%r", video_id, query
                        )
                        return video_id
                elif resp.status_code == 403:
                    # Quota exceeded — stop trying
                    logger.warning("YouTube API quota exceeded")
                    return None
            except Exception as e:
                logger.error("YouTube search error for query=%r: %s", query, e)

    # Last resort: search without music category filter
    try:
        async with httpx.AsyncClient(timeout=8) as client:
            resp = await client.get(
                "https://www.googleapis.com/youtube/v3/search",
                params={
                    "part": "snippet",
                    "q": f"{title} {artist}",
                    "type": "video",
                    "maxResults": 3,
                    "key": settings.YOUTUBE_API_KEY,
                },
            )
            if resp.status_code == 200:
                items = resp.json().get("items", [])
                if items:
                    return items[0]["id"]["videoId"]
    except Exception as e:
        logger.error("YouTube fallback search error: %s", e)

    return None
