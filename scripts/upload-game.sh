#!/usr/bin/env bash
#
# Upload the Godot web export under games/ to the public GCS bucket that serves
# the game at https://storage.googleapis.com/bencost-games/. The game is hosted
# off Cloud Run because its index.wasm (~40 MiB) exceeds Cloud Run's 32 MiB HTTP
# response cap; GCS has no such limit and serves the wasm as application/wasm.

set -euo pipefail

readonly PROJECT=${PROJECT:-bencost}
readonly BUCKET=${BUCKET:-bencost-games}

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT"

gcloud storage rsync -r games/ "gs://${BUCKET}/" --project "$PROJECT"

cat <<EOF

Uploaded games/ -> gs://${BUCKET}/

  Trawler: https://storage.googleapis.com/${BUCKET}/trawler/index.html
EOF