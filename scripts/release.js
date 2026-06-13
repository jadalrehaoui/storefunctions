#!/usr/bin/env node
// Release helper.
// Auto-detects the platform(s) to release from what changed since the last tag
// (shared lib/ change -> both; windows/ or android/ only -> that one), then
// prompts for the bump (patch/minor/major). RELEASE_PLATFORM=windows|android|both
// overrides; a manual menu is the fallback when detection can't decide.
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

// Resolve the commit a tag points at, plus its timestamp (for picking the most
// recent baseline). Returns null if no tag matches the pattern.
function lastTagCommit(pattern) {
  try {
    const tag = execSync(`git describe --tags --abbrev=0 --match ${JSON.stringify(pattern)}`,
      { stdio: ['ignore', 'pipe', 'ignore'] }).toString().trim();
    if (!tag) return null;
    const commit = execSync(`git rev-list -n 1 ${JSON.stringify(tag)}`).toString().trim();
    const ts = parseInt(execSync(`git log -1 --format=%ct ${JSON.stringify(commit)}`).toString().trim(), 10);
    return { tag, commit, ts };
  } catch { return null; }
}

// Auto-detect which platforms changed since the last release.
// Rule: a shared change (lib/, assets/, fonts/, pubspec) affects BOTH apps; a
// change only inside windows/ or android/ targets just that platform. Baseline
// is the most recent of the last windows-v*/android-v* tags. Returns null when
// it can't tell (no prior tags / diff failure) so the caller can prompt.
function detectPlatforms() {
  const candidates = [lastTagCommit('windows-v*'), lastTagCommit('android-v*')].filter(Boolean);
  if (candidates.length === 0) return null;
  const baseline = candidates.sort((a, b) => a.ts - b.ts).pop();
  let files;
  try {
    files = execSync(`git diff --name-only ${JSON.stringify(baseline.commit)}..HEAD`)
      .toString().trim().split('\n').filter(Boolean);
  } catch { return null; }
  const shared = files.some((f) =>
    f.startsWith('lib/') || f.startsWith('assets/') || f.startsWith('fonts/') ||
    f === 'pubspec.yaml' || f === 'pubspec.lock');
  const winNative = files.some((f) => f.startsWith('windows/'));
  const andNative = files.some((f) => f.startsWith('android/'));
  return { baseline, windows: shared || winNative, android: shared || andNative };
}

(async () => {
  // 1) Platform — auto-detected from what changed since the last release.
  // Override anytime with RELEASE_PLATFORM=windows|android|both; falls back to a
  // manual menu when nothing can be detected.
  let releaseAndroid;
  let releaseWindows;
  const forced = (process.env.RELEASE_PLATFORM || '').toLowerCase();
  const detected = forced ? null : detectPlatforms();
  if (['windows', 'android', 'both'].includes(forced)) {
    releaseWindows = forced === 'windows' || forced === 'both';
    releaseAndroid = forced === 'android' || forced === 'both';
    console.log(`\nPlatform forced via RELEASE_PLATFORM=${forced}.`);
  } else if (detected && (detected.windows || detected.android)) {
    releaseWindows = detected.windows;
    releaseAndroid = detected.android;
    const picked = [releaseWindows && 'Windows', releaseAndroid && 'Android'].filter(Boolean).join(' + ');
    console.log(`\nAuto-detected changes since ${detected.baseline.tag} → releasing: ${picked}`);
  } else {
    console.log('\nCould not auto-detect a changed platform — choose manually.');
    console.log('Which platform is being released?');
    console.log('  1) Android');
    console.log('  2) Windows');
    console.log('  3) Both');
    const platChoice = await ask('> ');
    if (!['1', '2', '3'].includes(platChoice)) {
      console.error('Invalid choice.'); process.exit(1);
    }
    releaseAndroid = platChoice === '1' || platChoice === '3';
    releaseWindows = platChoice === '2' || platChoice === '3';
  }

  // 2) Bump kind
  const kindRaw = (await ask('Bump type [patch/minor/major] (patch): ')).toLowerCase() || 'patch';
  if (!['patch', 'minor', 'major'].includes(kindRaw)) {
    console.error('Invalid type.'); process.exit(1);
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

  console.log('\nSummary:');
  for (const p of plan) {
    console.log(`  ${p.platform}: ${p.cur.name}+${p.cur.build} -> ${p.next.name}+${p.next.build}`);
  }
  const tags = plan.map((p) => `${p.platform}-v${p.next.name}`);
  console.log(`Tags: ${tags.join(' ')}`);

  const ok = (await ask('Confirm and publish? [y/N]: ')).toLowerCase();
  if (ok !== 'y' && ok !== 'yes') { console.log('Aborted.'); process.exit(0); }

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
    console.error('! Could not update the DB:', e.message);
    console.error('  Continuing with commit + push anyway.');
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

  console.log(`\nDone. Published: ${tags.join(' ')}`);
})().catch((e) => { console.error(e); process.exit(1); });
