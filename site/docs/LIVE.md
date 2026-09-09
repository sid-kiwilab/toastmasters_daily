# Toastmasters Daily — live

Single source of truth for goals, architecture, and current state. Session notes go in [JOURNAL.md](JOURNAL.md).

## What this is

Web app for Toastmasters clubs to run live meetings: hosts create meetings and manage polls/evals/agendas; members and guests join via link. Club officers subscribe via Stripe (or use a 30-day trial). A Cloud Run agent provides optional AI chat.

**Repo layout**

```
toastmasters_daily/
├── site/                    # Firebase site (hosting, functions, rules, public/)
│   ├── public/              # Static HTML/JS/CSS
│   ├── functions/           # Cloud Functions (auto-import from utils/)
│   ├── docs/                # Project docs (this folder)
│   └── skills/              # Agent workflow skills
└── agents/
    └── toastmasters_agent/  # LangGraph chat agent (Cloud Run)
```

## Default rule

Don't change code, docs, or structure unless the user specifically asked. Plan/fix/sync only what they requested.

## Build principles

- **Lean** — no extra layers, shims, or abstractions the user didn't ask for
- **Match the repo** — static pages + callable Functions; dual Firebase apps for club vs member
- **Robust at boundaries** — auth, subscription checks, and rate limits in Functions; don't trust client writes for votes/evals
- **Plain copy** — user-facing text should be clear for club officers and guests

## Visual design system

See [`theme.md`](../theme.md) — indigo/purple gradients, GoogleSans, 1200px max content width, card/tile patterns.

## Current state

### Firebase projects

| Alias | Project ID | Used for |
|-------|------------|----------|
| default | `toastmasters-daily` | Hosting, Firestore, club auth, Functions, Storage |
| members | `toastmasters-daily-members` | Member auth only |

Client config: `public/js/firebase-config.js`. Shared auth helpers: `public/js/auth-utils.js`.

### Public routes

| Route | Purpose |
|-------|---------|
| `/` | Marketing home + Toasty chat (nearest-club discovery) |
| `/club-login`, `/club-signup` | Club officer auth |
| `/member-login`, `/member-signup` | Member auth |
| `/club-base/` | Club dashboard (meetings, guests) |
| `/club-base/meetings/`, `/club-base/guests/` | Sub-pages |
| `/member-base/` | Member home |
| `/meetings/{id}` | Live meeting (rewrite → `meetings/index.html`) |
| `/clubs/{code}` | Club discovery / guest entry (rewrite → `clubs/index.html`) |
| `/payment-success`, `/payment-cancelled` | Stripe return URLs |
| `/terms`, `/privacy` | Legal |

### Cloud Functions

Auto-loaded from `functions/utils/*.js` via `functions/index.js`.

| Export | Module | Notes |
|--------|--------|-------|
| `create_meeting`, `delete_meeting` | `meeting_functions.js` | Subscription/trial gate; daily limit |
| `submit_vote` | `poll_functions.js` | Rate limited |
| `submit_eval`, `delete_eval` | `eval_functions.js` | Admin writes |
| `upload_agenda` | `agenda_functions.js` | Storage upload |
| `create_checkout_session`, `cancel_subscription`, `resume_subscription`, `handle_stripe_webhook` | `stripe_functions.js` | Stripe config via `functions.config().stripe` |
| `create_user_document`, `delete_user_document` | `auth_functions.js` | Auth triggers; 30-day trial on signup |
| `ping_toastmasters_agent` | `pinger_functions.js` | Pub/Sub every 5 min |
| `geocode_club_location` | `geocode_functions.js` | Nominatim + geo-tz; rate limited (20/min) |
| `cleanup_rate_limits` | `rate_limiter_functions.js` | Hourly cleanup |

Rate limit tuning: [`RATE_LIMITING_GUIDE.md`](../RATE_LIMITING_GUIDE.md).

### Firestore model (summary)

- `users/{uid}` — profile, subscription, trial_end_date, stripe_customer_id, club_code, `club_name`, `club_location`, `club_info`, `club_lat`, `club_lng`, `club_timezone` (IANA)
- `users/{uid}/meetings/{meetingId}` — meeting docs; subcollections `polls/`, `evals/`
- `users/{uid}/guests/{deviceId}` — guest registry; subcollection `attendances/`
- `club_codes/{id}` — club share codes
- `active_meetings/{meetingId}` — lookup index (Functions only)
- `rate_limits/` — rate limiter state

Rules: [`firestore.rules`](../firestore.rules).

### Toastmasters agent

- Path: `agents/toastmasters_agent/`
- Deploy: Cloud Run (`gcloud run deploy toastmasters-agent …`)
- API: `POST /chat` (SSE when `stream: true`; optional `location`, `lat`, `lng` from browser geolocation)
- Tools: `find_nearby_clubs` (Firestore + haversine), `find_club` (name lookup + details), `web_search` (general TI info only — not for nearest club)
- Warmth: Firebase pinger + optional `--min-instances 1`
- Seed/backfill: `scripts/seed_nz_clubs.py`, `scripts/backfill_club_geo.py`

See [`agents/toastmasters_agent/README.md`](../../agents/toastmasters_agent/README.md).

### Environment & secrets

**Functions (Firebase config or env)**

- `stripe.secret_key`, `stripe.club_price_id` (and related Stripe vars)
- Set via `firebase functions:config:set` or deployment env

**Agent (`agents/toastmasters_agent/env.yaml`, gitignored)**

- `OPENAI_API_KEY`

**Client**

- Firebase web config is in `firebase-config.js` (public API keys — normal for Firebase)

### Key files

| Concern | Path |
|---------|------|
| Meeting runtime | `public/js/meetings/meeting-app.js`, `meeting-state.js`, `meeting-polls.js`, `meeting-evals.js` |
| Guest entry | `public/js/guest-entry.js` |
| Club timezone helpers | `public/js/club-timezone.js` |
| Notifications | `public/js/notifications.js` |
| Hosting | `firebase.json`, `.firebaserc` |
| Local server | `start-server.py`, `start-server.bat` |

## Goals

1. **Reliable live meetings** — join link, polls, evals, agenda work on meeting night
2. **Sustainable club revenue** — trial → Stripe subscription for hosting features
3. **Low ops burden** — Firebase + static front end; minimal moving parts
4. **Helpful agent** — fast first token via warm Cloud Run instance

## Milestones

### M0 — Foundation ✓

Firebase Hosting, dual auth, Firestore rules, core Functions

### M1 — Live meeting ✓

Meeting page, polls, evals, guest flow

### M2 — Club & member portals ✓

club-base, member-base, club codes, Stripe checkout

### M3 — Agent ✓

Cloud Run agent, pinger, streaming chat integration

### M4 — Polish & growth (ongoing)

Performance, UX, discovery, monitoring — track in journals

## Open decisions

- Whether to consolidate dual Firebase projects long term
- Agent UX surfacing in member-base vs meeting page only
- Analytics / error reporting strategy (currently minimal)

## Local development

From `site/`:

```bash
# Static site with URL rewrites (port 3000)
python start-server.py
# or
start-server.bat
```

Functions locally:

```bash
cd functions && npm install
firebase emulators:start --only functions,firestore
```

Agent locally: see agent README (Docker or uvicorn on 8080).

## Deploy

### Site (hosting + rules + functions)

From `site/` with Firebase CLI logged in:

```bash
firebase deploy --only hosting,firestore,storage,functions
```

Deploy subsets when appropriate:

```bash
firebase deploy --only hosting
firebase deploy --only functions
```

**Before functions deploy:** confirm Stripe config is set on the target project.

### Agent

From `agents/toastmasters_agent/`:

```bash
gcloud run deploy toastmasters-agent --source . --project toastmasters-daily --region us-central1 --env-vars-file=env.yaml --allow-unauthenticated
```

Update `pinger_functions.js` if the Cloud Run URL changes.

## Ship safely

1. Test locally on port 3000 — especially `/meetings/{id}` and `/clubs/{code}` rewrites
2. If Firestore rules or indexes changed, deploy rules/indexes before or with functions
3. If Functions behavior changed, exercise callable paths (meeting create, vote, Stripe webhook in staging if available)
4. After hosting deploy, smoke-test production URLs for changed pages
5. Never deploy untested rule changes that broaden write access

**Destructive / high-risk**

- `firestore.rules` changes that allow client writes on evals/votes/active_meetings
- Stripe webhook secret mismatch (subscriptions stop updating)
- Deleting Cloud Functions still referenced by the client

## Branch workflow

1. Branch from `main`
2. PLAN → implement → REVIEW → FIX (ship gate) → SYNC
3. Merge when preview/manual testing passes

## Contributors

See [JOURNAL.md](JOURNAL.md) for per-user session logs.

## Related

- [SCOPE.md](SCOPE.md) — product boundaries
- [README.md](../README.md) — onboarding
- [RATE_LIMITING_GUIDE.md](../RATE_LIMITING_GUIDE.md)
- [theme.md](../theme.md)
