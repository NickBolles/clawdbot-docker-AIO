# OpenClaw + code-server AIO image
FROM codercom/code-server:latest

USER root

# Base tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    git \
    gnupg \
    jq \
    postgresql-client \
    ripgrep \
    htop \
    vim \
    procps \
    sudo \
    wget \
    unzip \
    # Build tools (make, gcc, g++ etc. — needed for native modules)
    build-essential \
    python3 \
    python3-pip \
    # Chrome dependencies
    libnss3 \
    libnspr4 \
    libatk1.0-0 \
    libatk-bridge2.0-0 \
    libcups2 \
    libdrm2 \
    libdbus-1-3 \
    libxkbcommon0 \
    libxcomposite1 \
    libxdamage1 \
    libxfixes3 \
    libxrandr2 \
    libgbm1 \
    libpango-1.0-0 \
    libcairo2 \
    libasound2 \
    libatspi2.0-0 \
    libxss1 \
    libxtst6 \
    fonts-liberation \
    fonts-noto-color-emoji \
    && rm -rf /var/lib/apt/lists/*

# GitHub CLI
RUN curl -sSfL https://cli.github.com/packages/githubcli-archive-keyring.gpg | gpg --dearmor -o /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" > /etc/apt/sources.list.d/github-cli.list \
    && apt-get update && apt-get install -y gh && rm -rf /var/lib/apt/lists/*

# Docker CLI (for agents that need to manage test containers via host socket)
RUN curl -fsSL https://download.docker.com/linux/static/stable/x86_64/docker-27.5.1.tgz | tar xz -C /tmp \
    && mv /tmp/docker/docker /usr/local/bin/docker \
    && rm -rf /tmp/docker \
    && chmod +x /usr/local/bin/docker

# Node 22 + corepack
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y nodejs && rm -rf /var/lib/apt/lists/*

RUN corepack enable

# Bun
RUN curl -fsSL https://bun.sh/install | bash
ENV PATH="/root/.bun/bin:${PATH}"

# Google Chrome
RUN wget -q -O /tmp/google-chrome-stable_current_amd64.deb https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb \
    && apt-get update && apt-get install -y /tmp/google-chrome-stable_current_amd64.deb \
    && rm /tmp/google-chrome-stable_current_amd64.deb \
    && rm -rf /var/lib/apt/lists/*

# Playwright browsers (Chromium + Firefox + WebKit)
RUN npx playwright install --with-deps chromium firefox webkit

ENV PUPPETEER_EXECUTABLE_PATH=/usr/bin/google-chrome-stable
ENV CHROME_BIN=/usr/bin/google-chrome-stable
ENV CHROME_PATH=/usr/bin/google-chrome-stable

# Install OpenClaw globally via npm
# Pass --build-arg CACHE_BUST=$(date +%s) to force a fresh install
ARG OPENCLAW_VERSION=2026.4.26
ARG CACHE_BUST=0
RUN echo "cache-bust: ${CACHE_BUST}" && npm install -g openclaw@${OPENCLAW_VERSION}

# Install DAVE protocol support for Discord voice
RUN cd /usr/lib/node_modules/openclaw && npm install @snazzah/davey

# Alias clawdbot -> openclaw for backwards compatibility
RUN ln -s "$(which openclaw)" /usr/local/bin/clawdbot

# Additional apt packages (optional)
ARG OPENCLAW_DOCKER_APT_PACKAGES=""
RUN if [ -n "$OPENCLAW_DOCKER_APT_PACKAGES" ]; then \
    apt-get update && \
    apt-get install -y $OPENCLAW_DOCKER_APT_PACKAGES && \
    rm -rf /var/lib/apt/lists/*; \
    fi

# OpenClaw directories
ENV OPENCLAW_STATE_DIR=/home/coder/.openclaw
ENV OPENCLAW_WORKSPACE=/home/coder/clawd
RUN mkdir -p "${OPENCLAW_STATE_DIR}" "${OPENCLAW_WORKSPACE}" \
    && chown -R coder:coder "${OPENCLAW_STATE_DIR}" "${OPENCLAW_WORKSPACE}"

# VS Code extensions
RUN code-server --install-extension ms-python.python || true \
    && code-server --install-extension dbaeumer.vscode-eslint || true \
    && code-server --install-extension esbenp.prettier-vscode || true \
    && code-server --install-extension eamodio.gitlens || true

# Entrypoint
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Verify
RUN gh --version && node -v && npm -v && openclaw --help && google-chrome-stable --version \
    && make --version && python3 --version && npx playwright --version

# Ports: 18789=OpenClaw Dashboard, 18790=WebChat, 8443=code-server
EXPOSE 18789 18790 8443

ENV NODE_ENV=production
ENV CODE_SERVER_ENABLED=true
ENV GATEWAY_PORT=18789

USER coder

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD openclaw health || exit 1

ENTRYPOINT ["/entrypoint.sh"]
