"""
Shared Firestore club lookup, geocoding, distance, and formatted club details.
Used by find_nearby_clubs and join_meeting actions.
"""
import json
import logging
import math
import os
import urllib.parse
from difflib import SequenceMatcher
from zoneinfo import ZoneInfo

import requests

logger = logging.getLogger("toastmasters_agent.club_lookup")

_AGENT_ROOT = os.path.join(os.path.dirname(__file__), "..")
_CRED_PATH = os.path.join(_AGENT_ROOT, "service-account.json")
_BASE_URL = os.getenv("TOASTMASTERS_BASE_URL", "https://toastmastersdaily.com").rstrip("/")
_NOMINATIM_UA = "ToastmastersDaily/1.0 (https://toastmastersdaily.com)"

_db = None
_geocode_cache: dict[str, tuple[float, float] | None] = {}
_tz_finder = None


def _get_credential():
    raw = (os.getenv("FIREBASE_SERVICE_ACCOUNT_JSON") or "").strip()
    if raw:
        try:
            return json.loads(raw)
        except json.JSONDecodeError as e:
            logger.warning("FIREBASE_SERVICE_ACCOUNT_JSON invalid JSON: %s", e)
            return None
    if os.path.isfile(_CRED_PATH):
        try:
            with open(_CRED_PATH, "r", encoding="utf-8") as f:
                return json.load(f)
        except (json.JSONDecodeError, OSError) as e:
            logger.warning("Could not read %s: %s", _CRED_PATH, e)
            return None
    return None


def get_db():
    global _db
    if _db is not None:
        return _db
    cred_dict = _get_credential()
    if not cred_dict:
        logger.warning("No Firebase credentials (FIREBASE_SERVICE_ACCOUNT_JSON or service-account.json)")
        return None
    try:
        import firebase_admin
        from firebase_admin import credentials, firestore
    except ImportError:
        logger.warning("firebase_admin not installed")
        return None
    try:
        firebase_admin.get_app()
    except ValueError:
        firebase_admin.initialize_app(credentials.Certificate(cred_dict))
    _db = firestore.client()
    return _db


def _get_tz_finder():
    global _tz_finder
    if _tz_finder is None:
        from timezonefinder import TimezoneFinder
        _tz_finder = TimezoneFinder()
    return _tz_finder


def resolve_club_timezone(club: dict) -> str:
    """IANA timezone for a club: stored value, lat/lng lookup, or UTC."""
    tz = (club.get("club_timezone") or "").strip()
    if tz:
        return tz
    lat = club.get("club_lat")
    lng = club.get("club_lng")
    if lat is not None and lng is not None:
        try:
            found = _get_tz_finder().timezone_at(lng=float(lng), lat=float(lat))
            if found:
                return found
        except Exception as e:
            logger.warning("Timezone lookup failed for club %s: %s", club.get("club_name"), e)
    return "UTC"


def geocode_place(place: str) -> tuple[float, float] | None:
    """Forward-geocode a place name via Nominatim. Returns (lat, lng) or None."""
    key = (place or "").strip().lower()
    if not key:
        return None
    if key in _geocode_cache:
        return _geocode_cache[key]
    try:
        params = urllib.parse.urlencode({"q": place.strip(), "format": "json", "limit": 1})
        resp = requests.get(
            f"https://nominatim.openstreetmap.org/search?{params}",
            headers={"Accept": "application/json", "User-Agent": _NOMINATIM_UA},
            timeout=12,
        )
        resp.raise_for_status()
        data = resp.json()
        if not data:
            _geocode_cache[key] = None
            return None
        lat = float(data[0]["lat"])
        lng = float(data[0]["lon"])
        _geocode_cache[key] = (lat, lng)
        return (lat, lng)
    except Exception as e:
        logger.warning("Geocode failed for %r: %s", place, e)
        _geocode_cache[key] = None
        return None


def haversine_km(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    """Great-circle distance in kilometres."""
    r = 6371.0
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dlat = math.radians(lat2 - lat1)
    dlng = math.radians(lng2 - lng1)
    a = math.sin(dlat / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dlng / 2) ** 2
    return r * 2 * math.asin(math.sqrt(a))


def _fuzzy_score(query: str, club_name: str) -> float:
    q = (query or "").lower().strip()
    n = (club_name or "").lower().strip()
    if not q or not n:
        return 0.0
    full = SequenceMatcher(None, q, n).ratio()
    first_word = n.split()[0] if n.split() else n
    by_word = SequenceMatcher(None, q, first_word).ratio() if first_word else 0.0
    return max(full, by_word)


def _club_coords(club: dict) -> tuple[float, float] | None:
    lat = club.get("club_lat")
    lng = club.get("club_lng")
    if lat is not None and lng is not None:
        try:
            return (float(lat), float(lng))
        except (TypeError, ValueError):
            pass
    loc = (club.get("club_location") or "").strip()
    if loc:
        return geocode_place(loc)
    return None


def load_all_clubs(db) -> list[dict]:
    """Load clubs with name + code from Firestore."""
    if db is None:
        return []
    clubs = []
    for doc in db.collection("users").stream():
        d = doc.to_dict() or {}
        name = (d.get("club_name") or "").strip()
        code = d.get("club_code")
        if not name or code is None or d.get("is_seed"):
            continue
        code_str = str(int(code)) if isinstance(code, (int, float)) else str(code).strip()
        if not code_str:
            continue
        clubs.append({
            "uid": doc.id,
            "club_name": name,
            "club_code": code_str,
            "club_location": (d.get("club_location") or "").strip(),
            "club_info": (d.get("club_info") or "").strip(),
            "club_lat": d.get("club_lat"),
            "club_lng": d.get("club_lng"),
            "club_timezone": (d.get("club_timezone") or "").strip(),
        })
    return clubs


def _format_distance(distance_km: float) -> str:
    if distance_km < 1:
        return f" (~{int(round(distance_km * 1000))} m)"
    return f" (~{distance_km:.1f} km)"


def format_club_block(club: dict, distance_km: float | None = None) -> str:
    """Name, location, guest-join URL."""
    loc = club.get("club_location") or "Location not listed"
    dist = _format_distance(distance_km) if distance_km is not None else ""
    guest = f"{_BASE_URL}/clubs/{club['club_code']}"
    return "\n".join([club["club_name"], f"{loc}{dist}", f"Guest join: {guest}"])


def find_clubs_by_name(db, query: str) -> list[dict]:
    """Substring then fuzzy match on club_name."""
    query = (query or "").strip()
    all_clubs = load_all_clubs(db)
    if not query:
        return all_clubs
    matches = [c for c in all_clubs if query.lower() in c["club_name"].lower()]
    if not matches and len(query) >= 3:
        best = max(all_clubs, key=lambda c: _fuzzy_score(query, c["club_name"]), default=None)
        if best and _fuzzy_score(query, best["club_name"]) >= 0.5:
            matches = [best]
    return matches


NEARBY_RADIUS_KM = 80


def find_nearby_clubs(
    db,
    place: str,
    limit: int = 3,
    user_lat: float | None = None,
    user_lng: float | None = None,
    max_km: float | None = NEARBY_RADIUS_KM,
) -> tuple[list[tuple[dict, float]], str | None]:
    """Signed-up clubs within max_km of place or coords. Empty list + no error → web search."""
    coords = None
    if user_lat is not None and user_lng is not None:
        try:
            coords = (float(user_lat), float(user_lng))
        except (TypeError, ValueError):
            coords = None
    if coords is None:
        coords = geocode_place(place)
    if coords is None:
        label = place.strip() or "your location"
        return [], f"Could not find coordinates for '{label}'."
    user_lat, user_lng = coords
    all_clubs = load_all_clubs(db)
    if not all_clubs:
        return [], None
    ranked: list[tuple[dict, float]] = []
    for club in all_clubs:
        cc = _club_coords(club)
        if cc is None:
            continue
        km = haversine_km(user_lat, user_lng, cc[0], cc[1])
        ranked.append((club, km))
    if not ranked:
        return [], None
    ranked.sort(key=lambda x: x[1])
    if max_km is not None:
        ranked = [(c, km) for c, km in ranked if km <= max_km]
    return ranked[:limit], None
