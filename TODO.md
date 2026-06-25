# TODO — bsnes-jg-wasm

Plan / contract: [docs/plans/2026-06-25-bsnes-jg-wasm.md](docs/plans/2026-06-25-bsnes-jg-wasm.md).

## Open

### Accurate mode (the headline — same core the gate trusts)

- [ ] **Pin + build the core.** Set `BSNES_JG_PIN` to the llvm-mos-65816 `vendor/bsnes-jg` revision,
  run `task build`, confirm `web/cores/bsnes_jg_libretro.{wasm,js}` + `PROVENANCE.json`.
  (Plan verification step 1.)
- [ ] **Wire the page to the built core.** Resolve EmulatorJS custom-core packaging (or a minimal
  libretro-web loader); make `index.html` boot a demo on the local bsnes-jg core, not the CDN stock
  core. (Plan step 2; the concrete unknown.)
- [ ] **[verify] Fidelity CRC match.** In-browser framebuffer CRC == gate `jgxcheck` CRC
  (`0x9103` for `mandel-display`). The proof of "byte-for-byte the gate's output". (Plan step 3.)
- [ ] **Perf check** — 60 fps on a mid laptop + a phone for the zoom/Mode-7 demos.

### Polish

- [ ] Flip the page banner from "showcase" to "accurate" once the custom core is wired; show
  `PROVENANCE.json` (core commit) in the UI.
- [ ] Confirm `build.sh`'s `MAKE_TARGET` against bsnes-jg's actual libretro Makefile on first run;
  adjust LDFLAGS if it stops at `.bc` instead of emitting `.js`+`.wasm`.
- [ ] Deploy: static host (Cloudflare Pages per the `cloudflare-static-site` skill); single-thread →
  no special headers. Publish GPLv3 source alongside.

### Later (separate)

- [ ] **Showroom** — a demo-reel page consuming this core (curated `+mos-a16` productions). Its own
  effort; this repo just provides the `.wasm`.

## Done

- [x] Scaffolded the repo (2026-06-25): reproducible `build.sh` (emsdk bootstrap → pinned clone →
  WASM), EmulatorJS loader page (ROM picker + drag-drop, showcase mode working), `serve.py`,
  `sync-roms.sh`, `Taskfile.yml`, GPLv3 `LICENSE`+`NOTICE`, bundled demo ROMs, the plan.
