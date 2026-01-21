FROM node:22-bookworm

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install Bun (required for Clawdbot build scripts)
RUN curl -fsSL https://bun.sh/install | bash
ENV PATH="/root/.bun/bin:${PATH}"

# Enable corepack for pnpm
RUN corepack enable

# Install Google Chrome for browser automation (recommended by Clawdbot docs)
# Chrome works better than snap Chromium which has AppArmor restrictions
RUN apt-get update && \
    apt-get install -y \
    wget \
    gnupg \
    # Chrome/Chromium dependencies
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
    # Fonts for better rendering
    fonts-liberation \
    fonts-noto-color-emoji \
    # Additional useful tools
    ca-certificates \
    && wget -q -O /tmp/google-chrome-stable_current_amd64.deb https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb \
    && apt-get install -y /tmp/google-chrome-stable_current_amd64.deb \
    && rm /tmp/google-chrome-stable_current_amd64.deb \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Set Chrome executable paths for various tools
ENV PUPPETEER_EXECUTABLE_PATH=/usr/bin/google-chrome-stable
ENV CHROME_BIN=/usr/bin/google-chrome-stable
ENV CHROME_PATH=/usr/bin/google-chrome-stable

# Install GitHub CLI
RUN apt-get update && \
    apt-get install -y gh && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Install additional apt packages if specified
ARG CLAWDBOT_DOCKER_APT_PACKAGES=""
RUN if [ -n "$CLAWDBOT_DOCKER_APT_PACKAGES" ]; then \
    apt-get update && \
    apt-get install -y $CLAWDBOT_DOCKER_APT_PACKAGES && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*; \
    fi

WORKDIR /app

# Cache dependencies unless package metadata changes
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml .npmrc ./
COPY ui/package.json ./ui/package.json
COPY patches ./patches
COPY scripts ./scripts

RUN pnpm install --frozen-lockfile

# Copy application code
COPY . .

# Build the application
RUN pnpm build
RUN pnpm ui:install
RUN pnpm ui:build

ENV NODE_ENV=production

# Copy startup entrypoint script
COPY entrypoint-with-wake.sh /entrypoint-with-wake.sh
RUN chmod +x /entrypoint-with-wake.sh

# Expose ports
# 18789 - Control UI / Dashboard
# 18790 - WebChat (optional)
EXPOSE 18789 18790

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
  CMD node dist/index.js health || exit 1

# Start the gateway with startup heartbeat wake enabled
CMD ["/bin/bash", "/entrypoint-with-wake.sh"]
