# FIX — address findings

Work through REVIEW findings (or obvious bugs in scope). Lean diffs only.

**Default rule:** Don't change code, docs, or structure unless the user specifically asked. Fix only REVIEW findings or explicit requests. See [LIVE](../docs/LIVE.md#default-rule).

**Build principles:** Simple beats clever; gut dead code; don't add shims. [LIVE](../docs/LIVE.md#build-principles)

If REVIEW had no findings, skip diffs and go straight to the ship gate.

**Firestore / rules:** If `firestore.rules`, `firestore.indexes.json`, or `storage.rules` changed, note it for deploy — rules must ship with or before relying code.

Test affected routes with `python start-server.py` (port 3000) if UI changed. Use Firebase emulators if Functions logic changed.

## Ship gate (once)

Run **after** the last code change, on the frozen tree. Not during REVIEW. Not a second time to "confirm."

### UI-only changes (`public/`)

```bash
cd site
python start-server.py
```

Manually hit changed routes (`/`, `/meetings/test`, `/clubs/test`, club-base pages). Confirm no console errors on critical paths.

### Functions changes (`functions/`)

```bash
cd site/functions
npm install
node -e "require('./index'); console.log('functions load ok')"
```

Optional (if emulators available):

```bash
cd site
firebase emulators:start --only functions,firestore
```

### Rules changes

Read the diff aloud: confirm eval/vote/active_meeting writes still go through Functions only.

Fail = not done. Fix and re-run **the command that failed**. Do not restart REVIEW unless the fix changes behaviour or design.

## Report

- **Fixed** — what changed
- **Skipped** — what you left and why
- **Ship gate** — manual routes tested; functions load pass/fail; rules diff noted yes/no

If the gate passed and REVIEW was solid: **ready to SYNC.**
