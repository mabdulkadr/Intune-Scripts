<#
.SYNOPSIS
    Warn the current user, then run the original sign-out command.

.DESCRIPTION
    This remediation script keeps the same behavior as the original community
    script:
    - shows a simple message box to the current user
    - then runs the original sign-out command exactly as written

    The timeout value is displayed in the message shown to the user.

.RUN AS
    User

.EXAMPLE
    .\InvokeCurrentUserLoggedOff--Remediate.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.0
#>

#region ========================= CONFIGURATION =========================
# Use a fixed script name so logging stays consistent when Intune stages the script under a temporary local file name.
$ScriptName     = 'InvokeCurrentUserLoggedOff--Remediate.ps1'
$ScriptBaseName = 'InvokeCurrentUserLoggedOff--Remediate'

# Store the user-context log under the current user's temp folder.
$LogRoot      = Join-Path $env:TEMP 'Logs'
$SolutionName = 'InvokeCurrentUserLoggedOff'
$BasePath     = Join-Path $LogRoot $SolutionName
$LogFile      = Join-Path $BasePath ("{0}_{1}.txt" -f $env:COMPUTERNAME, $ScriptBaseName)

# Original user message timeout.
$timeout = 60
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

#region ==================== FIRST REMEDIATION BLOCK ====================
Start-LogRun
Write-Log -Message '=== Remediation START ==='
Write-Log -Message "Script: $ScriptName"
Write-Log -Message "Log file: $LogFile"

Write-Log -Message "Displaying the sign-out warning dialog for $timeout seconds."
Add-Type -AssemblyName PresentationCore,PresentationFramework
$msgBody = "You will be logged out in $timeout seconds"
[System.Windows.MessageBox]::Show($msgBody)

Write-Log -Message 'Running the original sign-out command.'
shutdown /L /f $timeout

Write-Log -Message '=== Remediation END ==='
#endregion ================= FIRST REMEDIATION BLOCK =================
