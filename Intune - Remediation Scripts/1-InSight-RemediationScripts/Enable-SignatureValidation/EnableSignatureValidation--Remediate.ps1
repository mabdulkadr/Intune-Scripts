<#
.SYNOPSIS
    Create the Wintrust configuration entries used to enable signature validation padding checks.

.DESCRIPTION
    This remediation script creates the Wintrust `Config` paths if they do not
    already exist and writes the `EnableCertPaddingCheck` value as `1`.

    It keeps the original script behavior exactly:
    - It only writes values when a target path does not already exist
    - It then schedules a restart in 45 minutes

.RUN AS
    System

.EXAMPLE
    .\EnableSignatureValidation--Remediate.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.0
#>

#region ========================= CONFIGURATION =========================
# Use a fixed script name so logging stays consistent when Intune stages the script under a temporary local file name.
$ScriptName     = 'EnableSignatureValidation--Remediate.ps1'
$ScriptBaseName = 'EnableSignatureValidation--Remediate'

# Detect the Windows system drive automatically instead of hard-coding C:.
$SystemDrive = if ([string]::IsNullOrWhiteSpace($env:SystemDrive)) {
    [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\')
}
else {
    $env:SystemDrive.TrimEnd('\')
}

# Registry values used by the original script.
$Path  = 'Registry::HKEY_LOCAL_MACHINE\Software\Microsoft\Cryptography\Wintrust\Config', 'Registry::HKEY_LOCAL_MACHINE\Software\Wow6432Node\Microsoft\Cryptography\Wintrust\Config'
$Name  = 'EnableCertPaddingCheck'
$Value = '1'

# Script-specific logging location.
$SolutionName = 'EnableSignatureValidation'
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

foreach ($i in $Path) {
    Write-Log -Message "Processing registry path: $i"

    if (!(Test-Path $i)) {
        New-Item -Path $i -Name 'Config' -Force | Out-Null
        New-ItemProperty -Path $i -Name $Name -Value $Value -Force | Out-Null
        Write-Log -Message 'Missing path was created and signature validation was enabled.' -Level 'OK'
    }
    else {
        Write-Log -Message 'Registry path already exists. Original script leaves it unchanged.'
    }
}

Write-Log -Message 'Scheduling restart in 45 minutes.'
shutdown.exe /r /t 2700 /c "I am afraid there is a critical sytem patch requiring a reboot in 45 minutes"

Write-Log -Message '=== Remediation END ==='
#endregion ================= FIRST REMEDIATION BLOCK =================
