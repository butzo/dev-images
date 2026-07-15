# dev-images — container kit

One repo holds everything container-related: the images, the project
template, and the personal-config snippets. Push this as
`github.com/butzo/dev-images`.

```
Containerfile.base      arch-dev:base  (shell/editor env, LSPs, yay, claude, bwrap)
Containerfile.aio       arch-dev:aio   (base + python, java, julia, rust, typst, C/C++)
justfile                local image builds (CI does the weekly ones)
.github/workflows/      weekly ghcr.io builds
project-template/       copy into each project repo (.devcontainer/ + justfile)
snippets/               goes into your dotfiles / .claude repo (see below)
```

Images are published to `ghcr.io/butzo/arch-dev:{base,aio}` plus dated
tags (`aio-YYYY-MM-DD`) for pinning. Weekly rebuild: Mondays 04:00 UTC,
`--no-cache` so pacman is actually fresh; also rebuilds on Containerfile
changes and manually via the Actions tab (workflow_dispatch).

---

## One-time setup

1. **Push this repo** to GitHub as `butzo/dev-images`.
2. **Trigger the workflow** once manually (Actions → build images → Run).
3. **Make the packages public**: GitHub → your profile → Packages →
   `arch-dev` → settings → visibility public. (Otherwise: `podman login
   ghcr.io` with a read:packages token on every machine that pulls.)
4. **Install the devcontainer CLI** on the host:
   AUR `devcontainer-cli` or `npm i -g @devcontainers/cli`.
   If your setup needs it, add `--docker-path podman` to the template
   justfile recipes (test first — `just raw-enter` always works regardless).
5. **Personal mounts**: copy `snippets/mounts.flags` to
   `~/.config/devcontainer/mounts.flags`, adjust the `/home/chris` paths.
   All dotfile mounts are read-only; host `~/.claude` mounts ro at
   `/claude-seed`. Keep this file in your dotfiles repo.
6. **.claude as a git repo**: `cd ~/.claude && git init`, add
   `snippets/claude-repo.gitignore` as `.gitignore` (tracks
   settings.json/skills/agents/CLAUDE.md; ignores credentials and all
   session state), commit, push to a private `butzo/claude-config`.
7. **Sandbox settings**: merge `snippets/claude-settings.json` into
   `~/.claude/settings.json` — enables the bwrap sandbox with
   `allowUnsandboxedCommands: false` and `failIfUnavailable: true`
   (fail closed) plus an egress allowlist. Verify key names against your
   Claude Code version (`claude config`) — the schema evolves.
8. Optional: export `ANTHROPIC_API_KEY` in your host env if you want
   containers to use a scoped API key instead of `claude login`.

## Per project

```sh
cp -r ~/dev-images/project-template/.devcontainer ~/projects/foo/
cp    ~/dev-images/project-template/justfile      ~/projects/foo/
cd ~/projects/foo && git add .devcontainer justfile   # commit them
just dev
```

`.devcontainer/` + justfile are project infrastructure and live committed
in the project repo (VS Code collaborators consume the same
devcontainer.json; it contains no personal paths — those come from your
mounts.flags at up-time).

First `just dev` pulls the image, creates the container, runs
post-create (copies your .claude checkout in, populates tldr cache,
smoke-tests bwrap — watch for its OK/WARNING line), and drops you in zsh.

## Daily

| Command | Effect |
|---|---|
| `just dev` | start if needed + enter zsh (the one you use) |
| `just stop` | stop the container (state persists) |
| `just rebuild` | recreate container (new mounts/config, fresh .claude copy) |
| `just update` | pull newest weekly image, then recreate |
| `just raw-enter` | plain `podman exec` bypass if the CLI misbehaves |

Inside: `nvim .`, `claude`, ad-hoc `yay -S`/`pacman -S` (dies with the
container — promote keepers into Containerfile.aio and let CI rebuild).

## Security model

- **podman** = boundary around the project environment (only workspace +
  ro dotfiles visible; `--userns=keep-id` so file ownership matches host).
- **bwrap** (Claude Code sandbox) = boundary around agent commands inside
  the container; fail-closed via `failIfUnavailable`.
- **.claude flow**: host checkout → ro `/claude-seed` mount → full copy
  (incl. `.git`) into container at create. Inspect agent-era changes with
  `git status`/`git diff` inside; worth keeping → redo on host checkout,
  commit/push there. Container copy is disposable; no push credentials
  inside.
- **Git**: identity mounted ro (commits work); SSH keys/agent never enter
  the container; pushes happen from the host.
- **Auth**: `ANTHROPIC_API_KEY` via remoteEnv, or `claude login` per
  container (state dies on rebuild).

## Known warts

- devcontainer CLI is Docker-first; podman works but keep `raw-enter`
  handy. `updateRemoteUserUID` is disabled because keep-id handles UIDs.
- `--mount ...,readonly` suffix support varies by CLI version — verify the
  nvim mount is actually ro (`touch` a file in it from inside).
- bwrap-in-podman needs nested unprivileged userns; post-create tells you
  immediately. Surgical fix: custom seccomp profile; blunt test:
  `--security-opt seccomp=unconfined` in runArgs.
- Clipboard: host→container paste works via kitty. Container-nvim → host
  clipboard uses OSC 52 (enabled conditionally in the nvim config when
  $container or $SSH_TTY is set). If kitty blocks writes, set
  `clipboard_control write-clipboard write-primary` in kitty.conf.
- After first sessions, audit `git status` in the .claude repo and extend
  its .gitignore for any state dirs your Claude Code version adds.
