@echo off
chcp 65001 >nul 2>&1
REM ============================================================
REM  start_backend.bat - Backend Server Startup Script (Windows)
REM  Starts the trading_system backend with uvicorn
REM ============================================================

setlocal enabledelayedexpansion

REM --- Resolve project root ---
set "SCRIPT_DIR=%~dp0"
REM Remove trailing backslash
if "%SCRIPT_DIR:~-1%"=="\" set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"
for %%I in ("%SCRIPT_DIR%\..") do set "PROJECT_ROOT=%%~fI"

echo.
echo ========================================
echo  Trading System - Starting Backend
echo ========================================
echo.
echo [INFO] Project root: %PROJECT_ROOT%

REM --- Check Python virtual environment ---
set "VENV_ACTIVATE=%PROJECT_ROOT%\backend\.venv\Scripts\activate.bat"

if not exist "%VENV_ACTIVATE%" (
    echo.
    echo [ERROR] Virtual environment not found: %VENV_ACTIVATE%
    echo.
    echo Please create the virtual environment with the following commands:
    echo   cd "%PROJECT_ROOT%\backend"
    echo   python -m venv .venv
    echo   .venv\Scripts\activate.bat
    echo   pip install -r requirements.txt
    echo.
    pause
    exit /b 1
)

REM --- Check .env file ---
if not exist "%PROJECT_ROOT%\backend\.env" (
    echo [WARNING] backend\.env file not found.
    echo           Starting with default settings.
    echo           It is recommended to create a .env file using create_env.ps1.
    echo.
)

REM --- Activate virtual environment ---
echo [INFO] Activating virtual environment...
call "%VENV_ACTIVATE%"
if errorlevel 1 (
    echo [ERROR] Failed to activate virtual environment.
    pause
    exit /b 1
)

REM --- Set working directory to project root ---
cd /d "%PROJECT_ROOT%"
echo [INFO] Working directory: %CD%

REM --- Start backend with uvicorn ---
echo.
echo [INFO] Starting uvicorn server...
echo [INFO] URL: http://localhost:8000
echo [INFO] Press Ctrl+C to stop
echo.

python -m uvicorn backend.main:app --host 0.0.0.0 --port 8000 --reload

if errorlevel 1 (
    echo.
    echo [ERROR] Failed to start uvicorn.
    echo         Please ensure the dependencies in requirements.txt are installed:
    echo           pip install -r backend\requirements.txt
    echo.
    pause
    exit /b 1
)

endlocal
