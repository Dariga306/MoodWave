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
        "temp": -4.0,
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
    "partly_cloudy": "chill",
    "rain": "melancholy",
    "drizzle": "melancholy",
    "snow": "cozy",
    "thunderstorm": "intense",
    "mist": "dreamy",
    "fog": "dreamy",
}

CONDITION_LABELS = {
    "clear": "Sunny",
    "clouds": "Cloudy",
    "partly_cloudy": "Partly Cloudy",
    "rain": "Rainy",
    "drizzle": "Rainy",
    "snow": "Snow",
    "thunderstorm": "Storm",
    "storm": "Storm",
    "mist": "Misty",
    "fog": "Foggy",
    "haze": "Hazy",
    "smoke": "Smoky",
}


def condition_label(condition: str) -> str:
    return CONDITION_LABELS.get(condition.lower().strip(), condition.strip().title())


def main_weather_condition(condition: str, description: str = "", clouds_pct: int = 0) -> str:
    """Collapse upstream weather into the six UI scenarios used by the app."""
    c = condition.lower().strip()
    d = description.lower()
    if c == "clear":
        return "clear"
    if c in {"thunderstorm", "storm"} or "thunder" in d or "storm" in d:
        return "storm"
    if c in {"rain", "drizzle"} or "rain" in d or "drizzle" in d:
        return "rain"
    if c == "snow" or "snow" in d or "blizzard" in d:
        return "snow"
    if c in {"clouds", "mist", "fog", "haze", "smoke"}:
        if "few" in d or "scattered" in d or "broken" in d or 0 < clouds_pct < 85:
            return "partly_cloudy"
        return "clouds"
    return "clouds"


def cloud_subtype(description: str) -> str:
    """Derive a semantic cloud subtype from OpenWeatherMap description."""
    d = description.lower()
    if "overcast" in d:
        return "overcast"
    if "few" in d:
        return "few_clouds"
    if "scattered" in d:
        return "scattered"
    if "broken" in d:
        return "broken_clouds"
    if "mist" in d or "fog" in d or "haze" in d:
        return "misty"
    return "cloudy"


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
        data = json.loads(cached)
        # Ensure temp is always float (backfill stale int entries)
        if "temp" in data and not isinstance(data["temp"], float):
            data["temp"] = float(data["temp"]) if data["temp"] is not None else None
        if "condition" in data:
            data["condition"] = main_weather_condition(
                str(data.get("condition", "")),
                str(data.get("description", "")),
                int(data.get("clouds_pct", 0) or 0),
            )
        # Backfill condition_label for stale cache entries
        if "condition_label" not in data and "condition" in data:
            data["condition_label"] = condition_label(data["condition"])
        elif "condition" in data:
            data["condition_label"] = condition_label(data["condition"])
        return data

    if not settings.OPENWEATHER_API_KEY:
        result = FALLBACK_WEATHER.get(
            city.lower(),
            {
                "city": _normalize_city_name(city),
                "temp": 20.0,
                "condition": "clear",
                "icon": "01d",
                "description": "clear sky",
                "mood_tag": "energetic",
            },
        )
        result = dict(result)
        result["temp"] = float(result["temp"])
        result["condition"] = main_weather_condition(
            str(result.get("condition", "")),
            str(result.get("description", "")),
            int(result.get("clouds_pct", 0) or 0),
        )
        result["condition_label"] = condition_label(result["condition"])
        result["condition_subtype"] = cloud_subtype(result.get("description", ""))
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
    raw_condition = str(data["weather"][0]["main"]).lower()
    raw_description = str(data["weather"][0]["description"])
    clouds_pct = int(data.get("clouds", {}).get("all", 0))
    normalized_condition = main_weather_condition(
        raw_condition,
        raw_description,
        clouds_pct,
    )
    result = {
        "city": _normalize_city_name(city, str(data.get("name", city))),
        "temp": float(data["main"]["temp"]),
        "feels_like": float(data["main"].get("feels_like", data["main"]["temp"])),
        "humidity": int(data["main"].get("humidity", 0)),
        "wind_speed": float(data.get("wind", {}).get("speed", 0)),
        "condition": normalized_condition,
        "condition_label": condition_label(normalized_condition),
        "condition_subtype": cloud_subtype(raw_description),
        "icon": data["weather"][0]["icon"],
        "description": raw_description,
        "mood_tag": map_weather_to_mood_tag(normalized_condition),
        "clouds_pct": clouds_pct,
    }
    await redis.setex(cache_key, WEATHER_CACHE_TTL, json.dumps(result))
    return result
