# sandbox-computer

This repo is the source of a portable Docker demo/example sandbox, published to
`ghcr.io/joelhooks/sandbox-computer`. See `README.md` for the full contract.

Two audiences, don't mix them up:

- `README.md` / this file — for agents working **on** this repo (bumping versions, editing the
  Dockerfile, changing the publish workflow).
- `docker/sandbox-agent-notice.md` — for agents working **inside** a running sandbox container in
  some other project. It gets copied into the image and describes the clean-room contract and the
  host-owns-URLs rule from that container's point of view.

`scripts/sandbox-init.sh` is the portable entry point other projects use to pull this template in.
It only copies a fixed allowlist of paths (`docker/`, `docker-compose.yml`, and the `scripts/*.sh`
that don't depend on anything outside this repo) — keep new portable scripts self-contained so
they survive being copied elsewhere.

Do not add project-specific (workshop/course/client) content here. If a demo needs something
beyond the base contract, that belongs in the project that scaffolds this template in, not in this
repo.
