@echo off
setlocal
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File "%~dp0Show-RoutePilotDashboard.ps1"
if errorlevel 1 (
    echo.
    echo The RoutePilot dashboard could not start. Review the error above.
    pause
)
exit /b %ERRORLEVEL%
