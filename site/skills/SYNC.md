# SYNC — document what shipped

Run when REVIEW is solid **and** the FIX [ship gate](FIX.md) has passed once. Docs only — no new features.

**Default rule:** Don't change code, docs, or structure unless the user specifically asked. Update only LIVE/README/journal sections that match what the user requested. See [LIVE](../docs/LIVE.md#default-rule).

## Before merge to `main`

Work is not done at SYNC — the branch still has to land safely.

**Merger checklist**

1. **Local smoke test** — changed routes on `python start-server.py` (port 3000)
2. **Rules/functions PR?** — plan `firebase deploy` for the right targets after merge
3. **PR description** — note `Rules: yes/no`, `Functions: yes/no`, `Agent: yes/no`
4. **Merge to `main`** only when testing passes

Deploy playbook: [firebase-deploy/SKILL.md](firebase-deploy/SKILL.md) · [LIVE — Deploy](../docs/LIVE.md#deploy)

## Update

| Changed… | Update… |
|----------|---------|
| Goals, milestones, scope | [`docs/LIVE.md`](../docs/LIVE.md), [`docs/SCOPE.md`](../docs/SCOPE.md) |
| Routes, architecture, deploy | [`docs/LIVE.md`](../docs/LIVE.md) — current state |
| Dev commands, README | [`README.md`](../README.md) |
| This session's work | **Your** `docs/journal/<git-username>.md` — prepend dated entry |

Use `git config user.name` for your journal filename. **Do not edit other people's journals.**

Journal entry (newest first):

- **Shipped** — bullets
- **Key files**
- **Gaps** — follow-ups if any

First time? Add yourself to [JOURNAL.md](../docs/JOURNAL.md).

## Journal overflow (~25 entries)

Archive per [JOURNAL.md](../docs/JOURNAL.md) and [archive/README.md](../docs/archive/README.md).

## LIVE overflow (~500 lines)

Move superseded sections to `docs/archive/LIVE_<n>.md`; link from LIVE.

## Report

List each doc file touched, one line each.
