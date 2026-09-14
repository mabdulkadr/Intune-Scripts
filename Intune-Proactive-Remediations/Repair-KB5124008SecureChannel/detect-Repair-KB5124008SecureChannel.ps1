<#
.TITLE
    Detection - KB5124008 Secure Channel Regression

.SYNOPSIS
    Detects devices affected by the KB5124008 secure channel regression: domain-joined,
    KB5124008 installed, and a regression indicator (non-zero MachineIdentityIsolation
    or a broken computer secure channel).

.DESCRIPTION
    Evaluates the conditions that together identify the KB5124008 secure channel
    regression on a device:

    1. The device is domain-joined (Win32_ComputerSystem.PartOfDomain).
    2. KB5124008 is installed (hotfix inventory).
    3. A regression indicator is present:
       - MachineIdentityIsolation exists and is not 0 (the workaround flag the paired
         remediation clears), OR
       - the computer secure channel is broken (Test-ComputerSecureChannel).

    Non-compliant only when in scope (1 and 2 hold) AND at least one regression
    indicator is found. Devices that are not domain-joined, or that do not have
    KB5124008 installed, are compliant by design (not applicable) so remediation
    never runs for unrelated broken-trust cases. This script NEVER modifies the
    system.

    Exit contract:
    Exit 0 = compliant (no remediation needed)
    Exit 1 = non-compliant (Intune runs the paired remediation)
    Exit 2 = script error (Intune must NOT treat a crash as non-compliance)

.TAGS
    Remediation,Detection,ActiveDirectory,SecureChannel,KB5124008

.REMEDIATIONTYPE
    Detection

.PAIRSCRIPT
    remediate-Repair-KB5124008SecureChannel.ps1

.PLATFORM
    Windows

.MINROLE
    Intune Service Administrator

.PERMISSIONS
    None (local SYSTEM context) - reads local hotfix inventory and runs a read-only secure channel test.

.AUTHOR
    Mohammad Abdelkader Omar

.VERSION
    1.0.1

.CHANGELOG
    1.0.1 (2026-09-14)
- Fixed $SolutionName casing (Repair-KB5124008SecureChannel) so the pair passes the
       compliance gate (PascalCase identity locks) and matches the folder identity.
    - Detection now reports a non-zero MachineIdentityIsolation value as a regression
      reason, matching the paired remediation post-verify condition.
    1.0.0 (2026-09-13)
    - Initial release
    - Null-safe registry read via Get-ItemProperty member access (Get-ItemPropertyValue throws terminating PSArgumentException when a value is absent)

.LASTUPDATE
    2026-09-14

.EXAMPLE
    .\detect-Repair-KB5124008SecureChannel.ps1
    Returns exit 0 when compliant; exit 1 when the paired remediation must run.

.EXAMPLE
    .\detect-Repair-KB5124008SecureChannel.ps1
    Returns exit 2 when an unexpected error prevents evaluation.

.NOTES
    - Runs in SYSTEM context via Intune Proactive Remediations.
    - Keep detection under 30 seconds: one CIM query, one hotfix query, one secure channel test.
    - Requires line-of-sight to a domain controller for a meaningful secure channel result.
    - Idempotent and read-only by definition.
    - Logs: <SystemDrive>\IntuneLogs\Repair-KB5124008SecureChannel\Repair-KB5124008SecureChannel-Detection.txt
#>

#Requires -Version 5.1

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# ============================================================================
# CONFIGURATION - solution identity and compliance target values.
# ============================================================================

$SolutionName         = 'Repair-KB5124008SecureChannel'
$ScriptMode           = 'Detection'
$HotFixId             = 'KB5124008'
$LsaPath              = 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa'
$IsolationName        = 'MachineIdentityIsolation'
$IsolationTargetValue = 0

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

# Writes one timestamped, level-colored line to console and log file.
function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [AllowEmptyString()]
        [string]$Message = "",
        [ValidateSet("INFO", "SUCCESS", "WARNING", "ERROR", "DEBUG")]
        [string]$Level = "INFO"
    )

    # Visual spacer support: callers use Write-Log -Message "" to break sections; early-return on empty.
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

# Logs the final message and terminates with the given exit code.
function Finish-Script {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [int]$ExitCode,
        [Parameter(Mandatory = $false)]
        [AllowEmptyString()]
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

# Returns a reason string per unmet condition; empty output = compliant.
function Test-ComplianceState {
    $reasons = [System.Collections.Generic.List[string]]::new()

    try {
        $computerSystem = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop

        # Not domain-joined means the KB5124008 regression cannot apply - compliant by design.
        if (-not $computerSystem.PartOfDomain) {
            Write-Log -Message 'Device is not domain-joined. KB5124008 secure channel check is not applicable.' -Level 'DEBUG'
            return @($reasons)
        }

        Write-Log -Message ("Domain: {0}" -f $computerSystem.Domain) -Level 'DEBUG'

        # The regression only exists on devices that actually installed KB5124008.
        # Get-HotFix emits a non-terminating "not found" error; SilentlyContinue returns $null instead.
        $hotfix = Get-HotFix -Id $HotFixId -ErrorAction SilentlyContinue
        if (-not $hotfix) {
            Write-Log -Message "Hotfix $HotFixId is not installed. KB5124008 secure channel check is not applicable." -Level 'DEBUG'
            return @($reasons)
        }

        Write-Log -Message ("Hotfix {0} is installed (installed on: {1})." -f $HotFixId, $hotfix.InstalledOn) -Level 'DEBUG'

        $isolation = (Get-ItemProperty -LiteralPath $LsaPath -ErrorAction Stop).$IsolationName
        Write-Log -Message "Current $IsolationName value: $isolation" -Level 'DEBUG'

        # Non-zero MachineIdentityIsolation is the regression flag the paired
        # remediation clears back to 0 - evaluate it even when the channel still tests.
        if ($null -ne $isolation -and $isolation -ne $IsolationTargetValue) {
            $reasons.Add("$IsolationName is set to $isolation (expected $IsolationTargetValue) while $HotFixId is installed")
        }

        $secureChannelHealthy = Test-ComputerSecureChannel -ErrorAction Stop
        Write-Log -Message "Secure channel healthy: $secureChannelHealthy" -Level 'DEBUG'

        if (-not $secureChannelHealthy) {
            $reasons.Add("Secure channel to domain '$($computerSystem.Domain)' is broken while $HotFixId is installed")
        }
    }
    catch [Microsoft.Management.Infrastructure.CimException] {
        throw "Failed to query Win32_ComputerSystem: $($_.Exception.Message)"
    }
    catch {
        throw "Failed to evaluate the KB5124008 secure channel state: $($_.Exception.Message)"
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
    if ($script:LogReady) {
        Write-Log -Message "Log file ready: $($script:LogFile)" -Level 'DEBUG'
    }
    Write-Log -Message "Detection started" -Level 'INFO'

    $reasons = Test-ComplianceState

    if ($reasons.Count -eq 0) {
        Finish-Script -ExitCode 0 -Message "Compliant - no KB5124008 secure channel regression detected" -Level 'SUCCESS'
    }

    foreach ($reason in $reasons) {
        Write-Output $reason
        Write-Log -Message "Non-compliant: $reason" -Level 'WARNING'
    }
    Finish-Script -ExitCode 1 -Message "Non-compliant - $($reasons.Count) condition(s) found" -Level 'WARNING'
}
catch {
    Write-Output "Detection error: $($_.Exception.Message)"
    Finish-Script -ExitCode 2 -Message "Detection script error: $($_.Exception.Message)" -Level 'ERROR'
}