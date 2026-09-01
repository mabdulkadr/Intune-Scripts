<#
.TITLE
    Disk Cleanup Detection Script

.SYNOPSIS
    Detects if system requires disk cleanup based on temp file accumulation.

.DESCRIPTION
    Checks Windows temp folders, per-user temp folders, and the recycle bin size.
    Returns exit code 1 when more than the threshold can be cleaned up,
    triggering the paired remediation that clears them. This script NEVER
    modifies or deletes anything.

    Exit contract:
    Exit 0 = compliant (cleanable space below threshold)
    Exit 1 = non-compliant (Intune runs the paired remediation)
    Exit 2 = script error (Intune must NOT treat a crash as non-compliance)

.TAGS
    Remediation,Detection

.REMEDIATIONTYPE
    Detection

.PAIRSCRIPT
    remediate-Invoke-DiskCleanup.ps1

.PLATFORM
    Windows

.MINROLE
    Intune Service Administrator

.PERMISSIONS
    None (local SYSTEM context) - measures temp folder and recycle bin sizes.

.AUTHOR
    Mohammad Abdelkader Omar

.VERSION
    1.1.1

.CHANGELOG
    1.1.1 (2026-08-26)
    - Migrated to Enterprise Admin standards
    1.1 - Fixed invalid return statement in Get-FolderSize that caused folder sizes to always report 0 bytes
    1.0 - Initial version

.LASTUPDATE
    2026-08-26

.EXAMPLE
    .\detect-Invoke-DiskCleanup.ps1
    Returns exit 0 when cleanable space is below 1 GB; exit 1 above it.

.EXAMPLE
    .\detect-Invoke-DiskCleanup.ps1
    Returns exit 2 when size measurement fails unexpectedly.

.NOTES
    - Runs in SYSTEM context via Intune Proactive Remediations.
    - Threshold is 1 GB of recoverable space.
    - Idempotent and read-only by definition.
    - Logs: <SystemDrive>\IntuneLogs\disk-cleanup\disk-cleanup-Detection.txt
#>

#Requires -Version 5.1

[CmdletBinding(SupportsShouldProcess = $true)]
param()

$ErrorActionPreference = 'Stop'

# ============================================================================
# CONFIGURATION - solution identity and compliance target values.
# ============================================================================

$SolutionName = 'disk-cleanup'
$ScriptMode   = 'Detection'

$threshold = 1GB

# ============================================================================
# LOGGING BLOCK (embedded canonical scripts/Write-Log.ps1 - copy VERBATIM)
# Single source of truth: Initialize-Log / Write-Banner / Write-Log / Finish-Script.
# ============================================================================

# --- Logging (CLI Configuration) --------------------------------------------
$script:SystemDrive = if ($env:SystemDrive) { $env:SystemDrive.TrimEnd('\') } else {
    [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\')
}
$script:LogRoot  = $null
$script:LogFile  = $null
$script:LogReady = $false

# Creates the Intune log folder/file and reports readiness.
function Initialize-Log {
    [CmdletBinding()]
    param(
        [string]$SolutionName = 'EnterpriseAdminTool',
        [string]$ScriptMode = 'run',
        [ValidateSet('Intune', 'General')]
        [string]$Type = 'General'
    )

    try {
        if ($Type -eq 'Intune') {
            $script:LogRoot = Join-Path $script:SystemDrive "IntuneLogs\$SolutionName"
            $script:LogFile = Join-Path $script:LogRoot "$SolutionName-$ScriptMode.txt"
        } else {
            $script:LogRoot = Join-Path $env:ProgramData "$SolutionName\Logs"
            $script:LogFile = Join-Path $script:LogRoot "$SolutionName`_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
        }

        if (-not (Test-Path -LiteralPath $script:LogRoot)) {
            $null = [System.IO.Directory]::CreateDirectory($script:LogRoot)
        }
        if (-not (Test-Path -LiteralPath $script:LogFile)) {
            $null = [System.IO.File]::Create($script:LogFile).Dispose()
        }

        $script:LogReady = $true
        return $true
    }
    catch {
        Write-Host "Log initialization failed: $($_.Exception.Message)" -ForegroundColor Red
        $script:LogReady = $false
        return $false
    }
}

# Writes the solution banner to console and log file.
function Write-Banner {
    [CmdletBinding()]
    [Alias('Show-Banner')]
    param()

    $title      = '{0} | {1}' -f $SolutionName, $ScriptMode
    $bannerLine = '=' * 78
    $lines      = @('', $bannerLine, $title, $bannerLine)

    foreach ($line in $lines) {
        if ($line -eq $title) {
            Write-Host $line -ForegroundColor White
        } else {
            Write-Host $line -ForegroundColor DarkGray
        }

        if ($script:LogReady -and $script:LogFile) {
            Add-Content -LiteralPath $script:LogFile -Value $line -Encoding UTF8 -ErrorAction SilentlyContinue -WhatIf:$false
        }
    }
}

# Writes one timestamped, level-colored line to console and log file.
function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Message = "",
        [ValidateSet("INFO", "SUCCESS", "WARNING", "ERROR", "DEBUG")]
        [string]$Level = "INFO"
    )

    # Visual spacer support: callers use Write-Log -Message "" to break sections; early-return on empty.
    if ([string]::IsNullOrEmpty($Message)) { return }

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logLine = "[$timestamp] [$Level] $Message"

    $color = switch ($Level) {
        "DEBUG"   { "DarkGray" }
        "INFO"    { "Cyan" }
        "SUCCESS" { "Green" }
        "WARNING" { "Yellow" }
        "ERROR"   { "Red" }
    }
    Write-Host $logLine -ForegroundColor $color

    if ($script:LogReady -and $script:LogFile) {
        Add-Content -LiteralPath $script:LogFile -Value $logLine -Encoding UTF8 -ErrorAction SilentlyContinue -WhatIf:$false
    }
}

# Logs the final message and terminates with the given exit code.
function Finish-Script {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [int]$ExitCode,
        [Parameter(Mandatory = $false)]
        [string]$Message = "",
        [ValidateSet("INFO", "SUCCESS", "WARNING", "ERROR", "DEBUG")]
        [string]$Level = "INFO",
        [switch]$NoExit
    )

    Write-Log -Message $Message -Level $Level
    if (-not $NoExit) {
        exit $ExitCode
    }
}

# ============================================================================
# DETECTION LOGIC
# Return a list of reason strings so operators see every failure at once.
# Empty list = compliant. Never modify the system here.
# ============================================================================

# Measures the recursive size of one folder; unreadable paths count as 0.
function Get-FolderSize {
    param([string]$Path)

    if (Test-Path $Path) {
        try {
            $size = (Get-ChildItem -Path $Path -Recurse -Force -ErrorAction SilentlyContinue |
                Measure-Object -Property Length -Sum).Sum
            if ($null -eq $size) { return 0 }
            return $size
        }
        catch { return 0 }
    }
    return 0
}

# Returns cleanable-space diagnostics plus reasons; reporting happens in MAIN.
function Test-ComplianceState {
    $reasons = [System.Collections.Generic.List[string]]::new()

    $totalSize = 0

    # Windows Temp
    $totalSize += Get-FolderSize "$env:WINDIR\Temp"

    # User Temp folders
    Get-ChildItem "C:\Users" -Directory -ErrorAction SilentlyContinue | ForEach-Object {
        $totalSize += Get-FolderSize "$($_.FullName)\AppData\Local\Temp"
    }

    # Recycle Bin
    try {
        $shell = New-Object -ComObject Shell.Application
        $shell.NameSpace(0xA).Items() | ForEach-Object {
            $totalSize += $_.ExtendedProperty("Size")
        }
    }
    catch {
        # Silently continue if unable to access recycle bin
        Write-Log -Message "Recycle bin size unavailable: $($_.Exception.Message)" -Level 'DEBUG'
    }

    Write-Log -Message "Cleanable space: $([math]::Round($totalSize / 1GB, 2)) GB (threshold: 1 GB)" -Level 'INFO'

    if ($totalSize -gt $threshold) {
        $reasons.Add("Cleanable space exceeds the $threshold byte threshold")
    }

    return @{
        CleanableGB = [math]::Round($totalSize / 1GB, 2)
        Reasons     = @($reasons)
    }
}

# ============================================================================
# MAIN
# ============================================================================
# Flow: init -> banner -> compliance checks -> exit 0 compliant / 1 non-compliant / 2 error.

try {
    $null = Initialize-Log -SolutionName $SolutionName -ScriptMode $ScriptMode -Type 'Intune'
    Write-Banner
    if ($script:LogReady) {
        Write-Log -Message "Log file ready: $($script:LogFile)" -Level 'DEBUG'
    }
    Write-Log -Message "Detection started" -Level 'INFO'

    $state = Test-ComplianceState

    Write-Output "Cleanable space: $($state.CleanableGB) GB"

    if ($state.Reasons.Count -eq 0) {
        Finish-Script -ExitCode 0 -Message "Compliant - no significant cleanable space found" -Level 'SUCCESS'
    }

    foreach ($reason in @($state.Reasons)) {
        Write-Output $reason
        Write-Log -Message "Non-compliant: $reason" -Level 'WARNING'
    }
    Finish-Script -ExitCode 1 -Message "Non-compliant - $($state.Reasons.Count) condition(s) found" -Level 'WARNING'
}
catch {
    Write-Output "Detection error: $($_.Exception.Message)"
    Finish-Script -ExitCode 2 -Message "Detection script error: $($_.Exception.Message)" -Level 'ERROR'
}

