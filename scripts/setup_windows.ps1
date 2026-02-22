#Requires -Version 5.1
<#
.SYNOPSIS
    Trading System Windows environment setup script

.DESCRIPTION
    Sets up the trading system development environment on a Windows environment on VMware Fusion.
    Installs Python 3.12, Node.js 20 LTS, and Git,
    then sets up the backend (FastAPI) and frontend (Svelte + Vite).

.PARAMETER ProjectRoot
    Path to the project root directory. Default: C:\trading_system

.EXAMPLE
    .\setup_windows.ps1
    .\setup_windows.ps1 -ProjectRoot "D:\dev\trading_system"

.NOTES
    - Running with administrator privileges is recommended (may be required for winget installation)
    - After the first run, you may need to re-run the script for PATH changes to take effect
    - Idempotent: safe to run multiple times
#>

param(
    [string]$ProjectRoot = "C:\trading_system"
)

# ==============================================================================
# Configuration
# ==============================================================================
$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

# ==============================================================================
# Helper functions
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
        Reloads the system and user PATH environment variables into the current session.
    #>
    $machinePath = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
    $userPath    = [System.Environment]::GetEnvironmentVariable("Path", "User")
    $env:Path    = "$machinePath;$userPath"
    Write-Info "Reloaded PATH environment variable."
}

function Test-CommandExists {
    param([string]$Command)
    $null -ne (Get-Command $Command -ErrorAction SilentlyContinue)
}

function Install-WithWinget {
    <#
    .SYNOPSIS
        Installs a package using winget (skips if already installed).
    #>
    param(
        [string]$PackageId,
        [string]$DisplayName,
        [string]$VerifyCommand,
        [string]$VerifyArgs = "--version"
    )

    Write-Info "Checking installation status of ${DisplayName}..."

    # Check if already installed using winget list
    $installed = winget list --id $PackageId --source winget 2>$null
    if ($LASTEXITCODE -eq 0 -and $installed -match $PackageId) {
        Write-Info "${DisplayName} is already installed. Skipping."
    }
    else {
        Write-Info "Installing ${DisplayName}..."
        winget install $PackageId `
            --source winget `
            --accept-package-agreements `
            --accept-source-agreements `
            --silent
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to install ${DisplayName}. (exit code: $LASTEXITCODE)"
        }
        Write-Info "${DisplayName} installation completed."

        # Reload PATH (to reflect new installation)
        Refresh-EnvironmentPath
    }

    # Verify version
    if ($VerifyCommand -and (Test-CommandExists $VerifyCommand)) {
        $version = & $VerifyCommand $VerifyArgs 2>&1
        Write-Detail "Detected version: $version"
    }
    else {
        Write-Warn "${VerifyCommand} command not yet found in PATH."
        Write-Warn "You may need to re-run the script or restart the terminal."
    }
}

# ==============================================================================
# Main process
# ==============================================================================

function Main {
    $startTime = Get-Date
    $script:StepCount = 0

    Write-Host ""
    Write-Host "######################################################################" -ForegroundColor Magenta
    Write-Host "#                                                                    #" -ForegroundColor Magenta
    Write-Host "#   Trading System - Windows Environment Setup                       #" -ForegroundColor Magenta
    Write-Host "#                                                                    #" -ForegroundColor Magenta
    Write-Host "######################################################################" -ForegroundColor Magenta
    Write-Host ""
    Write-Info "Project root: $ProjectRoot"
    Write-Info "Execution time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    Write-Host ""

    # ------------------------------------------------------------------
    # Step 0: Prerequisites check
    # ------------------------------------------------------------------
    Write-Step "Step 0: Checking prerequisites"

    # Administrator privileges check
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal(
        [Security.Principal.WindowsIdentity]::GetCurrent()
    )
    $isAdmin = $currentPrincipal.IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator
    )

    if ($isAdmin) {
        Write-Info "Running with administrator privileges."
    }
    else {
        Write-Warn "Running without administrator privileges."
        Write-Warn "If winget installation fails, please re-run as administrator."
        Write-Host ""
        $continue = Read-Host "Do you want to continue? (Y/n)"
        if ($continue -eq 'n' -or $continue -eq 'N') {
            Write-Info "Setup has been cancelled."
            return
        }
    }

    # Execution policy setting
    Write-Info "Checking PowerShell execution policy..."
    $currentPolicy = Get-ExecutionPolicy -Scope CurrentUser
    if ($currentPolicy -eq "Restricted" -or $currentPolicy -eq "AllSigned") {
        Write-Info "Changing execution policy to RemoteSigned..."
        Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
        Write-Info "Execution policy has been set to RemoteSigned."
    }
    else {
        Write-Info "Execution policy: $currentPolicy (no change required)"
    }

    # winget availability check
    if (-not (Test-CommandExists "winget")) {
        Write-Err "winget (Windows Package Manager) was not found."
        Write-Err "Please install App Installer from the Microsoft Store, or use Windows 10 1709 or later."
        throw "winget is not available."
    }
    Write-Info "winget is available."

    # ------------------------------------------------------------------
    # Step 1: Install Python 3.12
    # ------------------------------------------------------------------
    Write-Step "Step 1: Installing Python 3.12"

    try {
        Install-WithWinget `
            -PackageId "Python.Python.3.12" `
            -DisplayName "Python 3.12" `
            -VerifyCommand "python" `
            -VerifyArgs "--version"
    }
    catch {
        Write-Err "An error occurred during Python 3.12 setup: $_"
        throw
    }

    # ------------------------------------------------------------------
    # Step 2: Install Node.js 20 LTS
    # ------------------------------------------------------------------
    Write-Step "Step 2: Installing Node.js 20 LTS"

    try {
        Install-WithWinget `
            -PackageId "OpenJS.NodeJS.LTS" `
            -DisplayName "Node.js 20 LTS" `
            -VerifyCommand "node" `
            -VerifyArgs "--version"
    }
    catch {
        Write-Err "An error occurred during Node.js setup: $_"
        throw
    }

    # ------------------------------------------------------------------
    # Step 3: Install Git
    # ------------------------------------------------------------------
    Write-Step "Step 3: Installing Git"

    try {
        Install-WithWinget `
            -PackageId "Git.Git" `
            -DisplayName "Git" `
            -VerifyCommand "git" `
            -VerifyArgs "--version"
    }
    catch {
        Write-Err "An error occurred during Git setup: $_"
        throw
    }

    # ------------------------------------------------------------------
    # Step 4: Final PATH reload and required command verification
    # ------------------------------------------------------------------
    Write-Step "Step 4: Reloading PATH and verifying required commands"

    Refresh-EnvironmentPath

    $requiredCommands = @("python", "pip", "node", "npm", "git")
    $missingCommands = @()

    foreach ($cmd in $requiredCommands) {
        if (Test-CommandExists $cmd) {
            $ver = & $cmd --version 2>&1
            Write-Info "${cmd}: $ver"
        }
        else {
            Write-Err "${cmd} was not found in PATH."
            $missingCommands += $cmd
        }
    }

    if ($missingCommands.Count -gt 0) {
        Write-Host ""
        Write-Warn "The following commands were not found: $($missingCommands -join ', ')"
        Write-Warn "Please close and reopen the terminal, then re-run this script."
        Write-Warn "PATH will be correctly reflected in the new terminal session."
        Write-Host ""
        Write-Host "Re-run command:" -ForegroundColor Yellow
        Write-Host "  .\scripts\setup_windows.ps1 -ProjectRoot `"$ProjectRoot`"" -ForegroundColor White
        return
    }

    Write-Info "All required commands are available."

    # ------------------------------------------------------------------
    # Step 5: Preparing project directory
    # ------------------------------------------------------------------
    Write-Step "Step 5: Preparing project directory"

    if (-not (Test-Path $ProjectRoot)) {
        Write-Info "Creating project directory: $ProjectRoot"
        New-Item -ItemType Directory -Path $ProjectRoot -Force | Out-Null
    }
    else {
        Write-Info "Project directory already exists: $ProjectRoot"
    }

    # Check for backend directory
    $backendDir  = Join-Path $ProjectRoot "backend"
    $frontendDir = Join-Path $ProjectRoot "frontend"

    if (-not (Test-Path $backendDir)) {
        Write-Err "Backend directory not found: $backendDir"
        Write-Err "Please copy the project files to $ProjectRoot and re-run."
        throw "Backend directory does not exist."
    }

    if (-not (Test-Path $frontendDir)) {
        Write-Err "Frontend directory not found: $frontendDir"
        Write-Err "Please copy the project files to $ProjectRoot and re-run."
        throw "Frontend directory does not exist."
    }

    Write-Info "Backend directory: $backendDir"
    Write-Info "Frontend directory: $frontendDir"

    # ------------------------------------------------------------------
    # Step 6: Backend (Python / FastAPI) setup
    # ------------------------------------------------------------------
    Write-Step "Step 6: Setting up backend (Python / FastAPI)"

    try {
        Push-Location $backendDir

        # Create virtual environment (skip if already exists)
        $venvDir = Join-Path $backendDir ".venv"
        if (Test-Path $venvDir) {
            Write-Info "Python virtual environment already exists. Skipping."
        }
        else {
            Write-Info "Creating Python virtual environment..."
            python -m venv .venv
            if ($LASTEXITCODE -ne 0) {
                throw "Failed to create virtual environment."
            }
            Write-Info "Virtual environment created: $venvDir"
        }

        # Activate virtual environment
        Write-Info "Activating virtual environment..."
        $activateScript = Join-Path $venvDir "Scripts\Activate.ps1"
        if (-not (Test-Path $activateScript)) {
            throw "Activation script not found: $activateScript"
        }
        & $activateScript

        # Upgrade pip
        Write-Info "Upgrading pip..."
        python -m pip install --upgrade pip 2>&1 | Out-Null
        Write-Info "pip upgrade completed."

        # Install dependency packages
        $requirementsFile = Join-Path $backendDir "requirements.txt"
        if (Test-Path $requirementsFile) {
            Write-Info "Installing Python packages (requirements.txt)..."
            Write-Detail "Target file: $requirementsFile"
            pip install -r $requirementsFile
            if ($LASTEXITCODE -ne 0) {
                throw "pip install failed."
            }
            Write-Info "Python package installation completed."
        }
        else {
            Write-Warn "requirements.txt not found: $requirementsFile"
        }

        # Verify installation results
        Write-Info "Installed packages:"
        pip list --format=columns 2>&1 | Select-Object -First 20 | ForEach-Object {
            Write-Detail $_
        }
        $totalPackages = (pip list --format=freeze 2>&1 | Measure-Object).Count
        Write-Detail "... Total: $totalPackages packages"
    }
    catch {
        Write-Err "An error occurred during backend setup: $_"
        throw
    }
    finally {
        Pop-Location
    }

    # ------------------------------------------------------------------
    # Step 7: Frontend (Svelte / Vite) setup
    # ------------------------------------------------------------------
    Write-Step "Step 7: Setting up frontend (Svelte / Vite)"

    try {
        Push-Location $frontendDir

        # Check node_modules
        $nodeModulesDir = Join-Path $frontendDir "node_modules"

        Write-Info "Installing npm packages..."
        npm install
        if ($LASTEXITCODE -ne 0) {
            throw "npm install failed."
        }
        Write-Info "npm package installation completed."

        # Run build
        Write-Info "Building frontend..."
        npm run build
        if ($LASTEXITCODE -ne 0) {
            throw "npm run build failed."
        }
        Write-Info "Frontend build completed."

        # Verify build output directory
        $distDir = Join-Path $frontendDir "dist"
        if (Test-Path $distDir) {
            $fileCount = (Get-ChildItem -Path $distDir -Recurse -File).Count
            Write-Info "Build output: $distDir ($fileCount files)"
        }
    }
    catch {
        Write-Err "An error occurred during frontend setup: $_"
        throw
    }
    finally {
        Pop-Location
    }

    # ------------------------------------------------------------------
    # Completion summary
    # ------------------------------------------------------------------
    $endTime  = Get-Date
    $duration = $endTime - $startTime

    Write-Host ""
    Write-Host "######################################################################" -ForegroundColor Green
    Write-Host "#                                                                    #" -ForegroundColor Green
    Write-Host "#   Setup completed successfully!                                    #" -ForegroundColor Green
    Write-Host "#                                                                    #" -ForegroundColor Green
    Write-Host "######################################################################" -ForegroundColor Green
    Write-Host ""
    Write-Info "Elapsed time: $($duration.Minutes) min $($duration.Seconds) sec"
    Write-Host ""
    Write-Host "--- Environment Info ---" -ForegroundColor Cyan
    Write-Detail "Python:  $(python --version 2>&1)"
    Write-Detail "pip:     $(pip --version 2>&1)"
    Write-Detail "Node.js: $(node --version 2>&1)"
    Write-Detail "npm:     $(npm --version 2>&1)"
    Write-Detail "Git:     $(git --version 2>&1)"
    Write-Host ""
    Write-Host "--- Next Steps ---" -ForegroundColor Cyan
    Write-Detail "Start backend:"
    Write-Detail "  cd $backendDir"
    Write-Detail "  .\.venv\Scripts\Activate.ps1"
    Write-Detail "  uvicorn main:app --reload --host 0.0.0.0 --port 8000"
    Write-Host ""
    Write-Detail "Start frontend (development mode):"
    Write-Detail "  cd $frontendDir"
    Write-Detail "  npm run dev"
    Write-Host ""
}

# ==============================================================================
# Entry point
# ==============================================================================
try {
    Main
}
catch {
    Write-Host ""
    Write-Err "============================================================"
    Write-Err "  A fatal error occurred during setup"
    Write-Err "============================================================"
    Write-Err "Error details: $_"
    Write-Err "Error location: line $($_.InvocationInfo.ScriptLineNumber)"
    Write-Host ""
    Write-Warn "Troubleshooting:"
    Write-Warn "  1. Restart the terminal with administrator privileges and re-run"
    Write-Warn "  2. Check your network connection"
    Write-Warn "  3. Verify that winget is installed correctly:"
    Write-Warn "     winget --version"
    Write-Warn "  4. If PATH is not reflected, restart the terminal"
    Write-Host ""
    exit 1
}
