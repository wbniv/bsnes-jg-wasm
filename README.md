# bsnes-jg-wasm

**The cycle-accurate SNES core that gates a compiler's correctness — now in your browser.**

A WebAssembly build of [**bsnes-jg**](https://gitlab.com/jgemu/bsnes) (the Jolly Good fork of
bsnes), plus a minimal page that runs `.sfc` homebrew. Its reason to exist: bsnes-jg is the
**second leg of the differential gate** in the [`llvm-mos-65816`](https://github.com/wbniv/llvm-mos-65816)
project (a from-source LLVM fork adding native 16-bit-accumulator codegen — `+mos-a16` — for the
WDC 65816). That gate asserts *host == default@MAME == +mos-a16@MAME == +mos-a16@bsnes-jg*. By
shipping **the same core** to the web, a browser demo of the `+mos-a16` ROMs is byte-for-byte the
output the gate already verified — not a snes9x lookalike.

> **Why bsnes-jg and not snes9x?** snes9x is the turnkey browser default, but it is *not*
> cycle-accurate and its license is **non-commercial / GPL-incompatible**. bsnes-jg is
> **cycle-accurate AND GPLv3** — the accuracy-matched *and* license-clean choice. The only cost is
> one Emscripten core build, which `build.sh` owns.

---

## What's here

```
build.sh            # reproducible: bootstrap emsdk → clone libretro/bsnes-jg @pin → build core → web/cores/
serve.py            # local static server (single-thread by default; --isolated adds COOP/COEP for threaded builds)
sync-roms.sh        # refresh the bundled demo ROMs from a sibling llvm-mos-65816 checkout
Taskfile.yml        # task build / serve / sync-roms / clean
web/
  index.html        # the loader page (EmulatorJS frontend; ROM picker + drag-drop)
  roms/*.sfc        # snapshot of the +mos-a16 graphics demos (Mandelbrot zoom / Mode-7 / display / interactive)
  cores/            # build.sh drops bsnes_jg_libretro.{wasm,js} here (gitignored — reproducible)
docs/plans/         # the build plan / contract
LICENSE  NOTICE     # GPLv3 (the core) + attribution
```

## Quick start

```sh
task serve          # serve web/ on http://localhost:8000  (works today — see "Two modes" below)
```

Open [http://localhost:8000](http://localhost:8000), pick a demo (or drop your own `.sfc`).

## Build the accurate core

```sh
task build          # bootstraps emsdk into ./emsdk, clones the core, builds bsnes_jg_libretro.{wasm,js}
```

`emsdk` is bootstrapped automatically if `emcc` isn't on `PATH`. First run is slow (downloads the
Emscripten toolchain); after that it's cached.

## Two accuracy modes (be honest about which you're running)

| Mode | Core | Status | Use |
|------|------|--------|-----|
| **Showcase** (default) | EmulatorJS stock SNES core (loaded from CDN) | **works now, zero build** | quick "run it in a browser" demo |
| **Accurate** | the `bsnes-jg` core from `build.sh` | wiring in progress (see [the plan](docs/plans/2026-06-25-bsnes-jg-wasm.md)) | the credibility claim: *same core the gate trusts* |

The showcase mode gets you a working page immediately. The accurate mode — pointing the page at the
locally built `bsnes-jg` core and proving its framebuffer CRC matches the gate's headless
`jgxcheck` value — is the project's headline deliverable and is tracked in the plan's verification
steps.

## License

The bsnes-jg core is **GPLv3** (`LICENSE` is its verbatim `COPYING`). Anything that links or ships
the built core inherits GPLv3 — so this repo, and any deploy of `web/cores/*.wasm`, publishes its
source. The build scripts and loader here are GPLv3 to match. See `NOTICE` for attribution. The
bundled `.sfc` files are homebrew built by the `llvm-mos-65816` toolchain from its own example
sources.

## Not a CI test leg

This runs the *same* cores the `llvm-mos-65816` gate already runs natively (MAME + bsnes-jg), only
slower and harder to drive headless. It adds **no** correctness coverage and is deliberately **not**
wired into that project's differential gate. It exists to *show*, not to *verify*.
