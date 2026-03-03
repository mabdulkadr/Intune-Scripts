<#
.SYNOPSIS
    Repairs and resets key Windows Update components.

.DESCRIPTION
    This remediation script runs a Windows Update repair workflow that can
    include the built-in troubleshooter, DISM image repair, cleanup of common
    Windows Update policy values, resetting update components, and attempting
    to scan for and install pending software updates.

    Exit codes:
    - Exit 0: Completed successfully
    - Exit 1: One or more remediation steps failed

.RUN AS
    System

.EXAMPLE
    .\WindowsUpdateTroublshooting--Remediate.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.0
#>

#region ========================= CONFIGURATION =========================
# Use a fixed script name so logging stays consistent when Intune stages the script under a temporary local file name.
$ScriptName     = 'WindowsUpdateTroublshooting--Remediate.ps1'
$ScriptBaseName = 'WindowsUpdateTroublshooting--Remediate'

# Store logs under the system drive instead of hard-coding C:.
$SystemDrive   = if ($env:SystemDrive) { $env:SystemDrive } else { 'C:' }
$LogFolderName = 'Windows Update Troublshooting'
$LogDirectory  = Join-Path $SystemDrive "Intune\$LogFolderName"
$LogFilePath   = Join-Path $LogDirectory "$ScriptBaseName.txt"
$DismLogPath   = Join-Path $LogDirectory 'WindowsUpdateTroublshooting-DISM.txt'

# Windows Update diagnostics path used by the built-in troubleshooter.
$TroubleshooterPath = 'C:\Windows\diagnostics\system\WindowsUpdate'

# Registry locations commonly involved in paused or deferred update policies.
$RegistryCleanupMap = @{
    'HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UpdatePolicy\Settings' = @(
        'PausedQualityDate',
        'PausedFeatureDate',
        'PausedQualityStatus',
        'PausedFeatureStatus'
    )
    'HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\Update' = @(
        'PauseQualityUpdatesStartTime',
        'PauseFeatureUpdatesStartTime',
        'DeferFeatureUpdatesPeriodInDays'
    )
}
#endregion ====================== CONFIGURATION =========================

#region ======================= HELPER FUNCTIONS =======================
function Write-Log {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [ValidateSet('INFO', 'OK', 'WARN', 'FAIL')]
        [string]$Level = 'INFO'
    )

    $Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $LogLine   = "[$Timestamp] [$Level] $Message"

    Add-Content -Path $LogFilePath -Value $LogLine -Encoding UTF8
    Write-Output $LogLine
}

function Remove-RegistryProperties {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string[]]$PropertyNames
    )

    if (-not (Test-Path -Path $Path)) {
        Write-Log -Message "Registry path not found: $Path"
        return
    }

    $Item = Get-Item -Path $Path -ErrorAction Stop
    foreach ($PropertyName in $PropertyNames) {
        if ($Item.Property -contains $PropertyName) {
            Write-Log -Message "Removing registry property '$PropertyName' from '$Path'."
            Remove-ItemProperty -Path $Path -Name $PropertyName -ErrorAction Stop
        }
    }
}

function Ensure-RequiredModule {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ModuleName
    )

    if (Get-Module -ListAvailable -Name $ModuleName) {
        Write-Log -Message "Module '$ModuleName' is already available."
        return $true
    }

    if (-not (Get-Command -Name Install-Module -ErrorAction SilentlyContinue)) {
        Write-Log -Message "Install-Module is not available. Cannot install '$ModuleName'." -Level 'WARN'
        return $false
    }

    Write-Log -Message "Installing module '$ModuleName'."
    Install-Module -Name $ModuleName -Force -AllowClobber -ErrorAction Stop
    return $true
}
#endregion ==================== HELPER FUNCTIONS =======================

#region ==================== FIRST REMEDIATION BLOCK ====================
$HadFailures = $false

try {
    if (-not (Test-Path -Path $LogDirectory)) {
        New-Item -Path $LogDirectory -ItemType Directory -Force | Out-Null
    }

    Write-Log -Message '=== Remediation START ==='
    Write-Log -Message "Script: $ScriptName"
    Write-Log -Message "Log file: $LogFilePath"
    Write-Log -Message "DISM log file: $DismLogPath"

    # Run the built-in Windows Update troubleshooter when the required command is available.
    if ((Get-Command -Name Get-TroubleshootingPack -ErrorAction SilentlyContinue) -and (Test-Path -Path $TroubleshooterPath)) {
        try {
            Write-Log -Message 'Running the Windows Update troubleshooter.'
            Get-TroubleshootingPack -Path $TroubleshooterPath | Invoke-TroubleshootingPack -Unattended
            Write-Log -Message 'Windows Update troubleshooter completed.' -Level 'OK'
        }
        catch {
            $HadFailures = $true
            Write-Log -Message "Windows Update troubleshooter failed: $($_.Exception.Message)" -Level 'WARN'
        }
    } else {
        Write-Log -Message 'Windows Update troubleshooter is not available on this system.' -Level 'WARN'
    }

    # Repair the component store and system image health.
    try {
        Write-Log -Message 'Running DISM RestoreHealth.'
        Repair-WindowsImage -Online -RestoreHealth -NoRestart -LogPath $DismLogPath -ErrorAction Stop | Out-Null
        Write-Log -Message 'DISM RestoreHealth completed.' -Level 'OK'
    }
    catch {
        $HadFailures = $true
        Write-Log -Message "DISM RestoreHealth failed: $($_.Exception.Message)" -Level 'WARN'
    }

    # Remove common paused/deferred update policy values that can block scanning.
    foreach ($RegistryPath in $RegistryCleanupMap.Keys) {
        try {
            Remove-RegistryProperties -Path $RegistryPath -PropertyNames $RegistryCleanupMap[$RegistryPath]
        }
        catch {
            $HadFailures = $true
            Write-Log -Message "Registry cleanup failed for '$RegistryPath': $($_.Exception.Message)" -Level 'WARN'
        }
    }

    # Make sure the required PowerShell modules are available.
    foreach ($ModuleName in @('PSWindowsUpdate', 'FU.WhyAmIBlocked')) {
        try {
            $ModuleReady = Ensure-RequiredModule -ModuleName $ModuleName
            if (-not $ModuleReady) {
                $HadFailures = $true
            }
        }
        catch {
            $HadFailures = $true
            Write-Log -Message "Module preparation failed for '$ModuleName': $($_.Exception.Message)" -Level 'WARN'
        }
    }

    # Import PSWindowsUpdate when available so update commands can be used.
    if (Get-Module -ListAvailable -Name 'PSWindowsUpdate') {
        try {
            Import-Module -Name 'PSWindowsUpdate' -Force -ErrorAction Stop
            Write-Log -Message "Module 'PSWindowsUpdate' imported." -Level 'OK'
        }
        catch {
            $HadFailures = $true
            Write-Log -Message "Failed to import 'PSWindowsUpdate': $($_.Exception.Message)" -Level 'WARN'
        }
    }

    # Reset Windows Update components if the command is available.
    if (Get-Command -Name Reset-WUComponents -ErrorAction SilentlyContinue) {
        try {
            Write-Log -Message 'Resetting Windows Update components.'
            Reset-WUComponents -ErrorAction Stop | Out-Null
            Write-Log -Message 'Windows Update components were reset.' -Level 'OK'
        }
        catch {
            $HadFailures = $true
            Write-Log -Message "Reset-WUComponents failed: $($_.Exception.Message)" -Level 'WARN'
        }
    } else {
        Write-Log -Message 'Reset-WUComponents command is not available.' -Level 'WARN'
    }

    # Attempt to scan for and install software updates when the command is available.
    if (Get-Command -Name Get-WindowsUpdate -ErrorAction SilentlyContinue) {
        try {
            Write-Log -Message 'Checking for and installing pending software updates.'
            Get-WindowsUpdate -Install -AcceptAll -UpdateType Software -IgnoreReboot -ErrorAction Stop | Out-Null
            Write-Log -Message 'Windows Update scan/install step completed.' -Level 'OK'
        }
        catch {
            $HadFailures = $true
            Write-Log -Message "Get-WindowsUpdate failed: $($_.Exception.Message)" -Level 'WARN'
        }
    } else {
        Write-Log -Message 'Get-WindowsUpdate command is not available.' -Level 'WARN'
        $HadFailures = $true
    }

    if ($HadFailures) {
        Write-Log -Message 'One or more Windows Update remediation steps reported warnings or failures.' -Level 'FAIL'
        Write-Log -Message '=== Remediation END (Exit 1) ==='
        exit 1
    }

    Write-Log -Message 'Windows Update remediation completed successfully.' -Level 'OK'
    Write-Log -Message '=== Remediation END (Exit 0) ==='
    exit 0
}
catch {
    Write-Log -Message "Remediation error: $($_.Exception.Message)" -Level 'FAIL'
    Write-Log -Message '=== Remediation END (Exit 1) ==='
    exit 1
}
#endregion ================= FIRST REMEDIATION BLOCK =================
