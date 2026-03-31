from __future__ import annotations

import json
import logging
from typing import Optional

import httpx

from app.config import settings

logger = logging.getLogger(__name__)

WEATHER_CACHE_TTL = 1800
FALLBACK_WEATHER = {
    "astana": {
        "city": "Astana",
        "temp": -4,
        "condition": "snow",
        "icon": "13d",
        "description": "light snow",
        "mood_tag": "cozy",
    }
}
CITY_NAME_ALIASES = {
    "astana": "Astana",
    "nur-sultan": "Astana",
}

WEATHER_TO_MOOD = {
    "clear": "energetic",
    "clouds": "chill",
    "rain": "melancholy",
    "drizzle": "melancholy",
    "snow": "cozy",
    "thunderstorm": "intense",
    "mist": "dreamy",
    "fog": "dreamy",
}


def map_weather_to_mood_tag(condition: str) -> str:
    return WEATHER_TO_MOOD.get(condition.lower(), "chill")


def _normalize_city_name(requested_city: str, upstream_city: str | None = None) -> str:
    requested_key = requested_city.strip().lower()
    if requested_key in CITY_NAME_ALIASES:
        return CITY_NAME_ALIASES[requested_key]

    upstream_key = (upstream_city or "").strip().lower()
    if upstream_key in CITY_NAME_ALIASES:
        return CITY_NAME_ALIASES[upstream_key]

    return (upstream_city or requested_city).strip().title()


async def get_weather(city: str, redis) -> dict:
    cache_key = f"weather:{city.lower()}"
    cached = await redis.get(cache_key)
    if cached:
        return json.loads(cached)

    if not settings.OPENWEATHER_API_KEY:
        result = FALLBACK_WEATHER.get(
            city.lower(),
            {
                "city": _normalize_city_name(city),
                "temp": 20,
                "condition": "clear",
                "icon": "01d",
                "description": "clear sky",
                "mood_tag": "energetic",
            },
        )
        await redis.setex(cache_key, WEATHER_CACHE_TTL, json.dumps(result))
        return result

    url = "https://api.openweathermap.org/data/2.5/weather"
    params = {"q": city, "appid": settings.OPENWEATHER_API_KEY, "units": "metric"}

    try:
        async with httpx.AsyncClient(timeout=10) as client:
            response = await client.get(url, params=params)
    except httpx.HTTPError:
        if cached:
            return json.loads(cached)
        raise

    if response.status_code == 404:
        raise ValueError("CITY_NOT_FOUND")
    if response.status_code >= 500:
        if cached:
            return json.loads(cached)
        raise RuntimeError("WEATHER_UPSTREAM_DOWN")
    response.raise_for_status()

    data = response.json()
    condition = str(data["weather"][0]["main"]).lower()
    result = {
        "city": _normalize_city_name(city, str(data.get("name", city))),
        "temp": data["main"]["temp"],
        "condition": condition,
        "icon": data["weather"][0]["icon"],
        "description": data["weather"][0]["description"],
        "mood_tag": map_weather_to_mood_tag(condition),
    }
    await redis.setex(cache_key, WEATHER_CACHE_TTL, json.dumps(result))
    return result
