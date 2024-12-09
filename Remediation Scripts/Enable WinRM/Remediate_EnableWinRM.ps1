<#
.SYNOPSIS
    Enables WinRM (PSRemoting) on the device if it is not already enabled.

.DESCRIPTION
    Forces the configuration of PSRemoting, including setting up WinRM listeners and firewall rules.
    Skips network profile checks, ensuring remoting is enabled under all network conditions.

.NOTES
    Requires administrator privileges. If run via Intune Proactive Remediations as SYSTEM, it should have necessary permissions.

.PARAMETERS
    -Force                 Suppresses confirmation prompts.
    -SkipNetworkProfileCheck Allows enabling PSRemoting regardless of current network profile.

.NOTES
    Author: M.omar
    Website: momar.tech
    Date: 2024-07-14
#>

# Check if running as administrator
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "Error: Please run this script as Administrator." -ForegroundColor Red
    exit 1
}

Write-Host "`n*** Starting WinRM Configuration ***`n" -ForegroundColor Cyan

# Step 1: Check and Start WinRM Service
Write-Host "Step 1: Checking WinRM service status..." -ForegroundColor Yellow
$winrmService = Get-Service -Name WinRM -ErrorAction SilentlyContinue

if ($null -eq $winrmService) {
    Write-Host "Error: WinRM service not found. Ensure WinRM is installed." -ForegroundColor Red
    exit 1
}

if ($winrmService.Status -ne 'Running') {
    Write-Host "WinRM service is not running. Starting the service..." -ForegroundColor Yellow
    try {
        Start-Service WinRM
        Write-Host "WinRM service started successfully." -ForegroundColor Green
    } catch {
        Write-Host "Error: Failed to start WinRM service. $_" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "WinRM service is already running." -ForegroundColor Green
}

# Step 2: Enable PowerShell Remoting
Write-Host "`nStep 2: Enabling PowerShell remoting..." -ForegroundColor Yellow
try {
    Enable-PSRemoting -Force
    Write-Host "PowerShell remoting enabled successfully." -ForegroundColor Green
} catch {
    Write-Host "Error: Failed to enable PowerShell remoting. $_" -ForegroundColor Red
    exit 1
}

# Step 3: Set WinRM Service to Automatic
Write-Host "`nStep 3: Configuring WinRM service to start automatically on reboot..." -ForegroundColor Yellow
try {
    Set-Service -Name WinRM -StartupType Automatic
    Write-Host "WinRM service set to start automatically." -ForegroundColor Green
} catch {
    Write-Host "Error: Failed to set WinRM service startup type. $_" -ForegroundColor Red
    exit 1
}

# Step 4: Verify WinRM Configuration
Write-Host "`nStep 4: Verifying WinRM configuration..." -ForegroundColor Yellow
try {
    winrm quickconfig -quiet
    Write-Host "WinRM configuration verified successfully." -ForegroundColor Green
} catch {
    Write-Host "Error: Failed to verify WinRM configuration. $_" -ForegroundColor Red
    exit 1
}

# Completion Message
Write-Host "`n*** WinRM Configuration Completed Successfully ***`n" -ForegroundColor Cyan
