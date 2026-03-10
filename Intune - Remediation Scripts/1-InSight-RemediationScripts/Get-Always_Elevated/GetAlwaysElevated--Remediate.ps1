<#
.SYNOPSIS
    Create the Installer policy key and set AlwaysInstallElevated to 0.

.DESCRIPTION
    This remediation script creates the `Installer` policy key under:

        HKLM:\SOFTWARE\Policies\Microsoft\Windows\

    It then writes the `AlwaysInstallElevated` value as a `DWORD` with the
    value `0`.

    The original command sequence is preserved:
    - `New-Item -Path $Path -Name $Key`
    - `New-ItemProperty -Path $FullPath -Name $Name -Value $Value -PropertyType $Type`

.RUN AS
    System

.EXAMPLE
    .\GetAlwaysElevated--Remediate.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.0
#>

#region ========================= CONFIGURATION =========================
# Use a fixed script name so logging stays consistent when Intune stages the script under a temporary local file name.
$ScriptName     = 'GetAlwaysElevated--Remediate.ps1'
$ScriptBaseName = 'GetAlwaysElevated--Remediate'

# Detect the Windows system drive automatically instead of hard-coding C:.
$SystemDrive = if ([string]::IsNullOrWhiteSpace($env:SystemDrive)) {
    [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\')
}
else {
    $env:SystemDrive.TrimEnd('\')
}

# Registry values used by the original script.
$Path     = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\'
$Key      = 'Installer'
$FullPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Installer'
$Name     = 'AlwaysInstallElevated'
$Type     = 'DWORD'
$Value    = '0'

# Script-specific logging location.
$SolutionName = 'GetAlwaysElevated'
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
Write-Log -Message "Base registry path: $Path"
Write-Log -Message "Target registry path: $FullPath"

# Preserve the original remediation commands.
New-Item -Path $Path -Name $Key
Write-Log -Message 'Installer key creation command was executed.'

New-ItemProperty -Path $FullPath -Name $Name -Value $Value -PropertyType $Type
Write-Log -Message 'AlwaysInstallElevated registry value creation command was executed.' -Level 'OK'

Write-Log -Message '=== Remediation END ==='
#endregion ================= FIRST REMEDIATION BLOCK =================
