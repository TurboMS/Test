@echo off
REM Dubbelklicka for att lagga upp/uppdatera Lagertest Utrullning pa GitHub Pages.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0deploy-lagertest.ps1"
echo.
pause
