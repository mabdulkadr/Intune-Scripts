<#
.TITLE
    Detect-OfficeLTSC2024

.SYNOPSIS
    Intune custom detection script for Office LTSC Professional Plus 2024 (volume, Click-to-Run).

.DESCRIPTION
    Verifies that Office LTSC Professional Plus 2024 (volume licensed) is installed and that a core
    application (WINWORD.EXE) exists on disk. Touches only the Click-to-Run registry hive and
    the disk probe; the only write is the run transcript under IntuneLogs.
    Exit contract: 0 = installed (compliant), 1 = not installed (non-compliant),
    2 = script error. Intune treats any non-zero exit as "not installed" and re-evaluates the app.

.TAGS
    Intune,Detection,Office,LTSC,ClickToRun

.REMEDIATIONTYPE
    Win32 App Detection (no remediation partner)

.PAIRSCRIPT
    N/A - this is an Intune Win32 app detection rule, not part of a Proactive Remediation pair.

.PLATFORM
    Windows 10, Windows 11

.PERMISSIONS
    None (local SYSTEM context)

.AUTHOR
    Mohammad Abdelkader Omar | GitHub @mabdulkadr | momar.tech

.VERSION
    1.3.0

.CHANGELOG
    1.3.0 (2026-09-16) - Canonical rewrite matching Detect-ProjectPro2024: embedded structured
                         logging (Initialize-Log/Write-Banner/Write-Log/Finish-Script),
                         Test-ComplianceState reason list, canonical 0/1/2 exit contract,
                         run transcript under <SystemDrive>\IntuneLogs\OfficeLTSC2024\.
    1.2.0 (2026-09-16) - Migrated detection to ProPlus2024Volume (Office LTSC Professional
                          Plus 2024), matching the re-issued install configs.
    1.1.0 (2026-09-16) - Standardized header to the canonical multi-line format and aligned
                         the detection exit contract documentation with the paired Install/
                         Uninstall scripts.
    1.0.0 (2026-09-16) - Initial release.

.LASTUPDATE
    2026-09-16

.EXAMPLE
    Intune: upload as custom detection script, run as SYSTEM, run as 64-bit. Exit 0 = detected.

.NOTES
    - Runs in SYSTEM context via the Intune Management Extension as a Win32 app detection rule.
    - Read-only by design: registry + file probes plus a run transcript - never repackages or
      reinstalls anything.
    - Logs: <SystemDrive>\IntuneLogs\OfficeLTSC2024\OfficeLTSC2024-Detection.txt
#>

#Requires -Version 5.1

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$SolutionName = 'OfficeLTSC2024'
$ScriptMode   = 'Detection'

# --- Logging (CLI Configuration) ---------------------------------------------
# Canonical CLI logging helpers, copied verbatim (self-contained: no dot-sourcing).
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

function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [AllowEmptyString()]
        [string]$Message = "",
        [ValidateSet("INFO", "SUCCESS", "WARNING", "ERROR", "DEBUG")]
        [string]$Level = "INFO"
    )

    # Visual spacer support: callers commonly use `Write-Log -Message ""` to break
    # sections vertically. Mandatory binding treats an empty string as a missing
    # value, so the canonical helper MUST early-return on empty (Pitfall 30).
    if ([string]::IsNullOrEmpty($Message)) { return }

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
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
# DETECTION LOGIC
# ============================================================================

# Returns one reason string per unmet detection condition; empty list = compliant.
function Test-ComplianceState {
    $reasons = [System.Collections.Generic.List[string]]::new()
    $c2rKey  = 'HKLM:\SOFTWARE\Microsoft\Office\ClickToRun\Configuration'

    # Script error path (exit 2) when the authoritative registry key cannot be read.
    try {
        $config = Get-ItemProperty -LiteralPath $c2rKey -ErrorAction Stop
    }
    catch {
        $reasons.Add("ClickToRun registry key '$c2rKey' could not be read: $($_.Exception.Message)")
        return @($reasons)
    }

    # Non-compliant when the volume product is missing from ProductReleaseIds.
    if (([string]$config.ProductReleaseIds) -notmatch [regex]::Escape('ProPlus2024Volume')) {
        $reasons.Add("Product 'ProPlus2024Volume' not present in ProductReleaseIds: $($config.ProductReleaseIds)")
    }

    # Non-compliant when no version is reported (partial or failed install).
    if (-not $config.VersionToReport) {
        $reasons.Add('ClickToRun ProductReleaseIds matches but VersionToReport is empty.')
    }

    # Hardening: confirm a core binary actually exists at the reported install path.
    $installPath = $config.InstallPath
    if ($installPath -and -not (Test-Path -LiteralPath (Join-Path $installPath 'root\Office16\WINWORD.EXE'))) {
        $reasons.Add("WINWORD.EXE not found under InstallPath '$installPath'.")
    }

    return @($reasons)
}

# ============================================================================
# MAIN
# ============================================================================
# Flow: init -> banner -> compliance checks -> exit 0 compliant / 1 non-compliant / 2 error.

try {
    $null = Initialize-Log -SolutionName $SolutionName -ScriptMode $ScriptMode -Type 'Intune'
    Write-Banner
    Write-Log -Message "Detection started" -Level 'INFO'

    $reasons = Test-ComplianceState

    if ($reasons.Count -eq 0) {
        Finish-Script -ExitCode 0 -Message 'Office LTSC Professional Plus 2024 detected as installed' -Level 'SUCCESS'
    }

    foreach ($reason in $reasons) {
        Write-Output $reason
        Write-Log -Message "Non-compliant: $reason" -Level 'WARNING'
    }
    Finish-Script -ExitCode 1 -Message "Not installed - $($reasons.Count) condition(s) found" -Level 'WARNING'
}
catch {
    Write-Output "Detection error: $($_.Exception.Message)"
    Finish-Script -ExitCode 2 -Message "Detection script error: $($_.Exception.Message)" -Level 'ERROR'
}
