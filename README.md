# sandbox-computer

A clean-room Docker sandbox for demos and examples. Not tied to any one project — drop it into
whatever you're building and get a comfortable, consistent computer to demo from.

## Contract

Includes:

- Node 22, `pnpm` via Corepack
- `zsh` with Oh My Zsh, Starship (Pure preset), Atuin, fzf
- Pi, Claude Code, Codex CLI, OpenCode, Herdr
- Per-CLI zsh completions

Does not include:

- host dotfiles, host `~/.pi`/`~/.claude`/`~/.codex`, host secrets
- anything project-specific — that lives in the project you mount at `/workspace`

Tool auth/state persists across restarts through named Docker volumes, not the image. See
`docker/sandbox-agent-notice.md` for the in-container version of this contract.

## Use in a project

From any project directory:

```sh
bash /path/to/sandbox-computer/scripts/sandbox-init.sh .
```

Or, once `sandbox-init` is on `PATH`:

```sh
sandbox-init
```

That copies `docker/`, `docker-compose.yml`, and the portable `scripts/*.sh` into the current
directory. Re-running it is safe — existing files are left alone unless
`SANDBOX_INIT_FORCE=1` is set.

Then, in the target project:

```sh
bash scripts/docker-compose.sh pull sandbox      # pulls ghcr.io/joelhooks/sandbox-computer
bash scripts/docker-compose.sh run --rm sandbox  # drops into a zsh shell at /workspace
```

No prebuilt image available? Build locally instead:

```sh
bash scripts/docker-compose.sh build sandbox
```

## Herdr

```sh
bash scripts/start-sandbox-herdr.sh
```

Pulls the latest image (falling back to a local build) and starts Herdr inside the container
at `/workspace`.

## Exposing a demo URL

The container never builds its own tunnel. Publish the port on the host, then let the host
expose it:

```sh
bash scripts/docker-compose.sh run --rm --service-ports sandbox
bash scripts/sandbox-ui-url.sh --port 3000 --serve
```

That prints a tailnet URL via `tailscale serve`. For a public URL (e.g. projector/phone demo
with no tailnet access), opt in explicitly:

```sh
SANDBOX_PUBLIC=1 bash scripts/sandbox-ui-url.sh --port 3000 --serve
```

Treat Funnel URLs as temporary demo surfaces, not permanent public APIs.

## Publishing the image

`.github/workflows/publish-image.yml` builds and pushes `ghcr.io/joelhooks/sandbox-computer`
(`:latest` + `:<sha>`, linux/amd64 + linux/arm64) on push to `main` when the Dockerfile, zshrc,
completions, or compose file change. Trigger manually with `workflow_dispatch` if needed.

## Bumping tool versions

CLI versions are `ARG`s at the top of `docker/sandbox.Dockerfile`
(`PI_VERSION`, `CLAUDE_CODE_VERSION`, `CODEX_VERSION`, `OPENCODE_VERSION`, `HERDR_VERSION`,
`STARSHIP_VERSION`, `ATUIN_VERSION`). Bump, rebuild, push to `main`.
