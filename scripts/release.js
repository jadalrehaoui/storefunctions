#!/usr/bin/env node
// Release helper: bumps version in DB + lib/shared/constants.dart, commits, pushes.
// Usage: node scripts/release.js
//
// Requires: npm i pg (run once in repo root, or globally)

const readline = require('readline');
const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');
const { Client } = require('pg');

const DB = {
  host: '100.113.65.42',
  port: 5432,
  user: 'admin',
  password: 'admin',
  database: 'workdb',
};

const CONSTANTS_PATH = path.join(__dirname, '..', 'lib', 'shared', 'constants.dart');
const PUBSPEC_PATH = path.join(__dirname, '..', 'pubspec.yaml');

function ask(q) {
  const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
  return new Promise((resolve) => rl.question(q, (a) => { rl.close(); resolve(a.trim()); }));
}

function bump(version, kind) {
  const [maj, min, pat] = version.split('.').map((n) => parseInt(n, 10));
  if (kind === 'major') return `${maj + 1}.0.0`;
  if (kind === 'minor') return `${maj}.${min + 1}.0`;
  return `${maj}.${min}.${pat + 1}`;
}

(async () => {
  const kindRaw = (await ask('Release type [patch/minor/major] (patch): ')).toLowerCase() || 'patch';
  if (!['patch', 'minor', 'major'].includes(kindRaw)) {
    console.error('Invalid type'); process.exit(1);
  }

  const client = new Client(DB);
  await client.connect();

  const { rows } = await client.query("SELECT value FROM ui_config WHERE name = 'version'");
  if (!rows.length) { console.error("No 'version' row in ui_config"); process.exit(1); }
  const current = rows[0].value;
  const next = bump(current, kindRaw);

  console.log(`\n  current: ${current}`);
  console.log(`  next:    ${next}\n`);
  const ok = (await ask('Proceed? [y/N]: ')).toLowerCase();
  if (ok !== 'y' && ok !== 'yes') { console.log('Aborted.'); process.exit(0); }

  // Update DB
  await client.query("UPDATE ui_config SET value = $1 WHERE name = 'version'", [next]);
  await client.end();
  console.log(`✓ DB updated to ${next}`);

  // Update constants.dart
  let src = fs.readFileSync(CONSTANTS_PATH, 'utf8');
  src = src.replace(/const String appVersion = '[^']+';/, `const String appVersion = '${next}';`);
  fs.writeFileSync(CONSTANTS_PATH, src);
  console.log(`✓ constants.dart updated`);

  // Update pubspec.yaml (keep build number, increment it)
  let pub = fs.readFileSync(PUBSPEC_PATH, 'utf8');
  pub = pub.replace(/^version:\s*([0-9.]+)\+(\d+)/m, (_, _v, build) => `version: ${next}+${parseInt(build, 10) + 1}`);
  fs.writeFileSync(PUBSPEC_PATH, pub);
  console.log(`✓ pubspec.yaml updated`);

  // Git commit + push
  execSync('git add lib/shared/constants.dart pubspec.yaml', { stdio: 'inherit' });
  execSync(`git commit -m "chore: release v${next}"`, { stdio: 'inherit' });
  execSync('git push', { stdio: 'inherit' });
  console.log(`\n✓ Released v${next}`);
})().catch((e) => { console.error(e); process.exit(1); });
