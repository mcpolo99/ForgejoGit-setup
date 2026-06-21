@echo off
setlocal

echo.
echo ===============================
echo   Forgejo Self-Hosted Git
echo   Windows Setup
echo ===============================
echo.

:: Check if Git Bash is installed
where git >nul 2>&1
if %errorlevel% equ 0 (
    echo [OK] Git found
) else (
    echo [MISSING] Git / Git Bash
    echo.
    echo Downloading Git for Windows...
    curl -sL -o "%TEMP%\git-installer.exe" "https://github.com/git-for-windows/git/releases/latest/download/Git-2.47.1-64-bit.exe"
    echo Starting Git installer — follow the wizard...
    start /wait "%TEMP%\git-installer.exe"
    del "%TEMP%\git-installer.exe" 2>nul
    echo.
    echo Git installed. Please CLOSE this window and run run.cmd again.
    pause
    exit /b 1
)

:: Check if Docker Desktop is installed
where docker >nul 2>&1
if %errorlevel% equ 0 (
    echo [OK] Docker found
) else (
    echo [MISSING] Docker Desktop
    echo.
    echo Downloading Docker Desktop installer...
    curl -sL -o "%TEMP%\docker-installer.exe" "https://desktop.docker.com/win/main/amd64/Docker%%20Desktop%%20Installer.exe"
    echo Starting Docker Desktop installer — follow the wizard...
    start /wait "%TEMP%\docker-installer.exe"
    del "%TEMP%\docker-installer.exe" 2>nul
    echo.
    echo Docker Desktop installed. Restart your computer, then run run.cmd again.
    pause
    exit /b 1
)

:: Check if Tea CLI is installed
where tea >nul 2>&1
if %errorlevel% equ 0 (
    echo [OK] Tea CLI found
) else (
    echo [MISSING] Tea CLI — installing...
    echo.
    if not exist "%USERPROFILE%\AppData\Local\Microsoft\WindowsApps" (
        mkdir "%USERPROFILE%\AppData\Local\Microsoft\WindowsApps" 2>nul
    )
    curl -sL -o "%USERPROFILE%\AppData\Local\Microsoft\WindowsApps\tea.exe" "https://gitea.com/gitea/tea/releases/download/v0.14.1/tea-0.14.1-windows-amd64.exe"
    echo [OK] Tea CLI installed
)

:: All prerequisites met — run the main script via Git Bash
echo.
echo All prerequisites installed. Starting setup...
echo.

:: Find Git Bash
set "GITBASH="
if exist "C:\Program Files\Git\bin\bash.exe" set "GITBASH=C:\Program Files\Git\bin\bash.exe"
if exist "C:\Program Files (x86)\Git\bin\bash.exe" set "GITBASH=C:\Program Files (x86)\Git\bin\bash.exe"

if "%GITBASH%"=="" (
    echo ERROR: Cannot find Git Bash. Make sure Git is installed.
    pause
    exit /b 1
)

:: Run run.sh via Git Bash
"%GITBASH%" --login -c "cd '%~dp0' && ./run.sh"

endlocal
