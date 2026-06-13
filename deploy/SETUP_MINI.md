# Running the update/download server on the Mac mini

The Storefunctions update server (`server.js`, port **8080**) serves the in-app
"check for update" + install flow. The app already points at the mini's Tailscale
IP `100.113.65.42:8080` (`_deployBaseUrl` in the Flutter settings screen), so once
this is running on the mini **no app change is needed** — the update check and
install command resolve to it automatically.

It runs persistently under **launchd**, the same way the API does (label
`com.jadrehaoui.work-api`). This component's label is
**`com.jadrehaoui.storefunctions-deploy`**.

`server.js` now re-syncs the latest GitHub build every **5 minutes** (plus once at
boot), so new releases are picked up without a restart.

---

## One-time setup on the mini

Run these **once** on the Mac mini (over SSH:
`ssh jadrehaoui@jads-mac-mini.tail2ce668.ts.net`).

### 1. Put the deploy folder at `~/storefunctions-deploy`

Simplest: rsync just the `deploy/` dir from your dev Mac (no git history needed on
the mini for this component). From your **dev Mac**:

```bash
rsync -av --exclude node_modules --exclude .env \
  /Users/jadrehaoui/Desktop/Projects/Parallel/ui/deploy/ \
  jadrehaoui@jads-mac-mini.tail2ce668.ts.net:~/storefunctions-deploy/
```

(Alternatively, sparse-clone the `ui` repo and symlink `deploy/` — but rsync of just
this folder is the least fuss. Re-run the same rsync whenever you change `server.js`,
then restart with the kickstart command below.)

### 2. Create the `.env` (holds a PAT — keep it out of git)

On the **mini**, in `~/storefunctions-deploy/.env`:

```
GITHUB_TOKEN=ghp_your_fine_grained_token_here
GITHUB_REPO=jadalrehaoui/storefunctions
```

The token needs `Actions: read` + `Contents: read` on `jadalrehaoui/storefunctions`
(it downloads build artifacts). **`.env` is already gitignored** (`deploy/.env` in
the `ui` repo's `.gitignore`) — never commit it.

### 3. Install dependencies

```bash
cd ~/storefunctions-deploy
npm install        # deps: dotenv, pg
```

(Node must be at `/usr/local/bin/node` — that's what `start.sh` exec's, matching the
API's start wrapper.)

### 4. Install + load the launchd agent

```bash
cp ~/storefunctions-deploy/com.jadrehaoui.storefunctions-deploy.plist \
   ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.jadrehaoui.storefunctions-deploy.plist
```

Verify it's running (a `0` in the 2nd column = healthy, same convention as the API):

```bash
launchctl list | grep storefunctions-deploy
```

### 5. Confirm it serves

```bash
curl -s http://localhost:8080/api/version?platform=windows
curl -s http://localhost:8080/api/artifacts
```

---

## Operating it

**Logs** (set in the plist):

```bash
tail -f /tmp/storefunctions-deploy.log      # stdout (sync activity, startup)
tail -f /tmp/storefunctions-deploy.err.log  # stderr
```

**Restart** (e.g. after an rsync of new `server.js`):

```bash
launchctl kickstart -k gui/$(id -u)/com.jadrehaoui.storefunctions-deploy
```

**Stop / unload:**

```bash
launchctl unload ~/Library/LaunchAgents/com.jadrehaoui.storefunctions-deploy.plist
```

`KeepAlive` is `true`, so launchd restarts the process automatically if it crashes
or exits.
