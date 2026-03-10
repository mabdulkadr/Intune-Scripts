<#
.SYNOPSIS
    Enable location access and configure automatic time zone through the registry.

.DESCRIPTION
    This remediation script writes the registry values required by the
    AutomaticTimezone workflow.

    It sets location access to `Allow` and updates the `tzautoupdate` service
    startup value so automatic time zone detection can be used.

.RUN AS
    System

.EXAMPLE
    .\AutomaticTimezone--Remediate.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.0
#>

#region ========================= CONFIGURATION =========================
# Registry path and value used to enable location access.
$regpath  = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location'
$regname  = 'Value'
$regvalue = 'Allow'

# Registry path and value used to enable automatic time zone.
$regpath2  = 'HKLM:\SYSTEM\CurrentControlSet\Services\tzautoupdate'
$regname2  = 'start'
$regvalue2 = '3'

# Property types used by the target registry values.
$regtype  = 'STRING'
$regtype2 = 'DWORD'

# Use a fixed script name so logging stays consistent when Intune stages the script under a temporary local file name.
$ScriptName     = 'AutomaticTimezone--Remediate.ps1'
$ScriptBaseName = 'AutomaticTimezone--Remediate'

# Store logs under the system drive instead of hard-coding C:.
$SystemDrive = if ($env:SystemDrive) { $env:SystemDrive.TrimEnd('\') } else { 'C:' }

# Script-specific logging location.
$SolutionName = 'AutomaticTimezone'
$BasePath     = Join-Path (Join-Path $SystemDrive 'Intune') $SolutionName
$LogFile      = Join-Path $BasePath ('{0}.txt' -f $ScriptBaseName)
#endregion ====================== CONFIGURATION ======================

#region ========================= HELPER FUNCTIONS =========================
function Initialize-LogFile {
    if (-not (Test-Path -LiteralPath $BasePath)) {
        New-Item -Path $BasePath -ItemType Directory -Force | Out-Null
    }
    if (-not (Test-Path -LiteralPath $LogFile)) {
        New-Item -Path $LogFile -ItemType File -Force | Out-Null
    }
}

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

function Write-Log {
    param(
        [Parameter(Mandatory = $true)][string]$Message,
        [ValidateSet('INFO', 'OK', 'WARN', 'FAIL')][string]$Level = 'INFO'
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $line = "[$timestamp] [$Level] $Message"

    switch ($Level) {
        'OK'   { Write-Host $line -ForegroundColor Green }
        'WARN' { Write-Host $line -ForegroundColor Yellow }
        'FAIL' { Write-Host $line -ForegroundColor Red }
        default { Write-Host $line -ForegroundColor Cyan }
    }

    try { Add-Content -Path $LogFile -Value $line -Encoding UTF8 } catch {}
}
#endregion ====================== HELPER FUNCTIONS ======================

Start-LogRun
Write-Log -Level 'INFO' -Message '=== Remediation START ==='
Write-Log -Level 'INFO' -Message ('Script: {0}' -f $ScriptName)
Write-Log -Level 'INFO' -Message ('Log file: {0}' -f $LogFile)

#region ==================== FIRST REMEDIATION BLOCK ====================
New-ItemProperty -LiteralPath $regpath  -Name $regname  -Value $regvalue  -PropertyType $regtype  -Force -ErrorAction SilentlyContinue
New-ItemProperty -LiteralPath $regpath2 -Name $regname2 -Value $regvalue2 -PropertyType $regtype2 -Force -ErrorAction SilentlyContinue

Write-Log -Level 'OK' -Message 'Registry values were written for automatic time zone configuration.'
Write-Log -Level 'INFO' -Message '=== Remediation END ==='
#endregion ================= FIRST REMEDIATION BLOCK =================
