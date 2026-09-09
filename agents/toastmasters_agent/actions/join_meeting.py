"""
Find club by name from Firestore and return formatted details + join links.
Credentials: FIREBASE_SERVICE_ACCOUNT_JSON (env, JSON string) or service-account.json in agent root.
"""
import logging

from club_lookup import find_clubs_by_name, format_club_block, get_db

logger = logging.getLogger("toastmasters_agent.join_meeting")


def run(query: str) -> str:
    """
    Find clubs whose name matches the query (case-insensitive contains, then fuzzy for typos).
    Returns formatted club details with join links, or a not-found message.
    """
    query = (query or "").strip()
    db = get_db()
    if db is None:
        return "Club lookup is not configured (missing FIREBASE_SERVICE_ACCOUNT_JSON / service-account.json or firebase_admin)."
    try:
        clubs = find_clubs_by_name(db, query)
        if not clubs:
            if not query:
                return "No clubs found on Toastmasters Daily."
            return f"No matching clubs for '{query}' on Toastmasters Daily."
        blocks = []
        for club in clubs:
            blocks.append(format_club_block(club, db))
        intro = (
            "Guest join on Toastmasters Daily lets you visit a meeting on this site — "
            "it is not official Toastmasters International membership.\n"
        )
        return intro + "\n\n".join(blocks)
    except Exception as e:
        logger.exception("join_meeting Firestore error")
        return f"Could not look up clubs: {e}"
