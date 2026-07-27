# TODO — bsnes-jg-wasm

Plan / contract: [docs/plans/2026-06-25-bsnes-jg-wasm.md](docs/plans/2026-06-25-bsnes-jg-wasm.md).

## Open

### Accurate mode — remaining

- [T3] **Perf on a phone.** Laptop is ~82 fps raw (>60 with headroom); Asyncify adds overhead, so
  measure a real low-end phone for the zoom/Mode-7 demos before claiming mobile.
- [T2] **Firefox spot-check.** End-to-end is verified in Chromium; load the page once in current
  Firefox (single-thread, no COOP/COEP) to confirm before deploy. (Plan step 4.)

### Polish

- [T3] Optional: trim Asyncify cost (size/speed) with an `ASYNCIFY_ONLY`/`ADD` list once the core's
  swap-reachable call set is profiled — only if mobile perf needs it.
- [T2] Wire self-checks for the other demos (zoom/mode7/interactive) — needs their scripted-input
  gates (see `dev/mandel-interactive.sh`), not just a boot-time WRAM read.

### npm package — [plan](docs/plans/2026-07-27-npm-player-package.md)

- [T3] **A2–A3 package skeleton + sync CLI**: `package.json` (`@wbniv/bsnes-jg-player`, GPL-3.0-only),
  committed `dist/engine` + demo, `bin/sync.mjs` (`sync` / `--demo` / `--check` / `version`),
  `scripts/stage-dist.sh`.
- [T3] **A4 SnesPlayer.astro + integration.mjs + embed/{snippet.html,player.css}** with boot-contract
  docs in README.
- [T2] **A5 CI + publish workflows** (`ci.yml` rebuild⇄diff reproducibility gate + headless selfcheck,
  `publish.yml` npm provenance on `v*` tag) + `task package` / `task publish-dry`.
- [T3] **Phase C — indri.studio adoption**: install package; replace `scripts/sync-llvm-mos-emulator.sh`
  with the sync CLI; `EmulatorEmbed.astro` → `<SnesPlayer playBase="/apps/llvm-mos-65816/play">`;
  Base.astro boot logic removed; indri inherits poster clear-to-black (intentional; flag it).
- [T2] **Phase C — snes-rom-page skill**: delete vendored `engine/`; scaffold.sh → ROM+preview copy,
  manifest entry, `src/content/snes/<slug>.mdx` stub; drop snes-demos.ts append; update SKILL.md.

### Later (separate)

- [T3] **Showroom** — a demo-reel page consuming this core (curated `+mos-a16` productions). Its own
  effort; this repo just provides the `.wasm`.

## Watch

_Nothing being watched._

## Parked

_Nothing parked._

## Done

- [x] 2026-07-27 — [npm-package] A1: merged the 3 drifted app.js copies (kept adaptive yoff, manifest touchNav). See [plan](docs/plans/2026-07-27-npm-player-package.md).
- [x] **Mode 7 Mandelbrot, on-SNES + progressive** (2026-06-26): `mandel-display` rewritten to render
  in Mode 7 — 64×56 per-pixel bitmap computed on the 65816, revealed coarse→fine via **vblank DMA**
  (no force-blank flash), then a hardware affine **rotate+zoom**. CRC `0x204F` @ WRAM `$0400`/5200 fr.
  Also: build now defaults to the **a16 toolchain** so `mandel-mode7` builds (was skipped) — and it
  was made progressive too (128×128 far-WRAM compute, banded vblank reveal, CRC `0x75E8`).
- [x] **Fast first paint for `mandel-display`** (2026-06-26): progressive 4×4→8×7→16×14→32×28 ROM
  render + baked 4×4 loader preview; first visual <0.2 s, monotonic sharpen. CRC `0x9103` unchanged
  (self-check moved to WRAM `$0660` / 1400 frames). Deployed live (indri `v0.1.72`).
  [plan](docs/plans/2026-06-26-fast-first-paint-for-the-snes-mandelbrot-display.md)
- [x] **Deployed to indri.studio** (2026-06-25): the live emulator is embedded inline on
  [`/apps/llvm-mos-65816/`](https://indri.studio/apps/llvm-mos-65816/) running `mandel-display` + the
  `0x9103` self-check; `task bundle` → `dist-bundle/`, synced into indri's `public/`. Prod CSP block
  found+fixed (`'wasm-unsafe-eval'`); verified live (`v0.1.69`). [indri plan](../indri.studio/docs/plans/2026-06-25-llvm-mos-emulator-embed.md)
- [x] **Accurate mode wired + verified** (2026-06-25): built jgemu/bsnes 2.1.0 (sha256-pinned, the
  gate core) to wasm via a custom Jolly-Good-API frontend + Emscripten-fiber libco backend + Asyncify;
  canvas loader; in-browser self-check reads WRAM `0x9103` == gate. Verification 1–5 + perf PASS.
- [x] **[verify] Fidelity CRC match** (2026-06-25): in-browser `mandel-display` WRAM `$0580` ==
  `0x9103` == gate `jgxcheck`, headless Chrome — PASS. (Plan step 3.)
- [x] **Page flipped to accurate mode** (2026-06-25): EmulatorJS/CDN path removed; live PROVENANCE
  banner shows core version + sha256; `Verify fidelity` button added. (Plan polish.)
- [x] **build.sh build target resolved** (2026-06-25): `emmake make ENABLE_STATIC=1 DISABLE_MODULE=1
  USE_VENDORED_SAMPLERATE=1` → `libbsnes.a`, then `em++` links the frontend to `.js`+`.wasm`.
- [x] Scaffolded the repo (2026-06-25): reproducible `build.sh`, loader page, `serve.py`,
  `sync-roms.sh`, `Taskfile.yml`, GPLv3 `LICENSE`+`NOTICE`, bundled demo ROMs, the plan.

