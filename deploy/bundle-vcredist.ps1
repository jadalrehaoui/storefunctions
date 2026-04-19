# Copies the Microsoft Visual C++ runtime DLLs (vcruntime140.dll,
# vcruntime140_1.dll, msvcp140.dll, etc.) into the Flutter Windows Release
# folder so the app can run on machines that don't have the VC++
# Redistributable installed.
#
# Microsoft explicitly allows redistributing these DLLs alongside an app
# ("app-local deployment").
#
# Called from build.bat (local builds) and the GitHub Actions workflow.

param(
    [Parameter(Mandatory=$true)]
    [string]$ReleaseDir
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $ReleaseDir)) {
    throw "Release dir not found: $ReleaseDir"
}

# Find the newest VC CRT redist folder across any VS installation (any year,
# any edition — Community / Professional / Enterprise / BuildTools).
$pattern = 'C:\Program Files*\Microsoft Visual Studio\*\*\VC\Redist\MSVC\*\x64\Microsoft.VC*.CRT'
$redist = Get-ChildItem $pattern -Directory -ErrorAction SilentlyContinue |
    Sort-Object -Property @{ Expression = { [version]$_.Parent.Parent.Name } } |
    Select-Object -Last 1

if (-not $redist) {
    Write-Warning "VC++ Redist folder not found. Runtime DLLs will NOT be bundled."
    Write-Warning "Install 'Desktop development with C++' workload in Visual Studio to get them."
    exit 0
}

Write-Host "Bundling VC++ runtime from: $($redist.FullName)"
Copy-Item "$($redist.FullName)\*.dll" $ReleaseDir -Force

Get-ChildItem "$ReleaseDir\*.dll" |
    Where-Object { $_.Name -match '^(msvcp|vcruntime|concrt)' } |
    ForEach-Object { Write-Host "  + $($_.Name)" }
