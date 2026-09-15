# devcontainer - A containerized dev environment for AI agents

Arch Linux dev containers for working with coding agents such as Claude Code.
Podman walls off the project, bubblewrap sandboxes the agent's commands inside
the container, your dotfiles are mounted read-only, and git-crypt confidential
folders are masked so nothing in the container can read them.

```
Containerfile.base    arch-dev:base   shell/editor env, LSPs, paru, bwrap
Containerfile.aio     arch-dev:aio    base + Python, Java, Julia, Rust, Typst, C/C++, Claude Code
justfile              local image builds
.github/workflows/    weekly image builds to ghcr.io
project-template/     copy into a project: .devcontainer/ + justfile
snippets/             host-side config: mounts, Claude Code settings
```

## Quick start

After the [one-time setup](#one-time-setup):

```sh
cp -r ~/devcontainer/project-template/{.devcontainer,justfile} ~/projects/foo/
cd ~/projects/foo
just dev
```

Commit `.devcontainer/` and `justfile` in the project. devcontainer.json holds
no personal paths, so collaborators (VS Code included) use the same file.

The first `just dev` pulls the image, creates the container and runs
`post-create.sh`: it copies your Claude Code config in, fills the tldr cache
and checks that bwrap works (look for its `OK` or `WARNING` line). Then it
verifies the confidential masks and opens zsh.

## One-time setup

1. **Install the tools** on the host: podman, [just](https://github.com/casey/just)
   and the devcontainer CLI (AUR `devcontainer-cli` or
   `npm i -g @devcontainers/cli`). The template justfile passes
   `--docker-path podman`; change `engine` there to use Docker.
2. **Personal mounts**: copy `snippets/mounts.env` to
   `~/.config/devcontainer/mounts.env` and keep it in your dotfiles. Each
   `DEVC_MOUNT_n` fills one of ten mount slots in devcontainer.json; unset
   slots become an empty tmpfs. Paths use `${HOME}`, which expands when the
   justfile sources the file. Slot 2 mounts the `nvim-data` volume; fill it
   with `just refresh-nvim-data` from this repo.
3. **Claude Code sandbox**: merge `snippets/claude-settings.json` into
   `~/.claude/settings.json`. It enables the bwrap sandbox fail-closed
   (`failIfUnavailable: true`, `allowUnsandboxedCommands: false`) with a
   network allowlist. Check the key names against your Claude Code version.
4. **Claude Code config in git** (optional): `git init` in `~/.claude` with
   `snippets/claude-repo.gitignore` as `.gitignore`, so you can `git diff`
   what an agent changed inside a container.
5. **Auth**: run `claude login` in each container, or export
   `ANTHROPIC_API_KEY` on the host and uncomment `remoteEnv` in
   devcontainer.json.

The template uses the images at `ghcr.io/butzo/arch-dev`. To build your own,
see [Your own images](#your-own-images).

## Commands

### In a project (`project-template/justfile`)

| Command                 | What it does                                                        |
| ----------------------- | ------------------------------------------------------------------- |
| `just dev`              | start the container if needed, verify the masks, open zsh           |
| `just up`               | create or start the container                                       |
| `just enter`            | open zsh in the running container                                   |
| `just verify-isolation` | check that every confidential mask is an empty tmpfs                |
| `just stop`             | stop the container; its state is kept                               |
| `just rebuild`          | recreate the container (new image, devcontainer.json, mounts.env)   |
| `just update`           | pull the newest image, then `rebuild`                               |
| `just raw-enter`        | `podman exec` straight in if the devcontainer CLI misbehaves        |

`up` and `rebuild` refuse to start if git-crypt is unlocked but a mask is
missing from devcontainer.json.

Inside the container: `nvim .`, `claude`, and ad-hoc `paru -S` or `pacman -S`.
Packages installed that way disappear with the container; add the ones you
keep to `Containerfile.aio`.

### In this repo (`justfile`)

| Command                              | What it does                             |
| ------------------------------------ | ---------------------------------------- |
| `just build`                         | build `base`, then `aio` (the default)   |
| `just build-base` / `just build-aio` | build one image                          |
| `just rebuild`                       | build both images without layer cache    |
| `just push`                          | push `base` and `aio` to the registry    |
| `just pull`                          | pull `aio`                               |
| `just prune`                         | remove dangling images                   |
| `just refresh-nvim-data`             | fill the `nvim-data` volume              |

## Images

`base` is the shell and editor environment: zsh, neovim, LSPs and formatters,
CLI tools, paru and bubblewrap, with a `dev` user at UID 1000. `aio` adds the
language toolchains and Claude Code.

Tags are `base` and `aio`, plus dated `base-YYYY-MM-DD` and `aio-YYYY-MM-DD`
for pinning. CI rebuilds every Monday at 04:00 UTC with `--no-cache` so
pacman packages are fresh, on every push that changes a Containerfile or the
workflow, and on demand from the Actions tab.

### Your own images

1. Fork this repo and replace `ghcr.io/butzo` in `justfile`,
   `Containerfile.aio`, `.github/workflows/build.yml` and `project-template/`.
2. Run the workflow once from the Actions tab.
3. Make the `arch-dev` package public (profile → Packages → `arch-dev` →
   settings), or `podman login ghcr.io` with a `read:packages` token on every
   machine that pulls.

## Confidential folders

For repos that use git-crypt, devcontainer.json mounts an empty tmpfs over
`confidential/` and `.git/git-crypt`. Neither the plaintext
nor the key is visible inside the container, however it is started. The masks
use `notmpcopyup`: without it podman copies the host files into the tmpfs.
`just dev` runs `verify-isolation` before opening a shell.

## Security model

- **podman** bounds the project: only the workspace and the read-only mounts
  are visible. `--userns=keep-id` keeps file ownership in line with the host.
- **bwrap** (the Claude Code sandbox) bounds agent commands inside the
  container and fails closed.
- **Git**: your identity is mounted read-only, so commits work. SSH keys and
  the agent never enter the container; push from the host.
- **Claude Code config**: host `~/.claude` is mounted read-only at
  `/claude-seed` and copied into the container when it is created. The copy is
  disposable: inspect changes with `git diff` inside and redo the ones you
  want on the host. The whole directory is copied, including
  `.credentials.json` if it exists.

## Known issues

- The devcontainer CLI is Docker-first. Podman works, but keep
  `just raw-enter` handy. `updateRemoteUserUID` is off because keep-id
  handles UIDs.
- `devcontainer up --mount` only accepts `type=bind|volume,source,target`
  (no `readonly`, no `tmpfs`), which is why mounts live in slots in
  devcontainer.json. Check that a read-only mount really is one by `touch`ing
  a file in it.
- bwrap inside podman needs nested unprivileged user namespaces;
  post-create reports whether it works. The fix is a custom seccomp profile;
  to test, add `--security-opt seccomp=unconfined` to `runArgs`.
- Symlinks inside a mounted directory dangle in the container. Stow config
  directories as folder links, not per file.
- Clipboard: pasting into the container works through the terminal. Copying
  out of nvim uses OSC 52; in kitty, allow it with
  `clipboard_control write-clipboard write-primary`.
