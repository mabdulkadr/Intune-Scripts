<#
.SYNOPSIS
    Enables .NET Framework 3.5 on Windows 10/11.

.DESCRIPTION
    This script enables the .NET Framework 3.5 feature using Add-WindowsCapability.
    It handles errors and ensures the feature is installed successfully.

.EXAMPLE
    Deploy this script as a remediation script via Intune.

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Date    : 2024-12-17
#>

try {
    Write-Output "Checking .NET Framework 3.5 status..."

    # Get the current status of the .NET Framework 3.5 feature
    $Feature = Get-WindowsOptionalFeature -Online -FeatureName NetFx3

    if ($Feature.State -eq "Enabled") {
        Write-Output ".NET Framework 3.5 is already enabled."
    }
    else {
        Write-Output "Installing .NET Framework 3.5..."

        # Attempt to enable the feature using Add-WindowsCapability
        Add-WindowsCapability -Online -Name "NetFx3~~~~" -ErrorAction Stop

        Write-Output ".NET Framework 3.5 has been enabled successfully."
    }
}
catch {
    Write-Error "Failed to enable .NET Framework 3.5: $_"
    Exit 1  # Exit with failure if an error occurs
}
