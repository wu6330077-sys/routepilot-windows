@echo off
setlocal
cd /d "%~dp0"

echo RoutePilot beginner setup is starting...
echo Keep both local HTTP proxies running, then answer the prompts.
echo.

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Setup-RoutePilot.ps1"
set "ROUTEPILOT_EXIT=%ERRORLEVEL%"

echo.
if not "%ROUTEPILOT_EXIT%"=="0" (
    echo Setup stopped with exit code %ROUTEPILOT_EXIT%.
    echo Read the message above, fix the reported item, and run this file again.
) else (
    echo Setup finished. Restart Microsoft Edge if the policy was installed.
)
echo.
pause
exit /b %ROUTEPILOT_EXIT%
