<#
.SYNOPSIS
    Remediation script to uninstall a specific Windows update (KBxxxxxxx).

.DESCRIPTION
    If the specified KB update is installed, this script removes it using wusa.exe.

.EXAMPLE
    .\Remediate-KBUpdate.ps1

.NOTES
    Author: Your Name
    Date: 2025-02-04
#>

$KBNumber = "KB5050094"

# Check if the KB update is installed
$update = Get-HotFix | Where-Object { $_.HotFixID -eq $KBNumber }

if ($update) {
    Write-Host "Uninstalling $KBNumber..."
    Start-Process -FilePath "wusa.exe" -ArgumentList "/uninstall /kb:$($KBNumber.Trim('KB')) /quiet /norestart" -Wait -NoNewWindow
    Write-Host "$KBNumber uninstallation initiated. Restart may be required."
} else {
    Write-Host "$KBNumber is not installed. No action needed."
}
