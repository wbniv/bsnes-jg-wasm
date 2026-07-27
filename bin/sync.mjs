#!/usr/bin/env node
// bsnes-jg-player — vendor the packaged SNES player engine into a site's static dir.
//
//   bsnes-jg-player sync <dest>            copy dist/engine/* -> <dest>/ (+ ENGINE_VERSION)
//   bsnes-jg-player sync <dest> --demo     also seed roms/ + preview/ with the demo ROM
//   bsnes-jg-player sync --check <dest>    verify <dest> matches this package byte-for-byte
//   bsnes-jg-player version                print the package version
//
// `sync` never touches <dest>/roms or <dest>/preview (site content) unless --demo.
// `--check` is the anti-drift gate for site CI: exit 1 on any mismatch.
// Zero dependencies; Node >= 20.

import { createHash } from 'node:crypto';
import { cpSync, existsSync, mkdirSync, readFileSync, readdirSync, statSync, writeFileSync } from 'node:fs';
import { dirname, join, relative } from 'node:path';
import { fileURLToPath } from 'node:url';

const pkgRoot = dirname(dirname(fileURLToPath(import.meta.url)));
const pkg = JSON.parse(readFileSync(join(pkgRoot, 'package.json'), 'utf8'));
const engineDir = join(pkgRoot, 'dist', 'engine');
const demoDir = join(pkgRoot, 'dist', 'demo');

function usage(code = 0) {
  console.log(`bsnes-jg-player ${pkg.version} — vendor the SNES player engine into a static dir

usage:
  bsnes-jg-player sync <dest> [--demo]   copy the engine (app.js, cores/*) into <dest>
  bsnes-jg-player sync --check <dest>    verify <dest> matches this package (CI drift gate)
  bsnes-jg-player version                print the package version
  bsnes-jg-player --help                 this text

sync writes <dest>/ENGINE_VERSION (version + per-file sha256) and never touches
<dest>/roms or <dest>/preview unless --demo is given.`);
  process.exit(code);
}

function walk(dir, base = dir) {
  const out = [];
  for (const e of readdirSync(dir, { withFileTypes: true })) {
    const p = join(dir, e.name);
    if (e.isDirectory()) out.push(...walk(p, base));
    else out.push(relative(base, p));
  }
  return out.sort();
}

const sha256 = (p) => createHash('sha256').update(readFileSync(p)).digest('hex');

function engineManifest() {
  return walk(engineDir).map((f) => ({ file: f, sha256: sha256(join(engineDir, f)) }));
}

function doSync(dest, demo) {
  mkdirSync(dest, { recursive: true });
  const files = engineManifest();
  for (const { file } of files) {
    const to = join(dest, file);
    mkdirSync(dirname(to), { recursive: true });
    cpSync(join(engineDir, file), to);
  }
  if (demo) cpSync(demoDir, dest, { recursive: true });
  const stamp = {
    package: pkg.name,
    version: pkg.version,
    synced: files,
  };
  writeFileSync(join(dest, 'ENGINE_VERSION'), JSON.stringify(stamp, null, 2) + '\n');
  console.log(`synced ${pkg.name}@${pkg.version} -> ${dest}`);
  for (const { file, sha256: h } of files) console.log(`  ${file}  ${h.slice(0, 12)}`);
  if (demo) console.log('  + demo ROM (roms/, preview/)');
}

function doCheck(dest) {
  let ok = true;
  const report = (good, msg) => {
    console.log(`${good ? '✓' : '✗'} ${msg}`);
    if (!good) ok = false;
  };
  for (const { file, sha256: want } of engineManifest()) {
    const p = join(dest, file);
    if (!existsSync(p)) { report(false, `${file}  MISSING`); continue; }
    const got = sha256(p);
    report(got === want, `${file}  ${got === want ? `sha256 ${got.slice(0, 12)}… == package` : `sha256 ${got.slice(0, 12)}… != package ${want.slice(0, 12)}…`}`);
  }
  const stampPath = join(dest, 'ENGINE_VERSION');
  if (!existsSync(stampPath)) report(false, 'ENGINE_VERSION  MISSING (run sync)');
  else {
    let v = '?';
    try { v = JSON.parse(readFileSync(stampPath, 'utf8')).version; } catch { /* unparsable counts as drift */ }
    report(v === pkg.version, `ENGINE_VERSION  site has ${v}, installed package is ${pkg.version}`);
  }
  if (!ok) {
    console.error(`\nDRIFT: ${dest} does not match ${pkg.name}@${pkg.version}.`);
    console.error('Fix: run `npx bsnes-jg-player sync <dest>` (or your sync-engine script) and commit the result.');
    process.exit(1);
  }
  console.log(`\n${dest} matches ${pkg.name}@${pkg.version}.`);
}

const args = process.argv.slice(2);
if (!args.length || args.includes('-h') || args.includes('--help')) usage();

const cmd = args.shift();
if (cmd === 'version') { console.log(pkg.version); process.exit(0); }
if (cmd !== 'sync') { console.error(`unknown command: ${cmd}\n`); usage(1); }

const check = args.includes('--check');
const demo = args.includes('--demo');
const rest = args.filter((a) => a !== '--check' && a !== '--demo');
const dest = rest[0];
if (!dest) { console.error('sync: missing <dest>\n'); usage(1); }
if (check && demo) { console.error('sync: --check and --demo are mutually exclusive\n'); usage(1); }

if (check) doCheck(dest);
else doSync(dest, demo);
