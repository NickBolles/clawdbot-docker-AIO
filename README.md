# OpenClaw Gateway + code-server - Docker (Unraid)

An all-in-one Docker image for running an OpenClaw gateway with integrated code-server (VS Code in browser). This is designed for Unraid hosts that don't support docker-compose, based on the [official OpenClaw Docker setup](https://docs.openclaw.ai/install/docker).

[![Build and Push Docker Image](https://github.com/YOUR_USERNAME/clawdbot-docker/actions/workflows/docker-build.yml/badge.svg)](https://github.com/YOUR_USERNAME/clawdbot-docker/actions/workflows/docker-build.yml)

## Overview

OpenClaw (formerly Clawdbot) is an AI agent platform that connects Claude (and other LLMs) to messaging platforms like WhatsApp, Telegram, Discord, and more. This Docker image provides:

- **OpenClaw Gateway** - AI agent runtime
- **code-server** - VS Code in your browser for editing agent workspaces
- **Chrome** - Headless browser for automation

## Prerequisites

- Docker installed
- Anthropic API key (get one at https://console.anthropic.com/)

## Quick Start

### Option 1: Use Pre-built Image from GHCR (Recommended)

```bash
docker pull ghcr.io/YOUR_USERNAME/clawdbot-docker:latest
```

### Option 2: Build Locally

```bash
git clone https://github.com/openclaw/openclaw.git
cd openclaw
# Copy Dockerfile and entrypoint.sh to this directory
docker build -t openclaw:latest .
```

### Run with code-server

```bash
docker run -d \
  --name openclaw-gateway \
  -p 18789:18789 \
  -p 18790:18790 \
  -p 8443:8443 \
  -e CODE_SERVER_PASSWORD=your-password \
  -v ~/.openclaw:/home/coder/.openclaw \
  -v ~/clawd:/home/coder/clawd \
  --restart unless-stopped \
  openclaw:latest
```

Access:
- **OpenClaw Dashboard**: http://localhost:18789
- **code-server (VS Code)**: http://localhost:8443
- **WebChat**: http://localhost:18790

## code-server Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `CODE_SERVER_ENABLED` | `true` | Enable/disable code-server |
| `CODE_SERVER_PORT` | `8443` | Port for code-server |
| `CODE_SERVER_PASSWORD` | *(random)* | Password for code-server (shown in logs if not set) |
| `CODE_SERVER_AUTH` | `password` | Auth type: `password` or `none` |
| `CODE_SERVER_WORKSPACE` | `/home/coder/clawd` | Default workspace directory |

### Disable code-server

```bash
docker run -d \
  --name openclaw-gateway \
  -p 18789:18789 \
  -p 18790:18790 \
  -e CODE_SERVER_ENABLED=false \
  -v ~/.openclaw:/home/coder/.openclaw \
  -v ~/clawd:/home/coder/clawd \
  --restart unless-stopped \
  openclaw:latest
```

### No Password (not recommended)

```bash
docker run -d \
  --name openclaw-gateway \
  -p 18789:18789 \
  -p 8443:8443 \
  -e CODE_SERVER_AUTH=none \
  -v ~/.openclaw:/home/coder/.openclaw \
  -v ~/clawd:/home/coder/clawd \
  --restart unless-stopped \
  openclaw:latest
```

## Unraid Setup

### Container Configuration

Add a new container in Unraid with these settings:

**Basic Settings:**
- **Name**: `openclaw-gateway`
- **Repository**: `ghcr.io/YOUR_USERNAME/clawdbot-docker:latest`
- **Network Type**: `Bridge`

**Port Mappings:**
| Container Port | Host Port | Description |
|----------------|-----------|-------------|
| `18789` | `18789` | OpenClaw Dashboard |
| `18790` | `18790` | WebChat |
| `8443` | `8443` | code-server (VS Code) |

**Volume Mappings:**
| Container Path | Host Path | Description |
|----------------|-----------|-------------|
| `/home/coder/.openclaw` | `/mnt/user/appdata/openclaw/config` | OpenClaw config |
| `/home/coder/clawd` | `/mnt/user/appdata/openclaw/workspace` | Agent workspace |
| `/home/coder/.local/share/code-server` | `/mnt/user/appdata/openclaw/code-server` | code-server data (optional) |

**Environment Variables:**
| Variable | Value |
|----------|-------|
| `CODE_SERVER_PASSWORD` | `your-secure-password` |

**Advanced:**
- Extra Parameters: `--restart unless-stopped`

### First Run on Unraid

Before starting the container, run the onboarding wizard:

```bash
docker run -it --rm \
  -v /mnt/user/appdata/openclaw/config:/home/coder/.openclaw \
  -v /mnt/user/appdata/openclaw/workspace:/home/coder/clawd \
  ghcr.io/YOUR_USERNAME/clawdbot-docker:latest \
  openclaw onboard
```

Then start the container normally through the Unraid UI.

### Backwards Compatibility

The `clawdbot` command is aliased to `openclaw` inside the container for backwards compatibility. Both commands work interchangeably.

## Startup Behavior

By default, this image:
1. Starts Chrome in headless mode
2. Starts code-server (if enabled)
3. Starts the OpenClaw gateway
4. Triggers a heartbeat wake after startup

### Customize Startup Wake

| Variable | Default | Description |
|----------|---------|-------------|
| `WAKE_DELAY` | `5` | Seconds to wait before wake |
| `WAKE_TEXT` | `"Gateway started, checking in."` | Wake message |
| `GATEWAY_PORT` | `18789` | Gateway health check port |

### Skip Startup Wake

```bash
docker run -d \
  --name openclaw-gateway \
  -p 18789:18789 \
  -p 8443:8443 \
  -v ~/.openclaw:/home/coder/.openclaw \
  -v ~/clawd:/home/coder/clawd \
  --restart unless-stopped \
  --entrypoint openclaw \
  openclaw:latest \
  gateway
```

## Pre-installed VS Code Extensions

The image comes with these extensions pre-installed:
- Python
- ESLint
- Prettier
- GitLens

Install additional extensions through the code-server UI or:

```bash
docker exec openclaw-gateway code-server --install-extension <extension-id>
```

## Configuration

### Directory Structure

```
~/.openclaw/              # OpenClaw configuration
├── config.json5          # Main config
├── agents/               # Agent configurations
└── browser/              # Chrome user data

~/clawd/                  # Agent workspace (default)
├── agent-name/           # Per-agent directories
└── ...

~/.config/code-server/    # code-server config
└── config.yaml           # Generated at startup
```

## Installing Additional Packages

Build with extra apt packages:

```bash
docker build \
  --build-arg OPENCLAW_DOCKER_APT_PACKAGES="ffmpeg imagemagick python3-pip" \
  -t openclaw:latest \
  .
```

## Adding Messaging Channels

**WhatsApp (QR Code):**
```bash
docker exec -it openclaw-gateway openclaw channels login
```

**Telegram (Bot Token):**
```bash
docker exec -it openclaw-gateway openclaw channels add --channel telegram --token "YOUR_BOT_TOKEN"
```

**Discord (Bot Token):**
```bash
docker exec -it openclaw-gateway openclaw channels add --channel discord --token "YOUR_BOT_TOKEN"
```

## Health Check

```bash
docker exec openclaw-gateway openclaw health
```

## Troubleshooting

### View Logs
```bash
docker logs -f openclaw-gateway
```

### code-server Logs
```bash
docker exec openclaw-gateway cat /tmp/code-server.log
```

### Chrome Logs
```bash
docker exec openclaw-gateway cat /tmp/chrome.log
```

### Access Container Shell
```bash
docker exec -it openclaw-gateway /bin/bash
```

### Port Conflicts
Change host ports if needed:
```bash
-p 8080:18789    # Dashboard on 8080
-p 8888:8443     # code-server on 8888
```

### code-server Password Not Working
If you didn't set a password, check the logs for the auto-generated one:
```bash
docker logs openclaw-gateway | grep "code-server password"
```

## Documentation

- [Official OpenClaw Docs](https://docs.openclaw.ai/)
- [code-server Docs](https://coder.com/docs/code-server)
- [Docker Installation Guide](https://docs.openclaw.ai/install/docker)

## License

OpenClaw is open source. Check the [official repository](https://github.com/openclaw/openclaw) for license details.
