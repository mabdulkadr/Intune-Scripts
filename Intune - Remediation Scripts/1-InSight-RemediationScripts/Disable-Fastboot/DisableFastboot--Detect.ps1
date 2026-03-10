<#
.SYNOPSIS
    Detect whether Windows Fast Startup (Fastboot) is disabled.

.DESCRIPTION
    This detection script checks the `HiberbootEnabled` registry value under the
    Windows power configuration key.

    The device is treated as compliant only when Fast Startup is disabled and
    the registry value matches the configured expected value.

    Exit codes:
    - Exit 0: Compliant
    - Exit 1: Not Compliant

.RUN AS
    System or User, based on the Intune assignment configuration.

.EXAMPLE
    .\DisableFastboot--Detect.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.0
#>

#region ========================= CONFIGURATION =========================
# Registry path that stores the Fast Startup setting.
$RegPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power'

# Registry value name used for Fast Startup.
$RegName = 'HiberbootEnabled'

# Expected compliant registry value when Fast Startup is disabled.
$RegValue = 0

# Use a fixed script name so logging stays consistent when Intune stages the script under a temporary local file name.
$ScriptName     = 'DisableFastboot--Detect.ps1'
$ScriptBaseName = 'DisableFastboot--Detect'

# Detect the Windows system drive automatically instead of hard-coding C:.
$SystemDrive = if ([string]::IsNullOrWhiteSpace($env:SystemDrive)) {
    [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\')
}
else {
    $env:SystemDrive.TrimEnd('\')
}

# Script-specific logging location shared by the Detect and Remediate scripts.
$SolutionName = 'DisableFastboot'
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

#region ===================== FIRST DETECTION BLOCK =====================
Start-LogRun
Write-Log -Level 'INFO' -Message '=== Detection START ==='
Write-Log -Level 'INFO' -Message ("Script: {0}" -f $ScriptName)
Write-Log -Level 'INFO' -Message ("Log file: {0}" -f $LogFile)
Write-Log -Level 'INFO' -Message ("Registry path: {0}" -f $RegPath)
Write-Log -Level 'INFO' -Message ("Registry name: {0}" -f $RegName)

try {
    $Registry = Get-ItemProperty -Path $RegPath -Name $RegName -ErrorAction Stop | Select-Object -ExpandProperty $RegName
    Write-Log -Level 'INFO' -Message ("Current value: {0}" -f $Registry)

    if ($Registry -eq $RegValue) {
        Write-Output 'Compliant'
        Write-Log -Level 'OK' -Message 'Fast Startup is disabled as required.'
        Write-Log -Level 'INFO' -Message '=== Detection END (Exit 0) ==='
        exit 0
    }

    Write-Warning 'Not Compliant'
    Write-Log -Level 'WARN' -Message 'Fast Startup is still enabled or has an unexpected value.'
    Write-Log -Level 'INFO' -Message '=== Detection END (Exit 1) ==='
    exit 1
}
catch {
    Write-Warning 'Not Compliant'
    Write-Log -Level 'WARN' -Message 'The HiberbootEnabled registry value is missing or could not be read.'
    Write-Log -Level 'INFO' -Message '=== Detection END (Exit 1) ==='
    exit 1
}
#endregion ================== FIRST DETECTION BLOCK ==================
