@echo off
setlocal

REM === Restrict script location ===
set "EXPECTED_DIR=%APPDATA%\mpv"
set "SCRIPT_DIR=%~dp0"
REM Remove trailing backslash if present
if "%SCRIPT_DIR:~-1%"=="\" set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"

if /i not "%SCRIPT_DIR%"=="%EXPECTED_DIR%" (
    echo [ERROR] This script can only be run from: %EXPECTED_DIR%
    pause
    exit /b 1
)

REM === Configuration ===
set "REPO_NAME=mpvconfig"
set "BRANCH=main"
set "ZIP_PATH=%SCRIPT_DIR%\%REPO_NAME%.zip"
set "EXTRACT_DIR=%SCRIPT_DIR%\repo_extracted"
set "DOWNLOAD_URL=https://github.com/zydezu/%REPO_NAME%/archive/refs/heads/%BRANCH%.zip"

REM === Delete all files and folders except this script (move to Recycle Bin) ===
echo [INFO] Moving existing files to Recycle Bin...

REM Move folders to Recycle Bin
for /d %%D in ("%SCRIPT_DIR%\*") do (
    if /i not "%%~nxD"=="%~nx0" powershell -Command "Remove-Item -LiteralPath '%%D' -Recurse -Confirm:$false -ErrorAction SilentlyContinue -Force -Verbose | Out-Null; [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteDirectory('%%D', 'OnlyErrorDialogs', 'SendToRecycleBin')"
)

REM Move files to Recycle Bin
for %%F in ("%SCRIPT_DIR%\*") do (
    if /i not "%%~nxF"=="%~nx0" powershell -Command "[Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile('%%F', 'OnlyErrorDialogs', 'SendToRecycleBin')"
)

REM === Download ===
echo [INFO] Downloading latest files to %ZIP_PATH%...
curl -L -o "%ZIP_PATH%" "%DOWNLOAD_URL%"
if not exist "%ZIP_PATH%" (
    echo [ERROR] ZIP download failed.
    exit /b 1
)

REM === Clean up any previous extraction ===
if exist "%EXTRACT_DIR%" powershell -Command "[Microsoft.VisualBasic.FileIO.FileSystem]::DeleteDirectory('%EXTRACT_DIR%', 'OnlyErrorDialogs', 'SendToRecycleBin')"

echo [INFO] Extracting files...
powershell -Command "Expand-Archive -Force -Path '%ZIP_PATH%' -DestinationPath '%EXTRACT_DIR%'" >nul 2>&1
if not exist "%EXTRACT_DIR%" (
    echo [ERROR] ZIP extraction failed.
    exit /b 1
)

REM === Locate extracted folder ===
setlocal enabledelayedexpansion
set "SUBFOLDER=%EXTRACT_DIR%\%REPO_NAME%-%BRANCH%"

if exist "!SUBFOLDER!\" (
    echo [INFO] Updating files...
    xcopy "!SUBFOLDER!\*" "%SCRIPT_DIR%\" /s /e /y /h /i >nul
) else (
    echo [ERROR] Could not find extracted subfolder: !SUBFOLDER!
    exit /b 1
)
endlocal

REM === Clean up ===
powershell -Command "[Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile('%ZIP_PATH%', 'OnlyErrorDialogs', 'SendToRecycleBin')"
powershell -Command "[Microsoft.VisualBasic.FileIO.FileSystem]::DeleteDirectory('%EXTRACT_DIR%', 'OnlyErrorDialogs', 'SendToRecycleBin')"

echo [INFO] Update completed successfully.
pause
