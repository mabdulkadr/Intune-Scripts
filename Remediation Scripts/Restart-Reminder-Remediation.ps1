<#
.SYNOPSIS
    This script notifies the user that a restart is required through a Windows toast notification and a message box in both Arabic and English.

.DESCRIPTION
    The script performs the following actions if a restart is required:
    1. Displays a toast notification using the BurntToast PowerShell module in both Arabic and English.
    2. Displays a PowerShell message box with restart information in both Arabic and English.
    3. It does not trigger a system restart; it only notifies the user of the restart requirement.

.NOTES
    Author  : M.omar
    Website : momar.tech
    Date    : 2024-09-15
    Version : 1.0
#>

# Function to show a toast notification using BurntToast in both Arabic and English
function Show-ToastNotification {
    # Check if BurntToast is installed, and install it if necessary
    if (-not (Get-Module -ListAvailable -Name BurntToast)) {
        Install-Module -Name BurntToast -Force -SkipPublisherCheck -Scope CurrentUser
    }

    # Import BurntToast module to create toast notifications
    Import-Module BurntToast

    # Show the bilingual toast notification (Arabic and English)
    New-BurntToastNotification -Text "Restart Required - إعادة التشغيل مطلوب", `
        "Your system needs a restart. Please restart your computer as soon as possible.", `
        "جهازك بحاجة إلى إعادة تشغيل. الرجاء إعادة تشغيل الكمبيوتر في أسرع وقت ممكن."
}

# Function to check if a restart is required
function Check-RestartRequired {
    # Check if there is a pending reboot due to Windows Updates using WMI
    $wmiOS = Get-CimInstance -ClassName Win32_OperatingSystem
    $pendingReboot = $wmiOS.PSComputerName -and $wmiOS.RebootPending

    # Check if there are pending file rename operations (typically set by software installations)
    $pendingFileRename = (Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" `
        -Name PendingFileRenameOperations -ErrorAction SilentlyContinue).PendingFileRenameOperations

    # Return true if either a pending reboot or file rename operation is found
    if ($pendingReboot -or $pendingFileRename) {
        return $true
    } else {
        return $false
    }
}

# Function to show a PowerShell message box in both Arabic and English
function Show-RestartMessageBox {
    # Ensure the Windows Forms assembly is loaded to use message boxes
    Add-Type -AssemblyName System.Windows.Forms

    # Display the bilingual message box
    [System.Windows.Forms.MessageBox]::Show($message, $title, `
        [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
}

# Main logic to check for restart requirement and trigger notifications
if (Check-RestartRequired) {
    Show-ToastNotification  # Trigger Toast Notification
} else {
    Write-Host "No restart required."  # Output if no restart is needed
}
