| Date | Change |
|------|--------|
| [2026-07-27](https://github.com/wbniv/bsnes-jg-wasm/commit/85462bc) | app.js: merge the three drifted copies into one canonical player |

<!--history-meta v1
85462bc	author	Will Norris
85462bc	added	160
85462bc	deleted	0
85462bc	files	1
85462bc	body	Base is biohack.net's copy (fullscreen controller, poster clear-to-black).\nTwo deliberate changes on top:\n\n- yoff: KEEP the adaptive 'h >= 232 ? 8 : 0' and supersede aaacbae's yoff=0.\n  Measured per-row on this build (deterministic frames after _bjg_reset):\n  the 512x240 buffer carries content in rows [8,232) — blossom @900 spans\n  8..221, mandel-display @1500 spans 8..232. yoff=0 adds an 8px black band\n  and crops up to 9 content rows off the bottom; aaacbae's 'flush at buffer\n  top' rationale described the headless jgxcheck capture, not this buffer.\n\n- touch nav: the lzss-gallery chevron hit-test is no longer hardcoded to a\n  slug; a ROM opts in via manifest 'touchNav': {left:[x,y,w,h], right:[...]}.\n  Verified live: chevron taps hit, artwork taps stay inert.\n\nThe 'keep both site copies byte-identical' invariant dies here — sites will\nvendor this file via the sync CLI (see docs/plans/2026-07-27-npm-player-package.md).\n\nCo-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>\nClaude-Session: https://claude.ai/code/session_011DEG8ouwAWtqeWtcvZSysz
-->
