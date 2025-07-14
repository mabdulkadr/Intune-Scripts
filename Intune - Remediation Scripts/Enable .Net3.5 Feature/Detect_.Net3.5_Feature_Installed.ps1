<#
.SYNOPSIS
    Detects whether .NET Framework 3.5 is enabled.

.DESCRIPTION
    This script checks the status of the .NET Framework 3.5 feature on the target device.
    It outputs "Installed" if the feature is enabled and "Not Installed" otherwise.

.EXAMPLE
    Run the script in Intune as a detection script to verify .NET Framework 3.5 status.

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Date    : 2024-12-17
#>

# Check the state of the .NET Framework 3.5 feature
$Feature = Get-WindowsOptionalFeature -Online -FeatureName NetFx3

if ($Feature.State -eq "Enabled") {
    Write-Output "Installed"
    Exit 0  # Detection success (feature is enabled)
}
else {
    Write-Output "Not Installed"
    Exit 1  # Detection failed (feature not enabled)
}
