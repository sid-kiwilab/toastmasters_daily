# Toastmasters Daily — site

Firebase-hosted web app for live Toastmasters meetings, club management, member discovery, and Stripe subscriptions.

**Production:** [toastmastersdaily.com](https://toastmastersdaily.com) · Firebase project `toastmasters-daily`

## Repo layout

```
site/
├── public/           # Static HTML, CSS, JS
├── functions/        # Cloud Functions (utils/*.js auto-imported)
├── docs/             # LIVE, SCOPE, journals
├── skills/           # Agent workflow (PLAN → REVIEW → FIX → SYNC)
├── firebase.json
├── firestore.rules
└── theme.md          # Design system
```

AI chat agent lives in `../agents/toastmasters_agent/` (Cloud Run, separate deploy). Nearest-club discovery uses Firestore geo lookup; seed demo clubs with `python scripts/seed_nz_clubs.py` from that folder.

## Quick start

```bash
cd site
python start-server.py   # http://localhost:3000 — URL rewrites for /clubs/* and /meetings/*
```

Windows: `start-server.bat`

Functions:

```bash
cd functions && npm install
firebase emulators:start --only functions,firestore
```

## Agent workflow

| Skill | When |
|-------|------|
| [PLAN](skills/PLAN.md) | Before coding — scope and touch points |
| [SCOPE](skills/SCOPE.md) | Check request fits the product |
| [REVIEW](skills/REVIEW.md) | After implementation — read-only review |
| [FIX](skills/FIX.md) | Address findings + ship gate |
| [SYNC](skills/SYNC.md) | Update docs/journal when solid |
| [firebase-deploy](skills/firebase-deploy/SKILL.md) | Deploy hosting, rules, functions, agent |

Shared state: [docs/LIVE.md](docs/LIVE.md) · Product boundaries: [docs/SCOPE.md](docs/SCOPE.md)

## Deploy

```bash
cd site
firebase deploy --only hosting,firestore,storage,functions
```

See [docs/LIVE.md — Deploy](docs/LIVE.md#deploy) and [skills/firebase-deploy/SKILL.md](skills/firebase-deploy/SKILL.md).

## Related docs

- [RATE_LIMITING_GUIDE.md](RATE_LIMITING_GUIDE.md)
- [theme.md](theme.md)
- [agents/toastmasters_agent/README.md](../agents/toastmasters_agent/README.md)
