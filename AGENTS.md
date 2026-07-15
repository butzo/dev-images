# AGENTS.md

Working agreement for AI agents in this repo.

## Workflow

- **Present first.** Show plans, findings, or proposed solutions before touching any file.
- **Edit only on command.** Make file changes only when explicitly told to do so.
- **Explain before editing.** Describe what each change will do and why before making it.
- **Surface assumptions.** Always state assumptions made and confirm them before acting.
- **Small, scoped changes.** Keep edits focused and reviewable; no large sweeping rewrites.
- **Ask before destructive actions.** Deleting files, force-push, `git reset --hard`, etc. need approval first.
- **No unsolicited scope creep.** Don't refactor, reformat, or "improve" untouched code. If it seems worthwhile, suggest it — but only act after approval.
- **Report honestly.** If something failed or was skipped, say so plainly; never claim success unverified.
- **Commit only after approval.** Propose a commit message; commit only once approved.

## Commit messages

- **Format:** `type(scope): description` (Conventional Commits) — `scope` is the config module (a stow subfolder of `~/dotfiles`, e.g. `hyprland`, `waybar`, `wleave`).
- **Types:** `feat`, `fix`, `refactor`, `docs`, `test`, `chore`, `perf`, `ci`.
- **Keep the subject ≤ ~50 chars;** put any detail in a commit body below a blank line.

## Repo notes

- Use absolute paths — `cd` does not work reliably here (zoxide).
