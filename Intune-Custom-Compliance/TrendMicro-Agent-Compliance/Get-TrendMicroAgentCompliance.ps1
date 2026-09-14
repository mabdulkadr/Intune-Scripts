<#
.TITLE
    Custom Compliance - Trend Micro Apex One Detection

.SYNOPSIS
    Detects whether the Trend Micro Apex One executable is present on the device.

.DESCRIPTION
    Intune Custom Compliance discovery script that checks two independent
    executable-presence signals (the agent program folder containing its marker
    exe files, or a running agent process) to determine whether Trend Micro
    Apex One is installed.

    Emits a single-line JSON property bag ({"Trend Micro Apex One Security Agent":true|false})
    that the Intune custom compliance engine evaluates against its rule file.

    Exit contract:
    Exit 0 = compliant (JSON emitted successfully)
    Exit 2 = script error (Intune must NOT treat a crash as valid output)

    This script NEVER modifies the system — it is read-only by design.

.TAGS
    Security,Compliance

.PLATFORM
    Windows

.MINROLE
    Intune Service Administrator

.PERMISSIONS
    None (local SYSTEM context) - folder and process executable-presence checks only

.AUTHOR
    Mohammad Abdelkader Omar

.VERSION
    2.1.0

.CHANGELOG
    2.1.0 (2026-09-07)
    - Rename files/folder to follow Intune-Custom-Compliance convention
      (TrendMicro-Agent-Compliance, Get-TrendMicroAgentCompliance.ps1).
    - Align SolutionName with folder identity.
    2.0.0 (2026-09-07)
    - Rewrite to Enterprise Standards: canonical header, structured logging,
      try/catch error handling, exit-code contract.
    - Reduce detection to exe-presence only (folder markers + process); remove
      registry ARP and service checks per operator requirement.
    - Remove empty catch block in Test-Processes (Law 4).
    - Add Write-Log integration for fleet diagnostics.

.LASTUPDATE
    2026-09-07

.EXAMPLE
    .\Get-TrendMicroAgentCompliance.ps1
    Returns {"Trend Micro Apex One Security Agent":true} when installed,
    or {"Trend Micro Apex One Security Agent":false} when absent.

.NOTES
    - Runs in SYSTEM context via Intune Custom Compliance.
    - Detection-only: never modifies the filesystem, registry, services, or processes.
    - No Graph API calls; no interactive prompts.
    - Logs: <SystemDrive>\IntuneLogs\TrendMicroAgentCompliance\
#>

#Requires -Version 5.1

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'

$SolutionName = 'TrendMicroAgentCompliance'
$ScriptMode   = 'Compliance'

# ============================================================================
# LOGGING BLOCK (canonical: dot-source scripts/Write-Log.ps1)
# ============================================================================

$_scriptRoot = if ($PSScriptRoot) { $PSScriptRoot }
elseif ($PSCommandPath) { Split-Path -Parent $PSCommandPath }
elseif ($MyInvocation.MyCommand.Path) { Split-Path -Parent $MyInvocation.MyCommand.Path }
else { (Get-Location).Path }

# Self-contained logging for individually deployed scripts — inline the helpers
# so the script works on any machine without relative path dependencies.
# Canonical source: scripts/Write-Log.ps1 (copy verbatim, never re-type).

$script:SystemDrive = if ($env:SystemDrive) { $env:SystemDrive.TrimEnd('\') } else {
    [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\')
}
$script:LogRoot  = $null
$script:LogFile  = $null
$script:LogReady = $false

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

function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [AllowEmptyString()]
        [string]$Message = "",
        [ValidateSet("INFO", "SUCCESS", "WARNING", "ERROR", "DEBUG")]
        [string]$Level = "INFO"
    )
    if ([string]::IsNullOrEmpty($Message)) { return }

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    # Console = clean, no timestamp/level prefix - color alone conveys severity.
    # File    = detailed - keeps [timestamp] [LEVEL] for fleet troubleshooting.
    $fileLine  = "[$timestamp] [$Level] $Message"

    $color = switch ($Level) {
        "DEBUG"   { "DarkGray" }
        "INFO"    { "Cyan" }
        "SUCCESS" { "Green" }
        "WARNING" { "Yellow" }
        "ERROR"   { "Red" }
    }
    Write-Host $Message -ForegroundColor $color

    if ($script:LogReady -and $script:LogFile) {
        Add-Content -LiteralPath $script:LogFile -Value $fileLine -Encoding UTF8 -ErrorAction SilentlyContinue -WhatIf:$false
    }
}

function Write-Banner {
    [CmdletBinding()]
    param()
    $title      = '{0} | {1} | {2}' -f $SolutionName, $ScriptMode, (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
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

function Finish-Script {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [int]$ExitCode,
        [Parameter(Mandatory = $true)]
        [string]$Message,
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
# CONFIGURATION
# ============================================================================

# Confirmed install footprints (x86 paths from screenshots + common x64 fallbacks)
$script:FolderChecks = @(
    @{ Path = 'C:\Program Files (x86)\Trend Micro\Security Agent'; Markers = @('PccNt.exe', 'PccNTMon.exe') }
)

# ============================================================================
# DETECTION HELPERS
# ============================================================================

# Returns $true if the folder exists and contains at least one marker file.
function Test-FolderWithMarkers {
    param(
        [string]$Folder,
        [string[]]$Markers
    )
    if (-not (Test-Path -LiteralPath $Folder)) { return $false }
    foreach ($marker in $Markers) {
        $markerPath = Join-Path $Folder $marker
        if (Test-Path -LiteralPath $markerPath) { return $true }
    }
    return $false
}

# Returns $true if any folder-check set passes.
function Test-AnyFolderSet {
    param(
        [object[]]$Checks
    )
    foreach ($check in $Checks) {
        if (Test-FolderWithMarkers -Folder $check.Path -Markers $check.Markers) { return $true }
    }
    return $false
}

# Returns $true if any Trend Micro process is running.
function Test-Processes {
    $processNames = @('ntrtscan', 'PccNTMon', 'TmListen')
    try {
        $found = Get-Process -Name $processNames -ErrorAction SilentlyContinue
        if ($found) { return $true }
    }
    catch [System.Diagnostics.ProcessNotFoundException] {
        Write-Log -Message "Process check: no matching processes found" -Level 'DEBUG'
    }
    catch {
        Write-Log -Message "Process check failed: $($_.Exception.Message)" -Level 'WARNING'
    }
    return $false
}

# ============================================================================
# MAIN
# ============================================================================

try {
    $null = Initialize-Log -SolutionName $SolutionName -ScriptMode $ScriptMode -Type 'Intune'
    Write-Banner
    if ($script:LogReady) {
        Write-Log -Message "Log file ready: $($script:LogFile)" -Level 'DEBUG'
    }
    Write-Log -Message "Detection started - checking for Trend Micro Apex One executable" -Level 'INFO'

    # Evaluate the exe-marker signals (folder markers + running process)
    $folderHit = Test-AnyFolderSet -Checks $script:FolderChecks
    Write-Log -Message "Folder marker check: $folderHit" -Level 'DEBUG'

    $processHit = Test-Processes
    Write-Log -Message "Process check: $processHit" -Level 'DEBUG'

    $installed = $folderHit -or $processHit

    Write-Log -Message "Installed: $installed (folder=$folderHit process=$processHit)" -Level 'INFO'

    # Emit the exact key the JSON compliance rule expects — single compact line
    $output = @{ 'Trend Micro Apex One Security Agent' = $installed } | ConvertTo-Json -Compress
    Write-Output $output

    if ($installed) {
        Finish-Script -ExitCode 0 -Message "Trend Micro Apex One detected - compliant" -Level 'SUCCESS'
    }
    else {
        # Exit 0 with false — Intune custom compliance evaluates the JSON value,
        # not the exit code. The rule file sets the compliance condition.
        Finish-Script -ExitCode 0 -Message "Trend Micro Apex One not detected - JSON emitted" -Level 'INFO'
    }
}
catch {
    $errorMsg = "Detection error: $($_.Exception.Message)"
    Write-Output $errorMsg
    Finish-Script -ExitCode 2 -Message $errorMsg -Level 'ERROR'
}
