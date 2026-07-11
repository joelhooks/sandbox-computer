# Sandbox Computer

Clean room active. No host `.pi`, no private Brain, no host dotfiles, no baked secrets.

Installed CLIs:

- `pi`
- `claude`
- `codex`
- `opencode`
- `herdr`
- `git`

Run auth/setup explicitly for your chosen harness. Keep tokens out of the repo.

Tool state (`~/.pi`, `~/.claude`, `~/.codex`, `~/.opencode`, `~/.config/herdr`) persists
across restarts through named Docker volumes, not the image. Those volumes are shared by
every sandbox on this machine — log in once and other sandboxes here reuse it. That also
means `docker compose down --volumes` wipes machine-wide state, not just this project's;
to reset one tool, `docker volume rm sandbox-<tool>` deliberately instead.

If a process in this container needs to be reachable from outside Docker (a demo URL,
a webhook, a browser tab), it does **not** get its own tunnel from in here. Start the
container with `--service-ports`, publish the port on the host, and let the host expose
it (`scripts/sandbox-ui-url.sh`). The container serves the app; the host owns the URL.
