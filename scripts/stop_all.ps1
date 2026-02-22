#Requires -Version 5.1
<#
.SYNOPSIS
    Trading System All Services Stop Script

.DESCRIPTION
    Detects and stops uvicorn/python processes related to the Trading System.

.EXAMPLE
    .\stop_all.ps1

.EXAMPLE
    .\stop_all.ps1 -Force
    Force stop without confirmation prompt.
#>

[CmdletBinding()]
param(
    # Skip confirmation prompt
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# --- Resolve project root ---
$ProjectRoot = Split-Path (Split-Path $PSScriptRoot)

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Trading System - Stopping All Services" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# --- Search for Trading System related processes ---
Write-Host "[INFO] Searching for Trading System related processes..." -ForegroundColor Gray

$targetProcesses = @()

# Get python / uvicorn processes and determine if they are related to Trading System by command line
$pythonProcesses = Get-Process -Name "python", "python3", "uvicorn" -ErrorAction SilentlyContinue

foreach ($proc in $pythonProcesses) {
    try {
        $cimProc = Get-CimInstance Win32_Process -Filter "ProcessId=$($proc.Id)" -ErrorAction SilentlyContinue
        if (-not $cimProc) { continue }

        $cmdLine = $cimProc.CommandLine
        if (-not $cmdLine) { continue }

        # Target processes containing uvicorn backend.main:app,
        # or processes containing the project root path
        $isTarget = $false

        if ($cmdLine -match "uvicorn" -and $cmdLine -match "backend\.main") {
            $isTarget = $true
        }

        if ($cmdLine -match [regex]::Escape($ProjectRoot)) {
            $isTarget = $true
        }

        if ($isTarget) {
            $targetProcesses += [PSCustomObject]@{
                PID         = $proc.Id
                Name        = $proc.ProcessName
                CommandLine = $cmdLine
            }
        }
    }
    catch {
        # Skip processes that cannot be accessed
        continue
    }
}

# --- Display results ---
if ($targetProcesses.Count -eq 0) {
    Write-Host ""
    Write-Host "[INFO] No Trading System related processes found." -ForegroundColor Green
    Write-Host ""
    exit 0
}

Write-Host ""
Write-Host "[FOUND] $($targetProcesses.Count) related process(es) found:" -ForegroundColor Yellow
Write-Host ""

foreach ($tp in $targetProcesses) {
    # Truncate command line for display
    $shortCmd = $tp.CommandLine
    if ($shortCmd.Length -gt 100) {
        $shortCmd = $shortCmd.Substring(0, 97) + "..."
    }
    Write-Host "  PID: $($tp.PID)  Name: $($tp.Name)" -ForegroundColor White
    Write-Host "  Command: $shortCmd" -ForegroundColor Gray
    Write-Host ""
}

# --- Confirm stop ---
if (-not $Force) {
    $response = Read-Host "Stop the above process(es)? (y/N)"
    if ($response -notin @("y", "Y", "yes", "Yes")) {
        Write-Host "[INFO] Stop cancelled." -ForegroundColor Gray
        exit 0
    }
}

# --- Stop processes ---
Write-Host ""
$stoppedCount = 0
$failedCount = 0

foreach ($tp in $targetProcesses) {
    try {
        Write-Host "[STOPPING] PID $($tp.PID) ($($tp.Name))..." -ForegroundColor Yellow -NoNewline

        # First attempt graceful stop (equivalent to SIGTERM)
        $process = Get-Process -Id $tp.PID -ErrorAction SilentlyContinue
        if ($process) {
            $process.CloseMainWindow() | Out-Null
            # Wait 3 seconds
            if (-not $process.WaitForExit(3000)) {
                # Force kill if graceful stop failed
                Stop-Process -Id $tp.PID -Force -ErrorAction Stop
            }
        }

        Write-Host " Done" -ForegroundColor Green
        $stoppedCount++
    }
    catch {
        # Process may have already exited
        if (-not (Get-Process -Id $tp.PID -ErrorAction SilentlyContinue)) {
            Write-Host " (Already exited)" -ForegroundColor Gray
            $stoppedCount++
        }
        else {
            Write-Host " Failed: $_" -ForegroundColor Red
            $failedCount++
        }
    }
}

# --- Completion message ---
Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host " Stop Complete" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Stopped: $stoppedCount process(es)" -ForegroundColor White

if ($failedCount -gt 0) {
    Write-Host "  Failed:  $failedCount process(es)" -ForegroundColor Red
    Write-Host ""
    Write-Host "  Please re-run with administrator privileges:" -ForegroundColor Yellow
    Write-Host "    Start-Process powershell -Verb RunAs -ArgumentList '-File', '$PSCommandPath', '-Force'" -ForegroundColor Yellow
}

Write-Host ""
