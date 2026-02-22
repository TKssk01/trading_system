#Requires -Version 5.1
<#
.SYNOPSIS
    Trading System 環境設定ファイル (.env) 作成スクリプト

.DESCRIPTION
    対話形式で backend/.env ファイルを作成します。
    パスワード類は SecureString として入力され、画面に表示されません。
    既存の .env ファイルがある場合、値をデフォルトとして読み込みます。

.EXAMPLE
    .\create_env.ps1

.EXAMPLE
    .\create_env.ps1 -Overwrite
    既存の .env ファイルがある場合でも確認なしで上書きします。
#>

[CmdletBinding()]
param(
    # 確認なしで上書き
    [switch]$Overwrite
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# --- プロジェクトルートを解決 ---
$ProjectRoot = Split-Path (Split-Path $PSScriptRoot)
$EnvFile = Join-Path $ProjectRoot "backend\.env"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Trading System - 環境設定ファイル作成" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "[情報] 出力先: $EnvFile" -ForegroundColor Gray
Write-Host ""

# --- 既存の .env ファイルの読み込み ---
$existingValues = @{}

if (Test-Path $EnvFile) {
    Write-Host "[情報] 既存の .env ファイルを検出しました。" -ForegroundColor Yellow

    # 既存の値を読み込み (デフォルト値として使用)
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
        $response = Read-Host "既存の .env ファイルを上書きしますか? (y/N)"
        if ($response -notin @("y", "Y", "yes", "Yes")) {
            Write-Host "[情報] 作成をキャンセルしました。" -ForegroundColor Gray
            exit 0
        }
    }
    Write-Host ""
}

# --- デフォルト値の定義 ---
# 既存値があればそれをデフォルトとして使用
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

# --- 対話形式で値を入力 ---
Write-Host "--- 認証情報 (パスワードは非表示で入力されます) ---" -ForegroundColor Magenta
Write-Host ""

# API パスワード
$hasExistingApiPw = $existingValues.ContainsKey("TS_API_PASSWORD") -and $existingValues["TS_API_PASSWORD"] -ne ""
if ($hasExistingApiPw) {
    Write-Host "[情報] API パスワードは既に設定されています。" -ForegroundColor Gray
    $changeApiPw = Read-Host "  API パスワードを変更しますか? (y/N)"
}

if (-not $hasExistingApiPw -or $changeApiPw -in @("y", "Y", "yes", "Yes")) {
    $secureApiPw = Read-Host "  API パスワード (TS_API_PASSWORD)" -AsSecureString
    $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureApiPw)
    $apiPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)

    if ($apiPassword -eq "") {
        Write-Host "  [警告] API パスワードが空です。後で設定してください。" -ForegroundColor Yellow
    }
}
else {
    $apiPassword = $existingValues["TS_API_PASSWORD"]
}

# 注文パスワード
$hasExistingOrderPw = $existingValues.ContainsKey("TS_ORDER_PASSWORD") -and $existingValues["TS_ORDER_PASSWORD"] -ne ""
if ($hasExistingOrderPw) {
    Write-Host "[情報] 注文パスワードは既に設定されています。" -ForegroundColor Gray
    $changeOrderPw = Read-Host "  注文パスワードを変更しますか? (y/N)"
}

if (-not $hasExistingOrderPw -or $changeOrderPw -in @("y", "Y", "yes", "Yes")) {
    $secureOrderPw = Read-Host "  注文パスワード (TS_ORDER_PASSWORD)" -AsSecureString
    $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureOrderPw)
    $orderPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)

    if ($orderPassword -eq "") {
        Write-Host "  [警告] 注文パスワードが空です。後で設定してください。" -ForegroundColor Yellow
    }
}
else {
    $orderPassword = $existingValues["TS_ORDER_PASSWORD"]
}

Write-Host ""
Write-Host "--- 一般設定 (Enter でデフォルト値を使用) ---" -ForegroundColor Magenta
Write-Host ""

# API ベース URL
$defaultApiUrl = Get-Default "TS_API_BASE_URL" "http://localhost:18080/kabusapi"
$inputApiUrl = Read-Host "  API ベース URL [$defaultApiUrl]"
$apiBaseUrl = if ($inputApiUrl -ne "") { $inputApiUrl } else { $defaultApiUrl }

# 銘柄コード
$defaultSymbol = Get-Default "TS_SYMBOL" "1579"
$inputSymbol = Read-Host "  銘柄コード [$defaultSymbol]"
$symbol = if ($inputSymbol -ne "") { $inputSymbol } else { $defaultSymbol }

# 取引所
$defaultExchange = Get-Default "TS_EXCHANGE" "1"
$inputExchange = Read-Host "  取引所 (1=東証, 3=名証, 5=福証, 6=札証) [$defaultExchange]"
$exchange = if ($inputExchange -ne "") { $inputExchange } else { $defaultExchange }

# スリープ間隔
$defaultSleep = Get-Default "TS_SLEEP_INTERVAL" "0.3"
$inputSleep = Read-Host "  スリープ間隔 (秒) [$defaultSleep]"
$sleepInterval = if ($inputSleep -ne "") { $inputSleep } else { $defaultSleep }

# 強制決済時刻
$defaultCloseTime = Get-Default "TS_FORCE_CLOSE_TIME" "14:55"
$inputCloseTime = Read-Host "  強制決済時刻 (HH:MM) [$defaultCloseTime]"
$forceCloseTime = if ($inputCloseTime -ne "") { $inputCloseTime } else { $defaultCloseTime }

# 最大日次損失
$defaultMaxLoss = Get-Default "TS_MAX_DAILY_LOSS" "1.0"
$inputMaxLoss = Read-Host "  最大日次損失率 (%) [$defaultMaxLoss]"
$maxDailyLoss = if ($inputMaxLoss -ne "") { $inputMaxLoss } else { $defaultMaxLoss }

# --- 確認表示 ---
Write-Host ""
Write-Host "--- 設定内容の確認 ---" -ForegroundColor Magenta
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

$confirm = Read-Host "この内容で .env ファイルを作成しますか? (Y/n)"
if ($confirm -in @("n", "N", "no", "No")) {
    Write-Host "[情報] 作成をキャンセルしました。再度実行してください。" -ForegroundColor Gray
    exit 0
}

# --- .env ファイルの書き込み ---
Write-Host ""
Write-Host "[情報] .env ファイルを書き込み中..." -ForegroundColor Gray

$envContent = @"
# Trading System 環境設定ファイル
# 自動生成: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
#
# このファイルには機密情報が含まれます。
# Git にコミットしないでください。

# --- 認証情報 ---
TS_API_PASSWORD=$apiPassword
TS_ORDER_PASSWORD=$orderPassword

# --- API 設定 ---
TS_API_BASE_URL=$apiBaseUrl

# --- 取引設定 ---
TS_SYMBOL=$symbol
TS_EXCHANGE=$exchange
TS_SLEEP_INTERVAL=$sleepInterval
TS_FORCE_CLOSE_TIME=$forceCloseTime
TS_MAX_DAILY_LOSS=$maxDailyLoss
"@

try {
    # backend ディレクトリの存在確認
    $backendDir = Join-Path $ProjectRoot "backend"
    if (-not (Test-Path $backendDir)) {
        Write-Host "[エラー] backend ディレクトリが見つかりません: $backendDir" -ForegroundColor Red
        exit 1
    }

    # ファイル書き込み (UTF-8 BOM なし)
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($EnvFile, $envContent, $utf8NoBom)

    Write-Host "[完了] .env ファイルを作成しました: $EnvFile" -ForegroundColor Green
}
catch {
    Write-Host "[エラー] .env ファイルの書き込みに失敗しました: $_" -ForegroundColor Red
    exit 1
}

# --- ファイル権限の制限 ---
Write-Host "[情報] ファイル権限を制限中..." -ForegroundColor Gray

try {
    # 現在のユーザーのみにアクセスを制限
    $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    $acl = Get-Acl $EnvFile

    # 継承を無効にし、既存のACEを削除
    $acl.SetAccessRuleProtection($true, $false)

    # 現在のユーザーにフルコントロールを付与
    $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
        $currentUser,
        "FullControl",
        "Allow"
    )
    $acl.SetAccessRule($rule)
    Set-Acl -Path $EnvFile -AclObject $acl

    Write-Host "[完了] 現在のユーザー ($currentUser) のみにアクセスを制限しました。" -ForegroundColor Green
}
catch {
    # ACL 設定に失敗した場合は icacls にフォールバック
    Write-Host "[警告] ACL の設定に失敗しました。icacls で再試行します..." -ForegroundColor Yellow
    try {
        $null = icacls $EnvFile /inheritance:r /grant "${env:USERNAME}:F" 2>&1
        Write-Host "[完了] icacls でファイル権限を制限しました。" -ForegroundColor Green
    }
    catch {
        Write-Host "[警告] ファイル権限の制限に失敗しました。手動で設定してください。" -ForegroundColor Yellow
        Write-Host "       icacls `"$EnvFile`" /inheritance:r /grant `"${env:USERNAME}:F`"" -ForegroundColor Yellow
    }
}

# --- .gitignore の確認 ---
$gitignorePath = Join-Path $ProjectRoot ".gitignore"
$envRelativePath = "backend/.env"

if (Test-Path $gitignorePath) {
    $gitignoreContent = Get-Content $gitignorePath -Raw
    if ($gitignoreContent -notmatch [regex]::Escape($envRelativePath) -and
        $gitignoreContent -notmatch "\.env") {
        Write-Host ""
        Write-Host "[警告] .gitignore に .env が含まれていません。" -ForegroundColor Yellow
        Write-Host "       以下を .gitignore に追加することを強く推奨します:" -ForegroundColor Yellow
        Write-Host "         $envRelativePath" -ForegroundColor Yellow
    }
}
else {
    Write-Host ""
    Write-Host "[警告] .gitignore ファイルが見つかりません。" -ForegroundColor Yellow
    Write-Host "       .env ファイルが Git にコミットされないように注意してください。" -ForegroundColor Yellow
}

# --- 完了メッセージ ---
Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host " 環境設定ファイルの作成が完了しました" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "  start_backend.ps1 または start_all.ps1 で" -ForegroundColor White
Write-Host "  サーバーを起動できます。" -ForegroundColor White
Write-Host ""
