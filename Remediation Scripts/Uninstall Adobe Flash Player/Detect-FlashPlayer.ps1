<#
.SYNOPSIS
    Detection script for Adobe Flash Player remnants.

.DESCRIPTION
    Checks for existence of Adobe Flash Player via known file paths and registry entries.

.NOTES
    Author  : Mohammad Abdelkader
    Website : momar.tech
    Date    : 2025-06-30
#>

$FilePaths = @(
    'C:\Windows\System32\Macromed\Flash',
    'C:\Windows\SysWOW64\Macromed\Flash',
    "$env:APPDATA\Adobe\Flash Player",
    "$env:APPDATA\Macromedia\Flash Player"
)

$RegistryPaths = @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Adobe Flash Player NPAPI',
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Adobe Flash Player ActiveX',
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Adobe Flash Player Pepper',
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Adobe Flash Player NPAPI',
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Adobe Flash Player PPAPI',
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Adobe Flash Player Pepper'
)

foreach ($path in $FilePaths) {
    if (Test-Path $path) {
        Write-Output "Detected"
        exit 1
    }
}

foreach ($key in $RegistryPaths) {
    if (Test-Path $key) {
        Write-Output "Detected"
        exit 1
    }
}

Write-Output "Compliant"
exit 0
