#!/usr/bin/env node
// Release helper.
// Prompts: 1) platform (Android / Windows / Both), 2) bump (patch/minor/major).
// Bumps the chosen platform version file(s), updates lib/shared/constants.dart,
// updates DB rows version_android / version_windows, increments pubspec build
// number, commits, creates platform tag(s) (android-vX.Y.Z, windows-vX.Y.Z),
// and pushes branch + tags atomically.
//
// Inner pushes use --no-verify so the pre-push hook that invoked this script
// doesn't recurse on the bumped commit.

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

const ROOT = path.join(__dirname, '..');
const CONSTANTS_PATH = path.join(ROOT, 'lib', 'shared', 'constants.dart');
const PUBSPEC_PATH = path.join(ROOT, 'pubspec.yaml');
const ANDROID_VERSION_FILE = path.join(ROOT, 'release', 'android.version');
const WINDOWS_VERSION_FILE = path.join(ROOT, 'release', 'windows.version');

function ask(q) {
  const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
  return new Promise((resolve) => rl.question(q, (a) => { rl.close(); resolve(a.trim()); }));
}

function bumpName(version, kind) {
  const [maj, min, pat] = version.split('.').map((n) => parseInt(n, 10));
  if (kind === 'major') return `${maj + 1}.0.0`;
  if (kind === 'minor') return `${maj}.${min + 1}.0`;
  return `${maj}.${min}.${pat + 1}`;
}

function readVersionFile(p) {
  const raw = fs.readFileSync(p, 'utf8').trim();
  const [name, build] = raw.split('+');
  return { name, build: parseInt(build, 10) };
}

function writeVersionFile(p, name, build) {
  fs.writeFileSync(p, `${name}+${build}\n`);
}

function updateConstant(platform, version) {
  const constName = platform === 'android' ? 'appVersionAndroid' : 'appVersionWindows';
  let src = fs.readFileSync(CONSTANTS_PATH, 'utf8');
  const re = new RegExp(`const String ${constName} = '[^']+';`);
  if (!re.test(src)) {
    throw new Error(`Could not find ${constName} in constants.dart`);
  }
  src = src.replace(re, `const String ${constName} = '${version}';`);
  fs.writeFileSync(CONSTANTS_PATH, src);
}

function bumpPubspecBuild(toName) {
  // Single pubspec version: name = the just-released version, build = +1.
  let pub = fs.readFileSync(PUBSPEC_PATH, 'utf8');
  pub = pub.replace(/^version:\s*([0-9.]+)\+(\d+)/m,
    (_, _name, build) => `version: ${toName}+${parseInt(build, 10) + 1}`);
  fs.writeFileSync(PUBSPEC_PATH, pub);
}

async function upsertDbVersion(client, key, value) {
  const { rowCount } = await client.query(
    "UPDATE ui_config SET value = $1 WHERE name = $2",
    [value, key],
  );
  if (rowCount === 0) {
    await client.query(
      "INSERT INTO ui_config (name, value) VALUES ($1, $2)",
      [key, value],
    );
  }
}

(async () => {
  // 1) Platform
  console.log('\n¿Qué plataforma se publica?');
  console.log('  1) Android');
  console.log('  2) Windows');
  console.log('  3) Both');
  const platChoice = await ask('› ');
  if (!['1', '2', '3'].includes(platChoice)) {
    console.error('Opción inválida.'); process.exit(1);
  }
  const releaseAndroid = platChoice === '1' || platChoice === '3';
  const releaseWindows = platChoice === '2' || platChoice === '3';

  // 2) Bump kind
  const kindRaw = (await ask('Tipo de bump [patch/minor/major] (patch): ')).toLowerCase() || 'patch';
  if (!['patch', 'minor', 'major'].includes(kindRaw)) {
    console.error('Tipo inválido.'); process.exit(1);
  }

  // Compute next versions
  const plan = [];
  if (releaseAndroid) {
    const cur = readVersionFile(ANDROID_VERSION_FILE);
    const next = { name: bumpName(cur.name, kindRaw), build: cur.build + 1 };
    plan.push({ platform: 'android', file: ANDROID_VERSION_FILE, cur, next });
  }
  if (releaseWindows) {
    const cur = readVersionFile(WINDOWS_VERSION_FILE);
    const next = { name: bumpName(cur.name, kindRaw), build: cur.build + 1 };
    plan.push({ platform: 'windows', file: WINDOWS_VERSION_FILE, cur, next });
  }

  console.log('\nResumen:');
  for (const p of plan) {
    console.log(`  ${p.platform}: ${p.cur.name}+${p.cur.build} → ${p.next.name}+${p.next.build}`);
  }
  const tags = plan.map((p) => `${p.platform}-v${p.next.name}`);
  console.log(`Tags: ${tags.join(' ')}`);

  const ok = (await ask('¿Confirmar y publicar? [y/N]: ')).toLowerCase();
  if (ok !== 'y' && ok !== 'yes') { console.log('Abortado.'); process.exit(0); }

  // Update files
  for (const p of plan) {
    writeVersionFile(p.file, p.next.name, p.next.build);
    updateConstant(p.platform, p.next.name);
    console.log(`✓ ${p.platform}.version + constants.dart updated to ${p.next.name}`);
  }

  // pubspec.yaml: keep one source of truth. Use the highest just-released
  // name; bump the build number once per release.
  const latestName = plan
    .map((p) => p.next.name)
    .sort((a, b) => {
      const sa = a.split('.').map(Number); const sb = b.split('.').map(Number);
      for (let i = 0; i < 3; i++) if (sa[i] !== sb[i]) return sa[i] - sb[i];
      return 0;
    })
    .pop();
  bumpPubspecBuild(latestName);
  console.log(`✓ pubspec.yaml updated (name=${latestName}, build incremented)`);

  // DB
  try {
    const client = new Client(DB);
    await client.connect();
    for (const p of plan) {
      await upsertDbVersion(client, `version_${p.platform}`, p.next.name);
      console.log(`✓ DB ui_config.version_${p.platform} = ${p.next.name}`);
    }
    await client.end();
  } catch (e) {
    console.error('⚠ No se pudo actualizar la DB:', e.message);
    console.error('  Continuando con commit + push de todas formas.');
  }

  // Git
  const trackedFiles = [
    'lib/shared/constants.dart',
    'pubspec.yaml',
    ...plan.map((p) => path.relative(ROOT, p.file)),
  ];
  execSync(`git add ${trackedFiles.map((f) => JSON.stringify(f)).join(' ')}`, { stdio: 'inherit' });
  const commitMsg = `chore: release ${tags.join(' ')}`;
  execSync(`git commit -m ${JSON.stringify(commitMsg)}`, { stdio: 'inherit' });
  for (const tag of tags) {
    execSync(`git tag -a ${tag} -m ${JSON.stringify(commitMsg)}`, { stdio: 'inherit' });
  }

  // Push branch + tags atomically. --no-verify so we don't recurse into pre-push.
  const refs = ['HEAD', ...tags.map((t) => `refs/tags/${t}`)];
  execSync(`git push --no-verify --atomic origin ${refs.join(' ')}`, { stdio: 'inherit' });

  console.log(`\n✓ Publicado: ${tags.join(' ')}`);
})().catch((e) => { console.error(e); process.exit(1); });
