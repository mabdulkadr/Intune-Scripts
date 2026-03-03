<#
.SYNOPSIS
    Detects whether Windows system health repair is required.

.DESCRIPTION
    This detection script checks for a pending reboot state and runs
    `DISM /CheckHealth` to identify whether component store issues may require
    remediation. It is intended for use with Intune Remediations.

    Exit codes:
    - Exit 0: Compliant
    - Exit 1: Non-compliant or detection failed

.RUN AS
    System

.EXAMPLE
    .\WindowsSystemHealth--Detect.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.0
#>

#region ========================= CONFIGURATION =========================
# Use a fixed script name so logging stays consistent when Intune stages the script under a temporary local file name.
$ScriptName     = 'WindowsSystemHealth--Detect.ps1'
$ScriptBaseName = 'WindowsSystemHealth--Detect'

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

#region ===================== FIRST DETECTION BLOCK =====================
try {
    if (-not (Test-Path -Path $LogDirectory)) {
        New-Item -Path $LogDirectory -ItemType Directory -Force | Out-Null
    }

    Write-Log -Message '=== Detection START ==='
    Write-Log -Message "Script: $ScriptName"
    Write-Log -Message "Log file: $LogFilePath"
    Write-Log -Message "Computer name: $env:COMPUTERNAME"

    $NeedsRemediation = $false

    # Check whether a pending reboot already indicates an incomplete repair state.
    $RebootPending = Test-RebootPending
    Write-Log -Message "Reboot pending: $RebootPending"
    if ($RebootPending) {
        Write-Log -Message 'A pending reboot was detected.' -Level 'WARN'
        $NeedsRemediation = $true
    }

    # Run the lightweight DISM health check as a quick component store validation.
    Write-Log -Message 'Running DISM CheckHealth.'
    $DismResult = Invoke-ExternalCommand -FilePath 'dism.exe' -Arguments '/Online /Cleanup-Image /CheckHealth'
    Write-Log -Message "DISM CheckHealth exit code: $($DismResult.ExitCode)"

    if ($DismResult.ExitCode -ne 0) {
        Write-Log -Message 'DISM CheckHealth returned a non-zero exit code.' -Level 'WARN'
        $NeedsRemediation = $true
    }

    # Use a best-effort text check because DISM messaging may still indicate repairable corruption.
    if ($DismResult.StdOut -match 'repairable|corruption detected|component store corruption') {
        Write-Log -Message 'DISM output indicates repairable corruption.' -Level 'WARN'
        $NeedsRemediation = $true
    }

    if ($NeedsRemediation) {
        Write-Log -Message 'System health remediation is required.' -Level 'WARN'
        Write-Log -Message '=== Detection END (Exit 1) ==='
        exit 1
    }

    Write-Log -Message 'System health is compliant. No remediation is required.' -Level 'OK'
    Write-Log -Message '=== Detection END (Exit 0) ==='
    exit 0
}
catch {
    Write-Log -Message "Detection error: $($_.Exception.Message)" -Level 'FAIL'
    Write-Log -Message '=== Detection END (Exit 1) ==='
    exit 1
}
#endregion ================== FIRST DETECTION BLOCK ==================
