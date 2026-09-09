"""
Find Toastmasters Daily clubs nearest to a place name.
Geocodes via Nominatim, ranks by haversine distance, returns formatted details + join links.
"""
import logging

from club_lookup import format_club_block, find_nearby_clubs as _find_nearby, get_db

logger = logging.getLogger("toastmasters_agent.find_nearby_clubs")


def run(place: str, limit: int = 3, lat: float | None = None, lng: float | None = None) -> str:
    place = (place or "").strip()
    if not place and lat is None and lng is None:
        return "Please provide a location (city or suburb) to search for nearby clubs."

    db = get_db()
    if db is None:
        return "Club lookup is not configured (missing FIREBASE_SERVICE_ACCOUNT_JSON / service-account.json or firebase_admin)."

    try:
        ranked, err, meta = _find_nearby(db, place, limit=limit, user_lat=lat, user_lng=lng)
        if err:
            return err
        if not ranked:
            label = place or "your location"
            return f"No Toastmasters Daily clubs found near {label}."

        blocks = []
        for i, (club, km) in enumerate(ranked, start=1):
            header = f"--- Club {i} (closest)" if i == 1 else f"--- Club {i}"
            blocks.append(header + "\n" + format_club_block(club, db, distance_km=km))

        label = place or "your location"
        intro = (
            f"Here are the closest Toastmasters Daily clubs near {label}. "
            "Guest join lets you visit a meeting on this site — it is not official Toastmasters International membership.\n"
        )
        nearest_km = meta.get("nearest_km")
        if nearest_km is not None and nearest_km > 500:
            intro += (
                "Note: This is the closest club on Toastmasters Daily; "
                "there may be none registered near you yet.\n"
            )
        skipped = meta.get("skipped_no_coords") or 0
        if skipped:
            intro += f"({skipped} registered club(s) skipped — no location data on file.)\n"

        return intro + "\n\n".join(blocks)
    except Exception as e:
        logger.exception("find_nearby_clubs error")
        return f"Could not search for nearby clubs: {e}"
