# Plan — `bsnes-jg-wasm`: ship the gate's cycle-accurate core to the browser

**Status:** SCAFFOLDED (2026-06-25). Repo stood up at `~/SRC/bsnes-jg-wasm` with a working
showcase-mode page + a reproducible core-build pipeline; the **accurate-mode** integration
(verification steps 1–3) is the remaining headline work.

**Origin:** the [llvm-mos-65816 investigation](https://github.com/wbniv/llvm-mos-65816/blob/main/docs/investigations/snes-emulator-in-browser.md)
(`docs/investigations/snes-emulator-in-browser.md` in that repo) — verdict: yes, feasible; bsnes-jg
is a libretro core → compiles to WASM. Named `bsnes-jg-wasm` (user, 2026-06-25): the honest artifact
name. Repo location resolved to a **standalone repo** (user, 2026-06-25) — cleanly separate from the
LLVM tree's Apache-2.0-w/-LLVM-exception licensing and with its own GPLv3 publish story.

## Context

The `+mos-a16` toolchain produces 32 KiB LoROM `.sfc` homebrew (Mandelbrot zoom / Mode-7 / DMA
demos). We want them runnable **in a browser, no install**, in **the same cycle-accurate `bsnes-jg`
core the differential gate trusts** (the gate's second leg, `build/jgxcheck` → `vendor/bsnes-jg`),
so the page's pitch is "byte-for-byte what the gate verified," not a snes9x lookalike.

snes9x (the turnkey browser default) is high-compat but **not** cycle-accurate and **non-commercial /
GPL-incompatible**. bsnes-jg is **cycle-accurate AND GPLv3** — accuracy-matched and license-clean.
Cost = one Emscripten core build, owned by `build.sh`.

## Goal / deliverable

A self-contained **WASM build of bsnes-jg** (`bsnes_jg_libretro.{wasm,js}`) + a **minimal loader
page** that boots our `.sfc` ROMs and renders them, on a plain static host. Reusable: the same
`.wasm` later backs a "showroom" demo-reel page (out of scope here).

## Source of truth

- **Core:** [`libretro/bsnes-jg`](https://github.com/libretro/bsnes-jg) — libretro wrapper around the
  Jolly Good fork ([gitlab.com/jgemu/bsnes](https://gitlab.com/jgemu/bsnes), GPLv3). **Pin the clone
  to the commit matching the llvm-mos-65816 `vendor/bsnes-jg` revision** so "same core" is literally
  true (`build.sh` records the built SHA → `web/cores/PROVENANCE.json`).
- **Build:** Emscripten SDK + libretro's emscripten path
  ([RetroArch `pkg/emscripten`](https://github.com/libretro/RetroArch/tree/master/pkg/emscripten),
  [EmulatorJS: building raw cores](https://emulatorjs.org/docs4devs/buildingraw/)).
- **Loader:** EmulatorJS ([emulatorjs.org](https://emulatorjs.org)).

## Decisions (resolved)

1. **Repo:** standalone `~/SRC/bsnes-jg-wasm` ✅ (user, 2026-06-25).
2. **Audio:** bsnes-jg embeds the SPC700 IPL (no BIOS — same reason the gate's jg leg needs none);
   demos are sound-free → audio muted/stubbed initially.
3. **Threads:** default **single-threaded** (full speed for SNES, no COOP/COEP, any static host).
   `serve.py --isolated` is ready if a threaded build is ever wanted.

## Status of the scaffold

- ✅ `build.sh` — bootstraps emsdk, clones+pins the core, builds, drops artifacts + provenance.
- ✅ `web/index.html` — EmulatorJS loader, ROM picker (bundled demos) + drag-drop, accuracy-mode banner.
- ✅ `serve.py` (plain / `--isolated`), `sync-roms.sh`, `Taskfile.yml`, `LICENSE` (GPLv3), `NOTICE`.
- ✅ `web/roms/` — snapshot of mandel-{zoom,mode7,display,interactive}.sfc.
- ⏳ **Accurate mode** — point the page at the locally built `bsnes-jg` core and prove the CRC match
  (verification 1–3). Showcase mode (stock CDN core) works today as the interim.

## Verification

> Run each step; paste raw output below it in a code block; PASS/FAIL; write back here.

1. **Build + pin.** `./build.sh` (with `BSNES_JG_PIN` = the llvm-mos-65816 `vendor/bsnes-jg`
   revision) produces `web/cores/bsnes_jg_libretro.{wasm,js}` from a clean checkout, and
   `PROVENANCE.json` records that SHA.
2. **Boots a demo.** The page, wired to the built core, boots `mandel-display.sfc` and renders a
   recognizable Mandelbrot (screenshot).
3. **Fidelity (the headline).** The in-browser framebuffer CRC == the gate's headless `jgxcheck`
   CRC for the same ROM (`0x9103` for `mandel-display`) — same core, same pixels.
4. **Static-host friendly.** Works with **no COOP/COEP** (single-thread) in current Chromium + Firefox.
5. **License hygiene.** GPLv3 source published with the build; `NOTICE` present; no snes9x in the
   accurate-mode path.

## Risks / open items

- **"Same core" must be literally true** — the pin (step 1) is what makes the credibility claim real.
- **Custom-core wiring** — EmulatorJS packages cores in its own format; feeding a raw emscripten
  libretro `.wasm` may need repackaging or a minimal libretro-web loader. This is the concrete
  unknown behind step 2; resolve on the first build with the artifact in hand.
- **GPLv3** — fine; build source ships (this repo). Kept out of the LLVM tree via the standalone repo.
- **Perf** — cycle-accurate bsnes-jg is heavier than snes9x; verify 60 fps on a mid laptop + a phone.
- **Scope guard** — NOT a CI differential leg for llvm-mos-65816 (same cores it runs natively → no
  new coverage). For show only.
