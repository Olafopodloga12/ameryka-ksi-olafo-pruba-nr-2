@echo off
title Olafo Killer vs Pierogi
cd /d "%~dp0"
powershell -ExecutionPolicy Bypass -File "%~dp0server.ps1"
pause
