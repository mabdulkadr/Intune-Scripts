<#
.SYNOPSIS
    Start the Intune PushLaunch scheduled task to trigger a device sync.

.DESCRIPTION
    This remediation script looks for the `PushLaunch` scheduled task and starts
    it to force a new device sync.

    The script preserves the original behavior:
    - Exit 0 when the task starts successfully
    - Exit 1 when an exception occurs

.RUN AS
    System or User, based on the Intune assignment configuration.

.EXAMPLE
    .\DeviceAutoSyncer--Remediate.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.0
#>

#region ========================= CONFIGURATION =========================
# Scheduled task used by Intune device sync.
$TaskName = 'PushLaunch'

# Use a fixed script name so logging stays consistent when Intune stages the script under a temporary local file name.
$ScriptName     = 'DeviceAutoSyncer--Remediate.ps1'
$ScriptBaseName = 'DeviceAutoSyncer--Remediate'

# Detect the Windows system drive automatically instead of hard-coding C:.
$SystemDrive = if ([string]::IsNullOrWhiteSpace($env:SystemDrive)) {
    [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\')
}
else {
    $env:SystemDrive.TrimEnd('\')
}

# Script-specific logging location shared by the Detect and Remediate scripts.
$SolutionName = 'DeviceAutoSyncer'
$BasePath     = Join-Path (Join-Path $SystemDrive 'Intune') $SolutionName
$LogFile      = Join-Path $BasePath ("{0}.txt" -f $ScriptBaseName)
#endregion ====================== CONFIGURATION ======================

#region ======================= HELPER FUNCTIONS =======================
# Ensure the log directory exists before writing entries.
function Initialize-LogFile {
    if (-not (Test-Path -LiteralPath $BasePath)) {
        New-Item -Path $BasePath -ItemType Directory -Force | Out-Null
    }
}

function Start-LogRun {
    # Add a visual separator so each run is easier to scan in the same log file.
    Initialize-LogFile

    if (Test-Path -LiteralPath $LogFile) {
        $existingLog = Get-Item -LiteralPath $LogFile -ErrorAction SilentlyContinue
        if ($existingLog -and $existingLog.Length -gt 0) {
            Add-Content -Path $LogFile -Value '' -Encoding UTF8
        }
    }

    Add-Content -Path $LogFile -Value ('=' * 78) -Encoding UTF8
}

# Write a colorized console message and persist it to the log file.
function Write-Log {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [ValidateSet('INFO', 'OK', 'WARN', 'FAIL')]
        [string]$Level = 'INFO'
    )

    $ts   = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $line = "[{0}] [{1}] {2}" -f $ts, $Level, $Message

    switch ($Level) {
        'OK'   { Write-Host $line -ForegroundColor Green }
        'WARN' { Write-Host $line -ForegroundColor Yellow }
        'FAIL' { Write-Host $line -ForegroundColor Red }
        default { Write-Host $line -ForegroundColor Cyan }
    }

    Add-Content -Path $LogFile -Value $line -Encoding UTF8
}
#endregion ==================== HELPER FUNCTIONS ====================

#region ==================== FIRST REMEDIATION BLOCK ====================
Start-LogRun
Write-Log -Level 'INFO' -Message '=== Remediation START ==='
Write-Log -Level 'INFO' -Message ("Script: {0}" -f $ScriptName)
Write-Log -Level 'INFO' -Message ("Log file: {0}" -f $LogFile)
Write-Log -Level 'INFO' -Message ("Scheduled task target: {0}" -f $TaskName)

try {
    Get-ScheduledTask | Where-Object { $_.TaskName -eq $TaskName } | Start-ScheduledTask
    Write-Log -Level 'OK' -Message 'The PushLaunch task started successfully.'
    Write-Log -Level 'INFO' -Message '=== Remediation END (Exit 0) ==='
    exit 0
}
catch {
    Write-Error $_
    Write-Log -Level 'FAIL' -Message ("Remediation error: {0}" -f $_.Exception.Message)
    Write-Log -Level 'INFO' -Message '=== Remediation END (Exit 1) ==='
    exit 1
}
#endregion ================= FIRST REMEDIATION BLOCK =================
