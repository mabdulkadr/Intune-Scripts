<#
.SYNOPSIS
    Enable Microsoft Defender real-time protection.

.DESCRIPTION
    This remediation script enables Microsoft Defender real-time protection using:

        Set-MpPreference -DisableRealtimeMonitoring $false

    The original script reports success or failure using the version marker `R1`
    and keeps the same `try/catch` flow and exit codes.

.RUN AS
    System

.EXAMPLE
    .\GetRealTimeProtection--Remediate.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.0
#>

#region ========================= CONFIGURATION =========================
# Version marker preserved from the original script output.
$version = 'R1'

# Use a fixed script name so logging stays consistent when Intune stages the script under a temporary local file name.
$ScriptName     = 'GetRealTimeProtection--Remediate.ps1'
$ScriptBaseName = 'GetRealTimeProtection--Remediate'

# Detect the Windows system drive automatically instead of hard-coding C: for logging.
$SystemDrive = if ([string]::IsNullOrWhiteSpace($env:SystemDrive)) {
    [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\')
}
else {
    $env:SystemDrive.TrimEnd('\')
}

# Script-specific logging location.
$SolutionName = 'GetRealTimeProtection'
$BasePath     = Join-Path (Join-Path $SystemDrive 'Intune') $SolutionName
$LogFile      = Join-Path $BasePath ("{0}.txt" -f $ScriptBaseName)
#endregion ====================== CONFIGURATION ======================

#region ======================= HELPER FUNCTIONS =======================
# Ensure the log directory and log file exist before writing entries.
function Initialize-LogFile {
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
    $line = "[{0}] [{1}] {2}" -f $timestamp, $Level, $Message

    switch ($Level) {
        'OK' { Write-Host $line -ForegroundColor Green }
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

try {
    Set-MpPreference -DisableRealtimeMonitoring $false
    Write-Log -Message 'Microsoft Defender real-time protection was enabled.' -Level 'OK'
    Write-Log -Message '=== Remediation END (Exit 0) ==='
    Write-Output "$version Remediated"
    exit 0
}
catch {
    Write-Log -Message ("Remediation error: {0}" -f $_.Exception.Message) -Level 'FAIL'
    Write-Log -Message '=== Remediation END (Exit 1) ==='
    Write-Output "$version Failed"
    exit 1
}
#endregion ================= FIRST REMEDIATION BLOCK =================
