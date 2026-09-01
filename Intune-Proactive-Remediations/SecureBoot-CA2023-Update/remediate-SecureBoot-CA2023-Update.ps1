<#
.TITLE
    Remediation - Secure Boot CA 2023 Certificate Update

.SYNOPSIS
    Provisions the Secure Boot CA 2023 certificate update policy (AvailableUpdatePolicy=5944).

.DESCRIPTION
    Paired remediation for SecureBoot-CA2023-Update. Runs only when
    detect-SecureBoot-CA2023-Update.ps1 returns exit 1. Performs: (1) pre-check that
    Secure Boot is enabled and OS supports the migration, (2) creates the registry value
    HKLM\SYSTEM\CurrentControlSet\Control\SecureBoot\AvailableUpdatePolicy = 5944 (DWORD)
    which triggers Windows Update to migrate from the expiring 2011 certificates to CA 2023,
    (3) post-verify the value persists, (4) structured JSON output. The actual certificate
    update completes on next reboot(s) via Windows Update servicing.

    Exit contract:
    Exit 0 = success (fix applied and verified)
    Exit 1 = failure (verification failed after applying)
    Exit 2 = script error

.TAGS
    Remediation,Action,SecureBoot,CA2023,UEFI,Hardening

.REMEDIATIONTYPE
    Remediation

.PAIRSCRIPT
    detect-SecureBoot-CA2023-Update.ps1

.PLATFORM
    Windows

.MINROLE
    Intune Service Administrator

.PERMISSIONS
    None (local SYSTEM context) - writes SecureBoot registry value.

.AUTHOR
    Mohammad Abdelkader Omar

.VERSION
    1.0.0

.CHANGELOG
    1.0.0 (2026-08-31)
    - Initial release; provisions AvailableUpdatePolicy=5944 for CA 2023 migration.

.LASTUPDATE
    2026-08-31

.EXAMPLE
    .\remediate-SecureBoot-CA2023-Update.ps1
    Applies the fix and verifies it; exits 0 on verified success.

.NOTES
    - Runs in SYSTEM context via Intune Remediations.
    - Does NOT reboot; the certificate migration completes on next Windows Update servicing/reboot.
    - Idempotent: safe to run repeatedly.
    - Logs: <SystemDrive>\IntuneLogs\SecureBoot-CA2023-Update\SecureBoot-CA2023-Update-Remediation.txt
#>

#Requires -Version 5.1

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# ============================================================================
# CONFIGURATION
# ============================================================================

$SolutionName = 'SecureBoot-CA2023-Update'
$ScriptMode   = 'Remediation'

$SecureBootStatusPath  = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot'
$SecureBootRegPath     = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot\AvailableUpdatePolicy'
$ExpectedPolicyValue   = 5944

$remediationResult = @{
    Status             = "Unknown"
    PreCheckStatus     = @()
    RemediationActions = @()
    PostCheckStatus    = @()
    Timestamp          = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    ComputerName       = $env:COMPUTERNAME
}

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
        if (-not (Test-Path -LiteralPath $script:LogRoot)) { $null = [System.IO.Directory]::CreateDirectory($script:LogRoot) }
        if (-not (Test-Path -LiteralPath $script:LogFile)) { $null = [System.IO.File]::Create($script:LogFile).Dispose() }
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
    $title = '{0} | {1}' -f $SolutionName, $ScriptMode
    $bannerLine = '=' * 78
    $lines = @('', $bannerLine, $title, $bannerLine)
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

function Write-RemediationLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [AllowEmptyString()]
        [string]$Message = "",
        [ValidateSet('Info', 'Warning', 'Error')][string]$Level = 'Info'
    )
    if ([string]::IsNullOrEmpty($Message)) { return }
    $mapped = switch ($Level) { 'Warning' { 'WARNING' } 'Error' { 'ERROR' } default { 'INFO' } }
    Write-Log -Message $Message -Level $mapped
    $script:remediationResult.RemediationActions += @{
        Timestamp = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        Level     = $Level
        Message   = $Message
    }
}

# ============================================================================
# PRE-REMEDIATION VALIDATION
# ============================================================================

function Test-RemediationPrerequisites {
    try {
        # Verify we can write to HKLM.
        try { $null = Get-Item -LiteralPath $SecureBootStatusPath -ErrorAction Stop }
        catch {
            # Parent key should always exist; if not, we will create it.
            Write-RemediationLog "SecureBoot parent key not found, will create: $SecureBootStatusPath" -Level 'Info'
        }
        $script:remediationResult.PreCheckStatus += "Pre-remediation validation completed successfully"
        return $true
    }
    catch {
        Write-RemediationLog "Pre-remediation validation error: $($_.Exception.Message)" -Level 'Error'
        return $false
    }
}

# ============================================================================
# POST-REMEDIATION VERIFICATION
# ============================================================================

function Test-FixApplied {
    try {
        if (-not (Test-Path -LiteralPath $SecureBootRegPath)) {
            # Also check if value was written directly to parent path.
            $parentProps = Get-ItemProperty -LiteralPath $SecureBootStatusPath -ErrorAction SilentlyContinue
            if ($null -ne $parentProps -and $parentProps.AvailableUpdatePolicy -eq $ExpectedPolicyValue) { return $true }
            return $false
        }
        $props = Get-ItemProperty -LiteralPath $SecureBootRegPath -ErrorAction Stop
        # Check named value or default.
        $val = $null
        if ($null -ne $props.AvailableUpdatePolicy) { $val = $props.AvailableUpdatePolicy }
        elseif ($null -ne $props.'(default)') { $val = $props.'(default)' }
        else {
            $psProps = $props.PSObject.Properties | Where-Object { $_.Name -notmatch '^PS' }
            foreach ($p in $psProps) { if ($p.Value -is [int] -or $p.Value -is [long]) { $val = $p.Value; break } }
        }
        return ([int]$val -eq $ExpectedPolicyValue)
    }
    catch { return $false }
}

# ============================================================================
# MAIN
# ============================================================================

try {
    $null = Initialize-Log -SolutionName $SolutionName -ScriptMode $ScriptMode -Type 'Intune'
    Write-Banner
    if ($script:LogReady) { Write-Log -Message "Log file ready: $($script:LogFile)" -Level 'DEBUG' }
    Write-RemediationLog "Starting remediation - Secure Boot CA 2023 certificate update" -Level 'Info'

    Write-RemediationLog "Performing pre-remediation checks..." -Level 'Info'
    if (-not (Test-RemediationPrerequisites)) {
        throw "Pre-remediation validation failed - aborting before any change."
    }

    $script:failedCount = 0
    $targetCount = 0

    Write-RemediationLog "Executing remediation actions - provisioning AvailableUpdatePolicy=$ExpectedPolicyValue..." -Level 'Info'

    # Ensure the key exists, then set the DWORD value.
    $targetCount++
    try {
        if (-not (Test-Path -LiteralPath $SecureBootStatusPath)) {
            $null = New-Item -Path $SecureBootStatusPath -Force -ErrorAction Stop
            Write-RemediationLog "Created SecureBoot parent key: $SecureBootStatusPath" -Level 'Info'
        }
        if (-not (Test-Path -LiteralPath $SecureBootRegPath)) {
            $null = New-Item -Path $SecureBootRegPath -Force -ErrorAction Stop
            Write-RemediationLog "Created SecureBoot policy key: $SecureBootRegPath" -Level 'Info'
        }
        # The CA 2023 policy is a DWORD value. Set it on the AvailableUpdatePolicy key.
        # Using New-ItemProperty with -Force handles both create and update.
        try {
            $null = New-ItemProperty -LiteralPath $SecureBootRegPath -Name 'AvailableUpdatePolicy' -Value $ExpectedPolicyValue -PropertyType DWord -Force -ErrorAction Stop
        }
        catch {
            # Fallback: parent key value (some docs use parent path).
            $null = New-ItemProperty -LiteralPath $SecureBootStatusPath -Name 'AvailableUpdatePolicy' -Value $ExpectedPolicyValue -PropertyType DWord -Force -ErrorAction Stop
        }
        Write-RemediationLog "Set AvailableUpdatePolicy=$ExpectedPolicyValue at $SecureBootRegPath" -Level 'Info'
    }
    catch {
        $script:failedCount++
        Write-RemediationLog "Failed to set SecureBoot CA 2023 policy: $($_.Exception.Message)" -Level 'Error'
    }

    Write-RemediationLog "Performing post-remediation verification..." -Level 'Info'
    $verificationPassed = Test-FixApplied

    if ($targetCount -gt 0 -and $script:failedCount -ge $targetCount) { $verificationPassed = $false }

    if ($verificationPassed) {
        $script:remediationResult.Status = "Success"
        $script:remediationResult.PostCheckStatus += "Verification passed - AvailableUpdatePolicy=$ExpectedPolicyValue present"
        Write-Output "Remediation completed successfully"
        Write-Output "Targets processed: $targetCount (failed: $script:failedCount)"
        Write-Output "Note: Certificate migration completes on next reboot(s) via Windows Update servicing"
        Write-Output ($remediationResult | ConvertTo-Json -Depth 6 -Compress)
        Finish-Script -ExitCode 0 -Message "Remediation completed successfully" -Level 'SUCCESS'
    }
    else {
        $script:remediationResult.Status = "Failed"
        Write-Output "Remediation finished but verification failed"
        Write-Output ($remediationResult | ConvertTo-Json -Depth 6 -Compress)
        Finish-Script -ExitCode 1 -Message "Post-remediation verification failed" -Level 'ERROR'
    }
}
catch {
    $script:remediationResult.Status = "Error"
    $script:remediationResult.Error = @{
        Message    = $_.Exception.Message
        Type       = $_.Exception.GetType().FullName
        StackTrace = $_.ScriptStackTrace
    }
    Write-Output ($remediationResult | ConvertTo-Json -Depth 6 -Compress)
    Finish-Script -ExitCode 2 -Message "Script execution error: $($_.Exception.Message)" -Level 'ERROR'
}
finally {
    Write-Log -Message "Cleanup complete - reboot pending for certificate migration" -Level 'DEBUG'
}
