<#
.SYNOPSIS
    This script installs Winget components, updates all installed applications, installs the Microsoft Company Portal, and performs necessary setup steps.

.DESCRIPTION
    The script performs the following actions:
    1. Creates necessary directories for logging.
    2. Starts a transcript for logging operations.
    3. Downloads Winget components if they are not already present.
    4. Installs the downloaded Winget components using Add-AppxPackage.
    5. Finds the latest Winget executable path.
    6. Resets and updates Winget sources.
    7. Updates all installed applications using Winget.
    8. Installs the Microsoft Company Portal using Winget.
    9. Creates a detection file to indicate the completion of the script.

.NOTES
    Author: M.omar
    Website: momar.tech
    Date: 2024-07-12
    Version: 1.0
#>

# Create folders for logging
New-Item -ItemType directory -Path C:\Intune -ErrorAction SilentlyContinue
New-Item -ItemType directory -Path C:\Intune\Winget -ErrorAction SilentlyContinue

# Start logging
try {
    Start-Transcript -Path "C:\Intune\Winget\winget_install_apps.log" -ErrorAction SilentlyContinue
} catch {
    Write-Host "Failed to start transcription: $_" -ForegroundColor Red
}

# Function to log messages with timestamps
function Log-Message {
    param (
        [string]$message,
        [string]$color = "White"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "$timestamp - $message" -ForegroundColor $color
}

# Function to download and install Winget components
function Install-WingetComponents {
    try {
        $wingetInstallerPath = "C:\Intune\Winget\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle"
        $vclibsPath = "C:\Intune\Winget\Microsoft.VCLibs.x64.14.00.Desktop.appx"
        $uiXamlPath = "C:\Intune\Winget\Microsoft.UI.Xaml.2.8.x64.appx"
        
        if (-not (Test-Path $wingetInstallerPath)) {
            Log-Message "Downloading Winget installer..." "Yellow"
            Invoke-WebRequest -Uri https://aka.ms/getwinget -OutFile $wingetInstallerPath -ErrorAction SilentlyContinue
        } else {
            Log-Message "Winget installer already exists. Skipping download." "Green"
        }

        if (-not (Test-Path $vclibsPath)) {
            Log-Message "Downloading VCLibs..." "Yellow"
            Invoke-WebRequest -Uri https://aka.ms/Microsoft.VCLibs.x64.14.00.Desktop.appx -OutFile $vclibsPath -ErrorAction SilentlyContinue
        } else {
            Log-Message "VCLibs already exists. Skipping download." "Green"
        }

        if (-not (Test-Path $uiXamlPath)) {
            Log-Message "Downloading UI.Xaml..." "Yellow"
            Invoke-WebRequest -Uri https://github.com/microsoft/microsoft-ui-xaml/releases/download/v2.8.6/Microsoft.UI.Xaml.2.8.x64.appx -OutFile $uiXamlPath -ErrorAction SilentlyContinue
        } else {
            Log-Message "UI.Xaml already exists. Skipping download." "Green"
        }

        Log-Message "Winget components downloaded successfully." "Green"
    } catch {
        Log-Message "Error downloading Winget components: $_" "Red"
        Stop-Transcript
        exit 1
    }

    try {
        Log-Message "Applying Winget packages..." "Yellow"
        
        # Function to check if the package is already installed
        function Is-PackageInstalled {
            param (
                [string]$packageName
            )
            $installedPackages = Get-AppxPackage
            foreach ($package in $installedPackages) {
                if ($package.Name -eq $packageName) {
                    return $true
                }
            }
            return $false
        }

        if (-not (Is-PackageInstalled "Microsoft.VCLibs")) {
            Add-AppxPackage -Path $vclibsPath -ErrorAction SilentlyContinue
        } else {
            Log-Message "VCLibs package already installed. Skipping." "Green"
        }

        if (-not (Is-PackageInstalled "Microsoft.UI.Xaml")) {
            Add-AppxPackage -Path $uiXamlPath -ErrorAction SilentlyContinue
        } else {
            Log-Message "UI.Xaml package already installed. Skipping." "Green"
        }

        if (-not (Is-PackageInstalled "Microsoft.DesktopAppInstaller")) {
            Add-AppxPackage -Path $wingetInstallerPath -ErrorAction SilentlyContinue
        } else {
            Log-Message "Winget installer package already installed. Skipping." "Green"
        }

        Start-Sleep -Seconds 15
        Log-Message "Winget packages applied successfully." "Green"
    } catch {
        Log-Message "Error applying Winget packages: $_" "Red"
        Stop-Transcript
        exit 1
    }
}

# Function to find and set the latest Winget executable path
function Set-LatestWingetPath {
    try {
        $winget = Get-ChildItem -Path 'C:\Program Files\WindowsApps\' -Filter winget.exe -Recurse | Sort-Object -Property 'FullName' -Descending | Select-Object -First 1 -ExpandProperty FullName | Tee-Object -FilePath C:\Intune\Winget\Winget-file-found-from.log
        if (-not $winget) {
            Log-Message "Winget executable not found." "Red"
            Stop-Transcript
            exit 1
        }
        Log-Message "Winget executable found: $winget" "Green"
        return $winget
    } catch {
        Log-Message "Error finding Winget executable: $_" "Red"
        Stop-Transcript
        exit 1
    }
}

# Function to reset and update Winget source
function Reset-And-Update-WingetSource {
    param (
        [string]$wingetPath
    )
    try {
        Log-Message "Resetting Winget source..." "Yellow"
        Start-Process -FilePath $wingetPath -NoNewWindow -Wait -ArgumentList 'source reset --force --verbose-logs' -RedirectStandardOutput C:\Intune\Winget\Winget-source-reset.log -RedirectStandardError C:\Intune\Winget\Winget-source-reset-error.log
        Start-Sleep -Seconds 15
        Log-Message "Winget source reset completed." "Green"
    } catch {
        Log-Message "Error resetting Winget source: $_" "Red"
        Stop-Transcript
        exit 1
    }

    try {
        Log-Message "Updating Winget source..." "Yellow"
        Start-Process -FilePath $wingetPath -NoNewWindow -Wait -ArgumentList 'source update' -RedirectStandardOutput C:\Intune\Winget\Winget-source-update.log -RedirectStandardError C:\Intune\Winget\Winget-source-update-error.log
        Start-Sleep -Seconds 15
        Log-Message "Winget source update completed." "Green"
    } catch {
        Log-Message "Error updating Winget source: $_" "Red"
        Stop-Transcript
        exit 1
    }
}

# Function to update all apps using Winget
function Update-AllApps {
    param (
        [string]$wingetPath
    )
    try {
        Log-Message "Updating all apps using Winget..." "Yellow"
        Start-Process -FilePath $wingetPath -NoNewWindow -Wait -ArgumentList 'upgrade --all --silent --accept-package-agreements --accept-source-agreements' -RedirectStandardOutput C:\Intune\Winget\Winget-upgrade-all.log -RedirectStandardError C:\Intune\Winget\Winget-upgrade-all-error.log
        Start-Sleep -Seconds 15
        Log-Message "All apps updated successfully." "Green"
    } catch {
        Log-Message "Error updating apps: $_" "Red"
        Stop-Transcript
        exit 1
    }
}

# Function to install Microsoft Company Portal using Winget
function Install-CompanyPortal {
    param (
        [string]$wingetPath
    )
    try {
        Log-Message "Installing Microsoft Company Portal..." "Yellow"
        Start-Process -FilePath $wingetPath -NoNewWindow -Wait -ArgumentList 'install 9wzdncrcwx8b --silent --accept-package-agreements --accept-source-agreements' -RedirectStandardOutput C:\Intune\Winget\Winget-install-company-portal.log -RedirectStandardError C:\Intune\Winget\Winget-install-company-portal-error.log
        Start-Sleep -Seconds 15
        Log-Message "Microsoft Company Portal installed successfully." "Green"
    } catch {
        Log-Message "Error installing Microsoft Company Portal: $_" "Red"
        Stop-Transcript
        exit 1
    }
}

# Main script execution
Log-Message "Starting Winget setup and application installation..." "Yellow"

Install-WingetComponents

$wingetPath = Set-LatestWingetPath

Reset-And-Update-WingetSource -wingetPath $wingetPath

Update-AllApps -wingetPath $wingetPath

Install-CompanyPortal -wingetPath $wingetPath

# Stop logging
try {
    Stop-Transcript
} catch {
    Write-Host "Failed to stop transcription: $_" -ForegroundColor Red
}

# Create detection method
if (-not (Test-Path "C:\Intune\Winget\winget_install_apps_end.txt")) {
    New-Item "C:\Intune\Winget\winget_install_apps_end.txt" -ItemType File -Value "Winget Application installer"
}

Log-Message "Script completed successfully." "Green"
