# Storefunctions installer / updater for Windows.
#
# Usage (from an elevated or normal PowerShell — no admin required):
#   iwr https://<deploy-server>/install.ps1 -UseBasicParsing | iex
#
# Or download first and run with overrides:
#   powershell -ExecutionPolicy Bypass -File .\install.ps1 -ServerUrl "http://10.0.0.5:8080"
#
# What it does:
#   1. Figures out the deploy server URL (parameter, env var, or prompt).
#   2. Closes any running storefunctions.exe.
#   3. Downloads /storefunctions-windows.zip into a temp folder.
#   4. Wipes and re-extracts the install folder (%LOCALAPPDATA%\Storefunctions).
#   5. Creates/updates a desktop shortcut named "Storefunctions".
#   6. Shows the new version reported by /api/version.

[CmdletBinding()]
param(
    [string]$ServerUrl = '{{SERVER_URL}}',
    [string]$InstallDir = (Join-Path $env:LOCALAPPDATA "Storefunctions"),
    [string]$ShortcutName = 'Parallel',
    [switch]$NoShortcut,
    [switch]$Launch
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

function Write-Step([string]$msg) {
    Write-Host ""
    Write-Host ">> $msg" -ForegroundColor Cyan
}

function Write-Ok([string]$msg) {
    Write-Host "   $msg" -ForegroundColor Green
}

function Write-Warn2([string]$msg) {
    Write-Host "   $msg" -ForegroundColor Yellow
}

function Fail([string]$msg) {
    Write-Host ""
    Write-Host "X $msg" -ForegroundColor Red
    exit 1
}

# --- 1. Resolve server URL ---------------------------------------------------
# If the placeholder was never replaced (script downloaded raw from git instead
# of through the deploy server), fall back to an interactive prompt.
if (-not $ServerUrl -or $ServerUrl -eq '{{SERVER_URL}}') {
    $ServerUrl = Read-Host "Deploy server URL (e.g. http://10.0.0.5:8080)"
}
$ServerUrl = $ServerUrl.TrimEnd('/')
if ([string]::IsNullOrWhiteSpace($ServerUrl)) {
    Fail "No server URL provided."
}

$ZipUrl = "$ServerUrl/storefunctions-windows.zip"
$VersionUrl = "$ServerUrl/api/version"

Write-Host ""
Write-Host "Storefunctions installer" -ForegroundColor White
Write-Host "========================" -ForegroundColor White
Write-Host "  Server : $ServerUrl"
Write-Host "  Target : $InstallDir"

# --- 2. Stop any running instance -------------------------------------------
Write-Step "Closing running instances"
$running = Get-Process storefunctions -ErrorAction SilentlyContinue
if ($running) {
    $running | Stop-Process -Force
    Start-Sleep -Milliseconds 600
    Write-Ok "Stopped $($running.Count) process(es)."
} else {
    Write-Ok "No running instance found."
}

# --- 3. Download zip ---------------------------------------------------------
Write-Step "Downloading latest zip"
$tempZip = Join-Path $env:TEMP "storefunctions-$([Guid]::NewGuid().ToString('N')).zip"
try {
    Invoke-WebRequest -Uri $ZipUrl -OutFile $tempZip -UseBasicParsing
} catch {
    Fail "Download failed: $($_.Exception.Message)"
}
$sizeMB = [math]::Round((Get-Item $tempZip).Length / 1MB, 1)
Write-Ok "Saved ${sizeMB} MB -> $tempZip"

# --- 4. Replace install folder ----------------------------------------------
Write-Step "Installing to $InstallDir"
if (Test-Path $InstallDir) {
    try {
        Remove-Item -Path $InstallDir -Recurse -Force
    } catch {
        Remove-Item $tempZip -ErrorAction SilentlyContinue
        Fail "Could not remove old install folder. Is the app still running? ($($_.Exception.Message))"
    }
}
New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
Expand-Archive -LiteralPath $tempZip -DestinationPath $InstallDir -Force
Remove-Item $tempZip -ErrorAction SilentlyContinue
Write-Ok "Files extracted."

$exePath = Join-Path $InstallDir "storefunctions.exe"
if (-not (Test-Path $exePath)) {
    Fail "storefunctions.exe not found in the zip. Contents: $(Get-ChildItem $InstallDir | Select-Object -ExpandProperty Name)"
}
Write-Ok "Main binary: $exePath"

# --- 5. Desktop shortcut -----------------------------------------------------
if (-not $NoShortcut) {
    Write-Step "Creating desktop shortcut"
    $desktop = [Environment]::GetFolderPath("Desktop")
    $shortcutPath = Join-Path $desktop "$ShortcutName.lnk"
    $oldShortcut = Join-Path $desktop "Storefunctions.lnk"
    if ($oldShortcut -ne $shortcutPath -and (Test-Path $oldShortcut)) {
        Remove-Item $oldShortcut -Force -ErrorAction SilentlyContinue
    }
    try {
        $wsh = New-Object -ComObject WScript.Shell
        $shortcut = $wsh.CreateShortcut($shortcutPath)
        $shortcut.TargetPath = $exePath
        $shortcut.WorkingDirectory = $InstallDir
        $shortcut.IconLocation = "$exePath,0"
        $shortcut.Description = $ShortcutName
        $shortcut.Save()
        Write-Ok "Shortcut: $shortcutPath"
    } catch {
        Write-Warn2 "Shortcut creation failed: $($_.Exception.Message)"
    }
}

# --- 6. Report version -------------------------------------------------------
Write-Step "Checking reported version"
try {
    $resp = Invoke-RestMethod -Uri $VersionUrl -UseBasicParsing -TimeoutSec 5
    $v = if ($resp.version) { $resp.version } elseif ($resp.value) { $resp.value } else { $null }
    if ($v) {
        Write-Ok "Server reports version: v$v"
    } else {
        Write-Warn2 "Version endpoint did not return a version field."
    }
} catch {
    Write-Warn2 "Could not reach $VersionUrl ($($_.Exception.Message))"
}

Write-Host ""
Write-Host "DONE. Installed at $InstallDir" -ForegroundColor Green

if ($Launch) {
    Write-Host ""
    Write-Host "Launching..." -ForegroundColor Cyan
    Start-Process -FilePath $exePath -WorkingDirectory $InstallDir
}
