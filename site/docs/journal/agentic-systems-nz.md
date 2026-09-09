# Journal — agentic-systems-nz

Newest first. Shared state: [LIVE.md](../LIVE.md).

---

## 2026-09-09 — Global web club search, local guest-join only

- **Shipped:** Typed city (e.g. Sydney CBD) is geocoded; GPS is only for "near me". Signed-up Toastmasters Daily clubs within ~80 km get compact guest-join cards. If none nearby, `web_search` lists official TI clubs (no TMD join URLs). Chat cards: one disclaimer, short "Join as guest / View club".
- **Key files:** `agents/toastmasters_agent/app.py`, `actions/find_nearby_clubs.py`, `actions/club_lookup.py`, `actions/web_search.py`, `site/public/index.html`
- **Gaps:** Calendar month nav still browser-local. Demo seed clubs in prod Firestore — remove when real clubs register.

---

## 2026-09-09 — Nearest-club agent + global timezone

- **Shipped:** Toasty finds nearest Toastmasters Daily clubs from Firestore (not web search); returns club details, meeting time in club TZ, and guest join links. Club location save geocodes to lat/lng/IANA timezone. Meeting calendar buckets by club TZ; meeting create uses club-local date/time. Demo clubs seeded (Botany, Howick, Pakuranga, Shoreditch). Chat UI shows per-club guest join cards.
- **Key files:** `agents/toastmasters_agent/actions/club_lookup.py`, `find_nearby_clubs.py`, `app.py`; `site/functions/utils/geocode_functions.js`; `site/public/js/club-timezone.js`; `site/public/index.html`; `site/public/clubs/index.html`; `site/public/club-base/index.html`; `site/public/club-base/meetings/index.html`; `agents/toastmasters_agent/scripts/seed_nz_clubs.py`, `backfill_club_geo.py`
- **Gaps:** Deploy Functions (`geocode_club_location`), Hosting, and Cloud Run agent. Calendar month nav still browser-local (edge case). Demo seed clubs in prod Firestore — remove when real clubs register.

---
