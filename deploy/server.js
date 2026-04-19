require('dotenv').config({ path: require('path').join(__dirname, '.env') });

const http = require('http');
const fs = require('fs');
const path = require('path');
const { Client: PgClient } = require('pg');

const PORT = 8080;
const PUBLIC_DIR = path.join(__dirname, 'public');
const STATE_FILE = path.join(__dirname, '.artifact-state.json');

function detectLanIp() {
  const nets = require('os').networkInterfaces();
  for (const name of Object.keys(nets)) {
    for (const net of nets[name]) {
      if (net.family === 'IPv4' && !net.internal) return net.address;
    }
  }
  return '127.0.0.1';
}
const SERVER_URL = `http://${detectLanIp()}:${PORT}`;
const TEMPLATED_EXTS = new Set(['.html', '.ps1']);

const GITHUB_TOKEN = process.env.GITHUB_TOKEN;
const GITHUB_REPO = process.env.GITHUB_REPO || 'jadalrehaoui/storefunctions';

const DB = {
  host: '100.113.65.42',
  port: 5432,
  user: 'admin',
  password: 'admin',
  database: 'workdb',
};

// Maps workflow file -> { artifactName, outputFile (in public/) }
const WORKFLOWS = {
  'build-windows.yml': { artifactName: 'storefunctions-windows', outputFile: 'storefunctions-windows.zip' },
  'build-android.yml': { artifactName: 'storefunctions-android', outputFile: 'app-release.apk' },
};

const MIME = {
  '.html': 'text/html; charset=utf-8',
  '.zip':  'application/zip',
  '.apk':  'application/vnd.android.package-archive',
  '.css':  'text/css',
  '.js':   'application/javascript',
  '.json': 'application/json',
};

// ──────────────────────────────────────────────────────────────────────────
// GitHub artifact sync
// ──────────────────────────────────────────────────────────────────────────

function loadState() {
  try { return JSON.parse(fs.readFileSync(STATE_FILE, 'utf8')); } catch { return {}; }
}
function saveState(state) {
  fs.writeFileSync(STATE_FILE, JSON.stringify(state, null, 2));
}

async function gh(url) {
  const res = await fetch(url, {
    headers: {
      Authorization: `Bearer ${GITHUB_TOKEN}`,
      Accept: 'application/vnd.github+json',
      'X-GitHub-Api-Version': '2022-11-28',
    },
  });
  if (!res.ok) throw new Error(`GitHub ${res.status} ${res.statusText} for ${url}`);
  return res;
}

async function downloadArtifact(artifactId, destZipPath) {
  const res = await gh(`https://api.github.com/repos/${GITHUB_REPO}/actions/artifacts/${artifactId}/zip`);
  const buf = Buffer.from(await res.arrayBuffer());
  fs.writeFileSync(destZipPath, buf);
}

// Extract first file from a zip into destPath using system unzip.
function extractFirstFile(zipPath, destPath) {
  const { execSync } = require('child_process');
  const tmpDir = path.join(path.dirname(zipPath), `.unzip-${Date.now()}`);
  fs.mkdirSync(tmpDir, { recursive: true });
  try {
    execSync(`unzip -o "${zipPath}" -d "${tmpDir}"`, { stdio: 'pipe' });
    const files = fs.readdirSync(tmpDir);
    if (!files.length) throw new Error('Empty artifact zip');
    fs.copyFileSync(path.join(tmpDir, files[0]), destPath);
  } finally {
    fs.rmSync(tmpDir, { recursive: true, force: true });
    fs.rmSync(zipPath, { force: true });
  }
}

async function syncWorkflow(workflowFile, cfg, state) {
  const runsRes = await gh(
    `https://api.github.com/repos/${GITHUB_REPO}/actions/workflows/${workflowFile}/runs?branch=main&status=success&per_page=1`
  );
  const runsJson = await runsRes.json();
  const run = runsJson.workflow_runs?.[0];
  if (!run) { console.log(`  ${workflowFile}: no successful runs`); return; }

  const lastRunId = state[workflowFile]?.runId;
  if (lastRunId === run.id) {
    console.log(`  ${workflowFile}: up to date (run ${run.id})`);
    return;
  }

  const artRes = await gh(`https://api.github.com/repos/${GITHUB_REPO}/actions/runs/${run.id}/artifacts`);
  const artJson = await artRes.json();
  const artifact = artJson.artifacts?.find((a) => a.name === cfg.artifactName);
  if (!artifact) { console.log(`  ${workflowFile}: artifact "${cfg.artifactName}" not found`); return; }

  console.log(`  ${workflowFile}: downloading run ${run.id} (artifact ${artifact.id})...`);
  const tmpZip = path.join(PUBLIC_DIR, `.tmp-${cfg.artifactName}.zip`);
  await downloadArtifact(artifact.id, tmpZip);
  extractFirstFile(tmpZip, path.join(PUBLIC_DIR, cfg.outputFile));

  state[workflowFile] = { runId: run.id, updatedAt: new Date().toISOString() };
  console.log(`  ${workflowFile}: ✓ updated -> public/${cfg.outputFile}`);
}

async function syncAllArtifacts() {
  if (!GITHUB_TOKEN) {
    console.log('⚠ GITHUB_TOKEN not set, skipping artifact sync');
    return;
  }
  console.log('Checking for updated artifacts on GitHub...');
  const state = loadState();
  for (const [wf, cfg] of Object.entries(WORKFLOWS)) {
    try {
      await syncWorkflow(wf, cfg, state);
    } catch (e) {
      console.error(`  ${wf}: ERROR ${e.message}`);
    }
  }
  saveState(state);
  console.log('Artifact sync complete.\n');
}

// ──────────────────────────────────────────────────────────────────────────
// HTTP server
// ──────────────────────────────────────────────────────────────────────────

async function getDbVersion() {
  const c = new PgClient(DB);
  await c.connect();
  try {
    const { rows } = await c.query("SELECT value FROM ui_config WHERE name = 'version'");
    return rows[0]?.value || null;
  } finally {
    await c.end();
  }
}

const server = http.createServer(async (req, res) => {
  if (req.url === '/api/version') {
    try {
      const version = await getDbVersion();
      res.writeHead(200, { 'Content-Type': 'application/json' });
      return res.end(JSON.stringify({
        version,
        windows: '/storefunctions-windows.zip',
        android: '/app-release.apk',
      }));
    } catch (e) {
      res.writeHead(500, { 'Content-Type': 'application/json' });
      return res.end(JSON.stringify({ error: e.message }));
    }
  }

  let filePath = req.url === '/' ? '/index.html' : req.url;
  filePath = path.join(PUBLIC_DIR, filePath);

  if (!filePath.startsWith(PUBLIC_DIR)) {
    res.writeHead(403);
    return res.end('Forbidden');
  }

  fs.stat(filePath, (err, stat) => {
    if (err || !stat.isFile()) {
      res.writeHead(404, { 'Content-Type': 'text/plain' });
      return res.end('Not found');
    }
    const ext = path.extname(filePath);
    const contentType = MIME[ext] || 'application/octet-stream';

    if (TEMPLATED_EXTS.has(ext)) {
      const content = fs.readFileSync(filePath, 'utf8')
        .split('{{SERVER_URL}}').join(SERVER_URL);
      const buf = Buffer.from(content, 'utf8');
      res.writeHead(200, {
        'Content-Type': contentType,
        'Content-Length': buf.length,
      });
      return res.end(buf);
    }

    res.writeHead(200, {
      'Content-Type': contentType,
      'Content-Length': stat.size,
      'Content-Disposition': (ext === '.zip' || ext === '.apk')
        ? `attachment; filename="${path.basename(filePath)}"` : '',
    });
    fs.createReadStream(filePath).pipe(res);
  });
});

(async () => {
  await syncAllArtifacts();

  server.listen(PORT, '0.0.0.0', () => {
    const { networkInterfaces } = require('os');
    const nets = networkInterfaces();
    console.log(`\n Storefunctions download server running\n`);
    for (const name of Object.keys(nets)) {
      for (const net of nets[name]) {
        if (net.family === 'IPv4' && !net.internal) {
          console.log(`   http://${net.address}:${PORT}`);
        }
      }
    }
    console.log(`   http://localhost:${PORT}\n`);
  });
})();
