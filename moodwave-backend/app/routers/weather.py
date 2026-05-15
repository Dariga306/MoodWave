from __future__ import annotations

import datetime
import json

import httpx
from fastapi import APIRouter, Depends, HTTPException, Query, Request
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.dependencies import get_current_user, get_db
from app.models.user import User
from app.services.weather import get_weather, condition_label

router = APIRouter()

WEATHER_PLAYLIST_CACHE_TTL = 1800
WEATHER_LISTENER_TTL = 1800
# Bump version suffix whenever the cached payload schema changes, to bust stale Redis entries
_PLAYLIST_CACHE_VER = "v8"

# ─── Playlist catalogue ────────────────────────────────────────────────────────
# Tuple: (key, name, description, emoji, mood, track_count)

WEATHER_PLAYLISTS = {
    "clear": [
        ("sunrise-glow",    "Morning Energy",     "The perfect upbeat pop playlist to start your day right", "☀️", "sunny", 128),
        ("golden-hour",     "Windows Down",       "Indie & pop bangers for driving with the windows open", "🌇", "sunny", 116),
        ("summer-hits",     "Summer Anthems",      "The hottest pop & chart anthems for sunny days", "🌞", "energetic", 140),
        ("blue-sky",        "Good Vibes Only",    "High-energy feel-good tracks for clear skies", "🛼", "sunny", 108),
        ("daylight-vibes",  "Daytime Rotation",   "Easy radio-friendly pop from morning to golden hour", "✨", "chill", 124),
        ("clear-morning",   "Morning Coffee",     "Soft acoustic indie for slow sunny mornings", "☕", "chill", 102),
        ("city-sun",        "City Pop Groove",    "Japanese city-pop, funk & groovy urban vibes", "🏙️", "energetic", 115),
        ("weekend-radiance","Weekend Vibes",       "Carefree pop & indie for a bright free weekend", "💛", "sunny", 131),
        ("patio-dreams",    "Backyard Chill",     "Relaxed indie folk for a sunny afternoon outside", "🌼", "chill", 111),
        ("afterglow-pop",   "Golden Hour Synths", "Shimmering dream-pop and electro as the day turns gold", "🎧", "sunny", 122),
    ],
    "rain": [
        ("rainy-window",    "Rainy Day Feels",    "Soft indie & acoustic for grey skies and slow thoughts", "🌧️", "rainy", 118),
        ("midnight-rain",   "Midnight Drive",     "R&B and indie for late-night rainy city drives", "🚕", "melancholy", 124),
        ("cozy-indoor",     "Stay Inside",        "Warm acoustic and folk for a cozy day indoors", "🕯️", "cozy", 109),
        ("after-rain",      "After the Storm",    "Hopeful indie tracks — when the clouds start to clear", "☔", "melancholy", 121),
        ("storm-journal",   "Deep Focus",         "Introspective indie & piano for writing and thinking", "📖", "rainy", 106),
        ("grey-day-soul",   "Soul & Blues",       "Soulful R&B for heavy grey skies", "🖤", "melancholy", 113),
        ("cafe-rain",       "Cafe Playlist",      "Soft indie & acoustic for a coffee shop rainy afternoon", "☕", "rainy", 132),
        ("umbrella-walk",   "Slow Walk Home",     "Chill lo-fi beats for a slow rainy city walk", "🚶", "chill", 117),
        ("rain-pop",        "Emotional Pop",      "Sad pop anthems and heartfelt ballads for the rain", "💧", "rainy", 101),
        ("thunder-heart",   "Drama & Thunder",    "Cinematic and intense — when the sky breaks open", "⛈️", "stormy", 127),
    ],
    "snow": [
        ("snow-day",        "Snow Day",           "Soft melodies and indie for quiet white mornings", "❄️", "cozy", 124),
        ("winter-night-drive","Night Drive",      "Dark indie and atmospheric tracks for snowy night drives", "🌙", "cozy", 118),
        ("indoor-warmth",   "Cozy Inside",        "Jazz, indie and soul for staying warm indoors", "☕", "calm", 131),
        ("frosted-pop",     "Winter Pop",         "Cold air indie-pop with icy synths and bright hooks", "🧊", "calm", 108),
        ("snowfall-piano",  "Piano & Snow",       "Soft piano and classical pieces for watching it snow", "🎹", "calm", 104),
        ("midnight-frost",  "Late Night Winter",  "Dreamy electronic and ambient for frosty after-midnight", "🌌", "dreamy", 119),
        ("winter-letters",  "Bittersweet",        "Emotional indie ballads and singer-songwriter gems", "💌", "melancholy", 112),
        ("home-blanket",    "Under a Blanket",    "Gentle acoustic folk for warmth, tea, and soft light", "🧣", "cozy", 137),
        ("ice-lights",      "Frozen Lights",      "Shimmering electronic beats for cold clear winter nights", "💎", "calm", 103),
        ("quiet-december",  "Still December",     "Minimal and ambient — the quiet of a cold winter day", "🕊️", "cozy", 114),
    ],
    "clouds": [
        ("cloud-nine",      "Head in the Clouds", "Dreamy indie pop for a light overcast day", "☁️", "cloudy", 123),
        ("grey-sky-blues",  "Soul & Overcast",    "Soulful R&B and blues for heavy grey skies", "🌫️", "melancholy", 116),
        ("mellow-mood",     "Slow & Mellow",      "Easy R&B, soft pop and neo-soul for a slow day", "🫧", "chill", 111),
        ("soft-commute",    "Commute Chill",      "Calm indie and acoustic for your morning commute", "🚇", "chill", 102),
        ("floating-afternoon","Dream Pop",        "Shoegaze and dream-pop for a cloudy afternoon in bed", "🪁", "dreamy", 119),
        ("silver-light",    "Soft Focus",         "Bright indie pop for silver overcast afternoons", "🩶", "cloudy", 105),
        ("lazy-sunday-clouds","Day Off Vibes",     "Lo-fi hip-hop and chill beats for a slow cloudy day off", "🛋️", "chill", 129),
        ("window-seat",     "Study & Relax",      "Lo-fi and chill — perfect for studying or chilling out", "🪟", "cloudy", 113),
        ("blue-grey",       "Deep Atmosphere",    "Electronic and ambient for heavy, moody overcast skies", "🌁", "dreamy", 120),
        ("drift-state",     "Drift Away",         "Slow atmospheric and post-rock for a quiet grey day", "🌊", "cloudy", 118),
    ],
    "storm": [
        ("electric-sky",    "Storm Energy",       "High-voltage rock and electric pop for heavy weather", "⚡", "stormy", 132),
        ("aftershock",      "Dark Drive",         "Alternative and synth punk for dark stormy roads", "🛣️", "intense", 121),
        ("pressure-drop",   "Heavy Skies",        "Hard rock and alternative for serious storm energy", "🌩️", "stormy", 116),
        ("night-static",    "Night Static",       "Industrial electronic and dark synth under thunder", "📡", "intense", 109),
        ("loud-weather",    "Turn It Up",         "Loud rock, metal and alternative for heavy weather", "🥁", "stormy", 127),
        ("black-cloud-run", "Fast & Dark",        "Punk rock and hard alternative — run through the storm", "🏃", "intense", 114),
        ("neon-storm",      "Neon Nights",        "Dark synth-pop and electro for city storm nights", "🌃", "stormy", 123),
        ("signal-break",    "Post-Rock Signal",   "Experimental and post-rock for fractured heavy moods", "📻", "intense", 105),
        ("storm-window",    "Watch It Pass",      "Cinematic and dramatic — intense but beautiful", "🪟", "melancholy", 110),
        ("thunderline",     "Bass & Thunder",     "Electronic bass and drops that hit like thunder", "🎚️", "stormy", 119),
    ],
    "mist": [
        ("fog-lights",      "Fog & Dream",        "Dream pop and ethereal indie for hazy morning light", "🌫️", "foggy", 117),
        ("haze-walk",       "Misty Morning",      "Lo-fi and mellow beats for a soft hazy start", "🚶", "dreamy", 105),
        ("ghost-trails",    "Ethereal & Dark",    "Atmospheric and ambient for deep foggy moods", "👣", "dreamy", 122),
        ("quiet-signals",   "Minimal Ambient",    "Subtle electronic textures for a quiet misty day", "📶", "foggy", 113),
        ("silver-mist",     "Soft & Gentle",      "Dreamy soft pop and gentle indie for misty calm", "🩶", "calm", 108),
        ("soft-focus",      "Blur & Breathe",     "Shoegaze and fuzzy dream-pop for soft foggy mornings", "📷", "dreamy", 120),
        ("early-fog",       "Early Morning",      "Folk and acoustic for a quiet muted morning start", "🌁", "foggy", 111),
        ("moon-haze",       "Midnight Mist",      "Dreamy indie and night-time sounds through the fog", "🌙", "dreamy", 119),
        ("dim-city",        "City After Dark",    "Urban hip-hop and lo-fi for night city in the haze", "🏙️", "chill", 115),
        ("mist-room",       "Ambient Room",       "Warm ambient and instrumental for space to think", "🕯️", "calm", 124),
    ],
}

# ─── Per-playlist Deezer search queries (unique per playlist for variety) ──────

PLAYLIST_SEARCH_QUERIES: dict[str, str] = {
    # clear — upbeat, pop, feel-good
    "sunrise-glow":        "Dua Lipa",
    "golden-hour":         "Harry Styles",
    "summer-hits":         "Olivia Rodrigo",
    "blue-sky":            "Pharrell Williams",
    "daylight-vibes":      "Charlie Puth",
    "clear-morning":       "Ed Sheeran",
    "city-sun":            "Bruno Mars",
    "weekend-radiance":    "Taylor Swift",
    "patio-dreams":        "Jack Johnson",
    "afterglow-pop":       "The 1975",
    # rain — moody, emotional, soulful
    "rainy-window":        "Lana Del Rey",
    "midnight-rain":       "The Weeknd",
    "cozy-indoor":         "Bon Iver",
    "after-rain":          "Phoebe Bridgers",
    "storm-journal":       "Sufjan Stevens",
    "grey-day-soul":       "Amy Winehouse",
    "cafe-rain":           "Norah Jones",
    "umbrella-walk":       "Nujabes",
    "rain-pop":            "Billie Eilish",
    "thunder-heart":       "Linkin Park",
    # snow — cozy, calm, introspective
    "snow-day":            "Fleet Foxes",
    "winter-night-drive":  "Radiohead",
    "indoor-warmth":       "John Coltrane",
    "frosted-pop":         "Arcade Fire",
    "snowfall-piano":      "Ludovico Einaudi",
    "midnight-frost":      "Tycho",
    "winter-letters":      "Iron and Wine",
    "home-blanket":        "Jose Gonzalez",
    "ice-lights":          "Jon Hopkins",
    "quiet-december":      "Max Richter",
    # clouds — indie, dream pop, r&b
    "cloud-nine":          "Tame Impala",
    "grey-sky-blues":      "D'Angelo",
    "mellow-mood":         "Frank Ocean",
    "soft-commute":        "Mac DeMarco",
    "floating-afternoon":  "Beach House",
    "silver-light":        "Vampire Weekend",
    "lazy-sunday-clouds":  "lofi",
    "window-seat":         "Erykah Badu",
    "blue-grey":           "James Blake",
    "drift-state":         "Explosions in the Sky",
    # storm — rock, electronic, intense
    "electric-sky":        "Imagine Dragons",
    "aftershock":          "Twenty One Pilots",
    "pressure-drop":       "Muse",
    "night-static":        "Nine Inch Nails",
    "loud-weather":        "Metallica",
    "black-cloud-run":     "Green Day",
    "neon-storm":          "The Midnight",
    "signal-break":        "Mogwai",
    "storm-window":        "Hans Zimmer",
    "thunderline":         "Skrillex",
    # mist — ethereal, dreamy, atmospheric
    "fog-lights":          "Mazzy Star",
    "haze-walk":           "Chillhop Music",
    "ghost-trails":        "Portishead",
    "quiet-signals":       "Brian Eno",
    "silver-mist":         "Cigarettes After Sex",
    "soft-focus":          "My Bloody Valentine",
    "early-fog":           "Nick Drake",
    "moon-haze":           "Washed Out",
    "dim-city":            "J Cole",
    "mist-room":           "Nils Frahm",
}

# ─── 5 artists per playlist → frontend does 5 parallel searches → ~100 tracks ──

PLAYLIST_ARTIST_QUERIES: dict[str, list[str]] = {
    # clear — energetic, pop, feel-good
    "sunrise-glow":        ["Dua Lipa", "Lizzo", "Katy Perry", "Nicki Minaj", "Bebe Rexha"],
    "golden-hour":         ["Harry Styles", "Rex Orange County", "Conan Gray", "Omar Apollo", "Still Woozy"],
    "summer-hits":         ["Olivia Rodrigo", "Doja Cat", "Ariana Grande", "Justin Bieber", "Selena Gomez"],
    "blue-sky":            ["Pharrell Williams", "Bruno Mars", "Zara Larsson", "Sigrid", "Ava Max"],
    "daylight-vibes":      ["Charlie Puth", "Jason Derulo", "Maroon 5", "Shawn Mendes", "Camila Cabello"],
    "clear-morning":       ["Ed Sheeran", "James Arthur", "Sam Smith", "Lewis Capaldi", "Tom Odell"],
    "city-sun":            ["Bruno Mars", "Anderson Paak", "Janelle Monae", "Childish Gambino", "Khalid"],
    "weekend-radiance":    ["Taylor Swift", "Sabrina Carpenter", "Gracie Abrams", "Conan Gray", "girl in red"],
    "patio-dreams":        ["Jack Johnson", "Ben Harper", "Jason Mraz", "John Mayer", "Mat Kearney"],
    "afterglow-pop":       ["The 1975", "Glass Animals", "MGMT", "Phoenix", "Two Door Cinema Club"],
    # rain — moody, emotional, r&b
    "rainy-window":        ["Lana Del Rey", "Lorde", "Clairo", "Soccer Mommy", "beabadoobee"],
    "midnight-rain":       ["The Weeknd", "Drake", "SZA", "PARTYNEXTDOOR", "6LACK"],
    "cozy-indoor":         ["Bon Iver", "Fleet Foxes", "The National", "Sufjan Stevens", "Pinegrove"],
    "after-rain":          ["Phoebe Bridgers", "Julien Baker", "Lucy Dacus", "Angel Olsen", "Mitski"],
    "storm-journal":       ["Arvo Part", "Nick Cave", "Joanna Newsom", "Tim Hecker", "William Basinski"],
    "grey-day-soul":       ["Amy Winehouse", "Adele", "Sam Smith", "Duffy", "Corinne Bailey Rae"],
    "cafe-rain":           ["Norah Jones", "Diana Krall", "Feist", "Madeleine Peyroux", "Katie Melua"],
    "umbrella-walk":       ["Nujabes", "J Dilla", "Madlib", "Knxwledge", "Mick Jenkins"],
    "rain-pop":            ["Billie Eilish", "Olivia Rodrigo", "Gracie Abrams", "Remi Wolf", "Caroline Polachek"],
    "thunder-heart":       ["Linkin Park", "Imagine Dragons", "Twenty One Pilots", "Paramore", "Fall Out Boy"],
    # snow — cozy, calm, introspective
    "snow-day":            ["Fleet Foxes", "Sufjan Stevens", "Gregory Alan Isakov", "Wilco", "Iron and Wine"],
    "winter-night-drive":  ["Radiohead", "Thom Yorke", "Portishead", "Massive Attack", "Burial"],
    "indoor-warmth":       ["John Coltrane", "Miles Davis", "Bill Evans", "Thelonious Monk", "Herbie Hancock"],
    "frosted-pop":         ["Arcade Fire", "Tame Impala", "Unknown Mortal Orchestra", "Mac DeMarco", "Kurt Vile"],
    "snowfall-piano":      ["Ludovico Einaudi", "Max Richter", "Nils Frahm", "Olafur Arnalds", "Hauschka"],
    "midnight-frost":      ["Tycho", "Bonobo", "Emancipator", "Com Truise", "Washed Out"],
    "winter-letters":      ["Iron and Wine", "Jose Gonzalez", "Big Thief", "Adrianne Lenker", "Damien Rice"],
    "home-blanket":        ["Jose Gonzalez", "Gregory Alan Isakov", "Angus and Julia Stone", "Novo Amor", "Ben Howard"],
    "ice-lights":          ["Jon Hopkins", "Four Tet", "Rival Consoles", "Olafur Arnalds", "Kiasmos"],
    "quiet-december":      ["Max Richter", "Brian Eno", "Arvo Part", "Johann Johannsson", "Stars of the Lid"],
    # clouds — indie, dream pop, neo-soul
    "cloud-nine":          ["Tame Impala", "Beach House", "MGMT", "Unknown Mortal Orchestra", "Mild High Club"],
    "grey-sky-blues":      ["D'Angelo", "Maxwell", "Lauryn Hill", "Sade", "Angie Stone"],
    "mellow-mood":         ["Frank Ocean", "SZA", "Daniel Caesar", "H.E.R.", "Summer Walker"],
    "soft-commute":        ["Mac DeMarco", "Mild High Club", "Men I Trust", "Homeshake", "Alex G"],
    "floating-afternoon":  ["Beach House", "Galaxie 500", "Cocteau Twins", "Pale Saints", "Julee Cruise"],
    "silver-light":        ["Vampire Weekend", "Father John Misty", "Real Estate", "Beirut", "Rostam"],
    "lazy-sunday-clouds":  ["Khalid", "Rex Orange County", "Still Woozy", "Omar Apollo", "Dominic Fike"],
    "window-seat":         ["Erykah Badu", "Jill Scott", "India Arie", "Bilal", "Meshell Ndegeocello"],
    "blue-grey":           ["James Blake", "Bon Iver", "William Fitzsimmons", "Daughter", "Mt. Wolf"],
    "drift-state":         ["Explosions in the Sky", "Sigur Ros", "This Will Destroy You", "Mogwai", "65daysofstatic"],
    # storm — rock, electronic, intense
    "electric-sky":        ["Imagine Dragons", "Bastille", "X Ambassadors", "OneRepublic", "Halsey"],
    "aftershock":          ["Twenty One Pilots", "Panic at the Disco", "My Chemical Romance", "Fall Out Boy", "Paramore"],
    "pressure-drop":       ["Muse", "Queens of the Stone Age", "Foo Fighters", "Royal Blood", "Nothing But Thieves"],
    "night-static":        ["Nine Inch Nails", "Marilyn Manson", "Filter", "HEALTH", "Crystal Castles"],
    "loud-weather":        ["Metallica", "Slipknot", "System of a Down", "Foo Fighters", "Disturbed"],
    "black-cloud-run":     ["Green Day", "Sum 41", "Blink-182", "The Offspring", "Good Charlotte"],
    "neon-storm":          ["The Midnight", "FM-84", "Timecop1983", "Night Drive", "Dana Jean Phoenix"],
    "signal-break":        ["Mogwai", "Explosions in the Sky", "This Will Destroy You", "Mono", "Russian Circles"],
    "storm-window":        ["Hans Zimmer", "Ennio Morricone", "Howard Shore", "Junkie XL", "Ramin Djawadi"],
    "thunderline":         ["Skrillex", "Deadmau5", "Knife Party", "Feed Me", "Kill the Noise"],
    # mist — ethereal, dreamy, atmospheric
    "fog-lights":          ["Mazzy Star", "Grouper", "Julee Cruise", "Low", "Cranes"],
    "haze-walk":           ["Chillhop Music", "Idealism", "Philanthrope", "Sagun", "Lofi Girl"],
    "ghost-trails":        ["Portishead", "Massive Attack", "Tricky", "Lamb", "Morcheeba"],
    "quiet-signals":       ["Brian Eno", "Harold Budd", "Tangerine Dream", "Stars of the Lid", "Tim Hecker"],
    "silver-mist":         ["Cigarettes After Sex", "Mark Hollis", "Cocteau Twins", "Slowdive", "Mazzy Star"],
    "soft-focus":          ["My Bloody Valentine", "Slowdive", "Ride", "Chapterhouse", "Lush"],
    "early-fog":           ["Nick Drake", "Elliott Smith", "Damien Rice", "Bill Callahan", "Bert Jansch"],
    "moon-haze":           ["Washed Out", "Toro y Moi", "Neon Indian", "Memory Tapes", "Small Black"],
    "dim-city":            ["J Cole", "Kendrick Lamar", "Isaiah Rashad", "Vince Staples", "Earl Sweatshirt"],
    "mist-room":           ["Nils Frahm", "William Basinski", "Johann Johannsson", "Harold Budd", "Hauschka"],
}

# ─── Cloud-specific colour palettes (10 entries, one per playlist slot) ────────
# Each entry is (gradient_start, gradient_end) hex strings
_CLOUD_PALETTES = [
    ("#4a6fa5", "#2d4e7e"),  # cloud-nine — soft blue
    ("#5a5a72", "#333350"),  # grey-sky-blues — steel indigo
    ("#6b8cae", "#3d5a7a"),  # mellow-mood — grey-blue
    ("#4f7a9c", "#2c4f6e"),  # soft-commute — muted steel
    ("#7a8fac", "#445870"),  # floating-afternoon — fog blue
    ("#8fa8c2", "#5a7a96"),  # silver-light — pale blue-grey
    ("#607d99", "#3a5570"),  # lazy-sunday — slate blue
    ("#3d6070", "#1e3a48"),  # window-seat — dark teal
    ("#5c7a8a", "#2e4a5a"),  # blue-grey-haze — deep teal
    ("#4a6480", "#253d56"),  # drift-state — ocean dusk
]

# Generic palettes for other weather types (index → (start, end))
_GENERIC_PALETTES = [
    ("#1e5a80", "#0e3450"),  # muted cerulean
    ("#3e2268", "#221244"),  # muted violet
    ("#163a72", "#0a2050"),  # muted navy
    ("#6a3e18", "#3a2008"),  # muted burnt orange
    ("#1a4a30", "#0a2c1c"),  # muted forest green
    ("#5a1840", "#301028"),  # muted berry
    ("#1a2535", "#0e1520"),  # dark charcoal
    ("#3a1862", "#200a40"),  # muted plum
    ("#6a4010", "#3a220a"),  # muted golden brown
    ("#0e4848", "#082a2e"),  # muted deep teal
]


# ─── Helpers ──────────────────────────────────────────────────────────────────

def _normalize_condition(condition: str) -> str:
    normalized = condition.lower().strip()
    if normalized in {"drizzle"}:
        return "rain"
    if normalized in {"thunderstorm"}:
        return "storm"
    if normalized in {"mist", "fog", "smoke", "haze"}:
        return "mist"
    if normalized not in WEATHER_PLAYLISTS:
        return "clouds"
    return normalized


def _playlist_theme(condition: str, index: int) -> tuple[str, str]:
    if condition == "clouds":
        return _CLOUD_PALETTES[index % len(_CLOUD_PALETTES)]
    return _GENERIC_PALETTES[index % len(_GENERIC_PALETTES)]


def _cloud_featured_index(weather: dict) -> int:
    """
    Choose the best-fit cloud playlist index based on:
    - time of day (UTC hour)
    - temperature
    - cloud subtype / description
    """
    hour = datetime.datetime.utcnow().hour
    temp = float(weather.get("temp") or 20)
    desc = (weather.get("description") or "").lower()
    clouds_pct = int(weather.get("clouds_pct") or 0)

    is_morning = 5 <= hour < 12
    is_afternoon = 12 <= hour < 17
    is_evening = 17 <= hour < 22
    is_night = hour >= 22 or hour < 5

    is_overcast = "overcast" in desc or clouds_pct >= 85
    is_light = "few" in desc or "scattered" in desc or clouds_pct < 40
    is_cold = temp < 8
    is_warm = temp > 18

    # Night — moody/atmospheric
    if is_night:
        return 8  # Blue-Grey Haze

    # Cold overcast — soulful heavy
    if is_overcast and is_cold:
        return 1  # Grey Sky Blues

    # Evening + cold
    if is_evening and is_cold:
        return 7  # Window Seat

    # Evening — dreamy
    if is_evening:
        return 4  # Floating Afternoon

    # Morning + light clouds + warm → uplifting
    if is_morning and is_light and is_warm:
        return 5  # Silver Light

    # Morning + light clouds
    if is_morning and is_light:
        return 0  # Cloud Nine

    # Afternoon + warm + light → chill
    if is_afternoon and is_warm and is_light:
        return 2  # Mellow Mood

    # Overcast commute hours
    if is_overcast and (is_morning or is_afternoon):
        return 3  # Soft Commute

    # Lazy afternoon / weekend feel
    if is_afternoon:
        return 6  # Lazy Sunday Clouds

    # Default
    return 0  # Cloud Nine


def _playlist_payloads(condition: str, total_listeners: int, weather: dict | None = None) -> list[dict]:
    normalized = _normalize_condition(condition)
    rows = WEATHER_PLAYLISTS.get(normalized, WEATHER_PLAYLISTS["clouds"])

    # For clouds: reorder so best-fit playlist is first
    featured_idx = 0
    if normalized == "clouds" and weather is not None:
        featured_idx = _cloud_featured_index(weather)

    # Build ordered list: featured first, then the rest in original order
    ordered_indices = [featured_idx] + [i for i in range(len(rows)) if i != featured_idx]

    # Listener spread: weighted decay
    weights = [1.0, 0.82, 0.68, 0.59, 0.52, 0.46, 0.40, 0.34, 0.29, 0.24]

    payload = []
    for rank, original_idx in enumerate(ordered_indices):
        playlist_key, name, description, emoji, mood, track_count = rows[original_idx]
        primary, secondary = _playlist_theme(normalized, original_idx)
        listener_count = int(total_listeners * weights[rank]) if total_listeners > 0 else 0
        payload.append(
            {
                "id": playlist_key,
                "title": name,
                "description": description,
                "emoji": emoji,
                "mood": mood,
                "weather_key": normalized,
                "track_count": track_count,
                "listeners_count": listener_count,
                "accent_start": primary,
                "accent_end": secondary,
                "seed_query": f"{name} {description}",
                "search_query": PLAYLIST_SEARCH_QUERIES.get(playlist_key, f"{name} {description}"),
                "artist_queries": PLAYLIST_ARTIST_QUERIES.get(playlist_key, [PLAYLIST_SEARCH_QUERIES.get(playlist_key, name)]),
                "is_featured": rank == 0,
            }
        )
    return payload


async def _listeners_count(redis, city: str) -> int:
    return await redis.scard(f"weather:listeners:{city.lower()}")


async def _get_top_listeners(redis, db: AsyncSession, city: str, limit: int = 5) -> list[dict]:
    """Return up to `limit` listener profiles for a city from Redis + DB."""
    try:
        member_strs = await redis.smembers(f"weather:listeners:{city.lower()}")
        ids = [int(s) for s in member_strs if str(s).lstrip("-").isdigit()]
        if not ids:
            return []
        ids = ids[:limit]
        result = await db.execute(
            select(
                User.id, User.display_name, User.username, User.avatar_url, User.first_name
            ).where(User.id.in_(ids))
        )
        rows = result.all()
        return [
            {
                "id": row.id,
                "display_name": row.display_name or row.first_name or row.username,
                "username": row.username,
                "avatar_url": row.avatar_url or "",
            }
            for row in rows
        ]
    except Exception:
        return []


# ─── Routes ───────────────────────────────────────────────────────────────────

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


@router.get(
    "/current",
    summary="Get current weather",
    description="Returns current weather details, listener count, and the featured playlist for the requested city.",
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

    listeners_count = await _listeners_count(redis, weather["city"])
    playlists = _playlist_payloads(weather["condition"], listeners_count, weather)
    return {
        **weather,
        "condition_label": weather.get("condition_label") or condition_label(weather["condition"]),
        "listeners_count": listeners_count,
        "featured_playlist": playlists[0] if playlists else None,
    }


@router.get(
    "/playlist",
    summary="Get weather playlists",
    description="Returns 10 playlists for the current weather, ordered with the best-fit playlist first and listener counts per playlist.",
)
async def weather_playlist(
    city: str = Query(...),
    request: Request = None,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    redis = request.app.state.redis
    cache_key = f"weather:playlist:{_PLAYLIST_CACHE_VER}:{city.lower()}"
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

        payload = {
            "city": weather["city"],
            "temp": float(weather["temp"]) if weather.get("temp") is not None else None,
            "feels_like": float(weather["feels_like"]) if weather.get("feels_like") is not None else None,
            "humidity": weather.get("humidity"),
            "wind_speed": weather.get("wind_speed"),
            "icon": weather.get("icon"),
            "description": weather.get("description"),
            "condition": _normalize_condition(weather["condition"]),
            "condition_label": weather.get("condition_label") or condition_label(weather["condition"]),
            "condition_subtype": weather.get("condition_subtype", ""),
            "clouds_pct": weather.get("clouds_pct", 0),
            "mood_tag": weather.get("mood_tag"),
            # Store raw weather for cloud scoring on cache hits
            "_weather_raw": {
                "temp": float(weather["temp"]) if weather.get("temp") is not None else 20.0,
                "description": weather.get("description", ""),
                "clouds_pct": weather.get("clouds_pct", 0),
            },
        }
        await redis.setex(cache_key, WEATHER_PLAYLIST_CACHE_TTL, json.dumps(payload))

    listener_key = f"weather:listeners:{payload['city'].lower()}"
    await redis.sadd(listener_key, current_user.id)
    await redis.expire(listener_key, WEATHER_LISTENER_TTL)
    listeners_count = await _listeners_count(redis, payload["city"])

    # For cloud scoring we need the raw weather snapshot
    weather_raw = payload.get("_weather_raw") or {"temp": payload.get("temp") or 20.0}
    playlists = _playlist_payloads(payload["condition"], listeners_count, weather_raw)

    top_listeners = await _get_top_listeners(redis, db, payload["city"])

    response_payload = {k: v for k, v in payload.items() if k != "_weather_raw"}
    return {
        **response_payload,
        "listeners_count": listeners_count,
        "featured_playlist": playlists[0] if playlists else None,
        "playlists": playlists,
        "top_listeners": top_listeners,
    }
