# Plans — bsnes-jg-wasm

*Index of the plans in this directory — one row per `*.md`, oldest → newest by the commit that first
introduced it, with a one-sentence summary, the commit(s) that touched it, and a category. Summaries are
**auto-generated** (Sonnet) — refine as needed; the shared `check-plan-index.sh` drift hook flags missing
rows on commit.*

**Categories:** `Feature` · `Fix` · `Investigation` · `Tooling` · `Docs` · `Infra` · `Platform`.

| Plan | Summary | Commit(s) | Category |
|---|---|---|---|
| [Plan — `bsnes-jg-wasm`: ship the gate's cycle-accurate core to the browser](2026-06-25-bsnes-jg-wasm.md) | Compile bsnes-jg 2.1.0 to WebAssembly and wire a minimal loader page for SNES homebrew ROMs. | `0c1dc94`, `66bc05d` | Platform |
| [Fast first paint for the SNES Mandelbrot display](2026-06-26-fast-first-paint-for-the-snes-mandelbrot-display.md) | Add progressive coarse-to-fine render passes and a baked canvas preview to cut mandel-display first-paint below 0.1 s. | `b5bacec`, `2092512` | Feature |
| [bsnes-jg player → reusable npm package + biohack.net migration](2026-07-27-npm-player-package.md) | Merge the three drifted app.js copies, ship the player as the @wbniv/bsnes-jg-player npm package (sync CLI + Astro component + embed), and migrate biohack.net to one dynamic route over a content collection. | [`85462bc`](https://github.com/wbniv/bsnes-jg-wasm/commit/85462bc) | Platform |

---

## How this index was derived

- **Order** = each plan's *creation* commit (oldest commit that touched the file), by committer date.
- **Commit(s)** = the full `git log --follow` set per plan, oldest → newest.
- **Summaries / categories** auto-generated from each plan's TL;DR (Sonnet, medium effort) — refine as needed.
- **Generated** 2026-06-26 for 2 plan(s); updated 2026-07-27 for 3 plan(s).
