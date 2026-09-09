#!/usr/bin/env python3
"""Remove demo seed clubs (is_seed=true) from Firestore. Run once in production."""
from __future__ import annotations

import argparse
import os
import sys
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

from club_lookup import get_db  # noqa: E402


def main():
    parser = argparse.ArgumentParser(description="Delete is_seed demo clubs from Firestore")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    db = get_db()
    if db is None:
        print("ERROR: Firebase Admin not configured")
        sys.exit(1)

    removed = 0
    for doc in db.collection("users").where("is_seed", "==", True).stream():
        d = doc.to_dict() or {}
        name = d.get("club_name", doc.id)
        code = d.get("club_code")
        print(f"{'Would remove' if args.dry_run else 'Removing'}: {name} (uid={doc.id}, code={code})")
        if not args.dry_run:
            for meeting in doc.reference.collection("meetings").stream():
                meeting.reference.delete()
            if code is not None:
                code_str = str(int(code)) if isinstance(code, (int, float)) else str(code).strip()
                db.collection("club_codes").document(code_str).delete()
            doc.reference.delete()
        removed += 1

    print(f"Done. {'Would remove' if args.dry_run else 'Removed'} {removed} seed club(s).")


if __name__ == "__main__":
    main()
