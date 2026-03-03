<#
.SYNOPSIS
    Repairs Windows component store and system file integrity issues.

.DESCRIPTION
    This remediation script runs `DISM /RestoreHealth` followed by
    `SFC /scannow`, then checks whether a reboot is required to finalize the
    repair. It is intended for use with Intune Remediations.

    Exit codes:
    - Exit 0: Completed successfully
    - Exit 1: Remediation failed
    - Exit 3010: Reboot required to finalize repairs

.RUN AS
    System

.EXAMPLE
    .\WindowsSystemHealth--Remediate.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.0
#>

#region ========================= CONFIGURATION =========================
# Use a fixed script name so logging stays consistent when Intune stages the script under a temporary local file name.
$ScriptName     = 'WindowsSystemHealth--Remediate.ps1'
$ScriptBaseName = 'WindowsSystemHealth--Remediate'

# Store logs under the system drive instead of hard-coding C:.
$SystemDrive   = if ($env:SystemDrive) { $env:SystemDrive } else { 'C:' }
$LogFolderName = 'Windows-SystemHealth-Repair'
$LogDirectory  = Join-Path $SystemDrive "Intune\$LogFolderName"
$LogFilePath   = Join-Path $LogDirectory "$ScriptBaseName.txt"
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

function Invoke-ExternalCommand {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,

        [Parameter(Mandatory = $true)]
        [string]$Arguments
    )

    $StartInfo = New-Object System.Diagnostics.ProcessStartInfo
    $StartInfo.FileName               = $FilePath
    $StartInfo.Arguments              = $Arguments
    $StartInfo.UseShellExecute        = $false
    $StartInfo.RedirectStandardOutput = $true
    $StartInfo.RedirectStandardError  = $true
    $StartInfo.CreateNoWindow         = $true

    $Process = New-Object System.Diagnostics.Process
    $Process.StartInfo = $StartInfo

    [void]$Process.Start()
    $StandardOutput = $Process.StandardOutput.ReadToEnd()
    $StandardError  = $Process.StandardError.ReadToEnd()
    $Process.WaitForExit()

    return [PSCustomObject]@{
        ExitCode = $Process.ExitCode
        StdOut   = $StandardOutput
        StdErr   = $StandardError
    }
}

function Test-RebootPending {
    $IsPending = $false

    if (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending') {
        $IsPending = $true
    }

    if (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired') {
        $IsPending = $true
    }

    try {
        $PendingRename = Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -Name 'PendingFileRenameOperations' -ErrorAction SilentlyContinue
        if ($PendingRename -and $PendingRename.PendingFileRenameOperations) {
            $IsPending = $true
        }
    }
    catch {
    }

    return $IsPending
}
#endregion ==================== HELPER FUNCTIONS =======================

#region ==================== FIRST REMEDIATION BLOCK ====================
try {
    if (-not (Test-Path -Path $LogDirectory)) {
        New-Item -Path $LogDirectory -ItemType Directory -Force | Out-Null
    }

    Write-Log -Message '=== Remediation START ==='
    Write-Log -Message "Script: $ScriptName"
    Write-Log -Message "Log file: $LogFilePath"
    Write-Log -Message "Computer name: $env:COMPUTERNAME"

    # Capture the reboot state before repairs begin.
    $RebootPendingBefore = Test-RebootPending
    Write-Log -Message "Reboot pending before repair: $RebootPendingBefore"
    if ($RebootPendingBefore) {
        Write-Log -Message 'A reboot is already pending before repair starts.' -Level 'WARN'
    }

    # Repair the component store first.
    Write-Log -Message 'Running DISM RestoreHealth.'
    $DismResult = Invoke-ExternalCommand -FilePath 'dism.exe' -Arguments '/Online /Cleanup-Image /RestoreHealth'
    Write-Log -Message "DISM RestoreHealth exit code: $($DismResult.ExitCode)"

    if ($DismResult.ExitCode -ne 0) {
        Write-Log -Message 'DISM RestoreHealth failed. Remediation stopped.' -Level 'FAIL'
        Write-Log -Message '=== Remediation END (Exit 1) ==='
        exit 1
    }

    Write-Log -Message 'DISM RestoreHealth completed successfully.' -Level 'OK'

    # Run SFC after DISM to repair remaining file integrity issues.
    Write-Log -Message 'Running SFC Scannow.'
    $SfcResult = Invoke-ExternalCommand -FilePath 'sfc.exe' -Arguments '/scannow'
    Write-Log -Message "SFC exit code: $($SfcResult.ExitCode)"

    if ($SfcResult.StdOut -match 'did not find any integrity violations') {
        Write-Log -Message 'SFC found no integrity violations.' -Level 'OK'
    }
    elseif ($SfcResult.StdOut -match 'successfully repaired') {
        Write-Log -Message 'SFC repaired integrity violations successfully.' -Level 'OK'
    }
    elseif ($SfcResult.StdOut -match 'unable to fix some') {
        Write-Log -Message 'SFC could not repair some files. Review CBS.log.' -Level 'FAIL'
        Write-Log -Message '=== Remediation END (Exit 1) ==='
        exit 1
    }
    else {
        Write-Log -Message 'SFC completed with an unrecognized result. Review the log output if needed.' -Level 'WARN'
    }

    # Re-check reboot state after repairs complete.
    $RebootPendingAfter = Test-RebootPending
    Write-Log -Message "Reboot pending after repair: $RebootPendingAfter"

    if ($RebootPendingBefore -or $RebootPendingAfter) {
        Write-Log -Message 'A reboot is required to finalize repairs.' -Level 'WARN'
        Write-Log -Message '=== Remediation END (Exit 3010) ==='
        exit 3010
    }

    Write-Log -Message 'Windows system health remediation completed successfully.' -Level 'OK'
    Write-Log -Message '=== Remediation END (Exit 0) ==='
    exit 0
}
catch {
    Write-Log -Message "Remediation error: $($_.Exception.Message)" -Level 'FAIL'
    Write-Log -Message '=== Remediation END (Exit 1) ==='
    exit 1
}
#endregion ================= FIRST REMEDIATION BLOCK =================
