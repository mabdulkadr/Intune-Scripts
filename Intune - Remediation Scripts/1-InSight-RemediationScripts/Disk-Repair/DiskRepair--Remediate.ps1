<#
.SYNOPSIS
    Scan the Windows system drive for file system or volume issues.

.DESCRIPTION
    This remediation script runs `Repair-Volume -Scan` against the Windows
    system drive and writes the raw scan result to the console.

    It keeps the original disk-repair behavior that previously existed inside
    the old detection script, but it is now placed in the remediation file
    where it belongs.

.RUN AS
    System

.EXAMPLE
    .\DiskRepair--Remediate.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.0
#>

#region ========================= CONFIGURATION =========================
# Use a fixed script name so logging stays consistent when Intune stages the script under a temporary local file name.
$ScriptName     = 'DiskRepair--Remediate.ps1'
$ScriptBaseName = 'DiskRepair--Remediate'

# Detect the Windows system drive automatically instead of hard-coding C:.
$SystemDrive = if ([string]::IsNullOrWhiteSpace($env:SystemDrive)) {
    [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\')
}
else {
    $env:SystemDrive.TrimEnd('\')
}
$SystemDriveLetter = $SystemDrive.TrimEnd(':')

# Script-specific logging location.
$SolutionName = 'DiskRepair'
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
Write-Log -Message "Scanning drive letter: $SystemDriveLetter"

try {
    # Keep the original remediation behavior and expose the raw Repair-Volume output.
    $repair = Repair-Volume -DriveLetter $SystemDriveLetter -Scan -Verbose

    Write-Output $repair
    Write-Log -Message ("Repair-Volume result: {0}" -f ($repair | Out-String).Trim())
    Write-Log -Message '=== Remediation END (Exit 0) ==='
    exit 0
}
catch {
    Write-Log -Message ("Remediation error: {0}" -f $_.Exception.Message) -Level 'FAIL'
    Write-Log -Message '=== Remediation END (Exit 1) ==='
    exit 1
}
#endregion ================= FIRST REMEDIATION BLOCK =================
