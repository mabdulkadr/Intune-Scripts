<#
.SYNOPSIS
    Fixes issues with Windows Time service, automatic time synchronization,
    and automatic time zone detection.

.DESCRIPTION
    This script:
    1. Ensures Windows Time service is running and configured.
    2. Enables automatic time synchronization.
    3. Configures automatic time zone detection.

.EXAMPLE
    Remediates non-compliance for time-related settings:
    .\Remediate-TimeIssues.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Date    : 2024-12-19
#>

# Define variables
$timeServiceName = "w32time"
$registryPathTimeZone = "HKLM:\SYSTEM\CurrentControlSet\Services\tzautoupdate"
$registryPropertyName = "Start"
$timeServer = "time.windows.com"

try {
    Write-Host "Step 1: Ensuring Windows Time service is running..." -ForegroundColor Yellow
    $timeService = Get-Service -Name $timeServiceName -ErrorAction SilentlyContinue
    if ($timeService.Status -ne "Running") {
        Start-Service -Name $timeServiceName
        Write-Host "Windows Time service started successfully." -ForegroundColor Green
    } else {
        Write-Host "Windows Time service is already running." -ForegroundColor Green
    }

    # Set the Windows Time service to start automatically
    Set-Service -Name $timeServiceName -StartupType Automatic
    Write-Host "Windows Time service set to Automatic startup." -ForegroundColor Green

    Write-Host "Step 2: Configuring automatic time synchronization..." -ForegroundColor Yellow
    w32tm /config /manualpeerlist:$timeServer /syncfromflags:manual /reliable:yes /update
    Write-Host "Time synchronization configured to use $timeServer." -ForegroundColor Green
    w32tm /resync
    Write-Host "Time synchronized successfully." -ForegroundColor Green

    Write-Host "Step 3: Enabling automatic time zone detection..." -ForegroundColor Yellow
    $currentValue = Get-ItemProperty -Path $registryPathTimeZone -Name $registryPropertyName -ErrorAction SilentlyContinue
    if ($currentValue.$registryPropertyName -ne 3) {
        Set-ItemProperty -Path $registryPathTimeZone -Name $registryPropertyName -Value 3
        Write-Host "Automatic time zone detection enabled." -ForegroundColor Green
    } else {
        Write-Host "Automatic time zone detection is already enabled." -ForegroundColor Green
    }

    # Restart location service if available
    Write-Host "Restarting Location Service (if applicable)..." -ForegroundColor Yellow
    $locationService = Get-Service -Name "lfsvc" -ErrorAction SilentlyContinue
    if ($locationService.Status -ne "Running") {
        Start-Service -Name "lfsvc"
        Write-Host "Location Service started successfully." -ForegroundColor Green
    } else {
        Write-Host "Location Service is already running." -ForegroundColor Green
    }

    Write-Host "All time-related issues have been fixed!" -ForegroundColor Green

} catch {
    Write-Host "Error during remediation: $_" -ForegroundColor Red
    Exit 1
}
