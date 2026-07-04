@echo off
:: Se posiciona en la carpeta del script
cd /d "%~dp0"

:: Crear archivo de sesión si no existe (evita error al arrancar)
if not exist aria2.session type nul > aria2.session

:: Definir y crear carpeta de destino en Windows
set "FINAL_PATH=%USERPROFILE%\Downloads\FromAria"
if not exist "%FINAL_PATH%" mkdir "%FINAL_PATH%"

echo Iniciando Aria2 en modo Servidor...
aria2c.exe --conf-path=aria2.conf --dir="%FINAL_PATH%"
pause