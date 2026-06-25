| Date | Change |
|------|--------|
| 2026-06-25 `0c1dc94` | scaffold bsnes-jg-wasm: the gate's cycle-accurate SNES core, in the browser |

<!--history-meta v1
0c1dc94	author	Will Norris
0c1dc94	added	82
0c1dc94	deleted	0
0c1dc94	files	1
0c1dc94	body	A WebAssembly build of bsnes-jg (the cycle-accurate core that is the second leg\nof the llvm-mos-65816 differential gate) + a loader page that runs the +mos-a16\nhomebrew demos. The pitch: a browser demo backed by THE SAME core the gate trusts\nis byte-for-byte what was verified — not a snes9x lookalike (snes9x is not\ncycle-accurate and is non-commercial/GPL-incompatible; bsnes-jg is cycle-accurate\nAND GPLv3).\n\nReproducible from repo + network:\n  build.sh        bootstrap emsdk -> clone+pin libretro/bsnes-jg -> build WASM core -> web/cores/\n  web/index.html  EmulatorJS loader (ROM picker + drag-drop; showcase mode works today)\n  serve.py        static server (plain single-thread; --isolated adds COOP/COEP for threaded builds)\n  sync-roms.sh / Taskfile.yml / LICENSE (GPLv3) / NOTICE\n  web/roms/       snapshot of mandel-{zoom,mode7,display,interactive}.sfc\n\nShowcase mode (stock CDN core) serves now (verified: page + ROM 200); accurate\nmode (the built bsnes-jg core, CRC-matched to the gate's jgxcheck) is the headline\nremaining work — see docs/plans/2026-06-25-bsnes-jg-wasm.md + TODO.md.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
