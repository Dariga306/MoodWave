import asyncio
import json
import logging
import os
import re
import subprocess
import sys
import unicodedata

logger = logging.getLogger(__name__)


def _yt_dlp_exe() -> str:
    """Return path to yt-dlp executable, preferring the venv's copy."""
    scripts_dir = os.path.dirname(sys.executable)
    candidate = os.path.join(scripts_dir, "yt-dlp.exe" if sys.platform == "win32" else "yt-dlp")
    return candidate if os.path.isfile(candidate) else "yt-dlp"


async def search_video_id(title: str, artist: str) -> str | None:
    """Search YouTube using yt-dlp subprocess (no API key needed)."""
    queries = [
        f"{artist} {title}",
        f"{title} {artist}",
        f"{artist} {title} audio",
        f"{title} {artist} official audio",
    ]
    loop = asyncio.get_running_loop()
    for query in queries:
        video_id = await loop.run_in_executor(
            None,
            _ytdlp_subprocess,
            query,
            title,
            artist,
        )
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
