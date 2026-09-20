# Toastmasters Daily

Production SaaS for **Toastmasters clubs** — live meetings (guests, polls, speech evals, agendas), club discovery, **Stripe** subscriptions, and **Toasty**, a geo-aware LangGraph agent on Cloud Run.

**Live:** [toastmastersdaily.com](https://toastmastersdaily.com)

## Why this stack looks “old”

This product shipped early and iterates on real club usage. The **web client is vanilla HTML, CSS, and JavaScript** on Firebase Hosting (Flutter was removed). There is **no Next.js or TypeScript frontend** here — by design for that phase of the product.

Later client and product work (e.g. expense automation, school-property PoCs, studio tools) moved to **Next.js, React, and TypeScript** for typed UI, App Router APIs, and shared component patterns. Toastmasters Daily remains the reference for **Firebase-first, real-time meeting ops** and **dual Firebase projects** (club vs member apps); new greenfield apps use the TS/Next stack.

## Features

- **Club officers** — trial or Stripe subscription; create meetings (QR/code), host live polls and evals, agenda PDF to Storage.
- **Guests** — join meetings and club pages without an account; device-scoped guest flows.
- **Members** — separate Firebase app for member discovery and club location (Nominatim + IANA timezone).
- **Toasty** — FastAPI + LangGraph + GPT-4o on Cloud Run; SSE streaming; tools for nearby signed-up clubs (~80 km), club lookup, and web search fallback for official Toastmasters listings.
- **Boundaries** — votes and eval writes through Cloud Functions; subscription checks on host actions.

## Repository layout

```
toastmasters_daily/
├── site/                         # Firebase (hosting, Firestore, Functions, Storage)
│   ├── public/                   # Static HTML / CSS / JS
│   ├── functions/                # Cloud Functions (Stripe, meetings, votes, …)
│   ├── firestore.rules
│   └── docs/                     # LIVE.md, SCOPE.md, journals
└── agents/toastmasters_agent/    # LangGraph chat agent (Cloud Run)
```

Site-specific quick start: [site/README.md](site/README.md). Agent deploy: [agents/toastmasters_agent/README.md](agents/toastmasters_agent/README.md).

## Stack

| Area | Technology |
|------|------------|
| Web UI | **Vanilla HTML/CSS/JS** (static `public/`), local `start-server.py` for dev rewrites |
| Backend | Firebase **Cloud Functions** (Node 20), Firestore, Storage, Hosting |
| Auth | **Two Firebase projects** — `toastmasters-daily` (clubs) and `toastmasters-daily-members` (members) |
| Payments | Stripe Checkout / Portal / webhooks (secrets in Functions config, not in git) |
| Agent | Python, FastAPI, LangGraph, OpenAI; deploy to **Google Cloud Run** |
| Geo | Nominatim, `geo-tz`, club-local meeting times |

## Quick start (local UI)

```bash
cd site
python start-server.py   # http://localhost:3000 — rewrites for /clubs/* and /meetings/*
```

Windows: `site/start-server.bat`

Functions (optional):

```bash
cd site/functions && npm install
firebase emulators:start --only functions,firestore
```

Production Firebase config is in `site/public/js/firebase-config.js` (public web SDK). You need your own Firebase project to run a full clone; this repo documents the **production architecture**, not hosted credentials.

## Agent (Toasty)

From `agents/toastmasters_agent`:

1. Copy `env.yaml.example` → `env.yaml` (gitignored) with your OpenAI key and Firebase service account JSON.
2. Local: Docker or `uvicorn app:app --port 8080`.
3. Deploy: `gcloud run deploy` with `--env-vars-file=env.yaml` (see agent README).

**Do not** run `seed_nz_clubs.py` against production — demo seed clubs were removed from prod search.

## Firestore rules

Guest-friendly reads and writes are intentional for meeting join flows; sensitive writes (votes, evals) go through Functions. Review [`site/firestore.rules`](site/firestore.rules) before deploying your own fork.

## Documentation

| Doc | Purpose |
|-----|---------|
| [site/docs/LIVE.md](site/docs/LIVE.md) | Architecture, routes, deploy |
| [site/docs/SCOPE.md](site/docs/SCOPE.md) | Product boundaries |
| [site/theme.md](site/theme.md) | Visual design system |

## Security

No Stripe secrets, webhook secrets, or service account keys are committed. Agent credentials live only in `env.yaml` (gitignored). Use Firebase Functions config / Secret Manager in production.

## License

All rights reserved unless a `LICENSE` file is added later. Public for portfolio and technical review; ask before commercial reuse.
