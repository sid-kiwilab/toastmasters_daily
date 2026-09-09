# Session journals

**One file per git user.** Shared project state lives in [LIVE.md](LIVE.md). Your journal is **only your sessions** — never edit someone else's file.

| Git user | Journal |
|----------|---------|
| sid-kiwilab | [journal/sid-kiwilab.md](journal/sid-kiwilab.md) |
| agentic-systems-nz | [journal/agentic-systems-nz.md](journal/agentic-systems-nz.md) |

## New contributor

1. Set **local** git identity in this repo:

   ```bash
   git config user.name "your-username"
   git config user.email "you@example.com"
   ```

2. Confirm: `git config user.name` → use that exact string as your filename slug.
3. Copy [`journal/_template.md`](journal/_template.md) → `journal/<your-username>.md`
4. Add a row to the table above.
5. After each solid session, prepend an entry via [SYNC](../skills/SYNC.md).

Use a filesystem-safe username (no `/` or `\`).

## Entry format

Newest at the top of **your** file:

```markdown
## YYYY-MM-DD — Short title

- **Shipped:** what landed
- **Key files:** `path/a`, `path/b`
- **Gaps:** follow-ups (optional)
```

## When your journal gets too big

**Trigger:** ~**25 entries** in your active file.

**Do this on SYNC** (your file only):

1. Move the **oldest** entries to `docs/archive/journal_<your-username>_<n>.md`
2. Keep **~15–20 newest** entries in `journal/<your-username>.md`
3. Link archive ↔ active journal at the top of each file

See [archive/README.md](archive/README.md).

## What goes where

| Doc | Who updates | Purpose |
|-----|-------------|---------|
| [LIVE.md](LIVE.md) | Anyone, on SYNC when shared state changed | Goals, architecture, deploy |
| [SCOPE.md](SCOPE.md) | When product boundaries change | Scope summary |
| `journal/<user>.md` | That user only | Session log |
| [README.md](../README.md) | On SYNC if commands/structure changed | Onboarding + skills |
