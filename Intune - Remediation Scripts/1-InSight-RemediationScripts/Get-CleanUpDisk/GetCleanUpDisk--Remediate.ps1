<#
.SYNOPSIS
    Configure and run Disk Cleanup for selected cleanup categories.

.DESCRIPTION
    This remediation script sets `StateFlags0001 = 2` for a predefined list of
    Disk Cleanup categories and then runs:

        CleanMgr.exe /sagerun:1

    The script keeps the original cleanup categories and execution flow exactly
    as they were defined in the source script.

.RUN AS
    System

.EXAMPLE
    .\GetCleanUpDisk--Remediate.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.0
#>

#region ========================= CONFIGURATION =========================
# Cleanup categories selected in the original script.
$cleanupTypeSelection = 'Temporary Sync Files', 'Downloaded Program Files', 'Memory Dump Files', 'Recycle Bin'

# Use a fixed script name so logging stays consistent when Intune stages the script under a temporary local file name.
$ScriptName     = 'GetCleanUpDisk--Remediate.ps1'
$ScriptBaseName = 'GetCleanUpDisk--Remediate'

# Detect the Windows system drive automatically instead of hard-coding C: for logging.
$SystemDrive = if ([string]::IsNullOrWhiteSpace($env:SystemDrive)) {
    [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\')
}
else {
    $env:SystemDrive.TrimEnd('\')
}

# Script-specific logging location.
$SolutionName = 'GetCleanUpDisk'
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
Write-Log -Message ("Cleanup categories: {0}" -f ($cleanupTypeSelection -join ', '))

foreach ($keyName in $cleanupTypeSelection) {
    $newItemParams = @{
        Path         = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\$keyName"
        Name         = 'StateFlags0001'
        Value        = 2
        PropertyType = 'DWord'
        ErrorAction  = 'SilentlyContinue'
    }

    New-ItemProperty @newItemParams | Out-Null
    Write-Log -Message "Prepared cleanup category: $keyName"
}

Start-Process -FilePath CleanMgr.exe -ArgumentList '/sagerun:1' -NoNewWindow -Wait
Write-Log -Message 'CleanMgr.exe completed.' -Level 'OK'
Write-Log -Message '=== Remediation END ==='
#endregion ================= FIRST REMEDIATION BLOCK =================
