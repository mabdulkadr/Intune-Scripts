<#
.SYNOPSIS
    Detect whether Office client telemetry is disabled for the current user.

.DESCRIPTION
    This detection script checks the per-user Office policy value:

        HKCU:\Software\Policies\Microsoft\office\common\clienttelemetry\DisableTelemetry

    The user is compliant only when `DisableTelemetry` exists and equals `1`.

    This setting is used to prevent Microsoft 365 / Office from sending client
    telemetry under the configured policy path.

    Exit codes:
    - Exit 0: Compliant
    - Exit 1: Not Compliant

.RUN AS
    User

.EXAMPLE
    .\GetOfficeTelemetry--Detect.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.0
#>

#region ========================= CONFIGURATION =========================
# Registry values used by the original script.
$Path  = 'HKCU:\Software\Policies\Microsoft\office\common\clienttelemetry'
$Name  = 'DisableTelemetry'
$Type  = 'DWORD'
$Value = 1

# Use a fixed script name so logging stays consistent when Intune stages the script under a temporary local file name.
$ScriptName     = 'GetOfficeTelemetry--Detect.ps1'
$ScriptBaseName = 'GetOfficeTelemetry--Detect'

# Detect the Windows system drive automatically instead of hard-coding C: for logging.
$SystemDrive = if ([string]::IsNullOrWhiteSpace($env:SystemDrive)) {
    [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\')
}
else {
    $env:SystemDrive.TrimEnd('\')
}

# Script-specific logging location.
$SolutionName = 'GetOfficeTelemetry'
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

#region ===================== FIRST DETECTION BLOCK =====================
Start-LogRun
Write-Log -Message '=== Detection START ==='
Write-Log -Message "Script: $ScriptName"
Write-Log -Message "Log file: $LogFile"
Write-Log -Message "Registry path: $Path"
Write-Log -Message "Registry value: $Name"

Try {
    $Registry = Get-ItemProperty -Path $Path -Name $Name -ErrorAction Stop | Select-Object -ExpandProperty $Name

    if ($Registry -eq $Value) {
        Write-Log -Message 'Office telemetry is disabled for the current user.' -Level 'OK'
        Write-Log -Message '=== Detection END (Exit 0) ==='
        Write-Output 'Compliant'
        Exit 0
    }

    Write-Log -Message 'Office telemetry is not set to the expected value.' -Level 'WARN'
    Write-Log -Message '=== Detection END (Exit 1) ==='
    Write-Warning 'Not Compliant'
    Exit 1
}
Catch {
    Write-Log -Message ("Detection error or missing value: {0}" -f $_.Exception.Message) -Level 'WARN'
    Write-Log -Message '=== Detection END (Exit 1) ==='
    Write-Warning 'Not Compliant'
    Exit 1
}
#endregion ================== FIRST DETECTION BLOCK ==================
