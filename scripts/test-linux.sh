#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE="${SWIFT_IMAGE:-swift:6.2}"
CMD="${*:-swift test}"

if ! docker info >/dev/null 2>&1; then
    echo "docker daemon not reachable. Start Colima:" >&2
    echo "  colima start --cpu 4 --memory 8 --arch aarch64" >&2
    exit 1
fi

exec docker run --rm -it \
    -v "$REPO_ROOT":/work \
    -v fastcsv-linux-build:/work/.build \
    -w /work \
    "$IMAGE" \
    bash -c "$CMD"
