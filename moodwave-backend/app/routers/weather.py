from __future__ import annotations

import json

import httpx
from fastapi import APIRouter, Depends, HTTPException, Query, Request

from app.dependencies import get_current_user
from app.models.user import User
from app.services.weather import get_weather

router = APIRouter()

WEATHER_PLAYLIST_CACHE_TTL = 1800
WEATHER_LISTENER_TTL = 1800

WEATHER_PLAYLISTS = {
    "clear": [
        ("Summer Hits", "Bright tracks for sunny weather", "37i9dQZF1DX1BzILRveYHb"),
        ("Sunny Vibes", "Warm and uplifting daytime songs", "37i9dQZF1DX0UrRvztWcAU"),
        ("Feel Good", "Positive pop and feel-good anthems", "37i9dQZF1DXdPec7aLTmlC"),
    ],
    "rain": [
        ("Rainy Day", "Soft songs for rainy moods", "37i9dQZF1DXbvABJXBIyiY"),
        ("Melancholy Mix", "Emotional and introspective picks", "37i9dQZF1DX3YSRoSdA634"),
        ("Cozy Indoor", "Warm indoor listening set", "37i9dQZF1DX4E3UdUs7fUx"),
    ],
    "snow": [
        ("Snow Day", "Comforting tracks for winter weather", "37i9dQZF1DWUNIrSzKgQbP"),
        ("Winter Night Drive", "Late night winter drive soundtrack", "37i9dQZF1DX4WYpdgoIcn6"),
        ("Indoor Warmth", "Calm and cozy room vibes", "37i9dQZF1DX9uKNf5jGX6m"),
    ],
    "clouds": [
        ("Cloud Nine", "Light and dreamy cloudy-day mix", "37i9dQZF1DXdbXrPNafg9d"),
        ("Mellow Mood", "Mellow and easy listening blend", "37i9dQZF1DX889U0CL85jj"),
        ("Grey Sky Blues", "Soulful songs for overcast hours", "37i9dQZF1DX7qK8ma5wgG1"),
    ],
}


@router.get(
    "/cities/search",
    summary="Search cities",
    description="Proxies city search through the backend so the Flutter web app avoids browser CORS issues.",
)
async def search_cities(
    q: str = Query(..., min_length=2),
):
    uri = (
        "https://nominatim.openstreetmap.org/search"
        f"?q={httpx.QueryParams({'q': q})['q']}"
        "&format=json"
        "&addressdetails=1"
        "&limit=12"
        "&featuretype=city"
        "&accept-language=en"
    )
    try:
        async with httpx.AsyncClient(timeout=8, follow_redirects=True) as client:
            response = await client.get(
                uri,
                headers={
                    "User-Agent": "MoodWave/1.0 (diplom project)",
                    "Accept": "application/json",
                },
            )
            response.raise_for_status()
    except Exception:
        raise HTTPException(status_code=503, detail="City search unavailable")

    data = response.json()
    cities: list[str] = []
    seen: set[str] = set()

    for item in data:
        addr = item.get("address") or {}
        name = (
            addr.get("city")
            or addr.get("town")
            or addr.get("village")
            or addr.get("hamlet")
            or str(item.get("display_name", "")).split(",")[0].strip()
        )
        if name and name not in seen:
            seen.add(name)
            cities.append(name)

    return {"cities": cities}


def _playlist_payloads(condition: str) -> list[dict]:
    normalized = condition.lower()
    if normalized in {"drizzle", "thunderstorm", "mist", "fog"}:
        normalized = "rain" if normalized in {"drizzle", "thunderstorm"} else "clouds"
    rows = WEATHER_PLAYLISTS.get(normalized, WEATHER_PLAYLISTS["clouds"])
    payload = []
    for name, description, playlist_id in rows:
        payload.append(
            {
                "name": name,
                "description": description,
                "spotify_playlist_id": playlist_id,
                "track_count": 50,
                "cover_url": f"https://i.scdn.co/image/{playlist_id}",
            }
        )
    return payload


async def _listeners_count(redis, city: str) -> int:
    return await redis.scard(f"weather:listeners:{city.lower()}")


@router.get(
    "/current",
    summary="Get current weather",
    description="Returns current weather details, a mood tag, and the listener count for the requested city.",
)
async def weather_current(
    city: str = Query(...),
    request: Request = None,
    current_user: User = Depends(get_current_user),
):
    redis = request.app.state.redis
    try:
        weather = await get_weather(city, redis)
    except ValueError:
        raise HTTPException(status_code=404, detail="City not found")
    except Exception:
        cached = await redis.get(f"weather:{city.lower()}")
        if cached:
            weather = json.loads(cached)
        else:
            raise HTTPException(status_code=503, detail="Weather service unavailable")

    return {
        **weather,
        "listeners_count": await _listeners_count(redis, weather["city"]),
    }


@router.get(
    "/playlist",
    summary="Get weather playlists",
    description="Returns three playlist suggestions based on current weather conditions and tracks active listeners for the city.",
)
async def weather_playlist(
    city: str = Query(...),
    request: Request = None,
    current_user: User = Depends(get_current_user),
):
    redis = request.app.state.redis
    cache_key = f"weather:playlist:{city.lower()}"
    cached = await redis.get(cache_key)
    if cached:
        payload = json.loads(cached)
    else:
        try:
            weather = await get_weather(city, redis)
        except ValueError:
            raise HTTPException(status_code=404, detail="City not found")
        except Exception:
            fallback = await redis.get(f"weather:{city.lower()}")
            if not fallback:
                raise HTTPException(status_code=503, detail="Weather service unavailable")
            weather = json.loads(fallback)

        playlists = _playlist_payloads(weather["condition"])
        payload = {"city": weather["city"], "condition": weather["condition"], "playlists": playlists}
        await redis.setex(cache_key, WEATHER_PLAYLIST_CACHE_TTL, json.dumps(payload))

    # User is considered actively listening weather playlists.
    listener_key = f"weather:listeners:{payload['city'].lower()}"
    await redis.sadd(listener_key, current_user.id)
    await redis.expire(listener_key, WEATHER_LISTENER_TTL)

    return {
        **payload,
        "listeners_count": await _listeners_count(redis, payload["city"]),
    }
