# YoloClaude

A secure Docker sandbox for running AI coding agents (like Claude Code) in unrestricted "yolo" mode.

## Why?

AI coding agents work best when they can execute commands freely without constant permission prompts. However, running agents with full system access is risky. YoloClaude solves this by providing an isolated Docker environment where agents can run unrestricted while your host system stays protected.

## Features

- **Isolated environment**: Agents run in a container, not on your host
- **Persistent workspace**: Named volume preserves installed packages and shell history
- **Your code, accessible**: `~/src` is mounted into the container
- **Claude CLI ready**: Your Claude installation is mounted (read-only)
- **LAN/Tailscale access**: Ports bound to `0.0.0.0` for remote access
- **Configurable**: Easy YAML config for ports, mounts, and resources

## Prerequisites

- Docker 20.10+
- Docker Compose v2 (`sudo apt install docker-compose-v2` on Ubuntu 24.04)

## Quick Start

```bash
# Clone the repo
git clone https://github.com/satu/yoloclaude.git
cd yoloclaude

# Edit config if needed
nano config.yaml

# Build and start
./yolo build
./yolo start

# Enter the sandbox
./yolo shell

# Or run Claude directly in yolo mode
./yolo claude myproject
```

## Commands

| Command | Description |
|---------|-------------|
| `./yolo build` | Build the Docker image |
| `./yolo start` | Start the container (detached) |
| `./yolo stop` | Stop the container |
| `./yolo shell` | Enter interactive shell |
| `./yolo claude <project>` | Run Claude in yolo mode in `~/src/<project>` (resumes last conversation) |
| `./yolo status` | Show container status |
| `./yolo logs` | Show container logs (`-f` to follow) |
| `./yolo restart` | Stop and start |
| `./yolo rebuild` | Full rebuild (no cache) and restart |

## Configuration

Edit `config.yaml` to customize:

```yaml
# Container name
container_name: yoloclaude

# Ports to expose (host:container)
ports:
  - 3000:3000   # Node.js / React
  - 4000:4000   # Firebase Emulator UI
  - 5001:5001   # Firebase Functions
  - 5173:5173   # Vite
  - 8000:8000   # Django / Python
  - 8080:8080   # General web server
  - 9000:9000   # Firebase Realtime Database
  - 9099:9099   # Firebase Auth
  - 9199:9199   # Firebase Storage
  - 9399:9399   # Firebase Data Connect

# Directories to mount
src_dir: ~/src
claude_config_dir: ~/.claude
claude_install_dir: ~/.local/share/claude
claude_bin: ~/.local/bin/claude

# Additional mounts (optional)
extra_mounts: []
  # - /path/on/host:/path/in/container:ro

# Resource limits
resources:
  memory: 8g
  cpus: 4
```

Changes take effect on next `./yolo start` or `./yolo restart`.

## Inside the Container

- **User**: Matches your host username with passwordless sudo
- **Projects**: `~/src` (your host's src directory)
- **Claude config**: `~/.claude`
- **Prompt**: Shows `[yolo]` prefix so you know you're in the sandbox

Installed packages persist between container restarts thanks to the named volume.

## Included Tools

- **Node.js 20.x** and npm
- **Python 3** and pip
- **Google Cloud SDK** (`gcloud`)
- **Firebase CLI** (`firebase`)
- **GitHub CLI** (`gh`)
- **Gemini CLI** (`gemini`)
- Git, curl, wget, and common build tools

Host credentials for `gh`, `gcloud`, and `firebase` are mounted automatically.

## Security

- Container runs as non-root user
- No `--privileged` flag
- Claude CLI binaries mounted read-only
- Explicit port mapping (no host networking)
- Resource limits configurable

## Troubleshooting

**Port already in use**: Edit `config.yaml` to change the conflicting port, then restart.

**Permission denied on mounted files**: The container user has UID/GID 1000. If your host user differs, rebuild with adjusted values in `docker-compose.yaml`.

**Claude CLI not found**: Ensure `claude_bin` and `claude_install_dir` in `config.yaml` point to your actual Claude installation.

## License

MIT
