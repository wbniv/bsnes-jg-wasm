// @wbniv/bsnes-jg-player — package entry for Astro consumers.
//
//   import SnesPlayer from '@wbniv/bsnes-jg-player/SnesPlayer.astro';
//   import bsnesPlayer from '@wbniv/bsnes-jg-player/integration';
//   import '@wbniv/bsnes-jg-player/css';
//
// The engine itself is vendored into public/ with the `bsnes-jg-player` CLI —
// this module only re-exports the build-time pieces.
export { default as integration } from './integration.mjs';
export const SNES_PLAYER_COMPONENT = '@wbniv/bsnes-jg-player/SnesPlayer.astro';
