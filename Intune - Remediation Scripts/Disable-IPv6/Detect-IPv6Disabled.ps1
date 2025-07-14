<#
.SYNOPSIS
    Detects whether IPv6 is disabled on all network interfaces.

.DESCRIPTION
    This PowerShell script checks if IPv6 is currently disabled on all network adapters. 
    If any network adapter still has IPv6 enabled, the script will return a non-compliant state.

.EXAMPLE
    .\Detect-IPv6Disabled.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Date    : 2024-11-04
#>

# Detection logic
$ipv6DisabledInterfaces = Get-NetAdapterBinding -ComponentID ms_tcpip6 | Where-Object { $_.Enabled -eq $false }

if ($ipv6DisabledInterfaces.Count -eq (Get-NetAdapterBinding -ComponentID ms_tcpip6).Count) {
    # IPv6 is disabled on all interfaces
    Write-Host "Compliant: IPv6 is disabled on all network interfaces."
    exit 0  # Return compliant state
} else {
    # IPv6 is still enabled on one or more interfaces
    Write-Host "Non-compliant: IPv6 is enabled on one or more network interfaces."
    exit 1  # Return non-compliant state
}
