# Fast first paint for the SNES Mandelbrot display

## Context

The deployed demo at [https://indri.studio/apps/llvm-mos-65816/](https://indri.studio/apps/llvm-mos-65816/)
shows a **black screen for ~1–4 s** before the Mandelbrot appears. Root cause is structural, not
emulator speed:

- `mandel-display.c:71-91` (in `../llvm-mos-65816/examples/snes/`) computes the **entire** 32×28
  escape buffer with `mandel_fill(fb, 32, 28, 15)` while the screen is **force-blanked**, then
  releases force-blank once to reveal everything at once. Nothing visual happens until the whole
  on-target 65816 compute (896 cells × up to 15 iterations × three software 32-bit fixed-point
  multiplies each) finishes.

This demo is the *only* one with the problem: `mandel-zoom`/`mandel-interactive`/`mandel-mode7`
DMA **precomputed** baked images (`mandel_image.h`, `pyramid_image.h`) to VRAM and display
instantly. `mandel-display` is the one whose *purpose* is the live on-SNES compute — its
`corpus_result = mandel_crc(fb, 896)` (read back at WRAM `$0580`) proves the math is byte-for-byte
the differential gate's (`== 0x9103`).

**Goal:** something recognizable on screen in well under 0.5 s (target <0.1 s for first frame),
without touching the verified final image. Two parts, both chosen by the user:

- **Part A — progressive multi-pass render in the ROM:** draw coarse→fine (4×4 → 8×7 → 16×14 →
  32×28) so the live compute paints a blocky-but-complete fractal almost immediately and sharpens.
- **Part B — instant baked preview in the loader:** paint a tiny precomputed *coarse* image on the
  canvas at page load to cover wasm-core download/instantiation latency, before the core renders
  its first frame.

## Hard constraints (fidelity — do not break)

1. **Final buffer must stay canonical.** The last pass must be exactly `mandel_fill(fb, 32, 28, 15)`
   and `corpus_result = mandel_crc(fb, 896)`, so the CRC stays `0x9103`. Progressive previews change
   *when/how* pixels appear, never the final `fb[]`. The self-check runs 1000 frames — the render
   (even with ~1.3× redundant coarse compute) completes in well under that.
2. **Do not modify `mandel.h`.** It is the single source of truth shared by host and target and is
   load-bearing for the gate. Reuse `mandel_cell`/`mandel_fill`/`mandel_palette`/`mandel_crc` as-is;
   the progressive driver lives only in `mandel-display.c`.
3. **`corpus_result` WRAM offset may shift.** Adding code/scratch can move the symbol off `$0580`,
   silently breaking the self-check. After building, re-derive the offset from
   `build/mandel-display.map` and update `web/roms/manifest.json` `off` if it moved (`want` stays
   `0x9103`). Mitigate by declaring any new RAM *after* `corpus_result`.

## Part A — progressive render in `mandel-display.c`

File: `../llvm-mos-65816/examples/snes/mandel-display.c` (only this file).

Restructure `main()` into four passes. Reuse existing `load_palette()`, `upload_solid_tiles()`,
`vram_w()`, `snes_vram_addr()`, and `mandel_fill()`. Add one helper and one small scratch buffer.

**No vblank/NMI needed.** `snes_wait_vblank()` requires `NMITIMEN` bit 7 enabled (per
`platforms/snes/snes_cpu.h:124-128`), which this ROM doesn't set. Instead keep the existing
**force-blank** mechanism: bracket each tilemap upload in force-blank, exactly as the code already
does once, and as `mandel-zoom.c` does on level swaps. The upload is sub-frame, so passes 2–4 add a
≤1-frame (~16 ms) blink while a complete coarser image is already showing — barely perceptible.

New scratch + helper (declare scratch **after** `corpus_result`):

```c
static uint8_t pre[16 * 14];   // preview scratch, max coarse grid = 224 B (low WRAM)

// Write the full 32x32 BG1 tilemap from an sw×sh source grid, each source cell
// nearest-neighbour scaled to fill the 32x28 image (rows/cols past the image -> tile 0).
// sx/sy derived per cell so any grid works; for the final pass (32x28) this is identity.
static void upload_scaled(const uint8_t *src, uint8_t sw, uint8_t sh) {
  snes_vram_addr(MAP_BASE);
  for (uint16_t i = 0; i < 1024; i++) {
    uint8_t col = i & 31, row = (uint8_t)(i >> 5);
    uint16_t v = 0;
    if (row < DH && col < DW) {
      uint8_t sc = (uint8_t)(((uint16_t)col * sw) / DW);
      uint8_t sr = (uint8_t)(((uint16_t)row * sh) / DH);
      v = src[(uint16_t)sr * sw + sc];
    }
    vram_w(v);
  }
}
```

`main()` flow:

```c
snes_ppu_reset_blank();          // force-blank + zero PPU (unchanged)
load_palette();
upload_solid_tiles();
// BG mode / scroll / TM setup (moved up, before first reveal) — screen still force-blanked

// Pass 1: 4x4 (16 cells, <0.1s) — reveal via the existing boot force-blank release (no blink)
mandel_fill(pre, 4, 4, DN);   upload_scaled(pre, 4, 4);   REG_INIDISP = INIDISP_ON;
// Pass 2: 8x7 (56 cells)
mandel_fill(pre, 8, 7, DN);   REG_INIDISP = INIDISP_FORCE_BLANK; upload_scaled(pre, 8, 7);   REG_INIDISP = INIDISP_ON;
// Pass 3: 16x14 (224 cells)
mandel_fill(pre,16,14, DN);   REG_INIDISP = INIDISP_FORCE_BLANK; upload_scaled(pre,16,14);   REG_INIDISP = INIDISP_ON;
// Pass 4: 32x28 CANONICAL — sets the verified buffer + CRC
mandel_fill(fb, DW, DH, DN);  corpus_result = mandel_crc(fb, (uint16_t)(DW * DH));
REG_INIDISP = INIDISP_FORCE_BLANK; upload_scaled(fb, DW, DH); REG_INIDISP = INIDISP_ON;
for (;;) {}
```

Passes 1–3 write only `pre`/the tilemap; `fb` is written exactly once, canonically, in pass 4 →
CRC unchanged by construction. Grid sizes divide the 32×28 tile field cleanly (4×4→8×7 tiles each,
8×7→4×4, 16×14→2×2, 32×28→1×1).

## Part B — instant baked coarse preview in the loader

Files: `web/app.js`, a new asset `web/preview/mandel-display.png`, and `deploy-bundle.sh`
(add the asset to the bundle copy list). All in `/home/will/SRC/bsnes-jg-wasm/`.

**Why coarse, not the final image:** painting the crisp final image and then handing off to the
live render (which starts at 4×4) would read as "crisp → blocky → crisp." A *coarse* baked preview
(rendered at the live first-pass resolution) makes the handoff monotonic: coarse baked → coarse
live → sharpen. The preview's job is purely to cover wasm-core download/instantiate latency (the
~3.9 MB `bsnes_jg.wasm` can take 0.5–2 s cold) with a fractal-shaped image instead of black.

- **Asset:** an 8×7 (or 4×4) PNG rendered from the *same* kernel/palette so colours match, kept
  reproducible — regenerate via the sibling repo's host renderer `tools/mandel-render.c`
  (`mandel-render out.png 8 7 15`) and copy into `web/preview/`. Document the one command in a
  short `make-preview.sh` (or a note) so the asset is rebuildable from source, not a mystery blob.
- **`app.js`:** at `init()`, before/independent of core load, size `#screen` to 256×224, set
  `ctx.imageSmoothingEnabled = false`, and `drawImage` the preview scaled to fill. The existing
  `present()` (`app.js:66-99`) already does `putImageData` over the whole canvas every live frame,
  so the first live frame naturally overwrites the preview — no explicit teardown needed. Guard for
  the asset being absent (standalone/dev page without it) so nothing breaks.

## Files to modify

- `../llvm-mos-65816/examples/snes/mandel-display.c` — progressive 4-pass `main()` + `upload_scaled`
  + `pre[]` (Part A).
- `bsnes-jg-wasm/web/app.js` — paint baked preview at init (Part B).
- `bsnes-jg-wasm/web/preview/mandel-display.png` — new baked coarse asset.
- `bsnes-jg-wasm/deploy-bundle.sh` — copy `web/preview/` into `dist-bundle/`.
- `bsnes-jg-wasm/web/roms/manifest.json` — only if `corpus_result` offset moved (constraint 3).
- `bsnes-jg-wasm/TODO.md` — entry; mark done after verification.

## Reproduce / deploy chain

```bash
# 1. Rebuild the ROM (containerized; rebuilds all SNES programs — only mandel-display.c changed)
cd ../llvm-mos-65816 && task build            # -> build/mandel-display.sfc, build/mandel-display.map
# 2. Re-derive corpus_result offset; update manifest if it moved off 0x580 (see Verification 2)
# 3. Sync ROM into the wasm repo
cd ../bsnes-jg-wasm && ./sync-roms.sh          # -> web/roms/mandel-display.sfc
# 4. (Part B) regenerate + place web/preview/mandel-display.png
# 5. Bundle (core is unchanged; build.sh not needed unless cores/ missing)
task bundle                                    # -> dist-bundle/ (now incl. preview/)
# 6. Deploy to indri.studio
cd ../indri.studio && ./scripts/sync-llvm-mos-emulator.sh ../bsnes-jg-wasm/dist-bundle
git add public/apps/llvm-mos-65816/ && git commit && git tag vX.Y.Z && git push && git push --tags
```

## Verification

Evidence captured 2026-06-26 (native `build/jgxcheck` + headless Chrome via CDP).

1. **Build the ROM** — `cd ../llvm-mos-65816 && task build`; confirm `build/mandel-display.sfc`
   rebuilt with no errors.

   ```
       mandel-display  32768 bytes
   ==> built 10 program(s)
   ```
   No regalloc/verify-machineinstrs errors (inlining `mandel_fill` 4× is fine). **PASS.**

2. **Re-derive WRAM offset** — `grep -i corpus_result build/mandel-display.map`; compute
   `off = addr - 0x7E0000` (WRAM base). If `!= 0x580`, update `web/roms/manifest.json` `off`.

   ```
   295:     660      660        2     1   ...:(.bss.corpus_result)
   ```
   LTO put `pre`@`0x200`, `fb`@`0x2E0`, so `corpus_result` moved `0x580` → **`0x660`**. Independent
   oracle `mandel-render … 32 28 15` → `full-grid CRC16=0x9103` (final buffer unchanged). Manifest
   updated: `off` `0x660`, `frames` `1400` (completion measured ~1240, see step 4). **PASS.**

3. **In-browser fidelity self-check** — `task serve`, open the page, click **Verify fidelity**;
   must read `✓ FIDELITY 0x9103 == gate`. (Reproduced headless via CDP: fresh power-on + 1400
   frames + read WRAM `0x660`.)

   ```
   core loaded: true
   preview asset reachable: true
   self-check: {"got":"0x9103"}
   canvas: 256x224 lit 43200/57344
   console errors: none
   RESULT: PASS
   ```
   **PASS** (got `0x9103` == gate; no console errors).

4. **First-paint timing** — load `?rom=mandel-display`; confirm the baked preview shows fast and the
   live render takes over seamlessly. Native completion sweep + headless progression timeline:

   ```
   jgxcheck completion: FAIL @1230 frames, PASS @1245 (got=0x9103)  -> compute done ~frame 1240
   headless progression (edgeFrac = horizontal-edge density; higher = finer):
   @ 157ms preview 4x4   edgeFrac 0.0098     <- something visual < 0.2 s
   @1000ms live  4x4     edgeFrac 0.0098     <- seamless (identical to preview, no dip)
   @3000ms pass2 8x7     edgeFrac 0.0168
   @8000ms pass3 16x14   edgeFrac 0.0260
   @26000ms pass4 32x28  edgeFrac 0.0397     <- final crisp
   ```
   Baked preview visible <0.2 s; live 4×4 matches it exactly (preview re-rendered at the pass-1 grid).
   **PASS.**

5. **Visual progression** — screenshots (`scratchpad/prog-*.png`) confirm monotonic sharpening
   preview→4×4→8×7→16×14→32×28 with no coarsening dip; final frame matches the host 32×28 reference
   (crisp green-on-blue Mandelbrot, identical to `mandel-render … 32 28 15`). **PASS.**

6. **No regression for other ROMs** — headless load of each (404 on their missing preview is silent):

   ```
   mandel-zoom: litPixels=51936 errors=none -> PASS
   mandel-interactive: litPixels=43508 errors=none -> PASS
   ```
   (`mandel-mode7` is mos-a16-only, skipped by the prebuilt toolchain build — its ROM is untouched.)
   **PASS.**

7. **Deploy** — run the chain above; confirm live at the indri URL shows fast first paint.
   *(Pending — held for confirmation, since it tags + pushes a production release to indri.studio.)*

## Notes / alternatives (rejected)

- **Loader turbo (batch `_bjg_run()` per RAF):** bounded by raw core throughput (~1.37× on laptop,
  possibly <1× on phone → stutter); doesn't fix black-until-done. Superseded by Part A.
- **Bake `mandel-display` like the other demos:** defeats its purpose (the live on-target-compute
  proof + Verify-fidelity story).
- **Lower `DN`/coarser final grid:** changes the CRC, breaks the gate. Off the table.
- **Alternative Part B (if visible build-up is unwanted):** bake the *final* crisp image and hold it
  until the live render reaches full res, then swap — hides the build-up behind the preview. One-line
  change to the baked asset resolution + swap trigger; not chosen (user wants the 4×4-first build-up).
