#!/usr/bin/env bash
# Runs once, inside the container, after creation.
set -euo pipefail

# --- Claude Code config: disposable per-container copy ---------------------
# /claude-seed is the allowlisted copy `just up` stages from host ~/.claude
# (config only, incl. .git so `git status`/`git diff` inside shows what the
# agent changed). The copy is disposable: to keep a change, redo it on the
# host checkout and commit/push there (no credentials in here).
if [ ! -e "$HOME/.claude/.seeded" ] && [ -d /claude-seed ]; then
  mkdir -p "$HOME/.claude"
  cp -a /claude-seed/. "$HOME/.claude/"

  # Plugin registries hold absolute host paths (/home/<user>/.claude/plugins/...).
  for f in "$HOME/.claude/plugins/installed_plugins.json" "$HOME/.claude/plugins/known_marketplaces.json"; do
    if [ -f "$f" ]; then sed -i -E "s#\"/[^\"]*/\.claude/plugins/#\"$HOME/.claude/plugins/#g" "$f"; fi
  done

  # Global state stays container-local: nothing from the host ~/.claude.json
  # (other projects' metadata, host MCP servers). Just skip onboarding.
  if [ ! -f "$HOME/.claude.json" ]; then
    echo '{"hasCompletedOnboarding": true}' > "$HOME/.claude.json"
  fi

  cat >> "$HOME/.claude/CLAUDE.md" <<'EOF'

# Devcontainer isolation (container-only note)

You run inside a devcontainer that isolates confidential content.

- `confidential/`, `.git/git-crypt/` and, in Obsidian vaults, `.claudian/` are
  masked with empty mounts on purpose. They are not empty on the host. Do not
  try to read, restore, decrypt or work around them.
- Because of the masks, `git status` lists their tracked files as deleted.
  These deletions are not real. Never stage or commit them.
- Stage explicit paths only (`git add <path>...`). Never use `git add -A`,
  `git add .`, `git add -u` or `git commit -a`.
- Before every commit, run `git diff --cached --name-status`. If it shows any
  `D` entry under a masked path, unstage it with `git restore --staged <path>`.
- `.git/hooks`, `.git/config`, `.devcontainer/`, `justfile`, `.claude/` and
  `.obsidian/` may be read-only on purpose. Do not work around that.
EOF

  touch "$HOME/.claude/.seeded"
  echo "post-create: seeded ~/.claude from /claude-seed (allowlisted, disposable)"
fi

# --- tealdeer: populate the tldr page cache -------------------------------
command -v tldr >/dev/null && tldr --update >/dev/null 2>&1 || true

# --- Sanity: verify bwrap can actually sandbox in here --------------------
if command -v bwrap >/dev/null; then
  if bwrap --ro-bind / / true 2>/dev/null; then
    echo "post-create: bwrap OK (nested userns available)"
  else
    echo "post-create: WARNING — bwrap failed. Claude Code with" \
         "failIfUnavailable=true will refuse to run commands." \
         "Check podman seccomp/caps." >&2
  fi
fi
