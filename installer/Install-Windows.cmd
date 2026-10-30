@echo off
setlocal
chcp 65001 >nul
set PYTHONUTF8=1
cd /d "%~dp0"
where py >nul 2>nul
if errorlevel 1 (
  python install.py %*
) else (
  py -3 install.py %*
)
if errorlevel 1 (
  echo.
  echo Python 3.11+ is required. See INSTALL.md / INSTALL.pt-BR.md.
  pause
)
endlocal
