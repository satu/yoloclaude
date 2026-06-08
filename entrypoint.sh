#!/bin/bash
# Start tailscaled in the background
sudo tailscaled --state=/var/lib/tailscale/tailscaled.state &

# Wait briefly for tailscaled to be ready, then bring up the connection
sleep 2
sudo tailscale up --accept-dns=false &

# Start services in the background
sudo touch /var/log/trellm.log /var/run/trellm.pid
sudo chown "$(id -u):$(id -g)" /var/log/trellm.log /var/run/trellm.pid
~/src/trellm/start-trellm.sh &
# humphrey runs in its own container now (see ../humphrey/deploy/).

# Execute the original CMD
exec "$@"
