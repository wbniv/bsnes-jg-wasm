#!/usr/bin/env bash
set -euo pipefail

# make-preview.sh — bake the coarse loading-preview image shown on the canvas while the
# ~3.9 MB wasm core downloads/instantiates (web/app.js paints it before the first live
# frame). It's a COARSE render of the SAME fixed-point Mandelbrot the mandel-display ROM
# computes on-SNES — same kernel, same palette (tools/mandel-render.c shares mandel.h with
# the ROM) — so it matches the demo's first live passes instead of being a foreign splash.
#
# Reproducible-from-source: regenerated from the sibling llvm-mos-65816 checkout, never
# hand-drawn. Re-run after changing the ROM's window/palette (DN) so the preview can't drift.

usage() {
  cat <<EOF
Usage: ./make-preview.sh [-h] [SRC_REPO_DIR]

Renders web/preview/mandel-display.png (coarse Mandelbrot) via the sibling repo's
host renderer (tools/mandel-render.c).

  SRC_REPO_DIR   path to the llvm-mos-65816 checkout (DEFAULT: ../llvm-mos-65816)

Env overrides:
  PREVIEW_W PREVIEW_H   preview grid (DEFAULT: 4 4 — matches the ROM's first live pass, so
                        the handoff from preview to live is seamless, no coarsening dip)
EOF
}
[ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ] && { usage; exit 0; }

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="${1:-$ROOT/../llvm-mos-65816}"
PW="${PREVIEW_W:-4}"
PH="${PREVIEW_H:-4}"

[ -f "$SRC/tools/mandel-render.c" ] || { echo "ERROR: no $SRC/tools/mandel-render.c" >&2; exit 1; }
DISP="$SRC/examples/snes/mandel-display.c"
# Pull DN (max iterations) from the ROM source so the preview palette can't drift out of sync.
DN="$(awk '/#define DN /{print $3; exit}' "$DISP" 2>/dev/null || true)"
DN="${DN:-15}"

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
cc -O2 -I "$SRC/examples/65816" -I "$SRC/tools" "$SRC/tools/mandel-render.c" -o "$TMP/mandel-render"
mkdir -p "$ROOT/web/preview"
"$TMP/mandel-render" "$ROOT/web/preview/mandel-display.png" "$PW" "$PH" "$DN"
echo "done: web/preview/mandel-display.png (${PW}x${PH}, N=${DN})"
