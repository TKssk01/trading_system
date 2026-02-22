#Requires -Version 5.1
<#
.SYNOPSIS
    Trading System 全サービス停止スクリプト

.DESCRIPTION
    Trading System に関連する uvicorn/python プロセスを検出して停止します。

.EXAMPLE
    .\stop_all.ps1

.EXAMPLE
    .\stop_all.ps1 -Force
    確認プロンプトなしで強制停止します。
#>

[CmdletBinding()]
param(
    # 確認プロンプトをスキップ
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# --- プロジェクトルートを解決 ---
$ProjectRoot = Split-Path (Split-Path $PSScriptRoot)

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Trading System - 全サービス停止" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# --- Trading System 関連プロセスを検索 ---
Write-Host "[情報] Trading System 関連プロセスを検索中..." -ForegroundColor Gray

$targetProcesses = @()

# python / uvicorn プロセスを取得し、コマンドラインで Trading System 関連かを判定
$pythonProcesses = Get-Process -Name "python", "python3", "uvicorn" -ErrorAction SilentlyContinue

foreach ($proc in $pythonProcesses) {
    try {
        $cimProc = Get-CimInstance Win32_Process -Filter "ProcessId=$($proc.Id)" -ErrorAction SilentlyContinue
        if (-not $cimProc) { continue }

        $cmdLine = $cimProc.CommandLine
        if (-not $cmdLine) { continue }

        # uvicorn backend.main:app を含むプロセス、
        # またはプロジェクトルートパスを含むプロセスを対象とする
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
        # アクセスできないプロセスはスキップ
        continue
    }
}

# --- 結果の表示 ---
if ($targetProcesses.Count -eq 0) {
    Write-Host ""
    Write-Host "[情報] Trading System 関連のプロセスは見つかりませんでした。" -ForegroundColor Green
    Write-Host ""
    exit 0
}

Write-Host ""
Write-Host "[検出] $($targetProcesses.Count) 個の関連プロセスが見つかりました:" -ForegroundColor Yellow
Write-Host ""

foreach ($tp in $targetProcesses) {
    # コマンドラインを短縮して表示
    $shortCmd = $tp.CommandLine
    if ($shortCmd.Length -gt 100) {
        $shortCmd = $shortCmd.Substring(0, 97) + "..."
    }
    Write-Host "  PID: $($tp.PID)  名前: $($tp.Name)" -ForegroundColor White
    Write-Host "  コマンド: $shortCmd" -ForegroundColor Gray
    Write-Host ""
}

# --- 停止確認 ---
if (-not $Force) {
    $response = Read-Host "上記のプロセスを停止しますか? (y/N)"
    if ($response -notin @("y", "Y", "yes", "Yes")) {
        Write-Host "[情報] 停止をキャンセルしました。" -ForegroundColor Gray
        exit 0
    }
}

# --- プロセスを停止 ---
Write-Host ""
$stoppedCount = 0
$failedCount = 0

foreach ($tp in $targetProcesses) {
    try {
        Write-Host "[停止中] PID $($tp.PID) ($($tp.Name))..." -ForegroundColor Yellow -NoNewline

        # まず graceful に停止を試みる (SIGTERM 相当)
        $process = Get-Process -Id $tp.PID -ErrorAction SilentlyContinue
        if ($process) {
            $process.CloseMainWindow() | Out-Null
            # 3秒待機
            if (-not $process.WaitForExit(3000)) {
                # graceful 停止できなかった場合は強制終了
                Stop-Process -Id $tp.PID -Force -ErrorAction Stop
            }
        }

        Write-Host " 完了" -ForegroundColor Green
        $stoppedCount++
    }
    catch {
        # プロセスが既に終了している場合
        if (-not (Get-Process -Id $tp.PID -ErrorAction SilentlyContinue)) {
            Write-Host " (既に終了)" -ForegroundColor Gray
            $stoppedCount++
        }
        else {
            Write-Host " 失敗: $_" -ForegroundColor Red
            $failedCount++
        }
    }
}

# --- 完了メッセージ ---
Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host " 停止完了" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "  停止済み: $stoppedCount プロセス" -ForegroundColor White

if ($failedCount -gt 0) {
    Write-Host "  失敗: $failedCount プロセス" -ForegroundColor Red
    Write-Host ""
    Write-Host "  管理者権限で再実行してください:" -ForegroundColor Yellow
    Write-Host "    Start-Process powershell -Verb RunAs -ArgumentList '-File', '$PSCommandPath', '-Force'" -ForegroundColor Yellow
}

Write-Host ""
