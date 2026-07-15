#!/usr/bin/env bash
# Runs once, inside the container, after creation.
set -euo pipefail

# --- Claude Code config: disposable per-container copy of the host repo ---
# Host ~/.claude (a git checkout of your claude-config repo) is mounted
# READ-ONLY at /claude-seed. Copy the FULL checkout including .git so you
# can `git status`/`git diff` inside the container to inspect what the
# agent changed. The copy is disposable: to keep a change, replicate it on
# the host checkout and commit/push there (no credentials in here).
# Runtime state (history, todos, credentials) is gitignored in that repo.
if [ ! -d "$HOME/.claude/.git" ] && [ -d /claude-seed ]; then
  mkdir -p "$HOME/.claude"
  cp -a /claude-seed/. "$HOME/.claude/"
  echo "post-create: copied ~/.claude checkout from /claude-seed (disposable)"
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
