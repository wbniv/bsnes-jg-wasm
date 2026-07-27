#!/usr/bin/env bash
# stage-dist.sh — copy the canonical player + built core into dist/ (the committed
# npm payload). web/ stays the single source; dist/ is generated-and-committed so
# `npm publish` and `npm i git+…` never depend on an emsdk build.
#
# dist/engine/  app.js + cores/{bsnes_jg.js,bsnes_jg.wasm,PROVENANCE.json}
# dist/demo/    one demo ROM (mandel-display) + minimal manifest + preview
set -euo pipefail

usage() { echo "usage: stage-dist.sh [-h|--help]  — stage web/ artifacts into dist/"; }
case "${1:-}" in -h|--help) usage; exit 0;; esac

cd "$(dirname "$0")/.."

for f in web/app.js web/cores/bsnes_jg.js web/cores/bsnes_jg.wasm web/cores/PROVENANCE.json; do
  [[ -f "$f" ]] || { echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) missing $f — run ./build.sh first" >&2; exit 1; }
done

mkdir -p dist/engine/cores dist/demo/roms dist/demo/preview
cp web/app.js dist/engine/app.js
cp web/cores/bsnes_jg.js web/cores/bsnes_jg.wasm web/cores/PROVENANCE.json dist/engine/cores/

cp web/roms/mandel-display.sfc dist/demo/roms/
cp web/roms/manifest.json dist/demo/roms/
cp web/preview/mandel-display.png dist/demo/preview/

echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) staged dist/ from web/:"
( cd dist && find . -type f -printf '  %-40p %10s bytes\n' | sort )
