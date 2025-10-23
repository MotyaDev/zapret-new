@echo off
chcp 65001 >nul 2>&1

set "CMD_SCRIPT=%~dp0scripts\service-manager.cmd"

if not exist "%CMD_SCRIPT%" (
    echo Error: Service manager not found at: %CMD_SCRIPT%
    pause
    exit /b 1
)

call "%CMD_SCRIPT%" %*
exit /b %ERRORLEVEL%
