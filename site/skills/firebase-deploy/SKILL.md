# Firebase & agent deploy

Deploy guidance for **Toastmasters Daily**. Run only when the user asked to deploy or merge deploy-affecting work.

## Prerequisites

- Firebase CLI logged in: `firebase login`
- Project: `toastmasters-daily` (default in `.firebaserc`)
- For agent: `gcloud` authenticated, project `toastmasters-daily`

## What to deploy

| Change in | Deploy target |
|-----------|---------------|
| `public/` | `firebase deploy --only hosting` |
| `firestore.rules`, `firestore.indexes.json` | `firebase deploy --only firestore` |
| `storage.rules` | `firebase deploy --only storage` |
| `functions/` | `firebase deploy --only functions` |
| Agent code | Cloud Run (separate; see below) |

From `site/`:

```bash
# Full site stack
firebase deploy --only hosting,firestore,storage,functions

# Subset examples
firebase deploy --only hosting
firebase deploy --only functions
```

## Order (safe)

1. **Indexes & rules** — if new queries or rule changes
2. **Functions** — if client depends on new/changed callables
3. **Hosting** — static assets last if they call new Functions

## Functions secrets

Stripe and other secrets use Firebase Functions config:

```bash
firebase functions:config:get
# firebase functions:config:set stripe.secret_key="..." stripe.club_price_id="..."
```

After config changes, redeploy functions.

## Post-deploy smoke test

- `https://toastmastersdaily.com/` (or hosting URL)
- Club login flow (if auth touched)
- Create meeting (if functions touched)
- `/meetings/{known-id}` (if meeting UI touched)

## Agent (Cloud Run)

From `agents/toastmasters_agent/`:

```bash
gcloud run deploy toastmasters-agent \
  --source . \
  --project toastmasters-daily \
  --region us-central1 \
  --env-vars-file=env.yaml \
  --allow-unauthenticated
```

If the service URL changes, update `TOASTMASTERS_AGENT_URL` in `site/functions/utils/pinger_functions.js` and redeploy functions.

## Rollback

- **Hosting:** redeploy previous commit from `main` or use Firebase Hosting release history in console
- **Functions:** redeploy last known good git revision
- **Rules:** revert commit and `firebase deploy --only firestore,storage` — treat rule rollbacks as urgent

## Never without explicit user request

- `firebase deploy` to the **members** project (member auth is separate; default deploy is club project)
- Deleting Firestore data from console
- Force-pushing `main`
