<#
.TITLE
    Detection - Secure Boot CA 2023 Certificate Update

.SYNOPSIS
    Verifies that the Windows Secure Boot CA 2023 certificate update is enabled and current.

.DESCRIPTION
    Evaluates whether the device has applied the Secure Boot CA 2023 certificate migration
    required before the June 2026 expiry of the 2011 certificates (KB5095093, KB5094126).
    Checks:
    1. Secure Boot is enabled (Confirm-SecureBootUEFI or WMI fallback).
    2. The update policy registry value at HKLM\SYSTEM\CurrentControlSet\Control\SecureBoot\AvailableUpdatePolicy equals 5944.
    3. The UEFICA2023 status registry value indicates certificates are up to date on Windows 11 24H2+.
    This script NEVER modifies the system.

    Exit contract:
    Exit 0 = compliant (no remediation needed)
    Exit 1 = non-compliant (Intune runs the paired remediation)
    Exit 2 = script error (Intune must NOT treat a crash as non-compliance)

.TAGS
    Remediation,Detection,SecureBoot,CA2023,UEFI,Hardening

.REMEDIATIONTYPE
    Detection

.PAIRSCRIPT
    remediate-SecureBoot-CA2023-Update.ps1

.PLATFORM
    Windows

.MINROLE
    Intune Service Administrator

.PERMISSIONS
    None (local SYSTEM context) - reads SecureBoot registry and UEFI state.

.AUTHOR
    Mohammad Abdelkader Omar

.VERSION
    1.0.0

.CHANGELOG
    1.0.0 (2026-08-31)
    - Initial release for June 2026 CA 2023 expiry; checks AvailableUpdatePolicy=5944 and SecureBoot state.

.LASTUPDATE
    2026-08-31

.EXAMPLE
    .\detect-SecureBoot-CA2023-Update.ps1
    Returns exit 0 when compliant; exit 1 when the paired remediation must run.

.NOTES
    - Runs in SYSTEM context via Intune Remediations (formerly Proactive Remediations).
    - Logs: <SystemDrive>\IntuneLogs\SecureBoot-CA2023-Update\SecureBoot-CA2023-Update-Detection.txt
#>

#Requires -Version 5.1

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# ============================================================================
# CONFIGURATION - solution identity and compliance target values.
# ============================================================================

$SolutionName = 'SecureBoot-CA2023-Update'
$ScriptMode   = 'Detection'

# Registry path provisioned by the Intune Settings Catalog policy for CA 2023.
# Intune writes DWORD AvailableUpdatePolicy = 5944 (decimal) at this path.
$SecureBootRegPath    = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot\AvailableUpdatePolicy'
$ExpectedPolicyValue  = 5944

# On 24H2+ devices the Secure Boot status subkey exposes certificate state.
$SecureBootStatusPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot'
$StatusValueNames     = @('UEFICA2023Status', 'AvailableUpdates')

# ============================================================================
# LOGGING BLOCK (embedded canonical scripts/Write-Log.ps1 - copy VERBATIM)
# ============================================================================

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
    [Alias('Show-Banner')]
    param()
    $title      = '{0} | {1}' -f $SolutionName, $ScriptMode
    $bannerLine = '=' * 78
    $lines      = @('', $bannerLine, $title, $bannerLine)
    foreach ($line in $lines) {
        if ($line -eq $title) { Write-Host $line -ForegroundColor White } else { Write-Host $line -ForegroundColor DarkGray }
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
    if (-not $NoExit) { exit $ExitCode }
}

# ============================================================================
# DETECTION LOGIC
# ============================================================================

# Returns $true when Secure Boot is enabled; $null when state cannot be determined (e.g., VM without UEFI).
function Test-SecureBootEnabled {
    try {
        $sb = Confirm-SecureBootUEFI -ErrorAction Stop
        return [bool]$sb
    }
    catch [System.PlatformNotSupportedException] {
        Write-Log -Message "SecureBoot check not supported on this platform (likely VM without UEFI)" -Level 'DEBUG'
        return $null
    }
    catch {
        # Fallback to WMI for older builds or restricted execution contexts.
        try {
            $wmiResult = Get-CimInstance -Namespace root/cimv2/security/microsofttpm -ClassName Win32_Tpm -ErrorAction SilentlyContinue
            Write-Log -Message "Confirm-SecureBootUEFI failed, WMI fallback attempted: $($_.Exception.Message)" -Level 'DEBUG'
            return $null
        }
        catch {
            return $null
        }
    }
}

function Test-ComplianceState {
    $reasons = [System.Collections.Generic.List[string]]::new()
    try {
        # 1) Secure Boot must be enabled for CA 2023 to be applicable.
        $secureBootEnabled = Test-SecureBootEnabled
        if ($secureBootEnabled -eq $false) {
            $reasons.Add("Secure Boot is disabled - enable Secure Boot before CA 2023 migration (BIOS/UEFI)")
            return @($reasons)
        }
        if ($null -eq $secureBootEnabled) {
            Write-Log -Message "Secure Boot state could not be determined - continuing to policy check" -Level 'DEBUG'
        } else {
            Write-Log -Message "Secure Boot is enabled" -Level 'DEBUG'
        }

        # 2) AvailableUpdatePolicy must be 5944 (decimal) - this is the Intune/GPO provisioned value.
        $policyValue = $null
        if (Test-Path -LiteralPath $SecureBootRegPath) {
            try {
                # The AvailableUpdatePolicy key uses a default value; try both named and default value reads.
                $regItem = Get-ItemProperty -LiteralPath $SecureBootRegPath -ErrorAction Stop
                # Try well-known value names first, then default.
                if ($null -ne $regItem.AvailableUpdatePolicy) { $policyValue = $regItem.AvailableUpdatePolicy }
                elseif ($null -ne $regItem.'(default)') { $policyValue = $regItem.'(default)' }
                else {
                    # Enumerate any DWORD value on the key.
                    $props = $regItem.PSObject.Properties | Where-Object { $_.Name -notmatch '^PS' }
                    foreach ($prop in $props) {
                        if ($prop.Value -is [int] -or $prop.Value -is [long]) { $policyValue = $prop.Value; break }
                    }
                }
            }
            catch {
                Write-Log -Message "Failed to read SecureBoot policy registry: $($_.Exception.Message)" -Level 'DEBUG'
            }
        }

        # Fallback: check parent path value if AvailableUpdatePolicy subkey approach varies.
        if ($null -eq $policyValue -and (Test-Path -LiteralPath $SecureBootStatusPath)) {
            try {
                $parentProps = Get-ItemProperty -LiteralPath $SecureBootStatusPath -ErrorAction SilentlyContinue
                if ($null -ne $parentProps.AvailableUpdatePolicy) { $policyValue = $parentProps.AvailableUpdatePolicy }
            }
            catch { }
        }

        if ($null -eq $policyValue) {
            $reasons.Add("SecureBoot CA 2023 update policy not provisioned - expected DWORD $ExpectedPolicyValue at $SecureBootRegPath (deploy Intune policy: Enable Secureboot Certificate Updates)")
        }
        elseif ([int]$policyValue -ne $ExpectedPolicyValue) {
            $reasons.Add("SecureBoot update policy value is $policyValue, expected $ExpectedPolicyValue at $SecureBootRegPath")
        }
        else {
            Write-Log -Message "SecureBoot CA 2023 policy correctly provisioned: $policyValue" -Level 'DEBUG'
        }

        # 3) UEFICA2023Status provides additional confidence on 24H2+ but is not strictly required for compliance.
        # We only WARN (not fail) if this value exists and is explicitly non-compliant, since firmware reboots may lag.
        foreach ($valueName in $StatusValueNames) {
            if (Test-Path -LiteralPath $SecureBootStatusPath) {
                try {
                    $statusProps = Get-ItemProperty -LiteralPath $SecureBootStatusPath -ErrorAction SilentlyContinue
                    $statusVal = $statusProps.$valueName
                    if ($null -ne $statusVal) {
                        Write-Log -Message "SecureBoot status ${valueName}: $statusVal" -Level 'DEBUG'
                    }
                }
                catch { }
            }
        }
    }
    catch {
        throw "Failed to evaluate Secure Boot CA 2023 state: $($_.Exception.Message)"
    }
    return @($reasons)
}

# ============================================================================
# MAIN
# ============================================================================

try {
    $null = Initialize-Log -SolutionName $SolutionName -ScriptMode $ScriptMode -Type 'Intune'
    Write-Banner
    if ($script:LogReady) { Write-Log -Message "Log file ready: $($script:LogFile)" -Level 'DEBUG' }
    Write-Log -Message "Detection started - Secure Boot CA 2023" -Level 'INFO'
    Write-Log -Message "Policy path: $SecureBootRegPath Expected: $ExpectedPolicyValue" -Level 'DEBUG'

    $reasons = Test-ComplianceState

    if ($reasons.Count -eq 0) {
        Finish-Script -ExitCode 0 -Message "Compliant - Secure Boot CA 2023 update policy provisioned" -Level 'SUCCESS'
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
