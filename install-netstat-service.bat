@echo off
setlocal enabledelayedexpansion

echo ========================================
echo Netstat Service Installer
echo ========================================
echo.

REM Check if running as administrator
net session >nul 2>&1
if %errorLevel% == 0 (
    echo [INFO] Running as administrator - OK
) else (
    echo [ERROR] This script must be run as administrator!
    echo Please right-click and select "Run as administrator"
    pause
    exit /b 1
)

echo.
echo [STEP 1] Creating directory C:\netstat...
if not exist "C:\netstat" (
    mkdir "C:\netstat"
    echo [INFO] Directory C:\netstat created successfully
) else (
    echo [INFO] Directory C:\netstat already exists
)

echo.
echo [STEP 2] Downloading files from GitHub...

REM Download netstat-service.ps1
echo [INFO] Downloading netstat-service.ps1...
powershell.exe -ExecutionPolicy Bypass -Command "try { Invoke-WebRequest -Uri 'https://github.com/navein-kumar/wazuh-Netstat-Powershell/raw/refs/heads/main/netstat-service.ps1' -OutFile 'C:\netstat\netstat-service.ps1' -UseBasicParsing; Write-Host '[SUCCESS] netstat-service.ps1 downloaded successfully' -ForegroundColor Green } catch { Write-Host '[ERROR] Failed to download netstat-service.ps1:' $_.Exception.Message -ForegroundColor Red; exit 1 }"

if %errorLevel% neq 0 (
    echo [ERROR] Failed to download netstat-service.ps1
    pause
    exit /b 1
)

REM Download nssm.exe
echo [INFO] Downloading nssm.exe...
powershell.exe -ExecutionPolicy Bypass -Command "try { Invoke-WebRequest -Uri 'https://github.com/navein-kumar/wazuh-Netstat-Powershell/raw/refs/heads/main/nssm.exe' -OutFile 'C:\netstat\nssm.exe' -UseBasicParsing; Write-Host '[SUCCESS] nssm.exe downloaded successfully' -ForegroundColor Green } catch { Write-Host '[ERROR] Failed to download nssm.exe:' $_.Exception.Message -ForegroundColor Red; exit 1 }"

if %errorLevel% neq 0 (
    echo [ERROR] Failed to download nssm.exe
    pause
    exit /b 1
)

echo.
echo [STEP 3] Verifying downloaded files...
if exist "C:\netstat\netstat-service.ps1" (
    echo [INFO] netstat-service.ps1 - OK
) else (
    echo [ERROR] netstat-service.ps1 not found!
    pause
    exit /b 1
)

if exist "C:\netstat\nssm.exe" (
    echo [INFO] nssm.exe - OK
) else (
    echo [ERROR] nssm.exe not found!
    pause
    exit /b 1
)

echo.
echo [STEP 4] Checking if NetstatService already exists...
sc query NetstatService >nul 2>&1
if %errorLevel% == 0 (
    echo [INFO] NetstatService already exists. Removing existing service...
    cd /d C:\netstat
    .\nssm.exe stop NetstatService >nul 2>&1
    .\nssm.exe remove NetstatService confirm >nul 2>&1
    echo [INFO] Existing service removed
)

echo.
echo [STEP 5] Installing NetstatService using NSSM...
cd /d C:\netstat

echo [INFO] Installing service...
.\nssm.exe install NetstatService powershell.exe "-ExecutionPolicy Bypass -File C:\netstat\netstat-service.ps1"
if %errorLevel% neq 0 (
    echo [ERROR] Failed to install NetstatService
    pause
    exit /b 1
)

echo [INFO] Setting service display name...
.\nssm.exe set NetstatService DisplayName "Network Monitor Service"

echo [INFO] Setting service description...
.\nssm.exe set NetstatService Description "Monitors network connections for Wazuh"

echo [INFO] Setting service to auto-start...
.\nssm.exe set NetstatService Start SERVICE_AUTO_START

echo.
echo [STEP 6] Starting NetstatService...
.\nssm.exe start NetstatService
if %errorLevel% neq 0 (
    echo [ERROR] Failed to start NetstatService
    pause
    exit /b 1
)

echo.
echo [STEP 7] Verifying service status...
timeout /t 3 /nobreak >nul
sc query NetstatService

echo.
echo ========================================
echo Installation completed successfully!
echo ========================================
echo.
echo Service Details:
echo - Name: NetstatService
echo - Display Name: Network Monitor Service
echo - Description: Monitors network connections for Wazuh
echo - Startup Type: Automatic
echo - Script Location: C:\netstat\netstat-service.ps1
echo.
echo To manage the service:
echo - Start:   nssm start NetstatService
echo - Stop:    nssm stop NetstatService
echo - Remove:  nssm remove NetstatService confirm
echo.

pause
