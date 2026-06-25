#!/usr/bin/env bash
set -euo pipefail

# build.sh — reproducibly build the bsnes-jg libretro core to WebAssembly.
#
#   1. bootstrap the Emscripten SDK into ./emsdk (if emcc isn't already on PATH)
#   2. clone libretro/bsnes-jg into ./vendor at a pinned commit
#   3. build the core for the emscripten platform
#   4. copy bsnes_jg_libretro.{wasm,js} into web/cores/
#
# Everything is reproducible from this repo + a network connection. No manual steps.

usage() {
  cat <<'EOF'
Usage: ./build.sh [-h]

Builds the bsnes-jg libretro core to WebAssembly (web/cores/).

Env overrides:
  BSNES_JG_PIN   git commit/tag/branch of libretro/bsnes-jg to build
                 (DEFAULT: master — but PIN this to the commit matching the
                  llvm-mos-65816 vendor/bsnes-jg revision so "same core" is literally true;
                  this is verification step 1 in docs/plans/2026-06-25-bsnes-jg-wasm.md)
  EMSDK_VERSION  Emscripten version to install (DEFAULT: latest)
  MAKE_TARGET    libretro make invocation override (see NOTE below)
EOF
}
[ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ] && { usage; exit 0; }

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PIN="${BSNES_JG_PIN:-master}"
EMSDK_VERSION="${EMSDK_VERSION:-latest}"
CORE_REPO="https://github.com/libretro/bsnes-jg.git"
ts() { date -u +%Y-%m-%dT%H:%M:%SZ; }
log() { echo "[$(ts)] $*"; }

# --- 1. Emscripten SDK -------------------------------------------------------
if ! command -v emcc >/dev/null 2>&1; then
  if [ ! -d "$ROOT/emsdk" ]; then
    log "emcc not found — bootstrapping emsdk into $ROOT/emsdk"
    git clone --depth 1 https://github.com/emscripten-core/emsdk.git "$ROOT/emsdk"
  fi
  log "installing + activating emsdk ($EMSDK_VERSION)"
  "$ROOT/emsdk/emsdk" install "$EMSDK_VERSION"
  "$ROOT/emsdk/emsdk" activate "$EMSDK_VERSION"
  # shellcheck disable=SC1091
  source "$ROOT/emsdk/emsdk_env.sh"
fi
log "using $(emcc --version | head -1)"

# --- 2. core source (pinned) -------------------------------------------------
mkdir -p "$ROOT/vendor"
CORE_DIR="$ROOT/vendor/bsnes-jg"
if [ ! -d "$CORE_DIR/.git" ]; then
  log "cloning $CORE_REPO"
  git clone "$CORE_REPO" "$CORE_DIR"
fi
git -C "$CORE_DIR" fetch --all --tags --quiet
log "checking out pin: $PIN"
git -C "$CORE_DIR" checkout --quiet "$PIN"
BUILT_SHA="$(git -C "$CORE_DIR" rev-parse HEAD)"
log "core source at $BUILT_SHA"

# --- 3. build for emscripten -------------------------------------------------
# NOTE (verify on first real run — Inc 0): libretro cores are conventionally built
# with `emmake make platform=emscripten` from the dir holding the libretro Makefile.
# bsnes-jg's libretro Makefile location/target name is confirmed on the first build;
# override via MAKE_TARGET / by editing the line below if upstream differs. The
# emscripten link step must emit a self-contained .js + .wasm (MODULARIZE, the
# libretro retro_* exports), not a bare .bc — adjust LDFLAGS if the core's Makefile
# stops at bitcode.
log "building core (platform=emscripten)"
( cd "$CORE_DIR" && emmake make ${MAKE_TARGET:-platform=emscripten} -j"$(nproc)" )

# --- 4. collect artifacts ----------------------------------------------------
mkdir -p "$ROOT/web/cores"
found=0
while IFS= read -r -d '' f; do
  cp -v "$f" "$ROOT/web/cores/"
  found=1
done < <(find "$CORE_DIR" -maxdepth 3 -name 'bsnes_jg_libretro*.wasm' -o -name 'bsnes_jg_libretro*.js' -print0 2>/dev/null || true)

if [ "$found" -eq 0 ]; then
  log "ERROR: no bsnes_jg_libretro.{wasm,js} produced — inspect the make output / MAKE_TARGET" >&2
  exit 1
fi

# record provenance so the page can display exactly which core it runs
printf '{ "core": "bsnes-jg", "source": "%s", "commit": "%s", "built": "%s" }\n' \
  "$CORE_REPO" "$BUILT_SHA" "$(ts)" > "$ROOT/web/cores/PROVENANCE.json"
log "done — artifacts + PROVENANCE.json in web/cores/"
