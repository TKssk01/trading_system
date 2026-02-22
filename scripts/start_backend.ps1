#Requires -Version 5.1
<#
.SYNOPSIS
    Trading System Backend Server Startup Script (PowerShell)

.DESCRIPTION
    Activates the Python virtual environment and starts the backend server with uvicorn.

.EXAMPLE
    .\start_backend.ps1
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# --- Resolve project root ---
$ProjectRoot = Split-Path $PSScriptRoot

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Trading System - Starting Backend" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "[INFO] Project root: $ProjectRoot" -ForegroundColor Gray

# --- Check Python virtual environment ---
$VenvActivate = Join-Path $ProjectRoot "backend\.venv\Scripts\Activate.ps1"

if (-not (Test-Path $VenvActivate)) {
    Write-Host ""
    Write-Host "[ERROR] Virtual environment not found: $VenvActivate" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please create the virtual environment with the following commands:" -ForegroundColor Yellow
    Write-Host "  cd `"$ProjectRoot\backend`"" -ForegroundColor Yellow
    Write-Host "  python -m venv .venv" -ForegroundColor Yellow
    Write-Host "  .\.venv\Scripts\Activate.ps1" -ForegroundColor Yellow
    Write-Host "  pip install -r requirements.txt" -ForegroundColor Yellow
    Write-Host ""
    exit 1
}

# --- Check .env file ---
$EnvFile = Join-Path $ProjectRoot "backend\.env"
if (-not (Test-Path $EnvFile)) {
    Write-Host "[WARNING] backend\.env file not found." -ForegroundColor Yellow
    Write-Host "          Starting with default settings." -ForegroundColor Yellow
    Write-Host "          It is recommended to create a .env file using create_env.ps1." -ForegroundColor Yellow
    Write-Host ""
}

# --- Activate virtual environment ---
Write-Host "[INFO] Activating virtual environment..." -ForegroundColor Gray
try {
    & $VenvActivate
}
catch {
    Write-Host "[ERROR] Failed to activate virtual environment: $_" -ForegroundColor Red
    exit 1
}

# --- Set working directory to project root ---
Set-Location $ProjectRoot
Write-Host "[INFO] Working directory: $(Get-Location)" -ForegroundColor Gray

# --- Start backend with uvicorn ---
Write-Host ""
Write-Host "[INFO] Starting uvicorn server..." -ForegroundColor Green
Write-Host "[INFO] URL: http://localhost:8000" -ForegroundColor Green
Write-Host "[INFO] Press Ctrl+C to stop" -ForegroundColor Gray
Write-Host ""

try {
    python -m uvicorn backend.main:app --host 0.0.0.0 --port 8000 --reload
}
catch {
    Write-Host ""
    Write-Host "[ERROR] Failed to start uvicorn: $_" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please ensure the dependencies in requirements.txt are installed:" -ForegroundColor Yellow
    Write-Host "  pip install -r backend\requirements.txt" -ForegroundColor Yellow
    Write-Host ""
    exit 1
}
