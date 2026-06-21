# =============================================
# Script: Instalar PSeInt Portable (CON ACTUALIZACION)
# Ubicacion: Poner este script en "00- INSTALLS"
# Destino: Instala en la carpeta SUPERIOR (..)
# =============================================

# Obtener la carpeta DONDE esta este script
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# La carpeta SUPERIOR (un nivel arriba) - RELATIVO
$parentDir = Split-Path -Parent $scriptDir

# Instalacion portable en la carpeta SUPERIOR
$installDir = Join-Path $parentDir "PSeInt"

# Directorios temporales
$tempDir = Join-Path $env:TEMP "PSeInt_Install"
$downloadedFile = Join-Path $tempDir "pseint-portable.zip"

# URL base para detectar la ultima version en SourceForge
$apiUrl = "https://sourceforge.net/projects/pseint/rss?path=/current"

# Archivo para guardar la version actual instalada
$versionFile = Join-Path $installDir "pseint_version.txt"

# Limpiar pantalla
Clear-Host

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "      PSEINT PORTABLE - INSTALADOR" -ForegroundColor Cyan
Write-Host "         (CON ACTUALIZACION)" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# =============================================
# FUNCION: Obtener ultima version disponible
# =============================================
function Get-LatestPSeIntVersion {
    Write-Host "  [INFO] Buscando ultima version de PSeInt..." -ForegroundColor Cyan
    
    try {
        # Consultar el RSS de SourceForge para ver los archivos recientes en /current
        $rss = Invoke-WebRequest -Uri $apiUrl -UseBasicParsing -ErrorAction Stop
        $xml = [xml]$rss.Content
        
        # Buscar el item que corresponda al zip portable de Windows de 64 bits
        # El formato suele ser pseint-w64-<fecha>.zip
        $items = $xml.rss.channel.item | Where-Object { $_.title -match "pseint-w64-.*\.zip" }
        
        if ($items) {
            # Seleccionar el mas reciente si hay varios
            $latestItem = $items[0]
            # Extraer la fecha/version del titulo (ej: "20240122" de "pseint-w64-20240122.zip")
            if ($latestItem.title -match 'pseint-w64-(\d+)\.zip') {
                $latestVersion = $Matches[1]
                $downloadUrl = $latestItem.link
                
                Write-Host "  [OK] Ultima version disponible: $latestVersion" -ForegroundColor Green
                return @{ version = $latestVersion; url = $downloadUrl }
            }
        }
        
        Write-Host "  [ERROR] No se pudo detectar el patron de version en SourceForge" -ForegroundColor Red
        return $null
    } catch {
        Write-Host "  [ERROR] No se pudo conectar a SourceForge" -ForegroundColor Red
        Write-Host "  Verifica tu conexion a internet" -ForegroundColor Yellow
        return $null
    }
}

# =============================================
# FUNCION: Obtener version instalada
# =============================================
function Get-InstalledPSeIntVersion {
    if (Test-Path $versionFile) {
        $version = Get-Content $versionFile -Raw -ErrorAction SilentlyContinue
        if ($version) {
            $version = $version.Trim()
            Write-Host "  [INFO] Version instalada: $version" -ForegroundColor Green
            return $version
        }
    }
    
    # Si no hay archivo de version, intentar detectar por la fecha del ejecutable principal
    $exeFile = Get-ChildItem -Path $installDir -Filter "pseint.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($exeFile -and (Test-Path $exeFile.FullName)) {
        try {
            $versionInfo = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($exeFile.FullName)
            if ($versionInfo.ProductVersion) {
                Write-Host "  [INFO] Version instalada (detectada): $($versionInfo.ProductVersion)" -ForegroundColor Green
                return $versionInfo.ProductVersion
            }
        } catch {}
    }
    
    Write-Host "  [INFO] No se encontro instalacion previa" -ForegroundColor Yellow
    return $null
}

# =============================================
# FUNCION: Version mas nueva?
# =============================================
function Is-NewerVersion {
    param(
        [string]$currentVersion,
        [string]$latestVersion
    )
    
    if (-not $currentVersion) { return $true }
    
    # Al usar formato de fechas numÃ©ricas (YYYYMMDD), una simple comparaciÃ³n de enteros o strings basta
    if ([bool]($latestVersion -as [int]) -and [bool]($currentVersion -as [int])) {
        return ([int]$latestVersion -gt [int]$currentVersion)
    }
    
    return $latestVersion -ne $currentVersion
}

# =============================================
# FUNCION: Respaldar configuracion
# =============================================
function Backup-PSeIntConfig {
    param([string]$backupPath)
    
    Write-Host "  Respaldando perfiles y configuraciones..." -ForegroundColor Gray
    
    # PSeInt portable guarda configuraciones en la misma carpeta raÃ­z o subcarpetas de perfiles
    # Respaldamos archivos de extensiones clave (.cfg, .dat, .txt personalizados)
    $backedUp = $false
    
    if (Test-Path $installDir) {
        $configFiles = Get-ChildItem -Path $installDir -Include "*.cfg", "*.dat" -Recurse -ErrorAction SilentlyContinue
        foreach ($file in $configFiles) {
            # Mantener la estructura relativa en el respaldo
            $relativeDir = $file.DirectoryName.Replace($installDir, "")
            $targetDir = Join-Path $backupPath $relativeDir
            if (-not (Test-Path $targetDir)) { New-Item -ItemType Directory -Path $targetDir -Force | Out-Null }
            
            Copy-Item -Path $file.FullName -Destination (Join-Path $targetDir $file.Name) -Force -ErrorAction SilentlyContinue
            $backedUp = $true
        }
    }
    
    if ($backedUp) {
        Write-Host "  [OK] Configuracion y perfiles respaldados" -ForegroundColor Green
    } else {
        Write-Host "  [INFO] No se encontro configuracion previa para respaldar" -ForegroundColor Gray
    }
    
    return $backedUp
}

# =============================================
# FUNCION: Restaurar configuracion
# =============================================
function Restore-PSeIntConfig {
    param([string]$backupPath)
    
    if (-not (Test-Path $backupPath)) { return }
    
    Write-Host "  Restaurando configuracion..." -ForegroundColor Gray
    
    try {
        # Copiar recursivamente todo lo respaldado de vuelta a la carpeta limpia
        Copy-Item -Path "$backupPath\*" -Destination $installDir -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "  [OK] Configuracion restaurada con exito" -ForegroundColor Green
    } catch {
        Write-Host "  [AVISO] Hubo problemas restaurando algunos archivos de configuracion" -ForegroundColor Yellow
    }
}

# =============================================
# FUNCION: Descargar PSeInt
# =============================================
function Download-PSeInt {
    param(
        [string]$version,
        [string]$url
    )
    
    Write-Host ""
    Write-Host "  Descargando PSeInt $version..." -ForegroundColor Cyan
    Write-Host "  Desde: $url" -ForegroundColor Gray
    
    try {
        # Forzar TLS 1.2 por si las moscas con SourceForge
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $url -OutFile $downloadedFile -UseBasicParsing -ErrorAction Stop
        Write-Host "  [OK] Descarga completada" -ForegroundColor Green
        return $true
    } catch {
        Write-Host "  [ERROR] No se pudo descargar PSeInt $version" -ForegroundColor Red
        return $false
    }
}

# =============================================
# FUNCION: Instalar PSeInt (CORREGIDA)
# =============================================
function Install-PSeInt {
    param([string]$version)
    
    Write-Host ""
    Write-Host "  Instalando PSeInt $version..." -ForegroundColor Cyan
    
    # Crear directorio de instalacion si no existe
    New-Item -ItemType Directory -Path $installDir -Force | Out-Null
    
    # Extraer ZIP
    Write-Host "  Extrayendo archivos..." -ForegroundColor Gray
    try {
        # Intentar con el metodo nativo clasico
        Expand-Archive -Path $downloadedFile -DestinationPath $installDir -Force -ErrorAction Stop
    } catch {
        try {
            # Metodo alternativo si el nativo falla
            Write-Host "  [AVISO] Reintentando extracción con motor alternativo..." -ForegroundColor Yellow
            $shell = New-Object -ComObject Shell.Application
            $zipFolder = $shell.NameSpace($downloadedFile)
            $destFolder = $shell.NameSpace($installDir)
            $destFolder.CopyHere($zipFolder.Items(), 0x14)
            Start-Sleep -Seconds 2 # Darle un momento al sistema para terminar de copiar
        } catch {
            Write-Host "  [ERROR] No se pudo extraer el archivo ZIP de ninguna forma" -ForegroundColor Red
            return $false
        }
    }
    
    # REORGANIZACIÓN CORREGIDA: 
    # Si por alguna razon se extrajo dentro de una subcarpeta "pseint", la acomodamos. 
    # Si los archivos ya estan sueltos en la raiz, no hace nada dañino.
    $subFolder = Join-Path $installDir "pseint"
    if (Test-Path $subFolder) {
        Write-Host "  Reorganizando estructura desde subcarpeta..." -ForegroundColor Gray
        Get-ChildItem -Path $subFolder | ForEach-Object {
            $destino = Join-Path $installDir $_.Name
            Move-Item -Path $_.FullName -Destination $destino -Force -ErrorAction SilentlyContinue
        }
        Remove-Item -Path $subFolder -Force -Recurse -ErrorAction SilentlyContinue
    }
    
    # Guardar archivo de version
    $version | Out-File -FilePath $versionFile -Encoding UTF8 -Force
    
    Write-Host "  [OK] Instalacion completada" -ForegroundColor Green
    return $true
}

# =============================================
# VERIFICAR ESTRUCTURA DE CARPETAS
# =============================================
$folderName = Split-Path $scriptDir -Leaf
if ($folderName -ne "00- INSTALLS") {
    Write-Host "  [AVISO] Este script deberia estar en una carpeta llamada '00- INSTALLS'" -ForegroundColor Yellow
    Write-Host "  Carpeta actual: $folderName" -ForegroundColor Yellow
    $response = Read-Host "  Continuar de todos modos? (S/N)"
    if ($response.ToUpper() -ne "S") {
        exit 0
    }
}

# =============================================
# DETECTAR VERSIONES
# =============================================
Write-Host "  ESTRUCTURA:" -ForegroundColor Yellow
Write-Host "    $parentDir\" -ForegroundColor Gray
Write-Host "      +-- PSeInt\              <- SE INSTALARA AQUI" -ForegroundColor Green
Write-Host "      +-- 00- INSTALLS\" -ForegroundColor Gray
Write-Host "           +-- PSEINT.ps1" -ForegroundColor Gray
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Obtener versiones remota
$remoteData = Get-LatestPSeIntVersion
if ($remoteData) {
    $latestVersion = $remoteData.version
    $downloadUrl = $remoteData.url
} else {
    Write-Host "  No se pudo obtener la ultima version. Usando ultima conocida de respaldo..." -ForegroundColor Yellow
    $latestVersion = "20240122"
    $downloadUrl = "https://downloads.sourceforge.net/project/pseint/current/pseint-w64-$latestVersion.zip"
}

$installedVersion = Get-InstalledPSeIntVersion
$needsUpdate = Is-NewerVersion -currentVersion $installedVersion -latestVersion $latestVersion

# =============================================
# DECIDIR SI ACTUALIZAR
# =============================================
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
if ($installedVersion) {
    if ($needsUpdate) {
        Write-Host "  NUEVA VERSION DISPONIBLE!" -ForegroundColor Green
        Write-Host "  Instalada: $installedVersion -> Nueva: $latestVersion" -ForegroundColor Yellow
    } else {
        Write-Host "  YA ESTAS ACTUALIZADO!" -ForegroundColor Green
        Write-Host "  Version instalada: $installedVersion (es la ultima)" -ForegroundColor Gray
    }
} else {
    Write-Host "  INSTALACION NUEVA" -ForegroundColor Green
    Write-Host "  Version a instalar: $latestVersion" -ForegroundColor Yellow
}
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

if (-not $needsUpdate) {
    Write-Host "  PSeInt ya esta actualizado. No es necesario hacer nada." -ForegroundColor Green
    Write-Host ""
    $openNow = Read-Host "Abrir PSeInt ahora? (S/N)"
    if ($openNow.ToUpper() -eq "S") {
        $exeFile = Get-ChildItem -Path $installDir -Filter "pseint.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($exeFile) {
            Start-Process -FilePath $exeFile.FullName
        }
    }
    Write-Host ""
    Write-Host "Presiona cualquier tecla para salir..."
    pause
    exit 0
}

# =============================================
# PREGUNTAR ANTES DE ACTUALIZAR
# =============================================
if ($installedVersion) {
    Write-Host "  Se actualizara de $installedVersion a $latestVersion" -ForegroundColor Cyan
    $response = Read-Host "  Continuar con la actualizacion? (S/N)"
    if ($response.ToUpper() -ne "S") {
        Write-Host "  Actualizacion cancelada." -ForegroundColor Red
        pause
        exit 0
    }
} else {
    Write-Host "  Se instalara PSeInt $latestVersion" -ForegroundColor Cyan
    $response = Read-Host "  Continuar? (S/N)"
    if ($response.ToUpper() -ne "S") {
        Write-Host "  Instalacion cancelada." -ForegroundColor Red
        pause
        exit 0
    }
}

# =============================================
# REALIZAR RESPALDO (si existe instalacion previa)
# =============================================
$backupFolder = $null
if ($installedVersion -and (Test-Path $installDir)) {
    $backupFolder = Join-Path $env:TEMP "PSeInt_Backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    New-Item -ItemType Directory -Path $backupFolder -Force | Out-Null
    Backup-PSeIntConfig -backupPath $backupFolder
    
    Write-Host ""
    Write-Host "  Eliminando version anterior..." -ForegroundColor Yellow
    Remove-Item -Path $installDir -Recurse -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1
}

# =============================================
# CREAR DIRECTORIO TEMPORAL
# =============================================
Write-Host ""
Write-Host "  Preparando instalacion..." -ForegroundColor Cyan
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

# =============================================
# DESCARGAR E INSTALAR
# =============================================
if (Download-PSeInt -version $latestVersion -url $downloadUrl) {
    $installSuccess = Install-PSeInt -version $latestVersion
    
    if ($installSuccess -and $backupFolder -and (Test-Path $backupFolder)) {
        Restore-PSeIntConfig -backupPath $backupFolder
        # Limpiar respaldo temporal
        Remove-Item -Path $backupFolder -Recurse -Force -ErrorAction SilentlyContinue
    }
} else {
    Write-Host ""
    Write-Host "  [ERROR] Fallo la descarga. Instalacion cancelada." -ForegroundColor Red
    if ($backupFolder -and (Test-Path $backupFolder)) {
        Remove-Item -Path $backupFolder -Recurse -Force -ErrorAction SilentlyContinue
    }
    pause
    exit 1
}

# =============================================
# CREAR ACCESOS DIRECTOS
# =============================================
Write-Host ""
Write-Host "  Creando accesos directos..." -ForegroundColor Cyan

$exeFile = Get-ChildItem -Path $installDir -Filter "pseint.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1

if ($exeFile -and (Test-Path $exeFile.FullName)) {
    # Acceso directo en el escritorio
    $desktopLink = Join-Path ([Environment]::GetFolderPath("Desktop")) "PSeInt Portable.lnk"
    
    $wsShell = New-Object -ComObject WScript.Shell
    $shortcut = $wsShell.CreateShortcut($desktopLink)
    $shortcut.TargetPath = $exeFile.FullName
    $shortcut.WorkingDirectory = $exeFile.DirectoryName
    $shortcut.IconLocation = $exeFile.FullName
    $shortcut.Save()
    Write-Host "  [OK] Acceso directo en escritorio" -ForegroundColor Green
    
    # Acceso directo en la carpeta SUPERIOR
    $parentLink = Join-Path $parentDir "PSeInt Portable.lnk"
    $shortcut2 = $wsShell.CreateShortcut($parentLink)
    $shortcut2.TargetPath = $exeFile.FullName
    $shortcut2.WorkingDirectory = $exeFile.DirectoryName
    $shortcut2.IconLocation = $exeFile.FullName
    $shortcut2.Save()
    Write-Host "  [OK] Acceso directo en: $parentDir" -ForegroundColor Green
}

# =============================================
# CREAR SCRIPT EJECUTOR (.bat)
# =============================================
$runnerScript = @'
@echo off
title PSeInt Portable
cd /d "%~dp0PSeInt"
if exist pseint.exe (
    start "" "pseint.exe" %*
) else (
    echo ERROR: No se encuentra pseint.exe
    echo.
    for /f "delims=" %%i in ('dir /s /b pseint.exe 2^>nul') do (
        start "" "%%i" %*
        exit /b
    )
    echo No se encontro pseint.exe
    pause
)
'@

$runnerPath = Join-Path $parentDir "Ejecutar PSeInt.bat"
$runnerScript | Out-File -FilePath $runnerPath -Encoding ASCII
Write-Host "  [OK] Script ejecutor: Ejecutar PSeInt.bat" -ForegroundColor Green

# =============================================
# LIMPIEZA
# =============================================
Write-Host ""
Write-Host "  Limpiando archivos temporales..." -ForegroundColor Cyan
try {
    Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "  [OK] Temporales eliminados" -ForegroundColor Green
} catch {
    Write-Host "  [AVISO] No se pudo eliminar: $tempDir" -ForegroundColor Yellow
}

# =============================================
# VERIFICACION FINAL
# =============================================
Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "        PSEINT PORTABLE INSTALADO!" -ForegroundColor Green
if ($installedVersion) {
    Write-Host "     ACTUALIZADO: $installedVersion -> $latestVersion" -ForegroundColor Yellow
} else {
    Write-Host "     VERSION (Compilacion): $latestVersion" -ForegroundColor Yellow
}
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "  UBICACION:" -ForegroundColor Yellow
Write-Host "    $installDir" -ForegroundColor White
Write-Host ""
Write-Host "  FORMAS DE ABRIR:" -ForegroundColor Yellow
Write-Host "    1. Acceso directo en el escritorio" -ForegroundColor White
Write-Host "    2. Acceso directo en: $parentDir" -ForegroundColor White
Write-Host "    3. Ejecutar PSeInt.bat" -ForegroundColor White
Write-Host ""
Write-Host "  MANTENIMIENTO:" -ForegroundColor Green
Write-Host "    - Vuelve a ejecutar este script si deseas buscar actualizaciones futuras." -ForegroundColor White
Write-Host "    - Se mantienen intactos tus esquemas de color y configuraciones." -ForegroundColor White
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan

$openNow = Read-Host "Abrir PSeInt ahora? (S/N)"
if ($openNow.ToUpper() -eq "S") {
    if ($exeFile -and (Test-Path $exeFile.FullName)) {
        Write-Host "  Abriendo PSeInt..." -ForegroundColor Gray
        Start-Process -FilePath $exeFile.FullName
    }
}

Write-Host ""
Write-Host "Presiona cualquier tecla para salir..."
pause
