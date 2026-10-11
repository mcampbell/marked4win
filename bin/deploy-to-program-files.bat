@echo off
rem Copy build\ to %ProgramFiles%\marked4win. Run as administrator.
rem Usage: bin\deploy-to-program-files.bat [destination]
setlocal

set "SRC=%~dp0..\build"
set "DEST=%~1"
if "%DEST%"=="" set "DEST=%ProgramFiles%\marked4win"

if not exist "%SRC%\marked4win.exe" (
    echo ERROR: "%SRC%\marked4win.exe" not found. Run build.ps1 first.
    exit /b 1
)

net session >nul 2>&1
if errorlevel 1 if "%~1"=="" (
    echo ERROR: Run this from an administrator command prompt.
    exit /b 1
)

rem Remove old assets so deleted files do not stay behind.
if exist "%DEST%\assets" rd /s /q "%DEST%\assets"

xcopy "%SRC%" "%DEST%\" /E /I /Y /Q
if errorlevel 1 (
    echo ERROR: Copy failed. Close marked4win and try again.
    exit /b 1
)

echo Installed to "%DEST%"
