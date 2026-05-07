import asyncio
import json
import logging
import os
import re
import subprocess
import sys
import urllib.parse
import unicodedata

import httpx

logger = logging.getLogger(__name__)


def _yt_dlp_exe() -> str:
    """Return path to yt-dlp executable, preferring the venv's copy."""
    scripts_dir = os.path.dirname(sys.executable)
    candidate = os.path.join(scripts_dir, "yt-dlp.exe" if sys.platform == "win32" else "yt-dlp")
    return candidate if os.path.isfile(candidate) else "yt-dlp"


async def search_video_id(title: str, artist: str) -> str | None:
    """Search YouTube: HTML scraping first (fast ~1-2s), yt-dlp as fallback."""
    primary_query = f"{artist} {title}"
    fallback_queries = [
        f"{artist} {title} official audio",
        f"{title} {artist}",
        f"{title} {artist} official audio",
    ]

    loop = asyncio.get_running_loop()

    # Fast path: run HTML search and yt-dlp in parallel, return whichever wins
    html_task = asyncio.create_task(_youtube_html_search(primary_query))
    ytdlp_future = loop.run_in_executor(
        None, _ytdlp_subprocess, primary_query, title, artist
    )

    # Wait for HTML result first (usually 1-2s)
    try:
        html_id = await asyncio.wait_for(asyncio.shield(html_task), timeout=3.0)
        if html_id:
            ytdlp_future.cancel()
            return html_id
    except (asyncio.TimeoutError, asyncio.CancelledError):
        pass

    # Wait for yt-dlp (higher quality scoring)
    try:
        ytdlp_id = await asyncio.wait_for(asyncio.wrap_future(ytdlp_future), timeout=20.0)
        if ytdlp_id:
            return ytdlp_id
    except (asyncio.TimeoutError, Exception):
        pass

    # Check if HTML search finished by now
    try:
        html_id = await asyncio.wait_for(html_task, timeout=2.0)
        if html_id:
            return html_id
    except (asyncio.TimeoutError, asyncio.CancelledError):
        pass

    # Fallback queries
    for query in fallback_queries:
        video_id = await _youtube_html_search(query)
        if video_id:
            return video_id

    return None


def _normalize_text(value: str) -> str:
    value = unicodedata.normalize("NFKC", value or "").lower()
    value = value.replace("&", " and ")
    value = re.sub(r"\((official|audio|lyrics?|video|visualizer|hd|4k|live|remaster.*?)\)", " ", value)
    value = re.sub(r"\[(official|audio|lyrics?|video|visualizer|hd|4k|live|remaster.*?)\]", " ", value)
    value = re.sub(r"[^a-z0-9а-яё]+", " ", value)
    return re.sub(r"\s+", " ", value).strip()


def _tokenize(value: str) -> set[str]:
    return {token for token in _normalize_text(value).split() if token}


def _score_entry(entry: dict, title: str, artist: str) -> int:
    candidate_title = (entry.get("title") or "").strip()
    candidate_channel = (entry.get("channel") or entry.get("uploader") or "").strip()
    normalized_candidate = _normalize_text(f"{candidate_title} {candidate_channel}")
    title_tokens = _tokenize(title)
    artist_tokens = _tokenize(artist)

    score = 0

    if title_tokens:
        matched = len(title_tokens & set(normalized_candidate.split()))
        score += matched * 45
        if matched == len(title_tokens):
            score += 160

    if artist_tokens:
        matched = len(artist_tokens & set(normalized_candidate.split()))
        score += matched * 60
        if matched == len(artist_tokens):
            score += 220

    title_norm = _normalize_text(title)
    artist_norm = _normalize_text(artist)
    if title_norm and title_norm in _normalize_text(candidate_title):
        score += 120
    if artist_norm and (
        artist_norm in _normalize_text(candidate_title)
        or artist_norm in _normalize_text(candidate_channel)
    ):
        score += 150

    lowered = candidate_title.lower()
    if "official audio" in lowered:
        score += 180
    elif "audio" in lowered:
        score += 120
    if "lyrics" in lowered:
        score -= 90
    if "live" in lowered:
        score -= 140
    if "karaoke" in lowered or "cover" in lowered:
        score -= 180
    if entry.get("channel_is_verified"):
        score += 40

    duration = entry.get("duration")
    if isinstance(duration, (int, float)):
        if 75 <= duration <= 600:
            score += 30
        else:
            score -= 120

    return score


def _ytdlp_subprocess(query: str, title: str, artist: str) -> str | None:
    try:
        result = subprocess.run(
            [
                _yt_dlp_exe(),
                "--dump-single-json",
                "--flat-playlist",
                "--no-warnings",
                "--quiet",
                "--no-check-certificates",
                f"ytsearch5:{query}",
            ],
            capture_output=True,
            text=True,
            timeout=20,
        )
        if result.returncode != 0:
            logger.warning(
                "yt-dlp returned code %s for query=%r stderr=%s",
                result.returncode,
                query,
                (result.stderr or "").strip()[:400],
            )
            return None

        payload = json.loads(result.stdout or "{}")
        entries = payload.get("entries") if isinstance(payload, dict) else None
        if not isinstance(entries, list):
            return None

        scored_entries = []
        for entry in entries:
            if not isinstance(entry, dict):
                continue
            video_id = (entry.get("id") or "").strip()
            if len(video_id) != 11:
                continue
            scored_entries.append((_score_entry(entry, title, artist), entry))

        if not scored_entries:
            return None

        scored_entries.sort(key=lambda item: item[0], reverse=True)
        best_score, best_entry = scored_entries[0]
        if best_score < 180:
            logger.warning("yt-dlp low-confidence result for query=%r score=%s", query, best_score)
            return None

        video_id = best_entry["id"].strip()
        logger.debug(
            "yt-dlp selected videoId=%s for query=%r title=%r score=%s",
            video_id,
            query,
            best_entry.get("title"),
            best_score,
        )
        return video_id
    except subprocess.TimeoutExpired:
        logger.warning("yt-dlp subprocess timeout for query=%r", query)
    except Exception as e:
        logger.error("yt-dlp subprocess error for query=%r: %s", query, e)
    return None


def _ytdlp_download_audio(video_id: str, audio_dir: str) -> str | None:
    """Download audio to audio_dir/{video_id}.m4a and return the file path."""
    import pathlib
    out_path = pathlib.Path(audio_dir) / f"{video_id}.m4a"
    if out_path.exists() and out_path.stat().st_size > 10_000:
        logger.debug("yt-dlp audio cache hit for videoId=%s", video_id)
        return str(out_path)

    out_path.parent.mkdir(parents=True, exist_ok=True)
    tmp_path = out_path.with_suffix(".tmp")
    try:
        result = subprocess.run(
            [
                _yt_dlp_exe(),
                "--no-warnings",
                "--quiet",
                "--no-check-certificates",
                "-f", "140/bestaudio[ext=m4a]/bestaudio",
                "-o", str(tmp_path),
                f"https://www.youtube.com/watch?v={video_id}",
            ],
            capture_output=True,
            text=True,
            timeout=120,
        )
        if result.returncode == 0 and tmp_path.exists() and tmp_path.stat().st_size > 10_000:
            tmp_path.rename(out_path)
            logger.info("yt-dlp downloaded audio for videoId=%s → %s", video_id, out_path)
            return str(out_path)
        logger.warning(
            "yt-dlp download failed videoId=%s code=%s stderr=%s",
            video_id, result.returncode, (result.stderr or "").strip()[:300],
        )
    except subprocess.TimeoutExpired:
        logger.warning("yt-dlp download timeout videoId=%s", video_id)
    except Exception as exc:
        logger.error("yt-dlp download error videoId=%s: %s", video_id, exc)
    finally:
        if tmp_path.exists():
            tmp_path.unlink(missing_ok=True)
    return None


async def download_audio(video_id: str, audio_dir: str) -> str | None:
    """Async wrapper — downloads audio file and returns local path."""
    loop = asyncio.get_running_loop()
    return await loop.run_in_executor(None, _ytdlp_download_audio, video_id, audio_dir)


async def _youtube_html_search(query: str) -> str | None:
    """Dependency-free fallback when yt-dlp is unavailable on the host."""
    search_url = (
        "https://www.youtube.com/results?search_query="
        f"{urllib.parse.quote_plus(query)}"
    )
    headers = {
        "User-Agent": (
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
            "AppleWebKit/537.36 (KHTML, like Gecko) "
            "Chrome/124.0 Safari/537.36"
        ),
        "Accept-Language": "en-US,en;q=0.9",
    }
    try:
        async with httpx.AsyncClient(
            timeout=15,
            follow_redirects=True,
            headers=headers,
        ) as client:
            response = await client.get(search_url)
        if response.status_code != 200:
            logger.warning(
                "YouTube HTML search returned %s for query=%r",
                response.status_code,
                query,
            )
            return None

        seen: set[str] = set()
        candidates = re.findall(r'"videoId":"([A-Za-z0-9_-]{11})"', response.text)
        for video_id in candidates:
            if video_id in seen:
                continue
            seen.add(video_id)
            return video_id
    except Exception as e:
        logger.warning("YouTube HTML fallback failed for query=%r: %s", query, e)
    return None
