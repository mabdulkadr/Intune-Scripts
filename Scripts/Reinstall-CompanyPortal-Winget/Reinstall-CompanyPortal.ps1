<#
.SYNOPSIS
    Installs or reinstalls the Microsoft Company Portal using winget.

.DESCRIPTION
    This script ensures the Microsoft Company Portal is correctly installed by first uninstalling it (if present) and then reinstalling it using winget.

.EXAMPLE
    ./Reinstall-CompanyPortal.ps1

.NOTES
    Author: M.omar
    Website: momar.tech
    Date: 2025-01-09
#>

# Function to check administrative privileges
function Check-AdminPrivilege {
    if (-Not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
        Write-Host "This script must be run as an Administrator." -ForegroundColor Red
        Exit
    }
}

# Function to resolve winget executable path
function Resolve-WingetPath {
    Write-Host "Resolving winget executable path..." -ForegroundColor Cyan
    $ResolveWingetPath = Resolve-Path "C:\Program Files\WindowsApps\Microsoft.DesktopAppInstaller_*_x64__8wekyb3d8bbwe" -ErrorAction SilentlyContinue
    if ($ResolveWingetPath) {
        $WingetPath = $ResolveWingetPath[-1].Path
        return "$WingetPath\winget.exe"
    } else {
        Write-Host "winget not found. Please ensure App Installer is installed." -ForegroundColor Red
        Start-Process "ms-windows-store://pdp/?ProductId=9NBLGGH4NNS1" -Wait
        Exit
    }
}

# Function to check if Company Portal is installed
function Check-CompanyPortal {
    Write-Host "Checking if the Company Portal is installed..." -ForegroundColor Cyan
    $installedApps = & $Winget list --name "Company Portal" -e 2>$null
    if ($installedApps -match "Company Portal") {
        Write-Host "Company Portal is installed. Preparing to uninstall..." -ForegroundColor Yellow
        return $true
    } else {
        Write-Host "Company Portal is not installed." -ForegroundColor Cyan
        return $false
    }
}

# Function to uninstall the Company Portal
function Uninstall-CompanyPortal {
    Write-Host "Uninstalling Company Portal..." -ForegroundColor Yellow
    try {
        & $Winget uninstall --name "Company Portal"
        Write-Host "Company Portal has been uninstalled successfully." -ForegroundColor Green
    } catch {
        Write-Host "Failed to uninstall Company Portal: $_" -ForegroundColor Red
        Exit
    }
}

# Function to install the Company Portal
function Install-CompanyPortal {
    Write-Host "Installing Company Portal..." -ForegroundColor Yellow
    try {
        & $Winget install "Company Portal" --source msstore --accept-package-agreements --accept-source-agreements
        Write-Host "Company Portal has been installed successfully." -ForegroundColor Green
    } catch {
        Write-Host "Failed to install Company Portal: $_" -ForegroundColor Red
        Exit
    }
}

# Main script execution
Check-AdminPrivilege
$Winget = Resolve-WingetPath
$isInstalled = Check-CompanyPortal
if ($isInstalled) {
    Uninstall-CompanyPortal
}
Install-CompanyPortal
