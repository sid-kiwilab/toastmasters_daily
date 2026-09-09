#!/usr/bin/env python3
"""
Seed demo clubs on Toastmasters Daily (Firestore).

Idempotent: reuses existing seed docs matched by is_seed + club_name.

Usage (from agents/toastmasters_agent):
  python scripts/seed_nz_clubs.py
  python scripts/seed_nz_clubs.py --dry-run

Requires FIREBASE_SERVICE_ACCOUNT_JSON or service-account.json (Admin SDK).

Do NOT run against production — creates fake clubs that duplicate real signups.
Use only on dev/staging, or remove with scripts/remove_seed_clubs.py.
"""
from __future__ import annotations

import argparse
import os
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path
from zoneinfo import ZoneInfo

_AGENT_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(_AGENT_ROOT / "actions"))

_env_path = _AGENT_ROOT / "env.yaml"
if _env_path.is_file():
    import yaml
    with open(_env_path, encoding="utf-8") as f:
        data = yaml.safe_load(f)
    if isinstance(data, dict):
        for k, v in data.items():
            if v is not None and str(v).strip():
                os.environ.setdefault(k, str(v).strip())

from club_lookup import get_db  # noqa: E402

SEED_CLUBS = [
    {
        "seed_id": "seed-nz-botany",
        "club_code": 28651001,
        "club_name": "Botany Toastmasters",
        "club_location": "Botany Town Centre, Auckland, New Zealand",
        "club_lat": -36.9275,
        "club_lng": 174.9067,
        "club_timezone": "Pacific/Auckland",
        "club_info": "Friendly East Auckland club meeting near Botany Town Centre. All welcome — practice speeches, evaluations, and table topics in a supportive setting.",
    },
    {
        "seed_id": "seed-nz-howick",
        "club_code": 28651002,
        "club_name": "Howick Toastmasters",
        "club_location": "Howick, Auckland, New Zealand",
        "club_lat": -36.8948,
        "club_lng": 174.9328,
        "club_timezone": "Pacific/Auckland",
        "club_info": "Howick-based Toastmasters club for speakers of all levels. Build confidence and leadership skills at our weekly meetings.",
    },
    {
        "seed_id": "seed-nz-pakuranga",
        "club_code": 28651003,
        "club_name": "Pakuranga Toastmasters",
        "club_location": "Pakuranga, Auckland, New Zealand",
        "club_lat": -36.9145,
        "club_lng": 174.8720,
        "club_timezone": "Pacific/Auckland",
        "club_info": "Pakuranga Toastmasters — a welcoming club in East Auckland focused on practical speaking and leadership development.",
    },
    {
        "seed_id": "seed-uk-shoreditch",
        "club_code": 28651004,
        "club_name": "Shoreditch Toastmasters",
        "club_location": "Shoreditch, London, United Kingdom",
        "club_lat": 51.5260,
        "club_lng": -0.0780,
        "club_timezone": "Europe/London",
        "club_info": "Central London Toastmasters club for professionals and newcomers. Practice speaking in a supportive urban setting.",
    },
]


def _next_wednesday_7pm(club_tz: str) -> datetime:
    """Next Wednesday 19:00 in club timezone, returned as UTC-aware datetime."""
    tz = ZoneInfo(club_tz)
    now = datetime.now(tz)
    days_ahead = (2 - now.weekday()) % 7
    if days_ahead == 0 and now.hour >= 19:
        days_ahead = 7
    target = (now + timedelta(days=days_ahead)).replace(hour=19, minute=0, second=0, microsecond=0)
    return target.astimezone(timezone.utc)


def _find_existing_seed(db, club_name: str) -> str | None:
    for doc in db.collection("users").where("is_seed", "==", True).stream():
        d = doc.to_dict() or {}
        if (d.get("club_name") or "").strip() == club_name:
            return doc.id
    return None


def seed_club(db, spec: dict, dry_run: bool = False) -> dict:
    from firebase_admin import firestore

    uid = _find_existing_seed(db, spec["club_name"]) or spec["seed_id"]
    code_str = str(spec["club_code"])
    club_tz = spec.get("club_timezone") or "UTC"
    trial_end = datetime(2030, 12, 31, tzinfo=timezone.utc)
    meeting_at = _next_wednesday_7pm(club_tz)

    user_doc = {
        "club_name": spec["club_name"],
        "club_location": spec["club_location"],
        "club_info": spec["club_info"],
        "club_code": spec["club_code"],
        "club_lat": spec["club_lat"],
        "club_lng": spec["club_lng"],
        "club_timezone": club_tz,
        "is_seed": True,
        "trial_end_date": trial_end,
        "created_at": firestore.SERVER_TIMESTAMP,
    }

    meeting_doc = {
        "title": "Weekly meeting",
        "creator_id": uid,
        "meeting_datetime": meeting_at,
        "created_at": firestore.SERVER_TIMESTAMP,
    }

    result = {
        "uid": uid,
        "club_name": spec["club_name"],
        "club_code": code_str,
        "club_timezone": club_tz,
        "club_url": f"https://toastmastersdaily.com/clubs/{code_str}",
        "meeting_at_utc": meeting_at.isoformat(),
    }

    if dry_run:
        result["dry_run"] = True
        return result

    user_ref = db.collection("users").document(uid)
    code_ref = db.collection("club_codes").document(code_str)

    user_ref.set(user_doc, merge=True)
    code_ref.set({"uid": uid}, merge=True)

    meetings_ref = user_ref.collection("meetings")
    existing = meetings_ref.where("meeting_datetime", ">=", datetime.now(timezone.utc)).limit(1).get()
    if existing:
        mid = existing[0].id
        result["meeting_id"] = mid
        result["meeting_url"] = f"https://toastmastersdaily.com/meetings/{mid}"
        return result

    active_ref = db.collection("active_meetings").document()
    meeting_id = active_ref.id
    batch = db.batch()
    batch.set(active_ref, meeting_doc)
    batch.set(meetings_ref.document(meeting_id), meeting_doc)
    batch.commit()

    result["meeting_id"] = meeting_id
    result["meeting_url"] = f"https://toastmastersdaily.com/meetings/{meeting_id}"
    return result


def main():
    parser = argparse.ArgumentParser(description="Seed demo Toastmasters Daily clubs")
    parser.add_argument("--dry-run", action="store_true", help="Print actions without writing")
    args = parser.parse_args()

    db = get_db()
    if db is None:
        print("ERROR: Firebase Admin not configured. Set FIREBASE_SERVICE_ACCOUNT_JSON or service-account.json")
        sys.exit(1)

    print("Seeding demo clubs (dry_run=%s)..." % args.dry_run)
    for spec in SEED_CLUBS:
        out = seed_club(db, spec, dry_run=args.dry_run)
        print(f"  {out['club_name']} ({out.get('club_timezone', 'UTC')})")
        print(f"    Club:    {out['club_url']}")
        if out.get("meeting_url"):
            print(f"    Meeting: {out['meeting_url']}")
        if out.get("dry_run"):
            print("    (dry run — no writes)")


if __name__ == "__main__":
    main()
