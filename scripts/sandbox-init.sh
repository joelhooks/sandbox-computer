#!/usr/bin/env bash
# Scaffold the sandbox-computer template into a project directory.
#
# Usage:
#   sandbox-init.sh [target-dir]
#
# Copies docker/, docker-compose.yml, and the portable scripts/ into
# target-dir (default: current directory). Safe to re-run: existing files
# are left alone unless SANDBOX_INIT_FORCE=1 is set.
set -euo pipefail

script_path="${BASH_SOURCE[0]}"
while [[ -L "${script_path}" ]]; do
  link_target="$(readlink "${script_path}")"
  case "${link_target}" in
    /*) script_path="${link_target}" ;;
    *) script_path="$(dirname "${script_path}")/${link_target}" ;;
  esac
done
template_root="$(cd "$(dirname "${script_path}")/.." && pwd)"
target_dir="$(cd "${1:-.}" && pwd)"

portable_paths=(
  "docker/sandbox.Dockerfile"
  "docker/sandbox-entrypoint.sh"
  "docker/sandbox.zshrc"
  "docker/sandbox-agent-notice.md"
  "docker/zsh-completions"
  "docker-compose.yml"
  "scripts/docker-compose.sh"
  "scripts/start-sandbox-herdr.sh"
  "scripts/sandbox-ui-url.sh"
)

force="${SANDBOX_INIT_FORCE:-0}"
copied=()
skipped=()

for rel_path in "${portable_paths[@]}"; do
  src="${template_root}/${rel_path}"
  dest="${target_dir}/${rel_path}"

  if [[ ! -e "${src}" ]]; then
    echo "warning: missing ${rel_path} in template at ${template_root}" >&2
    continue
  fi

  if [[ -e "${dest}" && "${force}" != "1" ]]; then
    skipped+=("${rel_path}")
    continue
  fi

  mkdir -p "$(dirname "${dest}")"
  cp -R "${src}" "${dest}"
  copied+=("${rel_path}")
done

for script in scripts/docker-compose.sh scripts/start-sandbox-herdr.sh scripts/sandbox-ui-url.sh; do
  [[ -f "${target_dir}/${script}" ]] && chmod +x "${target_dir}/${script}"
done

if ((${#copied[@]} > 0)); then
  echo "Copied:"
  printf '  %s\n' "${copied[@]}"
fi

if ((${#skipped[@]} > 0)); then
  echo "Already present, left alone (set SANDBOX_INIT_FORCE=1 to overwrite):"
  printf '  %s\n' "${skipped[@]}"
fi

cat <<EOF

Next steps in ${target_dir}:

  bash scripts/docker-compose.sh pull sandbox   # or: build sandbox
  bash scripts/docker-compose.sh run --rm sandbox

To expose a demo port safely (host owns the URL, container never does):

  bash scripts/docker-compose.sh run --rm --service-ports sandbox
  bash scripts/sandbox-ui-url.sh --serve
EOF
