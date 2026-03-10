<#
.SYNOPSIS
    Always trigger the Clear Recycle Bin remediation workflow.

.DESCRIPTION
    This detection script intentionally always returns a non-compliant result so
    the paired remediation script runs every time the proactive remediation
    package is evaluated.

    Exit codes:
    - Exit 1: Always trigger remediation

.RUN AS
    User

.EXAMPLE
    .\InvokeClearRecycleBin--Detect.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.0
#>

#region ========================= CONFIGURATION =========================
# Use a fixed script name so logging stays consistent when Intune stages the script under a temporary local file name.
$ScriptName     = 'InvokeClearRecycleBin--Detect.ps1'
$ScriptBaseName = 'InvokeClearRecycleBin--Detect'

# Store the user-context log under the current user's temp folder.
$LogRoot      = Join-Path $env:TEMP 'Logs'
$SolutionName = 'InvokeClearRecycleBin'
$BasePath     = Join-Path $LogRoot $SolutionName
$LogFile      = Join-Path $BasePath ("{0}_{1}.txt" -f $env:COMPUTERNAME, $ScriptBaseName)
#endregion ====================== CONFIGURATION ======================

#region ======================= HELPER FUNCTIONS =======================
# Ensure the log directory and log file exist before writing entries.
function Initialize-LogFile {
    if (-not (Test-Path -LiteralPath $LogRoot)) {
        New-Item -Path $LogRoot -ItemType Directory -Force | Out-Null
    }

    if (-not (Test-Path -LiteralPath $BasePath)) {
        New-Item -Path $BasePath -ItemType Directory -Force | Out-Null
    }

    if (-not (Test-Path -LiteralPath $LogFile)) {
        New-Item -Path $LogFile -ItemType File -Force | Out-Null
    }
}

# Add a visual separator so each run is easier to scan in the same log file.
function Start-LogRun {
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

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $line      = "[$timestamp] [$Level] $Message"

    switch ($Level) {
        'OK'   { Write-Host $line -ForegroundColor Green }
        'WARN' { Write-Host $line -ForegroundColor Yellow }
        'FAIL' { Write-Host $line -ForegroundColor Red }
        default { Write-Host $line -ForegroundColor Cyan }
    }

    Add-Content -Path $LogFile -Value $line -Encoding UTF8
}
#endregion ==================== HELPER FUNCTIONS ====================

#region ===================== FIRST DETECTION BLOCK =====================
Start-LogRun
Write-Log -Message '=== Detection START ==='
Write-Log -Message "Script: $ScriptName"
Write-Log -Message "Log file: $LogFile"
Write-Host 'Script will always be triggered'
Write-Log -Message 'This detection is configured to always trigger remediation.' -Level 'WARN'
Write-Log -Message '=== Detection END (Exit 1) ==='
exit 1
#endregion ================== FIRST DETECTION BLOCK ==================
