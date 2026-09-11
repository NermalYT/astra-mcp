@echo off
setlocal
rem Works at the release root or from platform\Windows in a source checkout.
set "astra_root=%~dp0"
if not exist "%astra_root%scripts\install.ps1" set "astra_root=%~dp0..\..\"
if not exist "%astra_root%scripts\install.ps1" (
  echo Extract the complete Astra Windows release before running this launcher.
  set "astra_exit=1"
  goto finish
)
where powershell.exe >nul 2>nul
if errorlevel 1 (
  echo Windows PowerShell is missing. Read START_HERE.md for prerequisites.
  set "astra_exit=1"
  goto finish
)
if "%~1"=="" if not defined ASTRA_NO_GUI (
  powershell.exe -NoLogo -NoProfile -STA -ExecutionPolicy Bypass -File "%astra_root%scripts\setup-gui.ps1"
  exit /b
)
echo Astra for Windows 11 Pro runs inside an initialized Ubuntu LTS WSL2 distribution.
echo Your ordinary Linux user may be asked for its sudo password.
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%astra_root%scripts\install.ps1" -InstallSystemDeps -ReplaceLegacy %*
set "astra_exit=%ERRORLEVEL%"
:finish
if not "%astra_exit%"=="0" echo Astra setup failed. Read the error above and START_HERE.md before retrying.
if not defined ASTRA_NO_PAUSE pause
exit /b %astra_exit%
