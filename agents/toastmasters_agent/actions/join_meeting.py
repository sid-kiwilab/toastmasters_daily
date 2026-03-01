"""
Find club by name from Firestore (users collection: club_name, club_code) and return join links.
Uses service-account.json in the agent root for Firebase Admin.
"""
import os
import logging

logger = logging.getLogger("toastmasters_agent.join_meeting")

# Agent root = parent of actions/
_AGENT_ROOT = os.path.join(os.path.dirname(__file__), "..")
_CRED_PATH = os.path.join(_AGENT_ROOT, "service-account.json")
_BASE_URL = os.getenv("TOASTMASTERS_BASE_URL", "https://toastmastersdaily.com").rstrip("/")

_db = None


def _get_db():
    global _db
    if _db is not None:
        return _db
    if not os.path.isfile(_CRED_PATH):
        logger.warning("service-account.json not found at %s", _CRED_PATH)
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
        firebase_admin.initialize_app(credentials.Certificate(_CRED_PATH))
    _db = firestore.client()
    return _db


def run(query: str) -> str:
    """
    Find clubs whose name matches the query (case-insensitive contains).
    Returns a string: one line per club with join link, or "No matching clubs."
    """
    query = (query or "").strip()
    db = _get_db()
    if db is None:
        return "Club lookup is not configured (missing service-account.json or firebase_admin)."
    try:
        users = db.collection("users").stream()
        clubs = []
        for doc in users:
            d = doc.to_dict() or {}
            name = (d.get("club_name") or "").strip()
            code = d.get("club_code")
            if not name or code is None:
                continue
            code_str = str(int(code)) if isinstance(code, (int, float)) else str(code).strip()
            if not code_str:
                continue
            if query and query.lower() not in name.lower():
                continue
            clubs.append((name, code_str))
        if not clubs:
            return "No matching clubs." if query else "No clubs found."
        lines = [f"{name} | Join: {_BASE_URL}/clubs/{code}" for name, code in clubs]
        return "\n".join(lines)
    except Exception as e:
        logger.exception("join_meeting Firestore error")
        return f"Could not look up clubs: {e}"
