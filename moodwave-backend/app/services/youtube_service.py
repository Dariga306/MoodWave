import asyncio
import logging
import os
import subprocess
import sys

logger = logging.getLogger(__name__)


def _yt_dlp_exe() -> str:
    """Return path to yt-dlp executable, preferring the venv's copy."""
    scripts_dir = os.path.dirname(sys.executable)
    candidate = os.path.join(scripts_dir, "yt-dlp.exe" if sys.platform == "win32" else "yt-dlp")
    return candidate if os.path.isfile(candidate) else "yt-dlp"


async def search_video_id(title: str, artist: str) -> str | None:
    """Search YouTube using yt-dlp subprocess (no API key needed)."""
    queries = [
        f"{title} {artist} official audio",
        f"{title} {artist}",
    ]
    loop = asyncio.get_event_loop()
    for query in queries:
        video_id = await loop.run_in_executor(None, _ytdlp_subprocess, query)
        if video_id:
            return video_id
    return None


def _ytdlp_subprocess(query: str) -> str | None:
    try:
        result = subprocess.run(
            [
                _yt_dlp_exe(),
                "--no-playlist",
                "--get-id",
                "--no-warnings",
                "--quiet",
                "--no-check-certificates",
                f"ytsearch1:{query}",
            ],
            capture_output=True,
            text=True,
            timeout=15,
        )
        output = result.stdout.strip()
        first_line = output.split("\n")[0].strip() if output else ""
        if len(first_line) == 11:
            logger.debug("yt-dlp found videoId=%s for query=%r", first_line, query)
            return first_line
    except subprocess.TimeoutExpired:
        logger.warning("yt-dlp subprocess timeout for query=%r", query)
    except Exception as e:
        logger.error("yt-dlp subprocess error for query=%r: %s", query, e)
    return None
