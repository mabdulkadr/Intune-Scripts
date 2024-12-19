<#
.SYNOPSIS
    Checks if Windows Time service is running, automatic time synchronization is enabled,
    and automatic time zone detection is configured.

.DESCRIPTION
    This script verifies:
    1. Windows Time service is running and configured correctly.
    2. Automatic time synchronization is enabled.
    3. Automatic time zone detection is configured.

.EXAMPLE
    Detects compliance for time-related settings:
    .\Detect-TimeIssues.ps1


.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Date    : 2024-12-19
#>

# Define variables
$timeServiceName = "w32time"
$registryPathTimeZone = "HKLM:\SYSTEM\CurrentControlSet\Services\tzautoupdate"
$registryPropertyName = "Start"

try {
    Write-Host "Checking Windows Time service status..." -ForegroundColor Yellow
    $timeService = Get-Service -Name $timeServiceName -ErrorAction SilentlyContinue
    if ($timeService.Status -ne "Running") {
        Write-Output "NonCompliant: Windows Time service is not running."
        Exit 1
    }

    Write-Host "Checking automatic time synchronization settings..." -ForegroundColor Yellow
    $timeConfig = w32tm /query /configuration | Select-String "NtpClient"
    if (-not $timeConfig) {
        Write-Output "NonCompliant: Automatic time synchronization is not configured."
        Exit 1
    }

    Write-Host "Checking automatic time zone detection settings..." -ForegroundColor Yellow
    $currentValue = Get-ItemProperty -Path $registryPathTimeZone -Name $registryPropertyName -ErrorAction SilentlyContinue
    if ($currentValue.$registryPropertyName -ne 3) {
        Write-Output "NonCompliant: Automatic time zone detection is not enabled."
        Exit 1
    }

    Write-Output "Compliant: All time-related settings are correctly configured."
    Exit 0

} catch {
    Write-Output "Error during detection: $_"
    Exit 2
}
