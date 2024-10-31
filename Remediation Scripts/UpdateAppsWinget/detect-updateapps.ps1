######## Detection Script ########
# Software Detection Script to check if software needs an update
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

# Initialize a flag to determine if any updates are needed
$updatesNeeded = $false

foreach ($app in $apps) {
    $appID = $app.ID
    $appName = $app.FriendlyName

    # Check if the application is installed
    $installed = .\winget.exe list --id $appID --accept-source-agreements --accept-package-agreements 2>$null

    if ($installed) {
        # Check if an upgrade is available
        $upgradeInfo = .\winget.exe upgrade --id $appID --accept-source-agreements --accept-package-agreements 2>$null

        if ($upgradeInfo -and $upgradeInfo -notmatch "No applicable update found") {
            Write-Host "$appName is installed but not the latest version. An update is available."
            $updatesNeeded = $true
        } else {
            Write-Host "$appName is installed and is the latest version."
        }
    } else {
        Write-Host "$appName is not installed."
    }
}

# Exit with code 1 if any updates are needed, else exit with code 0
if ($updatesNeeded) {
    exit 1
} else {
    exit 0
}
