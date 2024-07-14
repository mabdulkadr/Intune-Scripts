# Detection Script
$filePath = "C:\Intune\Winget\winget_install_apps_end.txt"

if (Test-Path -Path $filePath) {
    Write-Output "Detected"
    exit 0
} else {
    Write-Output "Not Detected"
    exit 1
}
