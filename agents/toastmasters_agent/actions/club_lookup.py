"""
Shared Firestore club lookup, geocoding, distance, and formatted club details.
Used by find_nearby_clubs and join_meeting actions.
"""
import json
import logging
import math
import os
import urllib.parse
from datetime import datetime, timezone
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


def _format_meeting_datetime(dt, club_timezone: str) -> str:
    if dt is None:
        return "No upcoming meeting scheduled"
    try:
        if hasattr(dt, "to_datetime"):
            d = dt.to_datetime().replace(tzinfo=timezone.utc)
        elif hasattr(dt, "timestamp"):
            d = datetime.fromtimestamp(dt.timestamp(), tz=timezone.utc)
        elif isinstance(dt, datetime):
            d = dt if dt.tzinfo else dt.replace(tzinfo=timezone.utc)
        else:
            return "No upcoming meeting scheduled"
        tz_name = club_timezone or "UTC"
        try:
            local = d.astimezone(ZoneInfo(tz_name))
        except Exception:
            local = d.astimezone(ZoneInfo("UTC"))
            tz_name = "UTC"
        days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        hour = local.hour % 12 or 12
        period = "AM" if local.hour < 12 else "PM"
        tz_label = local.tzname() or tz_name
        return (
            f"{days[local.weekday()]} {local.day} {months[local.month - 1]} {local.year}, "
            f"{hour}:{local.minute:02d} {period} {tz_label}"
        )
    except Exception:
        return "Upcoming meeting scheduled"


def _next_meeting(db, uid: str) -> dict | None:
    if db is None:
        return None
    try:
        now = datetime.now(timezone.utc)
        meetings_ref = db.collection("users").document(uid).collection("meetings")
        snap = meetings_ref.where("meeting_datetime", ">=", now).order_by("meeting_datetime").limit(1).get()
        for doc in snap:
            data = doc.to_dict() or {}
            return {
                "id": doc.id,
                "title": (data.get("title") or "Meeting").strip(),
                "meeting_datetime": data.get("meeting_datetime"),
            }
        all_snap = meetings_ref.limit(20).get()
        candidates = []
        for doc in all_snap:
            data = doc.to_dict() or {}
            dt = data.get("meeting_datetime")
            if not dt:
                continue
            try:
                d = dt.to_datetime().replace(tzinfo=timezone.utc) if hasattr(dt, "to_datetime") else None
            except Exception:
                d = None
            if d and d >= now:
                candidates.append((d, doc.id, data))
        if candidates:
            candidates.sort(key=lambda x: x[0])
            _, mid, data = candidates[0]
            return {
                "id": mid,
                "title": (data.get("title") or "Meeting").strip(),
                "meeting_datetime": data.get("meeting_datetime"),
            }
    except Exception as e:
        logger.warning("Could not load next meeting for %s: %s", uid, e)
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
        if not name or code is None:
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


def format_club_block(club: dict, db, distance_km: float | None = None) -> str:
    """Format a club with details, next meeting, and join URLs."""
    club_tz = resolve_club_timezone(club)
    lines = [club["club_name"]]
    loc = club.get("club_location") or "Location not listed"
    if distance_km is not None:
        if distance_km < 1:
            dist = f" (~{int(round(distance_km * 1000))} m away)"
        else:
            dist = f" (~{distance_km:.1f} km away)"
        lines.append(f"Location: {loc}{dist}")
    else:
        lines.append(f"Location: {loc}")
    if club.get("club_info"):
        lines.append(f"About: {club['club_info']}")
    meeting = _next_meeting(db, club["uid"])
    if meeting:
        when = _format_meeting_datetime(meeting.get("meeting_datetime"), club_tz)
        lines.append(f"Next meeting: {when} — {meeting['title']}")
        lines.append(f"Meeting link: {_BASE_URL}/meetings/{meeting['id']}")
    else:
        lines.append("Next meeting: No upcoming meeting scheduled on Toastmasters Daily")
    lines.append(f"Club page (guest join): {_BASE_URL}/clubs/{club['club_code']}")
    return "\n".join(lines)


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


def find_nearby_clubs(
    db,
    place: str,
    limit: int = 3,
    user_lat: float | None = None,
    user_lng: float | None = None,
) -> tuple[list[tuple[dict, float]], str | None, dict]:
    """
    Find clubs nearest to place. Returns ([(club, km), ...], error_message, meta).
    """
    meta: dict = {"skipped_no_coords": 0, "nearest_km": None}
    if user_lat is not None and user_lng is not None:
        try:
            coords = (float(user_lat), float(user_lng))
        except (TypeError, ValueError):
            coords = None
    else:
        coords = None
    if coords is None:
        coords = geocode_place(place)
    if coords is None:
        label = place.strip() or "your location"
        return [], f"Could not find coordinates for '{label}'. Try a city or suburb name.", meta
    user_lat, user_lng = coords
    all_clubs = load_all_clubs(db)
    if not all_clubs:
        return [], "No clubs are registered on Toastmasters Daily yet.", meta
    ranked: list[tuple[dict, float]] = []
    for club in all_clubs:
        cc = _club_coords(club)
        if cc is None:
            meta["skipped_no_coords"] += 1
            continue
        km = haversine_km(user_lat, user_lng, cc[0], cc[1])
        ranked.append((club, km))
    if not ranked:
        return [], "Clubs exist but none have location data yet.", meta
    ranked.sort(key=lambda x: x[1])
    meta["nearest_km"] = ranked[0][1]
    return ranked[:limit], None, meta
