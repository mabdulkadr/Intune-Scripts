######## Remediation Script #########
# Software Remediation Script to update the software
# Author: John Bryntze (Updated by ChatGPT)
# Date: [Current Date]

# Function to locate winget.exe
function Get-WinGetPath {
    try {
        $wingetPath = Resolve-Path "C:\Program Files\WindowsApps\Microsoft.DesktopAppInstaller_*_x64__8wekyb3d8bbwe\winget.exe" -ErrorAction Stop
        return $wingetPath[-1].Path
    } catch {
        Write-Error "winget.exe not found. Ensure that Winget is installed."
        exit 1
    }
}

# Retrieve winget.exe path and set location
$WinGetPathExe = Get-WinGetPath
$WinGetPath = Split-Path -Path $WinGetPathExe -Parent
Set-Location $WinGetPath

# Define list of applications with their Winget IDs and friendly names
$apps = @(
    @{ ID = "7zip.7zip"; FriendlyName = "7-Zip" },
    @{ ID = "winrar.winrar"; FriendlyName = "WinRAR" },
    @{ ID = "Google.Chrome"; FriendlyName = "Google Chrome" },
    @{ ID = "Mozilla.Firefox"; FriendlyName = "Mozilla Firefox" },
    @{ ID = "Zoom.Zoom"; FriendlyName = "Zoom" },
    @{ ID = "Notepad++.Notepad++"; FriendlyName = "Notepad++" },
    @{ ID = "Microsoft.CompanyPortal"; FriendlyName = "Company Portal" },
    @{ ID = "VideoLAN.VLC"; FriendlyName = "VLC" }
)

foreach ($app in $apps) {
    $appID = $app.ID
    $appName = $app.FriendlyName

    Write-Host "Attempting to update $appName..."

    # Attempt to upgrade the application
    $upgradeResult = .\winget.exe upgrade --id $appID --silent --accept-package-agreements --accept-source-agreements 2>&1

    if ($upgradeResult -match "No applicable update found") {
        Write-Host "$appName is already up to date."
    }
    elseif ($upgradeResult -match "Successfully installed") {
        Write-Host "$appName has been successfully updated."
    }
    else {
        Write-Host "Failed to update $appName. Details:`n$upgradeResult"
    }
}

exit 0
