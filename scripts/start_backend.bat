@echo off
chcp 65001 >nul 2>&1
REM ============================================================
REM  start_backend.bat - バックエンドサーバー起動スクリプト (Windows)
REM  trading_system バックエンドを uvicorn で起動します
REM ============================================================

setlocal enabledelayedexpansion

REM --- プロジェクトルートを解決 ---
set "SCRIPT_DIR=%~dp0"
REM 末尾のバックスラッシュを除去
if "%SCRIPT_DIR:~-1%"=="\" set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"
for %%I in ("%SCRIPT_DIR%\..") do set "PROJECT_ROOT=%%~fI"

echo.
echo ========================================
echo  Trading System - バックエンド起動
echo ========================================
echo.
echo [情報] プロジェクトルート: %PROJECT_ROOT%

REM --- Python 仮想環境の確認 ---
set "VENV_ACTIVATE=%PROJECT_ROOT%\backend\.venv\Scripts\activate.bat"

if not exist "%VENV_ACTIVATE%" (
    echo.
    echo [エラー] 仮想環境が見つかりません: %VENV_ACTIVATE%
    echo.
    echo 以下のコマンドで仮想環境を作成してください:
    echo   cd "%PROJECT_ROOT%\backend"
    echo   python -m venv .venv
    echo   .venv\Scripts\activate.bat
    echo   pip install -r requirements.txt
    echo.
    pause
    exit /b 1
)

REM --- .env ファイルの確認 ---
if not exist "%PROJECT_ROOT%\backend\.env" (
    echo [警告] backend\.env ファイルが見つかりません。
    echo         デフォルト設定で起動します。
    echo         create_env.ps1 で .env ファイルを作成することを推奨します。
    echo.
)

REM --- 仮想環境をアクティベート ---
echo [情報] 仮想環境をアクティベート中...
call "%VENV_ACTIVATE%"
if errorlevel 1 (
    echo [エラー] 仮想環境のアクティベートに失敗しました。
    pause
    exit /b 1
)

REM --- 作業ディレクトリをプロジェクトルートに設定 ---
cd /d "%PROJECT_ROOT%"
echo [情報] 作業ディレクトリ: %CD%

REM --- uvicorn でバックエンドを起動 ---
echo.
echo [情報] uvicorn サーバーを起動します...
echo [情報] URL: http://localhost:8000
echo [情報] 停止するには Ctrl+C を押してください
echo.

python -m uvicorn backend.main:app --host 0.0.0.0 --port 8000 --reload

if errorlevel 1 (
    echo.
    echo [エラー] uvicorn の起動に失敗しました。
    echo         requirements.txt の依存関係がインストールされているか確認してください:
    echo           pip install -r backend\requirements.txt
    echo.
    pause
    exit /b 1
)

endlocal
