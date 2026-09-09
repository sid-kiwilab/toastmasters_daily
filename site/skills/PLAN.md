# PLAN — scope before code

Planning mode. **No implementation** unless the user asks to build in the same message.

**Default rule:** Don't change code, docs, or structure unless the user specifically asked. Plan only what they requested. See [LIVE](../docs/LIVE.md#default-rule).

## Read first

- [`README.md`](../README.md)
- [`docs/LIVE.md`](../docs/LIVE.md) — goals, architecture, deploy
- [`docs/SCOPE.md`](../docs/SCOPE.md) — product boundaries
- [`docs/JOURNAL.md`](../docs/JOURNAL.md) — read **your** `docs/journal/<git-username>.md`
- [`theme.md`](../theme.md) — if UI changes
- Relevant area under `public/` or `functions/utils/`

## Output a short plan

- **Scope** — what and why
- **Touch points** — likely HTML/JS paths, Functions modules, rules
- **Risks** — auth (club vs member), subscription gates, Firestore rules, Stripe, rate limits
- **Out of scope** — what we're not doing
- **Questions** — only if blocked (1–2 max)

## Build principles

From [LIVE](../docs/LIVE.md#build-principles):

- Static-first — no build step unless unavoidable
- Callable Functions for privileged writes
- Match existing patterns in `public/js/` and `functions/utils/`
- Plain user-facing copy

No code yet. Keep the plan lean.
