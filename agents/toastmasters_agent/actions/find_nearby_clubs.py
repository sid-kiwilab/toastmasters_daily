"""Clubs near a place: signed-up TMD clubs within 80 km, else web search."""
import logging

from club_lookup import NEARBY_RADIUS_KM, format_club_block, find_nearby_clubs as _find_nearby, get_db
from web_search import run as web_search_run

logger = logging.getLogger("toastmasters_agent.find_nearby_clubs")


def _web_fallback(label: str) -> str:
    logger.info("No TMD clubs within %skm of %s; web search", NEARBY_RADIUS_KM, label)
    results = web_search_run(f"Toastmasters clubs near {label}", club_list=True)
    return (
        f"No Toastmasters Daily clubs signed up near {label}.\n\n"
        f"Official clubs from the web:\n\n{results}"
    )


def run(place: str = "", limit: int = 3, lat: float | None = None, lng: float | None = None) -> str:
    place = (place or "").strip()
    use_gps = not place

    if use_gps and lat is None and lng is None:
        return "Please share your location or type a city to search for nearby clubs."

    label = place or "your location"
    db = get_db()
    if db is None:
        return _web_fallback(label)

    try:
        ranked, err = _find_nearby(
            db,
            place,
            limit=limit,
            user_lat=lat if use_gps else None,
            user_lng=lng if use_gps else None,
            max_km=NEARBY_RADIUS_KM,
        )
        if err:
            return _web_fallback(label)
        if not ranked:
            return _web_fallback(label)

        blocks = [format_club_block(club, distance_km=km) for club, km in ranked]
        return f"Toastmasters Daily clubs near {label}:\n\n" + "\n\n".join(blocks)
    except Exception as e:
        logger.exception("find_nearby_clubs error")
        return f"Could not search for nearby clubs: {e}"
