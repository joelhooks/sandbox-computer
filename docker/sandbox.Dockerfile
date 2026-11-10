# syntax=docker/dockerfile:1.7

# Pin a Node 24 patch release: starters demoed from this image need >=24.18.0,
# and the floating node:24-bookworm tag gives no lower bound.
FROM node:24.22.2-bookworm

LABEL org.opencontainers.image.source="https://github.com/joelhooks/sandbox-computer"
LABEL org.opencontainers.image.description="Joel's demo/example sandbox computer"

ARG PI_VERSION=1.5.2
ARG PI_CLAUDE_BRIDGE_VERSION=0.12.0
ARG CLAUDE_CODE_VERSION=2.1.322
ARG CODEX_VERSION=0.167.1
ARG OPENCODE_VERSION=1.19.5
ARG HERDR_VERSION=0.9.5
ARG PNPM_VERSION=12.18.0
# npm is pinned, not left at Node's bundled release (11.19.1 in 24.22.2): some
# Pi packages declare an exact npm in devEngines with onFail "error", and Pi
# installs packages with npm, so a newer npm refuses them (EBADDEVENGINES).
# Lift this when those packages relax the pin.
ARG NPM_VERSION=11.16.0
ARG STARSHIP_VERSION=1.27.0
ARG ATUIN_VERSION=18.24.6
ARG OH_MY_ZSH_REF=65749801cf4c3b1f3c79a20001909d72dadd307f
ARG ZSH_AUTOSUGGESTIONS_REF=85919cd1ffa7d2d5412f6d3fe437ebdbeeec4fc5
ARG ZSH_SYNTAX_HIGHLIGHTING_REF=0bfcb582e71d3abe604ce67bc0fe5a21f377507e
ARG TARGETARCH
ARG USERNAME=sandbox
ARG USER_UID=1001
ARG USER_GID=1001

ENV DEBIAN_FRONTEND=noninteractive
ENV PNPM_HOME=/home/${USERNAME}/.local/share/pnpm
ENV NPM_CONFIG_STORE_DIR=/home/${USERNAME}/.local/share/pnpm/store
ENV PATH=/home/${USERNAME}/.local/share/pnpm:/home/${USERNAME}/.npm-global/bin:/home/${USERNAME}/.local/bin:/usr/local/bin:/usr/local/sbin:/usr/sbin:/usr/bin:/sbin:/bin
ENV SHELL=/usr/bin/zsh
ENV COREPACK_ENABLE_DOWNLOAD_PROMPT=0
# Pi is pinned in this image (and projects pin their own); skip the
# "run pi update" prompt that would steer guests off the pinned version.
ENV PI_SKIP_VERSION_CHECK=1

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    fd-find \
    fzf \
    git \
    jq \
    less \
    nano \
    locales \
    openssh-client \
    ripgrep \
    sudo \
    unzip \
    zsh \
  && rm -rf /var/lib/apt/lists/* \
  && sed -i 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen \
  && locale-gen

ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

RUN groupadd --gid ${USER_GID} ${USERNAME} \
  && useradd --uid ${USER_UID} --gid ${USER_GID} -m -s /usr/bin/zsh ${USERNAME} \
  && echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${USERNAME} \
  && chmod 0440 /etc/sudoers.d/${USERNAME}

RUN npm install -g npm@${NPM_VERSION} \
  && npm --version \
  && corepack enable \
  && corepack prepare pnpm@${PNPM_VERSION} --activate \
  && npm install -g --ignore-scripts @earendil-works/pi-coding-agent@${PI_VERSION} \
  && npm install -g \
    @anthropic-ai/claude-code@${CLAUDE_CODE_VERSION} \
    @openai/codex@${CODEX_VERSION} \
    opencode-ai@${OPENCODE_VERSION} \
  && case "${TARGETARCH:-$(dpkg --print-architecture)}" in \
    amd64) herdr_arch="x86_64" ;; \
    arm64) herdr_arch="aarch64" ;; \
    *) echo "Unsupported Herdr architecture: ${TARGETARCH:-$(dpkg --print-architecture)}" >&2; exit 1 ;; \
  esac \
  && curl -fsSL -o /usr/local/bin/herdr "https://github.com/ogulcancelik/herdr/releases/download/v${HERDR_VERSION}/herdr-linux-${herdr_arch}" \
  && chmod +x /usr/local/bin/herdr \
  && herdr --version

RUN case "${TARGETARCH:-$(dpkg --print-architecture)}" in \
    amd64) starship_target="x86_64-unknown-linux-gnu" ;; \
    arm64) starship_target="aarch64-unknown-linux-musl" ;; \
    *) echo "Unsupported Starship architecture: ${TARGETARCH:-$(dpkg --print-architecture)}" >&2; exit 1 ;; \
  esac \
  && curl -fsSL -o /tmp/starship.tar.gz "https://github.com/starship/starship/releases/download/v${STARSHIP_VERSION}/starship-${starship_target}.tar.gz" \
  && tar -xzf /tmp/starship.tar.gz -C /usr/local/bin starship \
  && chmod +x /usr/local/bin/starship \
  && rm /tmp/starship.tar.gz \
  && starship --version

RUN case "${TARGETARCH:-$(dpkg --print-architecture)}" in \
    amd64) atuin_target="x86_64-unknown-linux-musl" ;; \
    arm64) atuin_target="aarch64-unknown-linux-musl" ;; \
    *) echo "Unsupported Atuin architecture: ${TARGETARCH:-$(dpkg --print-architecture)}" >&2; exit 1 ;; \
  esac \
  && cd /tmp \
  && atuin_archive="atuin-${atuin_target}.tar.gz" \
  && curl -fsSLO "https://github.com/atuinsh/atuin/releases/download/v${ATUIN_VERSION}/${atuin_archive}" \
  && curl -fsSLO "https://github.com/atuinsh/atuin/releases/download/v${ATUIN_VERSION}/${atuin_archive}.sha256" \
  && sha256sum -c "${atuin_archive}.sha256" \
  && tar -xzf "${atuin_archive}" \
  && install -m 0755 "atuin-${atuin_target}/atuin" /usr/local/bin/atuin \
  && rm -rf "${atuin_archive}" "${atuin_archive}.sha256" "atuin-${atuin_target}" \
  && atuin --version

# npm is pinned above; don't nag guests to upgrade it.
ENV NPM_CONFIG_UPDATE_NOTIFIER=false

USER ${USERNAME}
WORKDIR /workspace

RUN install_git_ref() { \
    repo="$1"; ref="$2"; dest="$3"; \
    mkdir -p "${dest}"; \
    git -C "${dest}" init -q; \
    git -C "${dest}" remote add origin "${repo}"; \
    git -C "${dest}" fetch --depth=1 origin "${ref}"; \
    git -C "${dest}" checkout -q FETCH_HEAD; \
  }; \
  install_git_ref https://github.com/ohmyzsh/ohmyzsh.git "${OH_MY_ZSH_REF}" /home/${USERNAME}/.oh-my-zsh; \
  install_git_ref https://github.com/zsh-users/zsh-autosuggestions.git "${ZSH_AUTOSUGGESTIONS_REF}" /home/${USERNAME}/.oh-my-zsh/custom/plugins/zsh-autosuggestions; \
  install_git_ref https://github.com/zsh-users/zsh-syntax-highlighting.git "${ZSH_SYNTAX_HIGHLIGHTING_REF}" /home/${USERNAME}/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting

COPY --chown=sandbox:sandbox docker/sandbox.zshrc /home/sandbox/.zshrc
COPY --chown=sandbox:sandbox docker/zsh-completions/ /home/sandbox/.zsh/completions/
COPY --chown=sandbox:sandbox docker/sandbox-agent-notice.md /home/sandbox/agent-notice.md

RUN mkdir -p /home/${USERNAME}/.cache /home/${USERNAME}/.config/atuin /home/${USERNAME}/.config/herdr /home/${USERNAME}/.local/bin /home/${USERNAME}/.local/share/opencode /home/${USERNAME}/.local/share/pnpm/store /home/${USERNAME}/.local/state /home/${USERNAME}/.pi/agent/extensions /home/${USERNAME}/.pi/agent/sessions /home/${USERNAME}/.claude /home/${USERNAME}/.codex /home/${USERNAME}/.opencode \
  && starship preset pure-preset -o /home/${USERNAME}/.config/starship.toml \
  && pnpm config set store-dir /home/${USERNAME}/.local/share/pnpm/store --global \
  && codex completion zsh > /home/${USERNAME}/.zsh/completions/_codex \
  && pnpm completion zsh > /home/${USERNAME}/.zsh/completions/_pnpm \
  && atuin gen-completions --shell zsh > /home/${USERNAME}/.zsh/completions/_atuin \
  && printf '%s\n' 'auto_sync = false' 'update_check = false' 'style = "compact"' 'inline_height = 20' 'show_preview = true' 'enter_accept = true' > /home/${USERNAME}/.config/atuin/config.toml

# claude-bridge lets Pi use Claude Code, and a Claude plan login, as a model
# provider (claude-bridge/* models). Installed the way Pi installs packages,
# into the image's ~/.pi/agent (settings.json + npm/). No login and no keys:
# the guest runs `claude` once to log in, and that state lives in the
# sandbox-claude volume. Docker copies this into a sandbox-pi volume only when
# that volume is first created; the entrypoint below covers older volumes.
ENV PI_CLAUDE_BRIDGE_VERSION=${PI_CLAUDE_BRIDGE_VERSION}
RUN pi install npm:pi-claude-bridge@${PI_CLAUDE_BRIDGE_VERSION} \
  && pi list \
  && : > /home/${USERNAME}/.pi/agent/.sandbox-claude-bridge-offered

# Adds claude-bridge once to a sandbox-pi volume made by an older image.
COPY --chmod=0755 docker/sandbox-entrypoint.sh /usr/local/bin/sandbox-entrypoint
ENTRYPOINT ["/usr/local/bin/sandbox-entrypoint"]

CMD ["zsh"]
