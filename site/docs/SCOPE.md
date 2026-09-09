# Toastmasters Daily — scope

Working summary of what this product is and what belongs in the repo. Use with the [SCOPE skill](../skills/SCOPE.md) to check whether a change fits.

**Snapshot date:** 2026-09-09

## What this is

**Toastmasters Daily** helps Toastmasters clubs run live meetings online: create meetings, share join links, run polls and evaluations, manage guests, upload agendas, and (for members) discover clubs and get AI help via a chat agent.

Production site: **toastmastersdaily.com** (Firebase Hosting on project `toastmasters-daily`).

## User types

| User | Auth project | Primary surfaces |
|------|--------------|------------------|
| **Club officer / meeting host** | `toastmasters-daily` (club) | Home, club signup/login, club-base dashboard, live meeting page |
| **Member / guest** | `toastmasters-daily-members` (member) | Member signup/login, member-base, guest entry, club discovery |
| **Anonymous guest** | None | Join meeting via link, guest entry form, vote in polls, submit evals |

Club hosts need an **active Stripe subscription or 30-day trial** to create meetings, manage polls, and upload agendas.

## Core features (in scope)

### Meetings

- Create/delete live meetings (Cloud Functions; subscription/trial gated)
- Shareable meeting URLs: `/meetings/{meeting_id}`
- Real-time meeting UI: agenda, roles, timers, welcome flow
- Limit: 3 meetings per host per calendar day (when datetime is set)
- `active_meetings` index for lookup (Functions write only)

### Polls & evaluations

- Polls subcollection under each meeting; voting via `submit_vote` (rate limited)
- Evaluations via `submit_eval` / `delete_eval` (client writes blocked; Functions only)

### Guests

- Guest entry form per club (`/clubs/{club_code}` or club-base guests)
- Device-based guest records with daily attendance tracking
- Unauthenticated create/update allowed by Firestore rules (by design)

### Club codes & discovery

- Club officers get a shareable club code (`club_codes` collection)
- Public club pages under `/clubs/**`

### Subscriptions (Stripe)

- Checkout, cancel, resume via callable Functions
- Webhook handler updates `users.subscription` and related fields
- Success/cancel landing pages: `/payment-success`, `/payment-cancelled`

### Agenda uploads

- `upload_agenda` callable Function (Storage + Firestore; rate limited)

### AI chat agent

- LangGraph agent on **Google Cloud Run** (`agents/toastmasters_agent`)
- Firebase scheduled Function pings agent every 5 minutes (keep warm)
- Streaming `/chat` API; CORS for toastmastersdaily.com and localhost

## Architecture (settled)

| Layer | Choice |
|-------|--------|
| Frontend | Static HTML/CSS/JS in `site/public/` (no build step) |
| Hosting | Firebase Hosting (`site/`) |
| Database | Firestore (`toastmasters-daily` project) |
| Auth | Two Firebase projects: club + member (dual-app pattern in `firebase-config.js`) |
| Backend | Firebase Cloud Functions v1 (`site/functions/utils/*.js`) |
| Files | Firebase Storage (agendas, assets) |
| Payments | Stripe (secrets in Functions config / env) |
| Agent | Cloud Run Python (LangGraph + OpenAI), separate deploy |

Local dev: `python start-server.py` or `start-server.bat` on port **3000** (URL rewrites for `/clubs/*` and `/meetings/*`).

## Out of scope (unless explicitly requested)

- Native mobile apps (Flutter folder name is historical; the shipped product is the web site)
- Full Toastmasters Pathways / TI official integrations
- Multi-club org admin / district dashboards
- Video conferencing (users bring Zoom/Meet/etc.)
- Replacing dual Firebase auth with a single project (major migration)
- Production SLAs, formal compliance certification

## Guiding principles

- **Ship for clubs first** — meeting night must work reliably with plain UX
- **Security at the boundary** — sensitive writes go through Cloud Functions; rules stay explicit
- **No build complexity** — prefer static pages and callable Functions over frameworks unless there is a strong reason
- **Lean diffs** — match existing patterns in `public/js/` and `functions/utils/`

## Key files for scope checks

| Area | Path |
|------|------|
| Hosting rewrites | `site/firebase.json` |
| Firestore rules | `site/firestore.rules` |
| Storage rules | `site/storage.rules` |
| Cloud Functions | `site/functions/utils/*.js` |
| Club UI | `site/public/club-base/`, `site/public/club-login/`, `site/public/club-signup/` |
| Member UI | `site/public/member-base/`, `site/public/member-login/`, `site/public/member-signup/` |
| Live meeting | `site/public/meetings/`, `site/public/js/meetings/` |
| Design tokens | `site/theme.md` |
| Agent | `agents/toastmasters_agent/` |
| Rate limits | `site/RATE_LIMITING_GUIDE.md` |
