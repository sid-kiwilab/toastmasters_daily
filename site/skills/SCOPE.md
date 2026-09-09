# SCOPE — check the change fits

Use before or during PLAN when the request might drift outside Toastmasters Daily.

**Default rule:** Don't change code unless the user asked. This skill is read-only unless they want doc updates.

## Read

- [`docs/SCOPE.md`](../docs/SCOPE.md) — product summary
- [`docs/LIVE.md`](../docs/LIVE.md) — current architecture

## Answer

1. **In scope?** yes / no / partial
2. **Which user type?** club host · member · guest · agent
3. **Touch points** — `public/` pages, `functions/utils/` modules, rules, agent
4. **Out-of-scope risk** — one line if the ask sounds like another product (mobile app rebuild, district admin, video hosting, etc.)

## If out of scope

Say so plainly. Offer the smallest in-scope slice that still helps the user, or ask them to confirm they want to expand scope.

## If scope doc is stale

Note what's wrong and offer to update `docs/SCOPE.md` on SYNC — don't silently expand scope in code.
