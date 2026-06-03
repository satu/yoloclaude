# yoloclaude — fleet deploy stack

The portable, self-contained form of yoloclaude (the trellm host), for migrating
between hosts with [`fleet`](../../homelab/fleet/) — the same way humphrey moves.
The interactive `./yolo` dev sandbox at the repo root is unchanged; this `deploy/`
directory is what `fleet` builds, ships, and runs.

## Why this exists

The host-coupled `./yolo` flow bind-mounts the host's `~/src` (275 GB), the docker
socket, and 8 host credential dirs — none of which exist on another host. This
stack removes every host bind so **all state lives in named volumes** and the
stack (incl. its Tailscale identity) is portable:

| Volume | Holds |
|---|---|
| `yoloclaude-tailscale` | the tailnet node identity `yoloclaude` (synced first) |
| `yoloclaude-home` | `/home/dariofreni` — `.claude`, `.config/{gh,gcloud,firebase}`, `.trellm`, `.ssh`, `.password-store`, `.gnupg`, `.chrome-trellm`, … (all creds + state) |
| `yoloclaude-src` | only the projects trellm manages, seeded from the host's `~/src` (not aosp/openwrt) |

## One-time refactor on magnus (Phase A — verify before migrating)

```bash
# 1. Seed the src volume with the 12 trellm projects (verbatim copy).
./seed-src-volume.sh

# 2. Stop the host-coupled container (releases the cred binds).
cd ..  &&  ./yolo stop  &&  cd deploy

# 3. Fold the host deploy creds into the home volume's stub paths
#    (gh, the single dario.freni gcloud account, firebase, gitconfig).
#    See "Credential fold" below.

# 4. Bring up the self-contained stack on magnus and verify.
docker compose up -d
docker exec -it yoloclaude bash -lc 'gh auth status && gcloud auth list && firebase projects:list && claude --version'
docker exec yoloclaude bash -lc 'tail -f /var/log/trellm.log'   # confirm trellm polls
```

If anything is wrong, `docker compose down` and `cd .. && ./yolo start` restores
the original host-coupled container (its volumes were never touched).

### Credential fold

The home volume's `.config/{gh,gcloud,firebase}` are empty stub mountpoints today
(masked by the binds), so creds must be copied in once while the container is
down. Copy `~/.config/gh`, `~/.gitconfig`, `~/.config/git`, `~/.config/firebase`,
`~/.config/configstore/firebase-tools.json`, and **only the `dario.freni`**
gcloud account into the volume, then verify (step 4). All Google creds are
durable refresh tokens, so a one-time copy persists. `~/.ssh`, `~/.password-store`,
`~/.gnupg` already ride the home volume. Drop `~/Android` and `~/.gemini`.

## Migrate to hertz (Phase B)

Prereqs on hertz (one-time): **add 12–16 GB swap** (it has 0 — gating, or a
peak OOM-kills humphrey) and grant the `yoloclaude` tailnet node access to the
`homeassistant` exit node in the tailnet ACL (tag it `tag:yoloclaude` or grant
the node directly — it is currently untagged).

```bash
cd ../../homelab/fleet
./fleet preseed yoloclaude --to hertz   # ship image + volumes while it runs
./fleet migrate yoloclaude --to hertz   # down on magnus → delta-sync → up on hertz
./fleet status yoloclaude
# Verify egress is the HOME IP (exit node took), trellm health, ssh→humphrey:
docker --context ... exec yoloclaude curl -s https://ifconfig.me
```

magnus retains its volumes for `./fleet rollback yoloclaude`. trellm's
`restart: unless-stopped` auto-starts it on hertz reboots, so magnus can be
powered off. To resume hands-on dev, boot magnus and `git pull` each project.

## Notes

- The migration **reuses the running image** (`yoloclaude-yoloclaude:latest`);
  `Dockerfile` + `entrypoint.sh` here are the canonical definition for rebuilds
  and bake the tailscaled-wait + runtime docker-GID fix.
- `compose.yaml` keeps the `privileged` stack verbatim (kernel-mode Tailscale +
  Chrome). hertz's modern kernel needs no per-host override (unlike the NAS).
