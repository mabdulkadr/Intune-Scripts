<#
.SYNOPSIS
    Disables IPv6 on all network interfaces and updates the system registry.

.DESCRIPTION
    This PowerShell script automates the process of disabling IPv6 bindings on all network interfaces 
    and updates the registry to disable IPv6 components. The changes will take effect after a system restart.

.EXAMPLE
    .\Remediate-DisableIPv6.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Date    : 2024-11-04
#>

try {
    Write-Host "Starting remediation: Disabling IPv6 on all network interfaces." -ForegroundColor Green

    # Retrieve all network interfaces with IPv6 enabled
    $interfaces = Get-NetAdapterBinding -ComponentID ms_tcpip6 | Select-Object -ExpandProperty Name

    if ($interfaces.Count -eq 0) {
        Write-Host "No interfaces with IPv6 found. No changes needed." -ForegroundColor Yellow
    } else {
        foreach ($interface in $interfaces) {
            try {
                # Disable IPv6 binding on each interface
                Disable-NetAdapterBinding -Name $interface -ComponentID ms_tcpip6 -ErrorAction Stop
                Write-Host "IPv6 has been disabled on interface: $interface" -ForegroundColor Green
            } catch {
                Write-Host "Error disabling IPv6 on interface: $interface. $_" -ForegroundColor Red
            }
        }

        # Update registry to disable IPv6 components system-wide
        try {
            New-ItemProperty -Path HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters\ `
            -Name DisabledComponents -Type DWord -Value 255 -Force
            Write-Host "Registry updated to disable IPv6 components. A system restart is required for changes to take effect." -ForegroundColor Cyan
        } catch {
            Write-Host "Error updating registry: $_" -ForegroundColor Red
        }
    }

    Write-Host "Remediation completed successfully. A system restart is required to apply changes." -ForegroundColor Green
} catch {
    Write-Host "An unexpected error occurred during remediation: $_" -ForegroundColor Red
}
