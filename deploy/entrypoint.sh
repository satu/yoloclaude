#!/bin/bash
# yoloclaude entrypoint (fleet deploy variant).
#
# Brings up kernel-mode Tailscale (identity persisted in the yoloclaude-tailscale
# volume, carried across hosts by `fleet`), launches the trellm daemon, then
# holds the container open on CMD (sleep infinity) for interactive use.
#
# Behaviourally equivalent to the top-level entrypoint.sh, plus: a tailscaled
# socket wait and runtime docker-GID reconciliation for the (disabled-by-default)
# docker.sock bind.
set -uo pipefail

USER_NAME="$(id -un)"

# --- Docker socket GID reconciliation (only if the socket is bind-mounted) ----
# The docker.sock bind is disabled in compose.yaml by default. If re-enabled,
# the host's docker GID differs per host (magnus=998, hertz=988) while the image
# baked one GID at build time — reconcile at runtime so the user can reach it.
if [ -S /var/run/docker.sock ]; then
    SOCK_GID="$(stat -c '%g' /var/run/docker.sock)"
    GRP="$(getent group "$SOCK_GID" | cut -d: -f1)"
    if [ -z "$GRP" ]; then
        GRP=docker_host
        sudo groupadd -g "$SOCK_GID" "$GRP" 2>/dev/null || true
    fi
    id -nG | grep -qw "$GRP" || sudo usermod -aG "$GRP" "$USER_NAME"
fi

# --- Tailscale (kernel mode; identity lives in the /var/lib/tailscale volume) --
sudo mkdir -p /var/run/tailscale /var/lib/tailscale
sudo -b sh -c 'tailscaled --state=/var/lib/tailscale/tailscaled.state >/var/log/tailscaled.log 2>&1'
for _ in $(seq 1 30); do
    [ -S /var/run/tailscale/tailscaled.sock ] && break
    sleep 0.5
done
# Persisted state (carried in the volume) is already authed — just ensure up.
# --accept-dns=false matches the original sandbox. The per-host exit node is
# applied by `fleet` after bring-up (not here).
sudo tailscale up --hostname=yoloclaude --accept-dns=false || true

# --- trellm daemon ------------------------------------------------------------
sudo touch /var/log/trellm.log /var/run/trellm.pid
sudo chown "$(id -u):$(id -g)" /var/log/trellm.log /var/run/trellm.pid
if [ -x "$HOME/src/trellm/start-trellm.sh" ]; then
    "$HOME/src/trellm/start-trellm.sh" &
else
    echo "WARN: $HOME/src/trellm/start-trellm.sh not found — trellm not started." >&2
fi

# Hold the container open (or run whatever CMD was passed).
exec "$@"
