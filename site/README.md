# Toastmasters Daily — Firebase site

This folder is the **Firebase app** (hosting, Firestore rules, Cloud Functions, static client).

**Start here for overview, stack notes, and live product context:** [../README.md](../README.md)

## Repo layout (this folder)

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

AI chat agent: [../agents/toastmasters_agent/](../agents/toastmasters_agent/) (Cloud Run, separate deploy).

## Quick start

```bash
python start-server.py   # http://localhost:3000 — URL rewrites for /clubs/* and /meetings/*
```

Windows: `start-server.bat`

Functions:

```bash
cd functions && npm install
firebase emulators:start --only functions,firestore
```

## Deploy

```bash
firebase deploy --only hosting,firestore,storage,functions
```

See [docs/LIVE.md](docs/LIVE.md#deploy) and [skills/firebase-deploy/SKILL.md](skills/firebase-deploy/SKILL.md).

## Related docs

- [docs/LIVE.md](docs/LIVE.md)
- [docs/SCOPE.md](docs/SCOPE.md)
- [RATE_LIMITING_GUIDE.md](RATE_LIMITING_GUIDE.md)
- [theme.md](theme.md)
