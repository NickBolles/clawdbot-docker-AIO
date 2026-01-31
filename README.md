# OpenClaw Gateway - Docker (Unraid)

An all-in-one Docker image for running an OpenClaw gateway. This is designed for Unraid hosts that don't support docker-compose, based on the [official OpenClaw Docker setup](https://docs.openclaw.ai/install/docker).

[![Build and Push Docker Image](https://github.com/YOUR_USERNAME/openclaw-docker/actions/workflows/docker-build.yml/badge.svg)](https://github.com/YOUR_USERNAME/openclaw-docker/actions/workflows/docker-build.yml)

## Overview

OpenClaw is a personal AI assistant platform that connects Claude (and other LLMs) to messaging platforms like WhatsApp, Telegram, Discord, and more. This Docker image provides a containerized gateway that you can run on Unraid or any Docker host.

## Prerequisites

- Docker installed
- Anthropic API key (get one at https://console.anthropic.com/)

## Quick Start

### Option 1: Use Pre-built Image from GHCR (Recommended)

Pull the latest pre-built image from GitHub Container Registry:

```bash
docker pull ghcr.io/YOUR_USERNAME/openclaw-docker:latest
```

Then skip to step 4 below and use `ghcr.io/YOUR_USERNAME/openclaw-docker:latest` as the image name.

### Option 2: Build Locally

### 1. Clone OpenClaw Repository

First, clone the official OpenClaw repository:

```bash
git clone https://github.com/openclaw/openclaw.git
cd openclaw
```

### 2. Copy This Dockerfile

Copy this `Dockerfile` into the openclaw repository root.

### 3. Build the Image

Build with optional apt packages for plugins:

```bash
docker build \
  --build-arg OPENCLAW_DOCKER_APT_PACKAGES="ffmpeg build-essential" \
  -t openclaw:latest \
  .
```

Or build without extra packages:

```bash
docker build -t openclaw:latest .
```

### 4. Create Configuration Directory

```bash
mkdir -p ~/.openclaw
```

### 5. Run Initial Setup (Onboarding)

Run the onboarding wizard to create your initial configuration:

```bash
docker run -it --rm \
  -v ~/.openclaw:/root/.openclaw \
  -v ~/.openclaw/workspace:/root/.openclaw/workspace \
  openclaw:latest \
  node dist/index.js onboard
```

This will guide you through:
- Creating your first agent
- Setting up your Anthropic API key
- Configuring providers and models

### 6. Run the Gateway

```bash
docker run -d \
  --name openclaw-gateway \
  -p 18789:18789 \
  -p 18790:18790 \
  -v ~/.openclaw:/root/.openclaw \
  -v ~/.openclaw/workspace:/root/.openclaw/workspace \
  --restart unless-stopped \
  openclaw:latest
```

The gateway will now be running with:
- **Control UI / Dashboard**: http://localhost:18789
- **WebChat** (optional): http://localhost:18790

## Startup Behavior

By default, this image triggers a heartbeat wake immediately after the gateway starts. This is useful for:
- Catching issues after container restarts
- Agent checking in automatically after deployment
- Monitoring and alerting on startup

The startup wake process:
1. Starts the gateway
2. Waits for it to be healthy
3. Triggers an immediate heartbeat pulse
4. Keeps the gateway running normally

### Customize Startup Wake

You can control the startup behavior with environment variables:

```bash
docker run -d \
  --name openclaw-gateway \
  -p 18789:18789 \
  -p 18790:18790 \
  -v ~/.openclaw:/root/.openclaw \
  -v ~/.openclaw/workspace:/root/.openclaw/workspace \
  -e WAKE_DELAY=10 \
  -e WAKE_TEXT="Custom startup message" \
  --restart unless-stopped \
  openclaw:latest
```

**Available environment variables:**
- `WAKE_DELAY` - Seconds to wait before triggering wake (default: `5`)
- `WAKE_TEXT` - Custom message for the wake (default: `"Gateway started, checking in."`)
- `GATEWAY_PORT` - Gateway port to health-check (default: `18789`)

### Skip Startup Wake

If you want to use the standard gateway startup without the wake, override the command:

```bash
docker run -d \
  --name openclaw-gateway \
  -p 18789:18789 \
  -p 18790:18790 \
  -v ~/.openclaw:/root/.openclaw \
  -v ~/.openclaw/workspace:/root/.openclaw/workspace \
  --restart unless-stopped \
  --entrypoint node \
  openclaw:latest \
  dist/index.js gateway
```

## Unraid Setup

### Container Configuration

Add a new container in Unraid with these settings:

**Basic Settings:**
- **Name**: `openclaw-gateway`
- **Repository**: `ghcr.io/YOUR_USERNAME/openclaw-docker:latest` (or `openclaw:latest` if built locally)
- **Network Type**: `Bridge`

**Port Mappings:**
- Container Port `18789` → Host Port `18789` (TCP) - Control UI
- Container Port `18790` → Host Port `18790` (TCP) - WebChat

**Volume Mappings:**
- Container Path: `/root/.openclaw` → Host Path: `/mnt/user/appdata/openclaw/config`
- Container Path: `/root/.openclaw/workspace` → Host Path: `/mnt/user/appdata/openclaw/workspace`

**Advanced:**
- Extra Parameters: `--restart unless-stopped`

### First Run on Unraid

Before starting the container, run the onboarding wizard:

```bash
docker run -it --rm \
  -v /mnt/user/appdata/openclaw/config:/root/.openclaw \
  -v /mnt/user/appdata/openclaw/workspace:/root/.openclaw/workspace \
  ghcr.io/YOUR_USERNAME/openclaw-docker:latest \
  node dist/index.js onboard
```

Then start the container normally through the Unraid UI.

## Configuration

### Directory Structure

- `~/.openclaw/` - Configuration files, agent configs, sessions
- `~/.openclaw/workspace/` - Agent workspace for file operations

### Adding Channels

To add messaging channels (WhatsApp, Telegram, Discord), use the CLI:

**WhatsApp (QR Code):**
```bash
docker exec -it openclaw-gateway node dist/index.js channels login
```

**Telegram (Bot Token):**
```bash
docker exec -it openclaw-gateway node dist/index.js channels add --channel telegram --token "YOUR_BOT_TOKEN"
```

**Discord (Bot Token):**
```bash
docker exec -it openclaw-gateway node dist/index.js channels add --channel discord --token "YOUR_BOT_TOKEN"
```

See [OpenClaw Channels Documentation](https://docs.openclaw.ai/channels) for more details.

### Environment Variables

You can pass additional configuration via environment variables:

```bash
docker run -d \
  --name openclaw-gateway \
  -p 18789:18789 \
  -p 18790:18790 \
  -e NODE_ENV=production \
  -e ANTHROPIC_API_KEY=your-api-key \
  -v ~/.openclaw:/root/.openclaw \
  -v ~/.openclaw/workspace:/root/.openclaw/workspace \
  --restart unless-stopped \
  openclaw:latest
```

## Installing Additional Packages

The Dockerfile supports installing apt packages during build for plugin compatibility:

```bash
docker build \
  --build-arg OPENCLAW_DOCKER_APT_PACKAGES="ffmpeg imagemagick git curl jq" \
  -t openclaw:latest \
  .
```

Common packages you might need:
- `ffmpeg` - Audio/video processing
- `imagemagick` - Image manipulation
- `git` - Git operations
- `build-essential` - Compiling native modules
- `python3` - Python scripts

## Health Check

Check if the gateway is healthy:

```bash
docker exec openclaw-gateway node dist/index.js health
```

## Updating

### Using Pre-built Images (GHCR)

If you're using the pre-built image from GHCR, simply pull the latest version:

```bash
docker pull ghcr.io/YOUR_USERNAME/openclaw-docker:latest
docker stop openclaw-gateway
docker rm openclaw-gateway
```

Then start a new container with the same volume mounts. Images are automatically built and pushed on every commit to the main branch.

### Building Locally

To update when building locally:

1. Pull the latest changes:
```bash
cd openclaw
git pull origin main
```

2. Rebuild the image:
```bash
docker build -t openclaw:latest .
```

3. Stop and remove the old container:
```bash
docker stop openclaw-gateway
docker rm openclaw-gateway
```

4. Start a new container with the same volume mounts

## Automated Builds

This repository uses GitHub Actions to automatically build and push Docker images to GitHub Container Registry (GHCR) on:
- Every push to the `main` branch (tagged as `latest`)
- Every version tag (e.g., `v1.0.0`)
- Pull requests (for testing)

Images are available at: `ghcr.io/YOUR_USERNAME/openclaw-docker`

Available tags:
- `latest` - Latest build from main branch
- `main` - Same as latest
- `v1.0.0` - Specific version tags
- `sha-abc1234` - Specific commit SHA

To use a specific version:
```bash
docker pull ghcr.io/YOUR_USERNAME/openclaw-docker:v1.0.0
```

## Troubleshooting

### View Logs
```bash
docker logs -f openclaw-gateway
```

### Access Container Shell
```bash
docker exec -it openclaw-gateway /bin/bash
```

### Configuration Issues
Check your configuration files in `~/.openclaw/openclaw.json`

### Port Conflicts
If ports 18789 or 18790 are already in use, change the host port:
```bash
-p 8080:18789  # Use port 8080 instead
```

## Documentation

- [Official OpenClaw Docs](https://docs.openclaw.ai/)
- [Docker Installation Guide](https://docs.openclaw.ai/install/docker)
- [Gateway Configuration](https://docs.openclaw.ai/gateway/configuration)
- [Channels Setup](https://docs.openclaw.ai/channels)

## License

OpenClaw is open source. Check the [official repository](https://github.com/openclaw/openclaw) for license details.
