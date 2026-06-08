#!/bin/bash -l
# Start yoloclaude container at boot
# Added to user crontab with: @reboot /home/dariofreni/src/yoloclaude/start-on-boot.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Wait for Docker to be ready
for i in $(seq 1 60); do
    if docker info &>/dev/null; then
        break
    fi
    sleep 2
done

if ! docker info &>/dev/null; then
    echo "Docker not available after 120s, giving up" >&2
    exit 1
fi

# Start yoloclaude container
cd "$SCRIPT_DIR"
./yolo start
