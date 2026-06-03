#!/bin/bash
# Seed the yoloclaude-src named volume from the host's ~/src with ONLY the
# projects trellm manages (its Trello board's working_dirs) — NOT the whole
# ~275 GB ~/src (which includes aosp/openwrt that trellm never touches).
#
# Idempotent: re-run to rsync deltas. Run once before the first migrate, then
# again right before cutover to catch changes the running trellm made
# (preseed-style). Copies dirs VERBATIM (incl. .venv/node_modules) for an
# instant-on first boot; disk is a non-issue (hertz has 271 GB free).
set -euo pipefail

VOL=yoloclaude-src
SRC=/home/dariofreni/src
HELPER=fleet-rsync:1   # alpine + rsync helper (built by fleet)

# Keep in sync with ~/.trellm/config.yaml `working_dir` entries.
PROJECTS=(
    trellm
    jesuschristtheapp
    mcptools
    logos
    stilllovefilm
    whisp
    mbspending
    humphrey
    ilovepets
    nostalgia
    smugcoin
    sus
    patchright-mcp-lite   # used by trellm's browser stack
)

if ! docker image inspect "$HELPER" >/dev/null 2>&1; then
    echo "ERROR: helper image $HELPER missing — run a fleet command once to build it." >&2
    exit 1
fi

docker volume create "$VOL" >/dev/null
echo "Seeding $VOL from $SRC (${#PROJECTS[@]} projects)…"

# rsync include set: only the named project dirs, exclude everything else.
INCLUDES=()
for p in "${PROJECTS[@]}"; do
    if [ ! -d "$SRC/$p" ]; then
        echo "  WARN: $SRC/$p not found — skipping" >&2
        continue
    fi
    INCLUDES+=( --include="/$p" --include="/$p/***" )
done

docker run --rm \
    -v "$VOL":/dst \
    -v "$SRC":/src:ro \
    "$HELPER" \
    rsync -aHX --numeric-ids --delete --info=stats2 \
        "${INCLUDES[@]}" --exclude='/*' \
        /src/ /dst/

echo
echo "=== $VOL contents ==="
docker run --rm -v "$VOL":/dst "$HELPER" sh -c 'du -sh /dst; echo; du -sh /dst/* 2>/dev/null | sort -rh'
