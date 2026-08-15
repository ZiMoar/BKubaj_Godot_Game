# Agent Notes (for Ziva AI sessions)

Instructions that should be honored in every session. Read this file at the
start of work.

## Git workflow
- **Always `git commit` + `git push` after bigger updates** (new features,
  systems, content additions, or non-trivial rewrites).
- For small tweaks, a commit at the end of the session is fine; still push.
- Commit messages should be descriptive (e.g. the style used in recent history:
  one-line imperative summaries).
- Check `git status` before wrapping up a session to make sure nothing bigger
  is left uncommitted.

## Session continuity
- Chat/message history can be lost on resets (a known platform quirk when
  messages are queued while the agent is processing — avoid queueing plain
  messages mid-generation).
- Project state on disk is the source of truth. Re-read open scene/script files
  to re-establish context after a reset.
