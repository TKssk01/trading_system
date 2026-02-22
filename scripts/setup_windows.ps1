#Requires -Version 5.1
<#
.SYNOPSIS
    Trading System Windows 環境セットアップスクリプト

.DESCRIPTION
    VMware Fusion 上の Windows 環境にトレーディングシステムの開発環境を構築します。
    Python 3.12、Node.js 20 LTS、Git をインストールし、
    バックエンド（FastAPI）とフロントエンド（Svelte + Vite）をセットアップします。

.PARAMETER ProjectRoot
    プロジェクトのルートディレクトリパス。デフォルト: C:\trading_system

.EXAMPLE
    .\setup_windows.ps1
    .\setup_windows.ps1 -ProjectRoot "D:\dev\trading_system"

.NOTES
    - 管理者権限での実行を推奨（winget インストールに必要な場合があります）
    - 初回実行後、PATH の反映のためにスクリプトの再実行が必要な場合があります
    - べき等性: 複数回実行しても安全です
#>

param(
    [string]$ProjectRoot = "C:\trading_system"
)

# ==============================================================================
# 設定
# ==============================================================================
$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

# ==============================================================================
# ヘルパー関数
# ==============================================================================

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "==============================================================" -ForegroundColor Cyan
    Write-Host "  $Message" -ForegroundColor Cyan
    Write-Host "==============================================================" -ForegroundColor Cyan
}

function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Green
}

function Write-Warn {
    param([string]$Message)
    Write-Host "[WARN] $Message" -ForegroundColor Yellow
}

function Write-Err {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

function Write-Detail {
    param([string]$Message)
    Write-Host "       $Message" -ForegroundColor Gray
}

function Refresh-EnvironmentPath {
    <#
    .SYNOPSIS
        システムおよびユーザーの PATH 環境変数を現在のセッションに再読み込みします。
    #>
    $machinePath = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
    $userPath    = [System.Environment]::GetEnvironmentVariable("Path", "User")
    $env:Path    = "$machinePath;$userPath"
    Write-Info "PATH 環境変数を再読み込みしました。"
}

function Test-CommandExists {
    param([string]$Command)
    $null -ne (Get-Command $Command -ErrorAction SilentlyContinue)
}

function Install-WithWinget {
    <#
    .SYNOPSIS
        winget を使用してパッケージをインストールします（既にインストール済みの場合はスキップ）。
    #>
    param(
        [string]$PackageId,
        [string]$DisplayName,
        [string]$VerifyCommand,
        [string]$VerifyArgs = "--version"
    )

    Write-Info "${DisplayName} のインストール状態を確認中..."

    # winget list で既にインストール済みか確認
    $installed = winget list --id $PackageId 2>$null
    if ($LASTEXITCODE -eq 0 -and $installed -match $PackageId) {
        Write-Info "${DisplayName} は既にインストールされています。スキップします。"
    }
    else {
        Write-Info "${DisplayName} をインストール中..."
        winget install $PackageId `
            --accept-package-agreements `
            --accept-source-agreements `
            --silent
        if ($LASTEXITCODE -ne 0) {
            throw "${DisplayName} のインストールに失敗しました。(exit code: $LASTEXITCODE)"
        }
        Write-Info "${DisplayName} のインストールが完了しました。"

        # PATH を再読み込み（新しいインストールを反映）
        Refresh-EnvironmentPath
    }

    # バージョン確認
    if ($VerifyCommand -and (Test-CommandExists $VerifyCommand)) {
        $version = & $VerifyCommand $VerifyArgs 2>&1
        Write-Detail "検出バージョン: $version"
    }
    else {
        Write-Warn "${VerifyCommand} コマンドがまだ PATH に見つかりません。"
        Write-Warn "スクリプトの再実行、またはターミナルの再起動が必要な場合があります。"
    }
}

# ==============================================================================
# メイン処理
# ==============================================================================

function Main {
    $startTime = Get-Date
    $script:StepCount = 0

    Write-Host ""
    Write-Host "######################################################################" -ForegroundColor Magenta
    Write-Host "#                                                                    #" -ForegroundColor Magenta
    Write-Host "#   Trading System - Windows 環境セットアップ                        #" -ForegroundColor Magenta
    Write-Host "#                                                                    #" -ForegroundColor Magenta
    Write-Host "######################################################################" -ForegroundColor Magenta
    Write-Host ""
    Write-Info "プロジェクトルート: $ProjectRoot"
    Write-Info "実行日時: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    Write-Host ""

    # ------------------------------------------------------------------
    # ステップ 0: 前提条件チェック
    # ------------------------------------------------------------------
    Write-Step "ステップ 0: 前提条件の確認"

    # 管理者権限チェック
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal(
        [Security.Principal.WindowsIdentity]::GetCurrent()
    )
    $isAdmin = $currentPrincipal.IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator
    )

    if ($isAdmin) {
        Write-Info "管理者権限で実行中です。"
    }
    else {
        Write-Warn "管理者権限なしで実行中です。"
        Write-Warn "winget のインストールに失敗する場合は、管理者として再実行してください。"
        Write-Host ""
        $continue = Read-Host "続行しますか？ (Y/n)"
        if ($continue -eq 'n' -or $continue -eq 'N') {
            Write-Info "セットアップを中止しました。"
            return
        }
    }

    # 実行ポリシーの設定
    Write-Info "PowerShell 実行ポリシーを確認中..."
    $currentPolicy = Get-ExecutionPolicy -Scope CurrentUser
    if ($currentPolicy -eq "Restricted" -or $currentPolicy -eq "AllSigned") {
        Write-Info "実行ポリシーを RemoteSigned に変更します..."
        Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
        Write-Info "実行ポリシーを RemoteSigned に設定しました。"
    }
    else {
        Write-Info "実行ポリシー: $currentPolicy (変更不要)"
    }

    # winget の存在確認
    if (-not (Test-CommandExists "winget")) {
        Write-Err "winget (Windows Package Manager) が見つかりません。"
        Write-Err "Windows 10 1709 以降、または Microsoft Store から App Installer をインストールしてください。"
        throw "winget が利用できません。"
    }
    Write-Info "winget が利用可能です。"

    # ------------------------------------------------------------------
    # ステップ 1: Python 3.12 のインストール
    # ------------------------------------------------------------------
    Write-Step "ステップ 1: Python 3.12 のインストール"

    try {
        Install-WithWinget `
            -PackageId "Python.Python.3.12" `
            -DisplayName "Python 3.12" `
            -VerifyCommand "python" `
            -VerifyArgs "--version"
    }
    catch {
        Write-Err "Python 3.12 のセットアップ中にエラーが発生しました: $_"
        throw
    }

    # ------------------------------------------------------------------
    # ステップ 2: Node.js 20 LTS のインストール
    # ------------------------------------------------------------------
    Write-Step "ステップ 2: Node.js 20 LTS のインストール"

    try {
        Install-WithWinget `
            -PackageId "OpenJS.NodeJS.LTS" `
            -DisplayName "Node.js 20 LTS" `
            -VerifyCommand "node" `
            -VerifyArgs "--version"
    }
    catch {
        Write-Err "Node.js のセットアップ中にエラーが発生しました: $_"
        throw
    }

    # ------------------------------------------------------------------
    # ステップ 3: Git のインストール
    # ------------------------------------------------------------------
    Write-Step "ステップ 3: Git のインストール"

    try {
        Install-WithWinget `
            -PackageId "Git.Git" `
            -DisplayName "Git" `
            -VerifyCommand "git" `
            -VerifyArgs "--version"
    }
    catch {
        Write-Err "Git のセットアップ中にエラーが発生しました: $_"
        throw
    }

    # ------------------------------------------------------------------
    # ステップ 4: PATH の最終再読み込みと必須コマンド確認
    # ------------------------------------------------------------------
    Write-Step "ステップ 4: PATH の再読み込みと必須コマンドの確認"

    Refresh-EnvironmentPath

    $requiredCommands = @("python", "pip", "node", "npm", "git")
    $missingCommands = @()

    foreach ($cmd in $requiredCommands) {
        if (Test-CommandExists $cmd) {
            $ver = & $cmd --version 2>&1
            Write-Info "${cmd}: $ver"
        }
        else {
            Write-Err "${cmd} が PATH に見つかりません。"
            $missingCommands += $cmd
        }
    }

    if ($missingCommands.Count -gt 0) {
        Write-Host ""
        Write-Warn "以下のコマンドが見つかりませんでした: $($missingCommands -join ', ')"
        Write-Warn "ターミナルを閉じて再度開いてから、このスクリプトを再実行してください。"
        Write-Warn "新しいターミナルセッションでは PATH が正しく反映されます。"
        Write-Host ""
        Write-Host "再実行コマンド:" -ForegroundColor Yellow
        Write-Host "  .\scripts\setup_windows.ps1 -ProjectRoot `"$ProjectRoot`"" -ForegroundColor White
        return
    }

    Write-Info "全ての必須コマンドが利用可能です。"

    # ------------------------------------------------------------------
    # ステップ 5: プロジェクトディレクトリの準備
    # ------------------------------------------------------------------
    Write-Step "ステップ 5: プロジェクトディレクトリの準備"

    if (-not (Test-Path $ProjectRoot)) {
        Write-Info "プロジェクトディレクトリを作成中: $ProjectRoot"
        New-Item -ItemType Directory -Path $ProjectRoot -Force | Out-Null
    }
    else {
        Write-Info "プロジェクトディレクトリは既に存在します: $ProjectRoot"
    }

    # backend ディレクトリの存在確認
    $backendDir  = Join-Path $ProjectRoot "backend"
    $frontendDir = Join-Path $ProjectRoot "frontend"

    if (-not (Test-Path $backendDir)) {
        Write-Err "バックエンドディレクトリが見つかりません: $backendDir"
        Write-Err "プロジェクトファイルを $ProjectRoot にコピーしてから再実行してください。"
        throw "バックエンドディレクトリが存在しません。"
    }

    if (-not (Test-Path $frontendDir)) {
        Write-Err "フロントエンドディレクトリが見つかりません: $frontendDir"
        Write-Err "プロジェクトファイルを $ProjectRoot にコピーしてから再実行してください。"
        throw "フロントエンドディレクトリが存在しません。"
    }

    Write-Info "バックエンドディレクトリ: $backendDir"
    Write-Info "フロントエンドディレクトリ: $frontendDir"

    # ------------------------------------------------------------------
    # ステップ 6: バックエンド（Python / FastAPI）セットアップ
    # ------------------------------------------------------------------
    Write-Step "ステップ 6: バックエンドのセットアップ (Python / FastAPI)"

    try {
        Push-Location $backendDir

        # 仮想環境の作成（既に存在する場合はスキップ）
        $venvDir = Join-Path $backendDir ".venv"
        if (Test-Path $venvDir) {
            Write-Info "Python 仮想環境は既に存在します。スキップします。"
        }
        else {
            Write-Info "Python 仮想環境を作成中..."
            python -m venv .venv
            if ($LASTEXITCODE -ne 0) {
                throw "仮想環境の作成に失敗しました。"
            }
            Write-Info "仮想環境を作成しました: $venvDir"
        }

        # 仮想環境のアクティベート
        Write-Info "仮想環境をアクティベート中..."
        $activateScript = Join-Path $venvDir "Scripts\Activate.ps1"
        if (-not (Test-Path $activateScript)) {
            throw "アクティベートスクリプトが見つかりません: $activateScript"
        }
        & $activateScript

        # pip のアップグレード
        Write-Info "pip をアップグレード中..."
        python -m pip install --upgrade pip 2>&1 | Out-Null
        Write-Info "pip のアップグレードが完了しました。"

        # 依存パッケージのインストール
        $requirementsFile = Join-Path $backendDir "requirements.txt"
        if (Test-Path $requirementsFile) {
            Write-Info "Python パッケージをインストール中 (requirements.txt)..."
            Write-Detail "インストール対象ファイル: $requirementsFile"
            pip install -r $requirementsFile
            if ($LASTEXITCODE -ne 0) {
                throw "pip install に失敗しました。"
            }
            Write-Info "Python パッケージのインストールが完了しました。"
        }
        else {
            Write-Warn "requirements.txt が見つかりません: $requirementsFile"
        }

        # インストール結果の確認
        Write-Info "インストール済みパッケージ一覧:"
        pip list --format=columns 2>&1 | Select-Object -First 20 | ForEach-Object {
            Write-Detail $_
        }
        $totalPackages = (pip list --format=freeze 2>&1 | Measure-Object).Count
        Write-Detail "... 合計 $totalPackages パッケージ"
    }
    catch {
        Write-Err "バックエンドのセットアップ中にエラーが発生しました: $_"
        throw
    }
    finally {
        Pop-Location
    }

    # ------------------------------------------------------------------
    # ステップ 7: フロントエンド（Svelte / Vite）セットアップ
    # ------------------------------------------------------------------
    Write-Step "ステップ 7: フロントエンドのセットアップ (Svelte / Vite)"

    try {
        Push-Location $frontendDir

        # node_modules の確認
        $nodeModulesDir = Join-Path $frontendDir "node_modules"

        Write-Info "npm パッケージをインストール中..."
        npm install
        if ($LASTEXITCODE -ne 0) {
            throw "npm install に失敗しました。"
        }
        Write-Info "npm パッケージのインストールが完了しました。"

        # ビルドの実行
        Write-Info "フロントエンドをビルド中..."
        npm run build
        if ($LASTEXITCODE -ne 0) {
            throw "npm run build に失敗しました。"
        }
        Write-Info "フロントエンドのビルドが完了しました。"

        # ビルド出力ディレクトリの確認
        $distDir = Join-Path $frontendDir "dist"
        if (Test-Path $distDir) {
            $fileCount = (Get-ChildItem -Path $distDir -Recurse -File).Count
            Write-Info "ビルド出力: $distDir ($fileCount ファイル)"
        }
    }
    catch {
        Write-Err "フロントエンドのセットアップ中にエラーが発生しました: $_"
        throw
    }
    finally {
        Pop-Location
    }

    # ------------------------------------------------------------------
    # 完了サマリー
    # ------------------------------------------------------------------
    $endTime  = Get-Date
    $duration = $endTime - $startTime

    Write-Host ""
    Write-Host "######################################################################" -ForegroundColor Green
    Write-Host "#                                                                    #" -ForegroundColor Green
    Write-Host "#   セットアップが正常に完了しました!                                #" -ForegroundColor Green
    Write-Host "#                                                                    #" -ForegroundColor Green
    Write-Host "######################################################################" -ForegroundColor Green
    Write-Host ""
    Write-Info "所要時間: $($duration.Minutes) 分 $($duration.Seconds) 秒"
    Write-Host ""
    Write-Host "--- 環境情報 ---" -ForegroundColor Cyan
    Write-Detail "Python:  $(python --version 2>&1)"
    Write-Detail "pip:     $(pip --version 2>&1)"
    Write-Detail "Node.js: $(node --version 2>&1)"
    Write-Detail "npm:     $(npm --version 2>&1)"
    Write-Detail "Git:     $(git --version 2>&1)"
    Write-Host ""
    Write-Host "--- 次のステップ ---" -ForegroundColor Cyan
    Write-Detail "バックエンド起動:"
    Write-Detail "  cd $backendDir"
    Write-Detail "  .\.venv\Scripts\Activate.ps1"
    Write-Detail "  uvicorn main:app --reload --host 0.0.0.0 --port 8000"
    Write-Host ""
    Write-Detail "フロントエンド起動 (開発モード):"
    Write-Detail "  cd $frontendDir"
    Write-Detail "  npm run dev"
    Write-Host ""
}

# ==============================================================================
# エントリーポイント
# ==============================================================================
try {
    Main
}
catch {
    Write-Host ""
    Write-Err "============================================================"
    Write-Err "  セットアップ中に致命的なエラーが発生しました"
    Write-Err "============================================================"
    Write-Err "エラー詳細: $_"
    Write-Err "エラー位置: $($_.InvocationInfo.ScriptLineNumber) 行目"
    Write-Host ""
    Write-Warn "トラブルシューティング:"
    Write-Warn "  1. 管理者権限でターミナルを再起動して再実行してください"
    Write-Warn "  2. ネットワーク接続を確認してください"
    Write-Warn "  3. winget が正しくインストールされているか確認してください:"
    Write-Warn "     winget --version"
    Write-Warn "  4. PATH が反映されない場合はターミナルを再起動してください"
    Write-Host ""
    exit 1
}
