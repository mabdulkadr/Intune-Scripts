<#
.SYNOPSIS
    Disable Windows Fast Startup (Fastboot) through the registry.

.DESCRIPTION
    This remediation script creates or updates the `HiberbootEnabled` registry
    value under the Windows power configuration key so Fast Startup remains
    disabled.

    The script preserves the original behavior by writing the value silently.

.RUN AS
    System or User, based on the Intune assignment configuration.

.EXAMPLE
    .\DisableFastboot--Remediate.ps1

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

# Registry value data that disables Fast Startup.
$RegValue = 0

# Registry value type.
$RegType = 'DWord'

# Use a fixed script name so logging stays consistent when Intune stages the script under a temporary local file name.
$ScriptName     = 'DisableFastboot--Remediate.ps1'
$ScriptBaseName = 'DisableFastboot--Remediate'

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

#region ==================== FIRST REMEDIATION BLOCK ====================
Start-LogRun
Write-Log -Level 'INFO' -Message '=== Remediation START ==='
Write-Log -Level 'INFO' -Message ("Script: {0}" -f $ScriptName)
Write-Log -Level 'INFO' -Message ("Log file: {0}" -f $LogFile)
Write-Log -Level 'INFO' -Message ("Registry path: {0}" -f $RegPath)
Write-Log -Level 'INFO' -Message ("Registry name: {0}" -f $RegName)
Write-Log -Level 'INFO' -Message ("Registry type: {0}" -f $RegType)

New-ItemProperty -LiteralPath $RegPath -Name $RegName -Value $RegValue -PropertyType $RegType -Force -ErrorAction SilentlyContinue | Out-Null

Write-Log -Level 'OK' -Message 'The HiberbootEnabled registry value was created or updated.'
Write-Log -Level 'INFO' -Message '=== Remediation END ==='
#endregion ================= FIRST REMEDIATION BLOCK =================
