<#
.SYNOPSIS
    Remediate CleanUpDisk on the Windows system drive based on defined conditions.

.DESCRIPTION
    This remediation script applies corrective actions for CleanUpDisk on the
    Windows system drive.
    Use with Intune Proactive Remediations or on-demand execution.

    Exit codes:
    - Exit 0: Completed successfully
    - Exit 1: Failed or requires further action

.RUN AS
    System or User (according to assignment settings and script requirements).

.EXAMPLE
    .\CleanUpDisk--Remediate.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.0
#>

#region ========================= CONFIGURATION =========================
# Use a fixed script name so logging stays consistent when Intune stages the script under a temporary local file name.
$ScriptName     = 'CleanUpDisk--Remediate.ps1'
$ScriptBaseName = 'CleanUpDisk--Remediate'

# Detect the Windows system drive automatically instead of hard-coding C:.
$SystemDrive = if ([string]::IsNullOrWhiteSpace($env:SystemDrive)) {
    [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\')
}
else {
    $env:SystemDrive.TrimEnd('\')
}
$SystemDriveLetter = $SystemDrive.TrimEnd(':')
$SystemDriveLabel  = "{0}:" -f $SystemDriveLetter

# Cleanup categories that will be enabled for the built-in Disk Cleanup utility.
$cleanupTypeSelection = 'Temporary Sync Files', 'Downloaded Program Files', 'Memory Dump Files', 'Recycle Bin'

# Additional paths to clear after the built-in cleanup completes.
$pathsToClean = @(
    (Join-Path $SystemDrive 'Temp')
)
#endregion ====================== CONFIGURATION ======================

#region ======================= PATHS AND LOGGING =======================
# Central log folder used by this remediation package.
$SolutionName = "CleanUpDisk"
$BasePath     = Join-Path (Join-Path $SystemDrive 'Intune') $SolutionName

# Remediation-specific log file.
$LogFile      = Join-Path $BasePath ("{0}.txt" -f $ScriptBaseName)
#endregion ==================== PATHS AND LOGGING ====================

#region ======================= HELPER FUNCTIONS =======================
# Ensure the log directory and file exist before any write attempts.
function Initialize-Logging {
    try {
        if (-not (Test-Path $BasePath)) {
            New-Item -Path $BasePath -ItemType Directory -Force -ErrorAction Stop | Out-Null
        }
        if (-not (Test-Path $LogFile)) {
            New-Item -Path $LogFile -ItemType File -Force -ErrorAction Stop | Out-Null
        }
        return $true
    }
    catch {
        return $false
    }
}

$LogReady = Initialize-Logging

# Convert bytes to a readable unit for summary and drive reporting.
function Format-Size {
    param([long]$Bytes)
    if ($Bytes -ge 1GB) { return ("{0:N2} GB" -f ($Bytes / 1GB)) }
    if ($Bytes -ge 1MB) { return ("{0:N2} MB" -f ($Bytes / 1MB)) }
    if ($Bytes -ge 1KB) { return ("{0:N2} KB" -f ($Bytes / 1KB)) }
    return ("{0} B" -f $Bytes)
}

# Return current drive usage details for before/after comparison.
function Get-DriveInfo {
    param([string]$DriveLetter = $SystemDriveLetter)
    try {
        $drive = Get-PSDrive -Name $DriveLetter -ErrorAction Stop
        return [pscustomobject]@{
            Free  = [int64]$drive.Free
            Used  = [int64]$drive.Used
            Total = [int64]$drive.Free + [int64]$drive.Used
        }
    }
    catch {
        return $null
    }
}

# Estimate the size of a directory before removing its contents.
function Get-DirectorySize {
    param([string]$Path)
    try {
        $files = Get-ChildItem -LiteralPath $Path -Recurse -Force -ErrorAction Stop | Where-Object { -not $_.PSIsContainer }
        return ($files | Measure-Object -Property Length -Sum).Sum
    }
    catch {
        return $null
    }
}

# Write colored console output and persist the same line to the log file.
function Write-Log {
    param(
        [Parameter(Mandatory = $true)][string]$Message,
        [ValidateSet("INFO", "OK", "WARN", "FAIL")]
        [string]$Level = "INFO"
    )

    $ts   = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[{0}] [{1}] {2}" -f $ts, $Level, $Message

    # Console for visibility, file for persistence
    switch ($Level) {
        "OK"   { Write-Host $line -ForegroundColor Green }
        "WARN" { Write-Host $line -ForegroundColor Yellow }
        "FAIL" { Write-Host $line -ForegroundColor Red }
        default { Write-Host $line -ForegroundColor Cyan }
    }

    if ($LogReady) {
        try { Add-Content -Path $LogFile -Value $line -ErrorAction SilentlyContinue } catch {}
    }
}
#endregion ==================== HELPER FUNCTIONS ====================

#region ==================== FIRST REMEDIATION BLOCK ====================
# Capture the starting state so the cleanup impact can be reported later.
Write-Log -Level "INFO" -Message "=== Remediation START ==="
$driveBefore = Get-DriveInfo -DriveLetter $SystemDriveLetter
Write-Log -Level "INFO" -Message ("Script: {0}" -f $ScriptName)
Write-Log -Level "INFO" -Message ("Log file: {0}" -f $LogFile)
if ($driveBefore) {
    Write-Log -Level "INFO" -Message ("{0} Free: {1} | Used: {2} | Total: {3}" -f $SystemDriveLabel, (Format-Size $driveBefore.Free), (Format-Size $driveBefore.Used), (Format-Size $driveBefore.Total))
}

$summary = @()
$totalCleanedBytes = 0

# Stage 1: enable selected cleanup handlers, then run the built-in Disk Cleanup utility.
Write-Log -Level "INFO" -Message "--- Stage 1: Disk Cleanup ---"
foreach ($keyName in $cleanupTypeSelection) {
    $newItemParams = @{
        Path         = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\$keyName"
        Name         = 'StateFlags0001'
        Value        = 1
        PropertyType = 'DWord'
        ErrorAction  = 'SilentlyContinue'
    }
    try {
        New-ItemProperty @newItemParams | Out-Null
        Write-Log -Level "OK" -Message ("Stage1: Enabled cleanup flag for {0}" -f $keyName)
    }
    catch {
        Write-Log -Level "WARN" -Message ("Stage1: Failed to set cleanup flag for {0}" -f $keyName)
    }
}
try {
    Start-Process -FilePath CleanMgr.exe -ArgumentList '/sagerun:1' -NoNewWindow -Wait
    Write-Log -Level "OK" -Message "Stage1: CleanMgr completed."
}
catch {
    # Continue even if CleanMgr fails so custom cleanup stages can still run.
    Write-Log -Level "WARN" -Message "Stage1: CleanMgr failed to run."
}

try {
    # Stage 2: remove the contents of configured folders while leaving the root folder intact.
    Write-Log -Level "INFO" -Message "--- Stage 2: Clear specified paths ---"
    foreach ($path in $pathsToClean) {
        if (Test-Path -LiteralPath $path) {
            $sizeBefore = Get-DirectorySize -Path $path
            try {
                # Remove only child items so the parent path remains available.
                Get-ChildItem -LiteralPath $path -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
                Write-Log -Level "OK" -Message ("Stage2: Cleared contents of {0}" -f $path)
                if ($sizeBefore -ne $null) {
                    $summary += [pscustomobject]@{ Path = $path; Bytes = $sizeBefore }
                    $totalCleanedBytes += $sizeBefore
                }
            }
            catch {
                Write-Log -Level "WARN" -Message ("Stage2: Failed to clear contents of {0}" -f $path)
            }
        }
        else {
            Write-Log -Level "INFO" -Message ("Stage2: Path not found, skipping: {0}" -f $path)
        }
    }
}
catch {
    # Keep processing because Stage 3 is in finally and should always execute.
    Write-Log -Level "WARN" -Message ("Stage2: Unhandled error: {0}" -f $_.Exception.Message)
}
finally {
    # Stage 3: empty every folder under the system drive named exactly "temp" (case-insensitive).
    Write-Log -Level "INFO" -Message ("--- Stage 3: Clear all 'temp' folders on {0}\\ ---" -f $SystemDriveLabel)
    $tempDirs = Get-ChildItem -LiteralPath ("{0}\" -f $SystemDriveLabel) -Directory -Recurse -Force -ErrorAction SilentlyContinue | Where-Object { $_.Name -ieq 'temp' }
    foreach ($dir in $tempDirs) {
        $sizeBefore = Get-DirectorySize -Path $dir.FullName
        try {
            # As above, preserve the temp folder and clear only its contents.
            Get-ChildItem -LiteralPath $dir.FullName -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
            Write-Log -Level "OK" -Message ("Stage3: Cleared contents of {0}" -f $dir.FullName)
            if ($sizeBefore -ne $null) {
                $summary += [pscustomobject]@{ Path = $dir.FullName; Bytes = $sizeBefore }
                $totalCleanedBytes += $sizeBefore
            }
        }
        catch {
            Write-Log -Level "WARN" -Message ("Stage3: Failed to clear contents of {0}" -f $dir.FullName)
        }
    }
}
#endregion ================= FIRST REMEDIATION BLOCK =================

#region ====================== FINAL SUMMARY BLOCK ======================
# Report estimated reclaimed space and the final drive state.
Write-Log -Level "INFO" -Message "=== Summary: cleaned content sizes ==="
foreach ($item in $summary) {
    Write-Log -Level "INFO" -Message ("Path: {0} | Cleared: {1}" -f $item.Path, (Format-Size -Bytes $item.Bytes))
}
Write-Log -Level "INFO" -Message ("Total cleared (estimated): {0}" -f (Format-Size -Bytes $totalCleanedBytes))

$driveAfter = Get-DriveInfo -DriveLetter $SystemDriveLetter
if ($driveAfter) {
    Write-Log -Level "INFO" -Message ("{0} Free after: {1} | Used: {2} | Total: {3}" -f $SystemDriveLabel, (Format-Size $driveAfter.Free), (Format-Size $driveAfter.Used), (Format-Size $driveAfter.Total))
}
Write-Log -Level "INFO" -Message "=== Remediation END ==="
#endregion =================== FINAL SUMMARY BLOCK ===================
