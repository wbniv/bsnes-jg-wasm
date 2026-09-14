#!/usr/bin/env bash
# stage-dist.sh — copy the canonical player + built core into dist/ (the committed
# npm payload). web/ stays the single source; dist/ is generated-and-committed so
# `npm publish` and `npm i git+…` never depend on an emsdk build.
#
# dist/engine/  app.js + cores/{bsnes_jg.js,bsnes_jg.wasm,PROVENANCE.json}
# dist/demo/    the DEMO_ROMS set below + a manifest filtered to it + previews
set -euo pipefail

usage() { echo "usage: stage-dist.sh [-h|--help]  — stage web/ artifacts into dist/"; }
case "${1:-}" in -h|--help) usage; exit 0;; esac

cd "$(dirname "$0")/.."

for f in web/app.js web/cores/bsnes_jg.js web/cores/bsnes_jg.wasm web/cores/PROVENANCE.json; do
  [[ -f "$f" ]] || { echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) missing $f — run ./build.sh first" >&2; exit 1; }
done

DEMO_ROMS=(mandel-display)

mkdir -p dist/engine/cores dist/demo/roms dist/demo/preview
cp web/app.js dist/engine/app.js
cp web/cores/bsnes_jg.js web/cores/bsnes_jg.wasm web/cores/PROVENANCE.json dist/engine/cores/

for id in "${DEMO_ROMS[@]}"; do
  cp "web/roms/$id.sfc" dist/demo/roms/
  cp "web/preview/$id.png" dist/demo/preview/
done

# The shipped demo manifest is filtered to DEMO_ROMS. web/roms/manifest.json also describes
# ROMs that live on the consuming sites (they are site content, not package payload), and
# copying it wholesale leaves `sync --demo` with picker buttons whose .sfc fetch 404s.
DEMO_ROMS="${DEMO_ROMS[*]}" python3 - web/roms/manifest.json dist/demo/roms/manifest.json <<'PY'
import collections, json, os, sys
keep = set(os.environ["DEMO_ROMS"].split())
src = json.load(open(sys.argv[1]), object_pairs_hook=collections.OrderedDict)
src["roms"] = [r for r in src["roms"] if r["id"] in keep]
missing = keep - {r["id"] for r in src["roms"]}
if missing:
    sys.exit("stage-dist: no manifest entry for demo ROM(s): " + ", ".join(sorted(missing)))
open(sys.argv[2], "w").write(json.dumps(src, indent=2, ensure_ascii=False) + "\n")
PY

echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) staged dist/ from web/:"
( cd dist && find . -type f -printf '  %-40p %10s bytes\n' | sort )
