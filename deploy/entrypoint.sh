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

# --- Docker: host socket (DooD) if bind-mounted, else our own dockerd (DinD) --
# If compose.yaml bind-mounts /var/run/docker.sock we use the host daemon and
# just reconcile the GID (it differs per host: magnus=998, hertz=988, baked at
# build time). Otherwise we run our OWN dockerd inside the container — it's
# privileged + cgroup:host, so Docker-in-Docker works. DinD storage lives in the
# yoloclaude-dind volume (/var/lib/docker), so built images survive recreate.
#
# Detection MUST use the mount table, not `[ -S /var/run/docker.sock ]`: /run is
# not a tmpfs in this image, so a container stop/start (e.g. host reboot) leaves
# the PREVIOUS run's dockerd socket behind. A bare `-S` test then mistakes that
# dead socket for a bind-mounted host one, skips launching dockerd, and DinD is
# silently down until the next recreate. `findmnt` only matches a real bind mount.
if findmnt -n /var/run/docker.sock >/dev/null 2>&1; then
    SOCK_GID="$(stat -c '%g' /var/run/docker.sock)"
    GRP="$(getent group "$SOCK_GID" | cut -d: -f1)"
    if [ -z "$GRP" ]; then
        GRP=docker_host
        sudo groupadd -g "$SOCK_GID" "$GRP" 2>/dev/null || true
    fi
    id -nG | grep -qw "$GRP" || sudo usermod -aG "$GRP" "$USER_NAME"
elif command -v dockerd >/dev/null 2>&1; then
    # Clear stale runtime state from a prior run before starting: a leftover
    # socket plus a stale containerd.pid (whose PID a restart reassigns to some
    # unrelated process) make a fresh dockerd hang on "containerd is still
    # running" until it times out. /var/lib/docker (the dind volume) is left
    # untouched so images persist; only the ephemeral /run state is wiped.
    sudo rm -rf /var/run/docker.sock /var/run/docker /var/run/docker.pid
    # root does the redirect (/var/log is root-only) and backgrounds dockerd.
    # --group <our primary group> makes the socket owned by us, so `docker` works
    # without docker-group membership (the image's docker group is an unrelated
    # gid, a leftover of the DOCKER_GID build-arg colliding with systemd-network).
    sudo -b sh -c "dockerd --group $(id -gn) >/var/log/dockerd.log 2>&1"
    # wait for the daemon to actually answer, not just for the socket to appear
    for _ in $(seq 1 40); do docker info >/dev/null 2>&1 && break; sleep 0.5; done
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

# --- sshd: ssh into the sandbox with your key --------------------------------
# `ssh dariofreni@yoloclaude` over the tailnet, anywhere the stack runs. The
# host key is persisted in the home volume (~/.ssh-host) and installed as the
# system host key on boot, so the fingerprint is STABLE across rebuilds and
# host migrations (no known_hosts churn). authorized_keys lives in the home
# volume too, so it travels with the stack.
sudo mkdir -p /run/sshd
HOSTKEY_DIR="$HOME/.ssh-host"
mkdir -p "$HOSTKEY_DIR"
if [ ! -f "$HOSTKEY_DIR/ssh_host_ed25519_key" ]; then
    ssh-keygen -q -t ed25519 -f "$HOSTKEY_DIR/ssh_host_ed25519_key" -N ""
fi
sudo install -m 600 "$HOSTKEY_DIR/ssh_host_ed25519_key"     /etc/ssh/ssh_host_ed25519_key
sudo install -m 644 "$HOSTKEY_DIR/ssh_host_ed25519_key.pub" /etc/ssh/ssh_host_ed25519_key.pub
mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"
[ -f "$HOME/.ssh/authorized_keys" ] && chmod 600 "$HOME/.ssh/authorized_keys"
sudo /usr/sbin/sshd

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
