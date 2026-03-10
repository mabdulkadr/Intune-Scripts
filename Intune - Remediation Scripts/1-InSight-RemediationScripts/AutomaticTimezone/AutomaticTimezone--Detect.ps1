<#
.SYNOPSIS
    Detect whether location access and automatic time zone are configured correctly.

.DESCRIPTION
    This detection script checks the two registry values used by the AutomaticTimezone
    remediation workflow.

    It verifies that location access is set to `Allow` and that the `tzautoupdate`
    service startup value is set to `3` before returning a compliant result.

.RUN AS
    System

.EXAMPLE
    .\AutomaticTimezone--Detect.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.0
#>

#region ========================= CONFIGURATION =========================
# Registry path and value used to confirm location access is enabled.
$regpath  = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location'
$regname  = 'Value'
$regvalue = 'Allow'

# Registry path and value used to confirm automatic time zone is enabled.
$regpath2  = 'HKLM:\SYSTEM\CurrentControlSet\Services\tzautoupdate'
$regname2  = 'start'
$regvalue2 = '3'

# Use a fixed script name so logging stays consistent when Intune stages the script under a temporary local file name.
$ScriptName     = 'AutomaticTimezone--Detect.ps1'
$ScriptBaseName = 'AutomaticTimezone--Detect'

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
Write-Log -Level 'INFO' -Message '=== Detection START ==='
Write-Log -Level 'INFO' -Message ('Script: {0}' -f $ScriptName)
Write-Log -Level 'INFO' -Message ('Log file: {0}' -f $LogFile)

#region ===================== FIRST DETECTION BLOCK =====================
try {
    $Registry  = Get-ItemProperty -Path $regpath -Name $regname -ErrorAction Stop | Select-Object -ExpandProperty $regname
    $Registry2 = Get-ItemProperty -Path $regpath2 -Name $regname2 -ErrorAction Stop | Select-Object -ExpandProperty $regname2

    if (($Registry -eq $regvalue) -and ($Registry2 -eq $regvalue2)) {
        Write-Output 'Compliant'
        Write-Log -Level 'OK' -Message 'Location access and automatic time zone are configured as expected.'
        Write-Log -Level 'INFO' -Message '=== Detection END (Exit 0) ==='
        Exit 0
    }
    else {
        Write-Warning 'Not Compliant'
        Write-Log -Level 'WARN' -Message 'One or more registry values do not match the required configuration.'
        Write-Log -Level 'INFO' -Message '=== Detection END (Exit 1) ==='
        Exit 1
    }
}
catch {
    Write-Warning 'Not Compliant'
    Write-Log -Level 'FAIL' -Message ('Detection error: {0}' -f $_.Exception.Message)
    Write-Log -Level 'INFO' -Message '=== Detection END (Exit 1) ==='
    Exit 1
}
#endregion ================== FIRST DETECTION BLOCK ==================
