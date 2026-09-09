#!/usr/bin/env python3
"""
Backfill club_lat, club_lng, and club_timezone for registered clubs missing geo data.

Usage (from agents/toastmasters_agent):
  python scripts/backfill_club_geo.py
  python scripts/backfill_club_geo.py --dry-run

Requires FIREBASE_SERVICE_ACCOUNT_JSON or service-account.json (Admin SDK).
"""
from __future__ import annotations

import argparse
import os
import sys
import time
from pathlib import Path

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

from club_lookup import geocode_place, get_db, resolve_club_timezone  # noqa: E402


def needs_backfill(data: dict) -> bool:
    if not (data.get("club_name") and data.get("club_location")):
        return False
    if data.get("club_lat") is None or data.get("club_lng") is None:
        return True
    if not (data.get("club_timezone") or "").strip():
        return True
    return False


def backfill_doc(db, doc_id: str, data: dict, dry_run: bool) -> dict | None:
    loc = (data.get("club_location") or "").strip()
    lat = data.get("club_lat")
    lng = data.get("club_lng")
    tz = (data.get("club_timezone") or "").strip()

    update = {}
    if lat is None or lng is None:
        coords = geocode_place(loc)
        if not coords:
            return None
        lat, lng = coords
        update["club_lat"] = lat
        update["club_lng"] = lng
        time.sleep(1.1)  # Nominatim rate limit courtesy

    if not tz:
        club = {
            "club_lat": lat,
            "club_lng": lng,
            "club_timezone": "",
            "club_name": data.get("club_name"),
        }
        tz = resolve_club_timezone(club)
        if tz:
            update["club_timezone"] = tz

    if not update:
        return None

    if not dry_run:
        db.collection("users").document(doc_id).set(update, merge=True)

    return {
        "uid": doc_id,
        "club_name": data.get("club_name"),
        "update": update,
    }


def main():
    parser = argparse.ArgumentParser(description="Backfill club geo/timezone fields")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    db = get_db()
    if db is None:
        print("ERROR: Firebase Admin not configured")
        sys.exit(1)

    updated = 0
    skipped = 0
    for doc in db.collection("users").stream():
        data = doc.to_dict() or {}
        if not needs_backfill(data):
            continue
        result = backfill_doc(db, doc.id, data, args.dry_run)
        if result:
            updated += 1
            name = (result.get("club_name") or doc.id).encode("ascii", "replace").decode("ascii")
            print(f"  {name}: {result['update']}")
        else:
            skipped += 1
            name = (data.get("club_name") or doc.id).encode("ascii", "replace").decode("ascii")
            loc = (data.get("club_location") or "").encode("ascii", "replace").decode("ascii")
            print(f"  SKIP {name}: could not geocode '{loc}'")

    print(f"Done. Updated {updated}, skipped {skipped} (dry_run={args.dry_run})")


if __name__ == "__main__":
    main()
