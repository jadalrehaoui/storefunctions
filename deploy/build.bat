@echo off
echo Building Storefunctions for Windows...

cd /d "%~dp0.."

flutter build windows --release
if %ERRORLEVEL% neq 0 (
    echo Build failed.
    pause
    exit /b 1
)

echo Packaging...

set RELEASE_DIR=build\windows\x64\runner\Release
set OUT_DIR=deploy\public
set ZIP_NAME=storefunctions.zip

if not exist "%OUT_DIR%" mkdir "%OUT_DIR%"

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0bundle-vcredist.ps1" -ReleaseDir "%RELEASE_DIR%"
if %ERRORLEVEL% neq 0 (
    echo VC++ runtime bundling failed.
    pause
    exit /b 1
)

powershell -Command "Compress-Archive -Path '%RELEASE_DIR%\*' -DestinationPath '%OUT_DIR%\%ZIP_NAME%' -Force"

echo Done. File saved to %OUT_DIR%\%ZIP_NAME%
pause
