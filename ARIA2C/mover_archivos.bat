@echo off
setlocal
:: %3 es la ruta completa del archivo que entrega Aria2
set "FILE_PATH=%3"
set "DEST_BASE=%USERPROFILE%\Downloads\FromAria"

:: Extraer la extensión
for %%i in ("%FILE_PATH%") do set "EXT=%%~xi"

:: Lógica de carpetas por extensión
if /I "%EXT%"==".pdf" set "SUB=Documentos"
if /I "%EXT%"==".mp4" set "SUB=Videos"
if /I "%EXT%"==".mkv" set "SUB=Videos"
if /I "%EXT%"==".zip" set "SUB=Comprimidos"
if /I "%EXT%"==".rar" set "SUB=Comprimidos"
if /I "%EXT%"==".jpg" set "SUB=Imagenes"
if /I "%EXT%"==".png" set "SUB=Imagenes"
if "%SUB%"=="" set "SUB=Otros"

:: Crear subcarpeta y mover el archivo
if not exist "%DEST_BASE%\%SUB%" mkdir "%DEST_BASE%\%SUB%"
move "%FILE_PATH%" "%DEST_BASE%\%SUB%\"

endlocal