<#
.SYNOPSIS
    Validate whether the device time zone is set to W. Europe Standard Time.

.DESCRIPTION
    This remediation script currently keeps the same behavior as the original
    community script: it reads the Windows time zone configuration from:

        HKLM:\SYSTEM\CurrentControlSet\Control\TimeZoneInformation\TimeZoneKeyName

    and returns a compliant or non-compliant result based on whether the value
    matches `W. Europe Standard Time`.

    Important:
    This script does not change the time zone. Its logic is intentionally kept
    unchanged from the original file.

    Exit codes:
    - Exit 0: Compliant
    - Exit 1: Not Compliant

.RUN AS
    Admin

.EXAMPLE
    .\GetTimeZoneWEurope--Remediate.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.0
#>

#region ========================= CONFIGURATION =========================
# Use a fixed script name so logging stays consistent when Intune stages the script under a temporary local file name.
$ScriptName     = 'GetTimeZoneWEurope--Remediate.ps1'
$ScriptBaseName = 'GetTimeZoneWEurope--Remediate'

# Store logs under the Windows system drive.
$SystemDrive = if ([string]::IsNullOrWhiteSpace($env:SystemDrive)) {
    [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\')
}
else {
    $env:SystemDrive.TrimEnd('\')
}

# Script-specific logging location.
$SolutionName = 'GetTimeZoneWEurope'
$BasePath     = Join-Path (Join-Path $SystemDrive 'Intune') $SolutionName
$LogFile      = Join-Path $BasePath ("{0}.txt" -f $ScriptBaseName)

# Registry values used by the original script.
$Path  = 'HKLM:\SYSTEM\CurrentControlSet\Control\TimeZoneInformation'
$Name  = 'TimeZoneKeyName'
$Type  = 'STRING'
$Value = 'W. Europe Standard Time'
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

try {
    $Registry = Get-ItemProperty -Path $Path -Name $Name -ErrorAction Stop | Select-Object -ExpandProperty $Name

    if ($Registry -eq $Value) {
        Write-Output 'Compliant'
        Write-Log -Message 'Compliant: time zone already matches W. Europe Standard Time.' -Level 'OK'
        Write-Log -Message '=== Remediation END (Exit 0) ==='
        exit 0
    }
    else {
        Write-Warning 'Not Compliant'
        Write-Log -Message 'Non-compliant: time zone does not match W. Europe Standard Time.' -Level 'WARN'
        Write-Log -Message '=== Remediation END (Exit 1) ==='
        exit 1
    }
}
catch {
    Write-Warning 'Not Compliant'
    Write-Log -Message ("Remediation error: {0}" -f $_.Exception.Message) -Level 'WARN'
    Write-Log -Message '=== Remediation END (Exit 1) ==='
    exit 1
}
#endregion ================= FIRST REMEDIATION BLOCK =================
