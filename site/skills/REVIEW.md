# REVIEW — check the work

Post-implementation pass. Read the code — do **not** run deploy here.

**Default rule:** Don't change code, docs, or structure unless the user specifically asked. Flag out-of-scope edits. See [LIVE](../docs/LIVE.md#default-rule).

**Do not run** full Firebase deploy or emulators as a review step. Manual local testing is the FIX [ship gate](FIX.md).

## Check

From [build principles](../docs/LIVE.md#build-principles):

- Requirements met?
- Over-engineering, dead code, duplicate logic?
- Auth correct (club vs member Firebase app)?
- Subscription/trial checks on privileged actions?
- Firestore rules still block client writes where Functions should own them?
- Rate limits on new callable Functions?
- User-facing copy plain and jargon-free?
- **`firestore.rules` / indexes changed?** Flag for FIX + deploy note.

Report findings — **don't do big fixes here**. Trivial nits (dead imports) OK inline.

## Output

Findings table:

| Severity | Area | Finding |
|----------|------|---------|
| high / medium / low | file | one line |

If clean: **No findings.**

Then ship gate — answer first:

**`Solid — FIX ship gate, then SYNC.`**

or

**`Not solid:`** + blockers (→ FIX, then REVIEW again)

Never go straight to SYNC: the ship gate still has to pass once.
