<#
.SYNOPSIS
    Detect whether user Downloads folders contain old files that should be cleaned.

.DESCRIPTION
    This detection script scans each user Downloads folder and looks for files
    older than the configured retention period.

    It ignores excluded file extensions and returns a non-compliant result only
    when one or more matching old files are found, so the cleanup remediation
    can run.

.RUN AS
    System

.EXAMPLE
    .\ClearDownloadFolder--Detect.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.0
#>

#region ========================= CONFIGURATION =========================
# Number of days to keep files before they are considered old.
$DaysToKeep = 90
$DateLimit = (Get-Date).AddDays(-$DaysToKeep)

# File extensions that should not trigger cleanup.
$ExcludeExtensions = @('.exe', '.msi', '.zip')

# Use a fixed script name so logging stays consistent when Intune stages the script under a temporary local file name.
$ScriptName     = 'ClearDownloadFolder--Detect.ps1'
$ScriptBaseName = 'ClearDownloadFolder--Detect'

# Store logs under the system drive instead of hard-coding C:.
$SystemDrive = if ($env:SystemDrive) { $env:SystemDrive.TrimEnd('\') } else { 'C:' }

# Script-specific logging location.
$SolutionName = 'ClearDownloadFolder'
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
$OldFilesFound = $false
$OldFileCount = 0

# Check each user's Downloads folder.
Get-ChildItem 'C:\Users\*\Downloads' -Directory -ErrorAction SilentlyContinue | ForEach-Object {
    $UserDownloads = $_.FullName

    # Count files older than the age limit that are not excluded by extension.
    Get-ChildItem $UserDownloads -File -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
        $File = $_

        if (($File.LastWriteTime -lt $DateLimit) -and ($ExcludeExtensions -notcontains $File.Extension)) {
            $OldFilesFound = $true
            $OldFileCount++
        }
    }
}

if ($OldFilesFound) {
    Write-Host "Found $OldFileCount files older than $DaysToKeep days - cleanup needed"
    Write-Log -Level 'WARN' -Message ("Found {0} files older than {1} days. Cleanup is required." -f $OldFileCount, $DaysToKeep)
    Write-Log -Level 'INFO' -Message '=== Detection END (Exit 1) ==='
    exit 1
}
else {
    Write-Host "No files older than $DaysToKeep days found - no cleanup needed"
    Write-Log -Level 'OK' -Message ("No eligible files older than {0} days were found." -f $DaysToKeep)
    Write-Log -Level 'INFO' -Message '=== Detection END (Exit 0) ==='
    exit 0
}
#endregion ================== FIRST DETECTION BLOCK ==================
