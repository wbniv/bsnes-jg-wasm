// Optional Astro integration: build-time drift guard.
//
// Verifies that the engine vendored into `public/<playDir>` (by `bsnes-jg-player
// sync`) matches the installed package version, using the ENGINE_VERSION stamp the
// CLI writes. It never copies files — explicit sync is the mechanism; this is the
// warning light. Site CI should run `bsnes-jg-player sync --check` as the hard gate.
//
//   import bsnesPlayer from '@wbniv/bsnes-jg-player/integration';
//   export default defineConfig({ integrations: [bsnesPlayer({ playDir: 'play' })] });

import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const pkgRoot = dirname(dirname(fileURLToPath(import.meta.url)));
const pkg = JSON.parse(readFileSync(join(pkgRoot, 'package.json'), 'utf8'));

/**
 * @param {{ playDir?: string, mode?: 'warn' | 'error' }} [options]
 *   playDir: path under public/ the engine was synced to (default 'play').
 *   mode: 'warn' (default) logs; 'error' fails the build on drift.
 */
export default function bsnesPlayer({ playDir = 'play', mode = 'warn' } = {}) {
  return {
    name: '@wbniv/bsnes-jg-player',
    hooks: {
      'astro:config:setup': ({ config, logger }) => {
        const stampPath = join(fileURLToPath(config.publicDir), playDir, 'ENGINE_VERSION');
        let msg = null;
        try {
          const stamp = JSON.parse(readFileSync(stampPath, 'utf8'));
          if (stamp.version !== pkg.version) {
            msg = `public/${playDir}/ENGINE_VERSION (${stamp.version}) != installed package (${pkg.version}). ` +
                  'The served engine predates the one this build was authored against. Run your sync-engine script before deploying.';
          }
        } catch {
          msg = `public/${playDir}/ENGINE_VERSION missing or unreadable — run \`npx bsnes-jg-player sync public/${playDir}\`.`;
        }
        if (!msg) return;
        if (mode === 'error') throw new Error(`[bsnes-jg-player] ${msg}`);
        logger.warn(msg);
      },
    },
  };
}
