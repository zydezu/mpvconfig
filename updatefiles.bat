@echo off
setlocal

REM === Configuration ===
set "REPO_NAME=mpvconfig"
set "BRANCH=main"
set "SCRIPT_DIR=%~dp0"
set "ZIP_PATH=%SCRIPT_DIR%%REPO_NAME%.zip"
set "EXTRACT_DIR=%SCRIPT_DIR%repo_extracted"
set "DOWNLOAD_URL=https://github.com/zydezu/%REPO_NAME%/archive/refs/heads/%BRANCH%.zip"

echo [INFO] Downloading latest files to %ZIP_PATH%...
curl -L -o "%ZIP_PATH%" "%DOWNLOAD_URL%"
if not exist "%ZIP_PATH%" (
    echo [ERROR] ZIP download failed.
    exit /b 1
)

REM === Clean up any previous extraction ===
if exist "%EXTRACT_DIR%" rd /s /q "%EXTRACT_DIR%"

echo [INFO] Extracting files...
powershell -Command "Expand-Archive -Force -Path '%ZIP_PATH%' -DestinationPath '%EXTRACT_DIR%'" >nul 2>&1
if not exist "%EXTRACT_DIR%" (
    echo [ERROR] ZIP extraction failed.
    exit /b 1
)

REM === Locate the extracted subfolder: mpvconfig-main ===
setlocal enabledelayedexpansion
set "SUBFOLDER=%EXTRACT_DIR%\%REPO_NAME%-%BRANCH%"

if exist "!SUBFOLDER!\" (
    echo [INFO] Updating files...
    xcopy "!SUBFOLDER!\*" "%SCRIPT_DIR%" /s /e /y /h /i >nul
) else (
    echo [ERROR] Could not find extracted subfolder: !SUBFOLDER!
    exit /b 1
)
endlocal

REM === Clean up ===
del /f /q "%ZIP_PATH%" >nul
rd /s /q "%EXTRACT_DIR%" >nul

echo [INFO] Update completed successfully.
pause