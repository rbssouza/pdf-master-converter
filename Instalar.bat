@echo off
title Instalador PDF Studio - Enterprise
echo Executando instalador com privilegios...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Instalador-PDF.ps1"
pause
