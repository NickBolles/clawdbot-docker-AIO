# Clawdbot + code-server AIO image
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

ENV PUPPETEER_EXECUTABLE_PATH=/usr/bin/google-chrome-stable
ENV CHROME_BIN=/usr/bin/google-chrome-stable
ENV CHROME_PATH=/usr/bin/google-chrome-stable

# Install Clawdbot globally via npm
ARG CLAWDBOT_VERSION=latest
RUN npm install -g clawdbot@${CLAWDBOT_VERSION}

# Additional apt packages (optional)
ARG CLAWDBOT_DOCKER_APT_PACKAGES=""
RUN if [ -n "$CLAWDBOT_DOCKER_APT_PACKAGES" ]; then \
    apt-get update && \
    apt-get install -y $CLAWDBOT_DOCKER_APT_PACKAGES && \
    rm -rf /var/lib/apt/lists/*; \
    fi

# Clawdbot directories
ENV CLAWDBOT_STATE_DIR=/home/coder/.clawdbot
ENV CLAWDBOT_WORKSPACE=/home/coder/clawd
RUN mkdir -p "${CLAWDBOT_STATE_DIR}" "${CLAWDBOT_WORKSPACE}" \
    && chown -R coder:coder "${CLAWDBOT_STATE_DIR}" "${CLAWDBOT_WORKSPACE}"

# VS Code extensions
RUN code-server --install-extension ms-python.python || true \
    && code-server --install-extension dbaeumer.vscode-eslint || true \
    && code-server --install-extension esbenp.prettier-vscode || true \
    && code-server --install-extension eamodio.gitlens || true

# Entrypoint
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Verify
RUN gh --version && node -v && npm -v && clawdbot --help && google-chrome-stable --version

# Ports: 18789=Dashboard, 18790=WebChat, 8443=code-server
EXPOSE 18789 18790 8443

ENV NODE_ENV=production
ENV CODE_SERVER_ENABLED=true
ENV GATEWAY_PORT=18789

USER coder

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD clawdbot health || exit 1

ENTRYPOINT ["/entrypoint.sh"]
