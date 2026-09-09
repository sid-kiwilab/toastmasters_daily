"""Find a signed-up club by name and return guest-join link."""
import logging

from club_lookup import find_clubs_by_name, format_club_block, get_db

logger = logging.getLogger("toastmasters_agent.join_meeting")


def run(query: str) -> str:
    query = (query or "").strip()
    db = get_db()
    if db is None:
        return "Club lookup is not configured."
    try:
        clubs = find_clubs_by_name(db, query)
        if not clubs:
            return f"No matching clubs for '{query}' on Toastmasters Daily." if query else "No clubs found."
        return "\n\n".join(format_club_block(c) for c in clubs)
    except Exception as e:
        logger.exception("join_meeting error")
        return f"Could not look up clubs: {e}"
