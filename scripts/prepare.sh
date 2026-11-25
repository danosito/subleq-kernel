#!/usr/bin/env bash
# Public-only inputs; refuses non-pristine destination. Usage: prepare.sh OUT
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
DEST=${1:?usage: prepare.sh EMPTY_OUTPUT_DIRECTORY}
if [[ -e "$DEST" ]]; then
    echo 'Output must not already exist' >&2
    exit 1
fi
mkdir -p "$DEST"
DEST=$(cd "$DEST" && pwd)
git clone https://github.com/adriancable/linux.git "$DEST/linux"
git -C "$DEST/linux" checkout --detach c06286b9aa8a2245af9fbea92b12d812a77a9aa1
[[ -z $(git -C "$DEST/linux" status --porcelain) ]]
git -C "$DEST/linux" apply --check "$ROOT/patches/0001-subleq-four-slot-virtio-idle.patch"
git -C "$DEST/linux" apply "$ROOT/patches/0001-subleq-four-slot-virtio-idle.patch"
# Leave rootfs empty: build.sh compiles only this repository's benign init.
mkdir -p "$DEST/rootfs"
printf 'Linux input: %s\n' "$(git -C "$DEST/linux" rev-parse HEAD)"
printf 'Patch applied; source directory: %s\n' "$DEST/linux"
