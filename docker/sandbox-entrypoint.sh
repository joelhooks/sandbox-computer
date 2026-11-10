#!/usr/bin/env bash
# Sandbox entrypoint: one first-run step, then exec the requested command.
#
# claude-bridge is installed into the image's ~/.pi/agent at build time. Docker
# copies that into the machine-wide sandbox-pi volume only when the volume is
# first created, so a volume made by an older image never sees it. This adds it
# once per volume, and only when no pi-claude-bridge source is declared at all,
# so a fork installed from git is left alone.
#
# Fails open: an offline or failed install prints a warning and the shell still
# starts; it retries on the next start. SANDBOX_CLAUDE_BRIDGE=0 skips it.
set -uo pipefail

ensure_claude_bridge() {
  [[ "${SANDBOX_CLAUDE_BRIDGE:-1}" == "0" ]] && return 0

  local agent_dir="${PI_CODING_AGENT_DIR:-${HOME}/.pi/agent}"
  local settings="${agent_dir}/settings.json"
  local marker="${agent_dir}/.sandbox-claude-bridge-offered"
  local spec="npm:pi-claude-bridge@${PI_CLAUDE_BRIDGE_VERSION:-latest}"

  # Already declared (npm or a fork), or already offered once and removed on purpose.
  [[ -f "${marker}" ]] && return 0
  if [[ -f "${settings}" ]] && grep -q 'pi-claude-bridge' "${settings}"; then
    return 0
  fi
  command -v pi >/dev/null 2>&1 || return 0

  echo "sandbox: adding claude-bridge to this machine's Pi config (${spec})..." >&2
  if timeout 180 pi install "${spec}" >/dev/null 2>&1; then
    mkdir -p "${agent_dir}" && : > "${marker}"
    echo "sandbox: claude-bridge added. Run \`claude\` once to log in, then pick a claude-bridge/* model in Pi." >&2
  else
    echo "sandbox: could not install claude-bridge (offline?). Pi still works; retrying next start, or run: pi install ${spec}" >&2
  fi
}

ensure_claude_bridge

if [[ $# -eq 0 ]]; then
  set -- zsh
fi
exec "$@"
