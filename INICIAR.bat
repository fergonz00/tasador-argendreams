@echo off
title Tasador ArgenDreams - Servidor local
cd /d %~dp0
echo.
echo  ============================================
echo   Tasador ArgenDreams - servidor local
echo  ============================================
echo.
echo  Abriendo http://localhost:8000 en el navegador...
echo  NO CIERRES ESTA VENTANA mientras uses la app.
echo  Para detener: cerra esta ventana o apreta Ctrl+C.
echo.
start "" http://localhost:8000
python -m http.server 8000
pause
