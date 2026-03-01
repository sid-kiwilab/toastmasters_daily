"""
Find club by name from Firestore (users collection: club_name, club_code) and return join links.
Credentials: FIREBASE_SERVICE_ACCOUNT_JSON (env, JSON string) or service-account.json in agent root.
Substring match first; if no match, fuzzy match (typos like "Pacfici" -> "Pacific") via difflib.
"""
import json
import os
import logging
from difflib import SequenceMatcher

logger = logging.getLogger("toastmasters_agent.join_meeting")

# Agent root = parent of actions/
_AGENT_ROOT = os.path.join(os.path.dirname(__file__), "..")
_CRED_PATH = os.path.join(_AGENT_ROOT, "service-account.json")
_BASE_URL = os.getenv("TOASTMASTERS_BASE_URL", "https://toastmastersdaily.com").rstrip("/")

_db = None


def _get_credential():
    """Credential dict from FIREBASE_SERVICE_ACCOUNT_JSON env or service-account.json file."""
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


def _get_db():
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


def _fuzzy_score(query: str, club_name: str) -> float:
    """Best ratio of query vs full name or vs first word (e.g. 'pacfici' vs 'Pacific')."""
    q = (query or "").lower().strip()
    n = (club_name or "").lower().strip()
    if not q or not n:
        return 0.0
    full = SequenceMatcher(None, q, n).ratio()
    first_word = n.split()[0] if n.split() else n
    by_word = SequenceMatcher(None, q, first_word).ratio() if first_word else 0.0
    return max(full, by_word)


def run(query: str) -> str:
    """
    Find clubs whose name matches the query (case-insensitive contains, then fuzzy for typos).
    Returns a string: one line per club with join link, or "No matching clubs."
    """
    query = (query or "").strip()
    db = _get_db()
    if db is None:
        return "Club lookup is not configured (missing FIREBASE_SERVICE_ACCOUNT_JSON / service-account.json or firebase_admin)."
    try:
        users = db.collection("users").stream()
        all_clubs = []
        for doc in users:
            d = doc.to_dict() or {}
            name = (d.get("club_name") or "").strip()
            code = d.get("club_code")
            if not name or code is None:
                continue
            code_str = str(int(code)) if isinstance(code, (int, float)) else str(code).strip()
            if not code_str:
                continue
            all_clubs.append((name, code_str))
        if not all_clubs:
            return "No clubs found."
        if not query:
            lines = [f"{name} | Join: {_BASE_URL}/clubs/{code}" for name, code in all_clubs]
            return "\n".join(lines)
        # Substring match first
        clubs = [(n, c) for n, c in all_clubs if query.lower() in n.lower()]
        if not clubs and len(query) >= 3:
            # Fuzzy match for typos (e.g. "Pacfici" -> "Pacific"); score vs full name and first word
            best = max(all_clubs, key=lambda nc: _fuzzy_score(query, nc[0]))
            if _fuzzy_score(query, best[0]) >= 0.5:
                clubs = [best]
        if not clubs:
            return "No matching clubs."
        lines = [f"{name} | Join: {_BASE_URL}/clubs/{code}" for name, code in clubs]
        return "\n".join(lines)
    except Exception as e:
        logger.exception("join_meeting Firestore error")
        return f"Could not look up clubs: {e}"
