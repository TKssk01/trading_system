#Requires -Version 5.1
<#
.SYNOPSIS
    Trading System All Services Startup Script

.DESCRIPTION
    Starts the backend server in a new PowerShell window and
    opens the frontend in a browser.

.EXAMPLE
    .\start_all.ps1
#>

[CmdletBinding()]
param(
    # Number of seconds to wait before automatically opening the browser
    [int]$BrowserDelay = 5,

    # Skip automatic browser launch
    [switch]$NoBrowser
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# --- Resolve project root ---
$ProjectRoot = Split-Path $PSScriptRoot
$BackendScript = Join-Path $PSScriptRoot "start_backend.ps1"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Trading System - Starting All Services" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "[INFO] Project root: $ProjectRoot" -ForegroundColor Gray

# --- Check backend script exists ---
if (-not (Test-Path $BackendScript)) {
    Write-Host "[ERROR] Backend script not found: $BackendScript" -ForegroundColor Red
    exit 1
}

# --- Check for existing processes ---
$existingUvicorn = Get-Process -Name "python", "uvicorn" -ErrorAction SilentlyContinue |
    Where-Object {
        try {
            $cmdLine = (Get-CimInstance Win32_Process -Filter "ProcessId=$($_.Id)" -ErrorAction SilentlyContinue).CommandLine
            $cmdLine -and $cmdLine -match "uvicorn" -and $cmdLine -match "backend\.main"
        } catch { $false }
    }

if ($existingUvicorn) {
    Write-Host "[WARNING] Backend server is already running (PID: $($existingUvicorn.Id -join ', '))" -ForegroundColor Yellow
    Write-Host "          Please stop it using stop_all.ps1 before restarting." -ForegroundColor Yellow
    Write-Host ""

    $response = Read-Host "Continue? (y/N)"
    if ($response -notin @("y", "Y", "yes", "Yes")) {
        Write-Host "[INFO] Startup cancelled." -ForegroundColor Gray
        exit 0
    }
}

# --- Start backend in a new window ---
Write-Host ""
Write-Host "[1/2] Starting backend server..." -ForegroundColor Green

try {
    $backendProcess = Start-Process powershell -ArgumentList @(
        "-NoExit",
        "-ExecutionPolicy", "Bypass",
        "-File", $BackendScript
    ) -PassThru

    Write-Host "      PID: $($backendProcess.Id)" -ForegroundColor Gray
    Write-Host "      Started in a new PowerShell window." -ForegroundColor Gray
}
catch {
    Write-Host "[ERROR] Failed to start backend: $_" -ForegroundColor Red
    exit 1
}

# --- Open browser ---
if (-not $NoBrowser) {
    Write-Host ""
    Write-Host "[2/2] Opening browser..." -ForegroundColor Green
    Write-Host "      Waiting $BrowserDelay seconds for the server to start..." -ForegroundColor Gray

    Start-Sleep -Seconds $BrowserDelay

    $url = "http://localhost:8000"

    # Check server response
    $serverReady = $false
    for ($i = 0; $i -lt 10; $i++) {
        try {
            $null = Invoke-WebRequest -Uri "$url/api/health" -TimeoutSec 2 -UseBasicParsing -ErrorAction Stop
            $serverReady = $true
            break
        }
        catch {
            Write-Host "      Waiting for server response... ($($i + 1)/10)" -ForegroundColor Gray
            Start-Sleep -Seconds 2
        }
    }

    if ($serverReady) {
        Write-Host "      Server is responding. Opening browser." -ForegroundColor Green
        Start-Process $url
    }
    else {
        Write-Host "[WARNING] Server is not responding yet. Please open the browser manually." -ForegroundColor Yellow
        Write-Host "          URL: $url" -ForegroundColor Yellow
    }
}
else {
    Write-Host ""
    Write-Host "[2/2] Automatic browser launch skipped." -ForegroundColor Gray
}

# --- Completion message ---
Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host " Startup Complete" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Backend:      http://localhost:8000" -ForegroundColor White
Write-Host "  Health Check: http://localhost:8000/api/health" -ForegroundColor White
Write-Host ""
Write-Host "  Run stop_all.ps1 to stop all services." -ForegroundColor Gray
Write-Host ""
