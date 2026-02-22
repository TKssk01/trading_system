#Requires -Version 5.1
<#
.SYNOPSIS
    Trading System バックエンドサーバー起動スクリプト (PowerShell)

.DESCRIPTION
    Python 仮想環境をアクティベートし、uvicorn でバックエンドサーバーを起動します。

.EXAMPLE
    .\start_backend.ps1
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# --- プロジェクトルートを解決 ---
$ProjectRoot = Split-Path (Split-Path $PSScriptRoot)

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Trading System - バックエンド起動" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "[情報] プロジェクトルート: $ProjectRoot" -ForegroundColor Gray

# --- Python 仮想環境の確認 ---
$VenvActivate = Join-Path $ProjectRoot "backend\.venv\Scripts\Activate.ps1"

if (-not (Test-Path $VenvActivate)) {
    Write-Host ""
    Write-Host "[エラー] 仮想環境が見つかりません: $VenvActivate" -ForegroundColor Red
    Write-Host ""
    Write-Host "以下のコマンドで仮想環境を作成してください:" -ForegroundColor Yellow
    Write-Host "  cd `"$ProjectRoot\backend`"" -ForegroundColor Yellow
    Write-Host "  python -m venv .venv" -ForegroundColor Yellow
    Write-Host "  .\.venv\Scripts\Activate.ps1" -ForegroundColor Yellow
    Write-Host "  pip install -r requirements.txt" -ForegroundColor Yellow
    Write-Host ""
    exit 1
}

# --- .env ファイルの確認 ---
$EnvFile = Join-Path $ProjectRoot "backend\.env"
if (-not (Test-Path $EnvFile)) {
    Write-Host "[警告] backend\.env ファイルが見つかりません。" -ForegroundColor Yellow
    Write-Host "       デフォルト設定で起動します。" -ForegroundColor Yellow
    Write-Host "       create_env.ps1 で .env ファイルを作成することを推奨します。" -ForegroundColor Yellow
    Write-Host ""
}

# --- 仮想環境をアクティベート ---
Write-Host "[情報] 仮想環境をアクティベート中..." -ForegroundColor Gray
try {
    & $VenvActivate
}
catch {
    Write-Host "[エラー] 仮想環境のアクティベートに失敗しました: $_" -ForegroundColor Red
    exit 1
}

# --- 作業ディレクトリをプロジェクトルートに設定 ---
Set-Location $ProjectRoot
Write-Host "[情報] 作業ディレクトリ: $(Get-Location)" -ForegroundColor Gray

# --- uvicorn でバックエンドを起動 ---
Write-Host ""
Write-Host "[情報] uvicorn サーバーを起動します..." -ForegroundColor Green
Write-Host "[情報] URL: http://localhost:8000" -ForegroundColor Green
Write-Host "[情報] 停止するには Ctrl+C を押してください" -ForegroundColor Gray
Write-Host ""

try {
    python -m uvicorn backend.main:app --host 0.0.0.0 --port 8000 --reload
}
catch {
    Write-Host ""
    Write-Host "[エラー] uvicorn の起動に失敗しました: $_" -ForegroundColor Red
    Write-Host ""
    Write-Host "requirements.txt の依存関係がインストールされているか確認してください:" -ForegroundColor Yellow
    Write-Host "  pip install -r backend\requirements.txt" -ForegroundColor Yellow
    Write-Host ""
    exit 1
}
