<#
.SYNOPSIS
    Remove old files from user Downloads folders.

.DESCRIPTION
    This remediation script scans each user Downloads folder and deletes files
    older than the configured retention period.

    It preserves excluded file extensions, writes an audit trail to the log,
    and reports a summary of deleted files, preserved files, and freed space.

.RUN AS
    System

.EXAMPLE
    .\ClearDownloadFolder--Remediate.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.0
#>

#region ========================= CONFIGURATION =========================
# Number of days to keep files before they are deleted.
$DaysToKeep = 90
$DateLimit = (Get-Date).AddDays(-$DaysToKeep)

# File extensions that should be preserved.
$ExcludeExtensions = @('.exe', '.msi', '.zip')

# Use a fixed script name so logging stays consistent when Intune stages the script under a temporary local file name.
$ScriptName     = 'ClearDownloadFolder--Remediate.ps1'
$ScriptBaseName = 'ClearDownloadFolder--Remediate'

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
Write-Log -Level 'INFO' -Message '=== Remediation START ==='
Write-Log -Level 'INFO' -Message ('Script: {0}' -f $ScriptName)
Write-Log -Level 'INFO' -Message ('Log file: {0}' -f $LogFile)
Write-Log -Level 'INFO' -Message ("Delete files older than: {0}" -f $DateLimit)

#region ==================== FIRST REMEDIATION BLOCK ====================
$DeletedCount = 0
$PreservedCount = 0
$TotalSizeFreed = 0

# Process each user's Downloads folder.
Get-ChildItem 'C:\Users\*\Downloads' -Directory -ErrorAction SilentlyContinue | ForEach-Object {
    $UserDownloads = $_.FullName
    $UserName = $_.Parent.Name

    Write-Log -Level 'INFO' -Message ("Processing: {0}" -f $UserName)

    # Only remove files older than the configured retention period.
    Get-ChildItem $UserDownloads -File -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
        $File = $_

        if ($File.LastWriteTime -lt $DateLimit) {
            if ($ExcludeExtensions -contains $File.Extension) {
                Write-Log -Level 'INFO' -Message ("  Preserved: {0} (excluded extension)" -f $File.Name)
                $PreservedCount++
            }
            else {
                try {
                    $FileSize = $File.Length
                    Remove-Item -Path $File.FullName -Force -ErrorAction Stop
                    Write-Log -Level 'OK' -Message ("  Deleted: {0} (Age: {1} days, Size: {2} MB)" -f $File.Name, [math]::Round((New-TimeSpan -Start $File.LastWriteTime -End (Get-Date)).TotalDays), [math]::Round($FileSize / 1MB, 2))
                    $DeletedCount++
                    $TotalSizeFreed += $FileSize
                }
                catch {
                    Write-Log -Level 'FAIL' -Message ("  ERROR: Could not delete {0} - {1}" -f $File.Name, $_.Exception.Message)
                }
            }
        }
        else {
            $PreservedCount++
        }
    }
}

Write-Log -Level 'INFO' -Message '=== Summary ==='
Write-Log -Level 'INFO' -Message ("Files deleted: {0}" -f $DeletedCount)
Write-Log -Level 'INFO' -Message ("Files preserved: {0}" -f $PreservedCount)
Write-Log -Level 'INFO' -Message ("Space freed: {0} GB" -f [math]::Round($TotalSizeFreed / 1GB, 2))
Write-Log -Level 'OK' -Message '=== Cleanup Completed ==='

exit 0
#endregion ================= FIRST REMEDIATION BLOCK =================
