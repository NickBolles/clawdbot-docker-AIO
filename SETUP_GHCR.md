# GitHub Container Registry Setup Guide

This guide explains how to set up GitHub Container Registry (GHCR) for this repository.

## Prerequisites

- GitHub repository with this code
- GitHub account with permissions to manage the repository

## Setup Steps

### 1. Enable GitHub Actions

GitHub Actions should be enabled by default. If not:

1. Go to your repository on GitHub
2. Click **Settings** → **Actions** → **General**
3. Under "Actions permissions", select "Allow all actions and reusable workflows"
4. Click **Save**

### 2. Configure Package Visibility

The workflow will automatically create a package in GHCR on the first successful build. After the first build:

1. Go to your GitHub profile
2. Click **Packages**
3. Find the `clawdbot-docker` package
4. Click on it, then click **Package settings**
5. Under "Danger Zone", change the visibility to **Public** (recommended for easy pulling)
6. Optionally, link the package to this repository

### 3. Update README

Replace `YOUR_USERNAME` in the README.md with your actual GitHub username:

```bash
# Find and replace in README.md
YOUR_USERNAME → your-github-username
```

For example, if your username is `johndoe`:
```
ghcr.io/YOUR_USERNAME/clawdbot-docker:latest
```

becomes:
```
ghcr.io/johndoe/clawdbot-docker:latest
```

### 4. Trigger a Build

The workflow will automatically trigger on:

- **Push to main**: Automatically builds and tags as `latest`
- **Creating a tag**: Create a version tag to build a versioned release
- **Manual trigger**: Go to Actions → Build and Push Docker Image → Run workflow

#### To create a version tag:

```bash
git tag v1.0.0
git push origin v1.0.0
```

This will build and push an image tagged as:
- `ghcr.io/YOUR_USERNAME/clawdbot-docker:latest`
- `ghcr.io/YOUR_USERNAME/clawdbot-docker:1.0.0`
- `ghcr.io/YOUR_USERNAME/clawdbot-docker:1.0`
- `ghcr.io/YOUR_USERNAME/clawdbot-docker:1`
- `ghcr.io/YOUR_USERNAME/clawdbot-docker:v1.0.0`

### 5. Verify Build

1. Go to **Actions** tab in your repository
2. Click on the latest workflow run
3. Verify the build completed successfully
4. Check that the image was pushed to GHCR

### 6. Pull the Image

Once built, anyone can pull the public image:

```bash
docker pull ghcr.io/YOUR_USERNAME/clawdbot-docker:latest
```

## Workflow Features

The GitHub Actions workflow includes:

- **Multi-platform support**: Builds for linux/amd64 (can be extended for arm64)
- **Automatic tagging**: Creates tags based on branch, version, and commit SHA
- **Layer caching**: Uses GitHub Actions cache to speed up builds
- **Metadata extraction**: Automatically extracts and applies Docker labels
- **PR testing**: Builds (but doesn't push) on pull requests
- **Build summary**: Shows image digest, tags, and pull command after successful builds

## Customizing the Build

### Adding Build Arguments

Edit `.github/workflows/docker-build.yml` and modify the `build-args` section:

```yaml
build-args: |
  CLAWDBOT_DOCKER_APT_PACKAGES=ffmpeg build-essential git curl python3
```

### Building for Multiple Platforms

To build for ARM64 (e.g., Raspberry Pi), modify the workflow:

```yaml
- name: Build and push Docker image
  uses: docker/build-push-action@v5
  with:
    platforms: linux/amd64,linux/arm64
    # ... rest of config
```

**Note**: Multi-platform builds are slower but allow the same image to run on different architectures.

## Troubleshooting

### Build Fails

- Check the Actions log for specific errors
- Ensure the Clawdbot repository is accessible
- Verify the Dockerfile syntax is correct

### Permission Denied

- The workflow uses `GITHUB_TOKEN` which is automatically provided
- No additional secrets needed
- Ensure Actions have write permissions: Settings → Actions → General → Workflow permissions → "Read and write permissions"

### Image Not Public

- By default, packages are private
- After first build, go to Packages and change visibility to Public
- Link the package to your repository for better organization

## Security Notes

- The `GITHUB_TOKEN` is automatically scoped to this repository only
- No need to create personal access tokens
- Images are scanned by GitHub for vulnerabilities (if enabled)
- Keep your API keys out of the image (use environment variables at runtime)

## Next Steps

After setup:
1. Update README.md with your username
2. Push a commit to trigger the first build
3. Make the package public
4. Share the image URL with users
