#Requires -Version 5.1
<#
.SYNOPSIS
    Trading System 全サービス起動スクリプト

.DESCRIPTION
    バックエンドサーバーを新しい PowerShell ウィンドウで起動し、
    ブラウザでフロントエンドを開きます。

.EXAMPLE
    .\start_all.ps1
#>

[CmdletBinding()]
param(
    # ブラウザを自動で開くまでの待機秒数
    [int]$BrowserDelay = 5,

    # ブラウザの自動起動をスキップ
    [switch]$NoBrowser
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# --- プロジェクトルートを解決 ---
$ProjectRoot = Split-Path (Split-Path $PSScriptRoot)
$BackendScript = Join-Path $PSScriptRoot "start_backend.ps1"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Trading System - 全サービス起動" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "[情報] プロジェクトルート: $ProjectRoot" -ForegroundColor Gray

# --- バックエンドスクリプトの存在確認 ---
if (-not (Test-Path $BackendScript)) {
    Write-Host "[エラー] バックエンドスクリプトが見つかりません: $BackendScript" -ForegroundColor Red
    exit 1
}

# --- 既存プロセスの確認 ---
$existingUvicorn = Get-Process -Name "python", "uvicorn" -ErrorAction SilentlyContinue |
    Where-Object {
        try {
            $cmdLine = (Get-CimInstance Win32_Process -Filter "ProcessId=$($_.Id)" -ErrorAction SilentlyContinue).CommandLine
            $cmdLine -and $cmdLine -match "uvicorn" -and $cmdLine -match "backend\.main"
        } catch { $false }
    }

if ($existingUvicorn) {
    Write-Host "[警告] バックエンドサーバーが既に起動しています (PID: $($existingUvicorn.Id -join ', '))" -ForegroundColor Yellow
    Write-Host "       stop_all.ps1 で停止してから再起動してください。" -ForegroundColor Yellow
    Write-Host ""

    $response = Read-Host "続行しますか? (y/N)"
    if ($response -notin @("y", "Y", "yes", "Yes")) {
        Write-Host "[情報] 起動をキャンセルしました。" -ForegroundColor Gray
        exit 0
    }
}

# --- バックエンドを新しいウィンドウで起動 ---
Write-Host ""
Write-Host "[1/2] バックエンドサーバーを起動中..." -ForegroundColor Green

try {
    $backendProcess = Start-Process powershell -ArgumentList @(
        "-NoExit",
        "-ExecutionPolicy", "Bypass",
        "-File", $BackendScript
    ) -PassThru

    Write-Host "      PID: $($backendProcess.Id)" -ForegroundColor Gray
    Write-Host "      新しい PowerShell ウィンドウで起動しました。" -ForegroundColor Gray
}
catch {
    Write-Host "[エラー] バックエンドの起動に失敗しました: $_" -ForegroundColor Red
    exit 1
}

# --- ブラウザを開く ---
if (-not $NoBrowser) {
    Write-Host ""
    Write-Host "[2/2] ブラウザを起動中..." -ForegroundColor Green
    Write-Host "      サーバーの起動を $BrowserDelay 秒待機します..." -ForegroundColor Gray

    Start-Sleep -Seconds $BrowserDelay

    $url = "http://localhost:8000"

    # サーバーの応答を確認
    $serverReady = $false
    for ($i = 0; $i -lt 10; $i++) {
        try {
            $null = Invoke-WebRequest -Uri "$url/api/health" -TimeoutSec 2 -UseBasicParsing -ErrorAction Stop
            $serverReady = $true
            break
        }
        catch {
            Write-Host "      サーバー応答待ち... ($($i + 1)/10)" -ForegroundColor Gray
            Start-Sleep -Seconds 2
        }
    }

    if ($serverReady) {
        Write-Host "      サーバーが応答しました。ブラウザを開きます。" -ForegroundColor Green
        Start-Process $url
    }
    else {
        Write-Host "[警告] サーバーがまだ応答しません。手動でブラウザを開いてください。" -ForegroundColor Yellow
        Write-Host "       URL: $url" -ForegroundColor Yellow
    }
}
else {
    Write-Host ""
    Write-Host "[2/2] ブラウザの自動起動をスキップしました。" -ForegroundColor Gray
}

# --- 完了メッセージ ---
Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host " 起動完了" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "  バックエンド: http://localhost:8000" -ForegroundColor White
Write-Host "  ヘルスチェック: http://localhost:8000/api/health" -ForegroundColor White
Write-Host ""
Write-Host "  停止するには stop_all.ps1 を実行してください。" -ForegroundColor Gray
Write-Host ""
