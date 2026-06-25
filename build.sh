#!/usr/bin/env bash
set -euo pipefail

# build.sh — reproducibly build the gate's cycle-accurate SNES core to WebAssembly.
#
# Builds jgemu/bsnes 2.1.0 — the EXACT core (version + sha256) the llvm-mos-65816
# differential gate trusts (its "second leg", dev/jgxcheck.cpp) — to wasm, and
# links our minimal Jolly-Good-API frontend (web/src/main.cpp) into a single
# self-contained module the loader page drives. No libretro, no EmulatorJS.
#
#   1. bootstrap the Emscripten SDK into ./emsdk (if emcc isn't already on PATH)
#   2. fetch + sha256-verify the pinned jgemu/bsnes tarball into ./vendor
#   3. patch libco with an Emscripten-fiber backend (the stock libco has no wasm
#      path; see web/src/libco_emscripten.c)
#   4. build the core static archive (emmake make, vendored libsamplerate)
#   5. link web/src/main.cpp + libbsnes.a -> web/cores/bsnes_jg.{js,wasm}
#
# Everything is reproducible from this repo + a network connection. No manual steps.

usage() {
  cat <<'EOF'
Usage: ./build.sh [-h]

Builds bsnes-jg (jgemu/bsnes 2.1.0) + the wasm frontend into web/cores/.

Env overrides:
  BSNES_VER      jgemu/bsnes version to build       (DEFAULT: 2.1.0 — the gate pin)
  BSNES_SHA256   expected sha256 of the tarball      (DEFAULT: the 2.1.0 hash)
  EMSDK_VERSION  Emscripten version to install        (DEFAULT: latest)
  OPT            optimization level for the core+link (DEFAULT: -O3)
EOF
}
[ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ] && { usage; exit 0; }

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BSNES_VER="${BSNES_VER:-2.1.0}"
# sha256 of gitlab.com/jgemu/bsnes/-/archive/2.1.0/bsnes-2.1.0.tar.gz — the same
# value pinned in llvm-mos-65816 dev/xcheck.sh, so "same core" is literally true.
BSNES_SHA256="${BSNES_SHA256:-a8e0fd36711406198afe1110ddc6960c9d795f4ab73d0badd8878396ac3d0c42}"
EMSDK_VERSION="${EMSDK_VERSION:-latest}"
OPT="${OPT:--O3}"
CORE_URL="https://gitlab.com/jgemu/bsnes/-/archive/${BSNES_VER}/bsnes-${BSNES_VER}.tar.gz"
CORE_DIR="$ROOT/vendor/bsnes-jg"
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
EMCC_VER="$(emcc --version | head -1)"
log "using $EMCC_VER"

# --- 2. core source (pinned + verified) --------------------------------------
mkdir -p "$ROOT/vendor"
if [ ! -d "$CORE_DIR/src" ]; then
  log "fetching jgemu/bsnes $BSNES_VER (pinned)"
  TARBALL="$ROOT/vendor/bsnes-${BSNES_VER}.tar.gz"
  curl -fsSL "$CORE_URL" -o "$TARBALL"
  echo "$BSNES_SHA256  $TARBALL" | sha256sum -c -
  mkdir -p "$CORE_DIR"
  tar xzf "$TARBALL" -C "$CORE_DIR" --strip-components=1
  rm -f "$TARBALL"
fi
log "core source: jgemu/bsnes $BSNES_VER (sha256 verified)"

# --- 3. patch libco with an Emscripten-fiber backend -------------------------
# Stock libco v20 has no wasm path (its dispatcher falls through to sjlj.c, which
# needs POSIX sigaltstack/raise — absent under Emscripten). Drop our fiber
# backend in and teach libco.c to use it for __EMSCRIPTEN__.
cp -f "$ROOT/web/src/libco_emscripten.c" "$CORE_DIR/deps/libco/emscripten.c"
LIBCO_C="$CORE_DIR/deps/libco/libco.c"
if ! grep -q '__EMSCRIPTEN__' "$LIBCO_C"; then
  log "patching deps/libco/libco.c dispatch for __EMSCRIPTEN__"
  awk '
    /#elif defined\(_WIN32\)/ && !done {
      print "  #elif defined(__EMSCRIPTEN__)";
      print "    #include \"emscripten.c\"";
      done = 1;
    }
    { print }
  ' "$LIBCO_C" > "$LIBCO_C.tmp" && mv "$LIBCO_C.tmp" "$LIBCO_C"
fi
grep -q '__EMSCRIPTEN__' "$LIBCO_C" || { log "ERROR: libco patch failed"; exit 1; }

# --- 4. build the core static archive (wasm) ---------------------------------
# ENABLE_STATIC=1 DISABLE_MODULE=1 -> objs/libbsnes.a (no .so, no SDL example);
# USE_VENDORED_SAMPLERATE=1 compiles the bundled libsamplerate into the archive,
# so the build is fully self-contained (no external -lsamplerate). emmake sets
# CC=emcc CXX=em++ AR=emar.
log "building core static archive (emmake make, vendored libsamplerate)"
emmake make -C "$CORE_DIR" \
  ENABLE_STATIC=1 DISABLE_MODULE=1 USE_VENDORED_SAMPLERATE=1 \
  CFLAGS="$OPT" CXXFLAGS="$OPT" \
  -j"$(nproc)"

ARCHIVE="$(find "$CORE_DIR/objs" -name 'libbsnes.a' | head -1)"
[ -n "$ARCHIVE" ] || { log "ERROR: core archive (libbsnes.a) not produced — inspect make output" >&2; exit 1; }
log "core archive: $ARCHIVE"

# --- 5. stage embedded data + link the wasm frontend -------------------------
# The loader reads the SNES game database from the wasm MEMFS; embed the small
# .bml files (skip the 2 MB CheatCodes.bml — not needed to load homebrew).
DATA_STAGE="$ROOT/vendor/.embed/Database"
rm -rf "$ROOT/vendor/.embed"; mkdir -p "$DATA_STAGE"
for f in boards.bml SuperFamicom.bml BSMemory.bml SufamiTurbo.bml; do
  cp "$CORE_DIR/Database/$f" "$DATA_STAGE/"
done

mkdir -p "$ROOT/web/cores"
EXPORTS='_bjg_load,_bjg_run,_bjg_reset,_bjg_video,_bjg_video_w,_bjg_video_h,_bjg_video_pitch,_bjg_loaded,_bjg_set_input,_bjg_wram,_bjg_wram_size,_malloc,_free,_main'

log "linking web/cores/bsnes_jg.js (+ .wasm) with Asyncify"
em++ $OPT -std=c++11 \
  -I"$CORE_DIR/src" \
  "$ROOT/web/src/main.cpp" "$ARCHIVE" \
  -sASYNCIFY=1 \
  -sASYNCIFY_STACK_SIZE=131072 \
  -sMODULARIZE=1 \
  -sEXPORT_NAME=BsnesJg \
  -sALLOW_MEMORY_GROWTH=1 \
  -sINITIAL_MEMORY=67108864 \
  -sEXPORTED_FUNCTIONS="$EXPORTS" \
  -sEXPORTED_RUNTIME_METHODS=ccall,cwrap,HEAPU8,HEAPU32 \
  -sENVIRONMENT=web \
  --embed-file "$DATA_STAGE"@/bsnes/Database \
  -o "$ROOT/web/cores/bsnes_jg.js"

[ -f "$ROOT/web/cores/bsnes_jg.wasm" ] || { log "ERROR: no bsnes_jg.wasm emitted" >&2; exit 1; }

# --- 6. provenance -----------------------------------------------------------
printf '{\n  "core": "bsnes-jg (jgemu/bsnes)",\n  "source": "%s",\n  "version": "%s",\n  "sha256": "%s",\n  "emscripten": "%s",\n  "built": "%s",\n  "note": "the exact core+version the llvm-mos-65816 differential gate trusts (dev/jgxcheck.cpp)"\n}\n' \
  "$CORE_URL" "$BSNES_VER" "$BSNES_SHA256" "$EMCC_VER" "$(ts)" \
  > "$ROOT/web/cores/PROVENANCE.json"

log "done — web/cores/bsnes_jg.{js,wasm} + PROVENANCE.json"
ls -la "$ROOT/web/cores/"
