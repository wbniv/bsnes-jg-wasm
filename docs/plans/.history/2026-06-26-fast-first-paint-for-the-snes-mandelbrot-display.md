| Date | Change |
|------|--------|
| 2026-06-26 `b5bacec` | Fast first paint for the mandel-display demo |

<!--history-meta v1
b5bacec	author	Will Norris
b5bacec	added	228
b5bacec	deleted	0
b5bacec	files	1
b5bacec	body	The deployed page force-blanked through mandel-display's full ~1240-frame\non-SNES compute, so the canvas stayed black for seconds before the Mandelbrot\nappeared. Two changes fix that:\n\n- ROM (synced from llvm-mos-65816): renders progressively 4×4 → 8×7 → 16×14 →\n  32×28, so a recognizable image lands fast and sharpens. The final pass is the\n  unchanged canonical buffer, so the fidelity CRC is still 0x9103 — but its WRAM\n  address moved 0x580 → 0x660 (manifest off + frame budget 1000 → 1400 updated).\n\n- Loader: paints a baked 4×4 preview (make-preview.sh, web/preview/) on the\n  canvas before the ~3.9 MB core loads, and holds it until the first non-black\n  live frame, so the SNES boot's force-blank doesn't flash to black. The preview\n  is rendered at the pass-1 grid, so the handoff to live is seamless (no dip).\n\nVerified headless (CDP): self-check 0x9103 @ 0x660 / 1400 frames, first visual\n<0.2 s, monotonic sharpen to crisp, zoom/interactive unaffected. See the plan.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>\nClaude-Session: https://claude.ai/code/session_012z1vSadjiUqKEsQ6dU4u3P
-->
