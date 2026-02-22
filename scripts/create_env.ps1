#Requires -Version 5.1
<#
.SYNOPSIS
    Trading System Environment Configuration File (.env) Creation Script

.DESCRIPTION
    Creates the backend/.env file interactively.
    Passwords are entered as SecureString and are not displayed on screen.
    If an existing .env file is found, its values are loaded as defaults.

.EXAMPLE
    .\create_env.ps1

.EXAMPLE
    .\create_env.ps1 -Overwrite
    Overwrite the existing .env file without confirmation.
#>

[CmdletBinding()]
param(
    # Overwrite without confirmation
    [switch]$Overwrite
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# --- Resolve project root ---
$ProjectRoot = Split-Path (Split-Path $PSScriptRoot)
$EnvFile = Join-Path $ProjectRoot "backend\.env"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Trading System - Create Environment Configuration File" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "[INFO] Output path: $EnvFile" -ForegroundColor Gray
Write-Host ""

# --- Load existing .env file ---
$existingValues = @{}

if (Test-Path $EnvFile) {
    Write-Host "[INFO] Existing .env file detected." -ForegroundColor Yellow

    # Load existing values (used as defaults)
    foreach ($line in (Get-Content $EnvFile)) {
        $line = $line.Trim()
        if ($line -eq "" -or $line.StartsWith("#") -or -not $line.Contains("=")) {
            continue
        }
        $parts = $line -split "=", 2
        $key = $parts[0].Trim()
        $value = $parts[1].Trim().Trim('"').Trim("'")
        $existingValues[$key] = $value
    }

    if (-not $Overwrite) {
        $response = Read-Host "Overwrite the existing .env file? (y/N)"
        if ($response -notin @("y", "Y", "yes", "Yes")) {
            Write-Host "[INFO] Creation cancelled." -ForegroundColor Gray
            exit 0
        }
    }
    Write-Host ""
}

# --- Define default values ---
# Use existing values as defaults if available
function Get-Default {
    param(
        [string]$Key,
        [string]$FallbackDefault
    )
    if ($existingValues.ContainsKey($Key) -and $existingValues[$Key] -ne "") {
        return $existingValues[$Key]
    }
    return $FallbackDefault
}

# --- Interactive input ---
Write-Host "--- Authentication (passwords are hidden during input) ---" -ForegroundColor Magenta
Write-Host ""

# API Password
$hasExistingApiPw = $existingValues.ContainsKey("TS_API_PASSWORD") -and $existingValues["TS_API_PASSWORD"] -ne ""
if ($hasExistingApiPw) {
    Write-Host "[INFO] API password is already set." -ForegroundColor Gray
    $changeApiPw = Read-Host "  Change API password? (y/N)"
}

if (-not $hasExistingApiPw -or $changeApiPw -in @("y", "Y", "yes", "Yes")) {
    $secureApiPw = Read-Host "  API Password (TS_API_PASSWORD)" -AsSecureString
    $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureApiPw)
    $apiPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)

    if ($apiPassword -eq "") {
        Write-Host "  [WARNING] API password is empty. Please set it later." -ForegroundColor Yellow
    }
}
else {
    $apiPassword = $existingValues["TS_API_PASSWORD"]
}

# Order Password
$hasExistingOrderPw = $existingValues.ContainsKey("TS_ORDER_PASSWORD") -and $existingValues["TS_ORDER_PASSWORD"] -ne ""
if ($hasExistingOrderPw) {
    Write-Host "[INFO] Order password is already set." -ForegroundColor Gray
    $changeOrderPw = Read-Host "  Change order password? (y/N)"
}

if (-not $hasExistingOrderPw -or $changeOrderPw -in @("y", "Y", "yes", "Yes")) {
    $secureOrderPw = Read-Host "  Order Password (TS_ORDER_PASSWORD)" -AsSecureString
    $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureOrderPw)
    $orderPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)

    if ($orderPassword -eq "") {
        Write-Host "  [WARNING] Order password is empty. Please set it later." -ForegroundColor Yellow
    }
}
else {
    $orderPassword = $existingValues["TS_ORDER_PASSWORD"]
}

Write-Host ""
Write-Host "--- General Settings (press Enter to use default values) ---" -ForegroundColor Magenta
Write-Host ""

# API Base URL
$defaultApiUrl = Get-Default "TS_API_BASE_URL" "http://localhost:18080/kabusapi"
$inputApiUrl = Read-Host "  API Base URL [$defaultApiUrl]"
$apiBaseUrl = if ($inputApiUrl -ne "") { $inputApiUrl } else { $defaultApiUrl }

# Symbol Code
$defaultSymbol = Get-Default "TS_SYMBOL" "1579"
$inputSymbol = Read-Host "  Symbol Code [$defaultSymbol]"
$symbol = if ($inputSymbol -ne "") { $inputSymbol } else { $defaultSymbol }

# Exchange
$defaultExchange = Get-Default "TS_EXCHANGE" "1"
$inputExchange = Read-Host "  Exchange (1=TSE, 3=NSE, 5=FSE, 6=SSE) [$defaultExchange]"
$exchange = if ($inputExchange -ne "") { $inputExchange } else { $defaultExchange }

# Sleep Interval
$defaultSleep = Get-Default "TS_SLEEP_INTERVAL" "0.3"
$inputSleep = Read-Host "  Sleep Interval (seconds) [$defaultSleep]"
$sleepInterval = if ($inputSleep -ne "") { $inputSleep } else { $defaultSleep }

# Force Close Time
$defaultCloseTime = Get-Default "TS_FORCE_CLOSE_TIME" "14:55"
$inputCloseTime = Read-Host "  Force Close Time (HH:MM) [$defaultCloseTime]"
$forceCloseTime = if ($inputCloseTime -ne "") { $inputCloseTime } else { $defaultCloseTime }

# Max Daily Loss
$defaultMaxLoss = Get-Default "TS_MAX_DAILY_LOSS" "1.0"
$inputMaxLoss = Read-Host "  Max Daily Loss Rate (%) [$defaultMaxLoss]"
$maxDailyLoss = if ($inputMaxLoss -ne "") { $inputMaxLoss } else { $defaultMaxLoss }

# --- Confirmation display ---
Write-Host ""
Write-Host "--- Confirm Settings ---" -ForegroundColor Magenta
Write-Host ""
Write-Host "  TS_API_BASE_URL    = $apiBaseUrl"
Write-Host "  TS_API_PASSWORD    = ********" -ForegroundColor DarkGray
Write-Host "  TS_ORDER_PASSWORD  = ********" -ForegroundColor DarkGray
Write-Host "  TS_SYMBOL          = $symbol"
Write-Host "  TS_EXCHANGE        = $exchange"
Write-Host "  TS_SLEEP_INTERVAL  = $sleepInterval"
Write-Host "  TS_FORCE_CLOSE_TIME = $forceCloseTime"
Write-Host "  TS_MAX_DAILY_LOSS  = $maxDailyLoss"
Write-Host ""

$confirm = Read-Host "Create the .env file with these settings? (Y/n)"
if ($confirm -in @("n", "N", "no", "No")) {
    Write-Host "[INFO] Creation cancelled. Please run the script again." -ForegroundColor Gray
    exit 0
}

# --- Write .env file ---
Write-Host ""
Write-Host "[INFO] Writing .env file..." -ForegroundColor Gray

$envContent = @"
# Trading System Environment Configuration File
# Auto-generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
#
# This file contains sensitive information.
# Do not commit it to Git.

# --- Authentication ---
TS_API_PASSWORD=$apiPassword
TS_ORDER_PASSWORD=$orderPassword

# --- API Settings ---
TS_API_BASE_URL=$apiBaseUrl

# --- Trading Settings ---
TS_SYMBOL=$symbol
TS_EXCHANGE=$exchange
TS_SLEEP_INTERVAL=$sleepInterval
TS_FORCE_CLOSE_TIME=$forceCloseTime
TS_MAX_DAILY_LOSS=$maxDailyLoss
"@

try {
    # Check backend directory exists
    $backendDir = Join-Path $ProjectRoot "backend"
    if (-not (Test-Path $backendDir)) {
        Write-Host "[ERROR] Backend directory not found: $backendDir" -ForegroundColor Red
        exit 1
    }

    # Write file (UTF-8 without BOM)
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($EnvFile, $envContent, $utf8NoBom)

    Write-Host "[DONE] .env file created: $EnvFile" -ForegroundColor Green
}
catch {
    Write-Host "[ERROR] Failed to write .env file: $_" -ForegroundColor Red
    exit 1
}

# --- Restrict file permissions ---
Write-Host "[INFO] Restricting file permissions..." -ForegroundColor Gray

try {
    # Restrict access to current user only
    $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    $acl = Get-Acl $EnvFile

    # Disable inheritance and remove existing ACEs
    $acl.SetAccessRuleProtection($true, $false)

    # Grant full control to current user
    $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
        $currentUser,
        "FullControl",
        "Allow"
    )
    $acl.SetAccessRule($rule)
    Set-Acl -Path $EnvFile -AclObject $acl

    Write-Host "[DONE] Access restricted to current user ($currentUser) only." -ForegroundColor Green
}
catch {
    # Fall back to icacls if ACL setting fails
    Write-Host "[WARNING] Failed to set ACL. Retrying with icacls..." -ForegroundColor Yellow
    try {
        $null = icacls $EnvFile /inheritance:r /grant "${env:USERNAME}:F" 2>&1
        Write-Host "[DONE] File permissions restricted using icacls." -ForegroundColor Green
    }
    catch {
        Write-Host "[WARNING] Failed to restrict file permissions. Please set them manually." -ForegroundColor Yellow
        Write-Host "          icacls `"$EnvFile`" /inheritance:r /grant `"${env:USERNAME}:F`"" -ForegroundColor Yellow
    }
}

# --- Check .gitignore ---
$gitignorePath = Join-Path $ProjectRoot ".gitignore"
$envRelativePath = "backend/.env"

if (Test-Path $gitignorePath) {
    $gitignoreContent = Get-Content $gitignorePath -Raw
    if ($gitignoreContent -notmatch [regex]::Escape($envRelativePath) -and
        $gitignoreContent -notmatch "\.env") {
        Write-Host ""
        Write-Host "[WARNING] .gitignore does not include .env." -ForegroundColor Yellow
        Write-Host "          It is strongly recommended to add the following to .gitignore:" -ForegroundColor Yellow
        Write-Host "            $envRelativePath" -ForegroundColor Yellow
    }
}
else {
    Write-Host ""
    Write-Host "[WARNING] .gitignore file not found." -ForegroundColor Yellow
    Write-Host "          Please ensure the .env file is not committed to Git." -ForegroundColor Yellow
}

# --- Completion message ---
Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host " Environment Configuration File Created Successfully" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "  You can start the server with" -ForegroundColor White
Write-Host "  start_backend.ps1 or start_all.ps1." -ForegroundColor White
Write-Host ""
