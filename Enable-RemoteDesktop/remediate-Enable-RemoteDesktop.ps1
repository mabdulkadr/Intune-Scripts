<#
.TITLE
    Remediation - Enable Remote Desktop

.SYNOPSIS
    Enables Remote Desktop, Network Level Authentication, RDP UDP support, and
    creates the expected inbound firewall rules.

.DESCRIPTION
    Paired remediation for Enable-RemoteDesktop. Runs only when
    detect-Enable-RemoteDesktop.ps1 returns exit 1. Performs: (1) pre-remediation
    validation, (2) registry and firewall fixes with failure tracking,
    (3) post-remediation verification, (4) structured JSON result output for
    Intune diagnostics.

    Exit contract:
    Exit 0 = success (fix applied and verified)
    Exit 1 = failure (verification failed after applying)
    Exit 2 = script error

.TAGS
    Remediation,Action,RemoteDesktop,RDP

.REMEDIATIONTYPE
    Remediation

.PAIRSCRIPT
    detect-Enable-RemoteDesktop.ps1

.PLATFORM
    Windows

.MINROLE
    Intune Service Administrator

.PERMISSIONS
    None (local SYSTEM context) - writes registry values and manages firewall rules.

.AUTHOR
    Mohammad Abdelkader Omar

.VERSION
    2.0.0

.CHANGELOG
    2.0.0 (2026-08-26)
    - Migrated to Enterprise Standards canonical structure (header, logging, exit contract)
    - Added pre-check / per-target fix / post-verify flow with JSON result output
    1.5 - Legacy release

.LASTUPDATE
    2026-08-26

.EXAMPLE
    .\remediate-Enable-RemoteDesktop.ps1
    Applies the fixes and verifies them; exits 0 on verified success.

.EXAMPLE
    .\remediate-Enable-RemoteDesktop.ps1
    Exits 1 if verification fails, exit 2 on unexpected script error.

.NOTES
    - Runs in SYSTEM context via Intune Proactive Remediations.
    - Idempotent: safe to run repeatedly; verify-before-and-after.
    - Logs: <SystemDrive>\IntuneLogs\Enable-RemoteDesktop\Enable-RemoteDesktop-Remediation.txt
#>

#Requires -Version 5.1

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# ============================================================================
# CONFIGURATION - solution identity and desired state values.
# ============================================================================

$SolutionName = 'Enable-RemoteDesktop'
$ScriptMode   = 'Remediation'

$TerminalServerPath  = 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server'
$TerminalServerName  = 'fDenyTSConnections'
$TerminalServerValue = 0
$ClientPolicyPath    = 'HKLM:\Software\Policies\Microsoft\Windows NT\Terminal Services\Client'
$ClientUdpName       = 'fClientDisableUDP'
$ClientUdpValue      = 0
$RdpTcpPath          = 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp'
$NlaRegistryName     = 'UserAuthentication'
$NlaRegistryValue    = 1
$TcpFirewallRuleName = 'RDP (TCP)'
$UdpFirewallRuleName = 'RDP (UDP)'
$RemoteAddress       = 'Any'

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

# Appends structured per-target remediation entries to the audit trail.
function Write-RemediationLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)][AllowEmptyString()][string]$Message = "",
        [ValidateSet('Info', 'Warning', 'Error')][string]$Level = 'Info'
    )
    # Console/file via canonical Write-Log + structured record for JSON output.
    $mapped = switch ($Level) { 'Warning' { 'WARNING' } 'Error' { 'ERROR' } default { 'INFO' } }
    Write-Log -Message $Message -Level $mapped
    $script:RemediationResult.RemediationActions += @{
        Timestamp = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        Level     = $Level
        Message   = $Message
    }
}

# ============================================================================
# PRE-REMEDIATION VALIDATION
# ============================================================================

# Gate check before any mutation - failures must not touch target state.
function Test-RemediationPrerequisites {
    try {
        # The base Terminal Server key must exist before values can be written to it.
        if (-not (Test-Path -LiteralPath $TerminalServerPath)) {
            throw "Required registry key not found: $TerminalServerPath"
        }

        $script:RemediationResult.PreCheckStatus += "Pre-remediation validation completed successfully"
        return $true
    }
    catch {
        Write-RemediationLog "Pre-remediation validation error: $($_.Exception.Message)" -Level 'Error'
        return $false
    }
}

# ============================================================================
# REMEDIATION ACTION (per-target pattern)
# ============================================================================

# Applies the fix to ONE target and returns a structured success/failure object.
function Invoke-FixTarget {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$TargetName,
        [Parameter(Mandatory = $true)][scriptblock]$Fix
    )
    # Returns $true when the fix was applied AND verified for this target.
    try {
        & $Fix
        return $true
    }
    catch {
        $script:FailedCount++
        Write-RemediationLog "Target FAILED: $TargetName - $($_.Exception.Message)" -Level 'Warning'
        return $false
    }
}

# Resolves the configured remote address scope ('*' or empty means Any).
function Get-EffectiveRemoteAddress {
    if ([string]::IsNullOrWhiteSpace($RemoteAddress) -or $RemoteAddress -eq '*') {
        return 'Any'
    }

    return $RemoteAddress.Trim()
}

# Ensures one registry value matches the desired state, creating the key when missing.
function Ensure-RegistryValue {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][int]$Value
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -Path $Path -Force -ErrorAction Stop | Out-Null
    }

    Write-RemediationLog "Setting '$Name' in '$Path' to '$Value'" -Level 'Info'
    Set-ItemProperty -LiteralPath $Path -Name $Name -Value $Value -Force -ErrorAction Stop | Out-Null

    $currentValue = Get-ItemPropertyValue -LiteralPath $Path -Name $Name -ErrorAction Stop
    if ($currentValue -ne $Value) {
        throw "Registry update ran, but $Name is still $currentValue."
    }
}

# Ensures an inbound RDP firewall rule exists and is enabled for the configured scope.
function Ensure-RdpFirewallRule {
    param(
        [Parameter(Mandatory = $true)][string]$DisplayName,
        [Parameter(Mandatory = $true)][ValidateSet('TCP', 'UDP')][string]$Protocol
    )

    $effectiveRemoteAddress = Get-EffectiveRemoteAddress
    $existingRule = Get-NetFirewallRule -DisplayName $DisplayName -ErrorAction SilentlyContinue

    if ($existingRule) {
        Write-RemediationLog "Updating firewall rule '$DisplayName' for protocol $Protocol with remote address '$effectiveRemoteAddress'" -Level 'Info'
        Set-NetFirewallRule -DisplayName $DisplayName -Direction Inbound -Action Allow -Protocol $Protocol -LocalPort '3389' -RemoteAddress $effectiveRemoteAddress -Profile Any -Enabled True -ErrorAction Stop | Out-Null
        return
    }

    Write-RemediationLog "Creating firewall rule '$DisplayName' for protocol $Protocol with remote address '$effectiveRemoteAddress'" -Level 'Info'
    New-NetFirewallRule -DisplayName $DisplayName -Direction Inbound -Action Allow -Protocol $Protocol -LocalPort 3389 -RemoteAddress $effectiveRemoteAddress -Profile Any -Enabled True -ErrorAction Stop | Out-Null
}

# ============================================================================
# POST-REMEDIATION VERIFICATION
# ============================================================================

# Post-fix verification - trust-but-verify before declaring exit 0.
function Test-FixApplied {
    try {
        # Re-check every condition the detector evaluated. Return $true only
        # when the observed state now matches the compliant definition.
        $denyOk = ((Get-ItemPropertyValue -LiteralPath $TerminalServerPath -Name $TerminalServerName -ErrorAction Stop) -eq $TerminalServerValue)
        $udpOk  = ((Get-ItemPropertyValue -LiteralPath $ClientPolicyPath -Name $ClientUdpName -ErrorAction Stop) -eq $ClientUdpValue)
        $nlaOk  = ((Get-ItemPropertyValue -LiteralPath $RdpTcpPath -Name $NlaRegistryName -ErrorAction Stop) -eq $NlaRegistryValue)

        $tcpRule = Get-NetFirewallRule -DisplayName $TcpFirewallRuleName -ErrorAction SilentlyContinue | Select-Object -First 1
        $udpRule = Get-NetFirewallRule -DisplayName $UdpFirewallRuleName -ErrorAction SilentlyContinue | Select-Object -First 1
        $tcpOk   = ($null -ne $tcpRule -and $tcpRule.Enabled -eq 'True')
        $fwUdpOk = ($null -ne $udpRule -and $udpRule.Enabled -eq 'True')

        return ($denyOk -and $udpOk -and $nlaOk -and $tcpOk -and $fwUdpOk)
    }
    catch {
        Write-RemediationLog "Verification could not read the Remote Desktop state: $($_.Exception.Message)" -Level 'Error'
        return $false
    }
}

# ============================================================================
# MAIN
# ============================================================================
# Flow: init -> pre-checks -> per-target fix -> post-verify -> exit 0 / 1 / 2.

try {
    $null = Initialize-Log -SolutionName $SolutionName -ScriptMode $ScriptMode -Type 'Intune'
    Write-Banner
    if ($script:LogReady) {
        Write-Log -Message "Log file ready: $($script:LogFile)" -Level 'DEBUG'
    }
    Write-RemediationLog "Starting remediation..." -Level 'Info'

    # --- Pre-checks ---
    Write-RemediationLog "Performing pre-remediation checks..." -Level 'Info'
    if (-not (Test-RemediationPrerequisites)) {
        throw "Pre-remediation validation failed - aborting before any change."
    }

    # --- Fix (per-target failure tracking) ---
    $script:FailedCount = 0
    $targetCount        = 0

    Write-RemediationLog "Executing remediation actions..." -Level 'Info'

    $targetCount++
    Invoke-FixTarget -TargetName "$TerminalServerName=$TerminalServerValue" -Fix {
        Ensure-RegistryValue -Path $TerminalServerPath -Name $TerminalServerName -Value $TerminalServerValue
    }

    $targetCount++
    Invoke-FixTarget -TargetName "$ClientUdpName=$ClientUdpValue" -Fix {
        Ensure-RegistryValue -Path $ClientPolicyPath -Name $ClientUdpName -Value $ClientUdpValue
    }

    $targetCount++
    Invoke-FixTarget -TargetName "$NlaRegistryName=$NlaRegistryValue" -Fix {
        Ensure-RegistryValue -Path $RdpTcpPath -Name $NlaRegistryName -Value $NlaRegistryValue
    }

    $targetCount++
    Invoke-FixTarget -TargetName "Firewall rule '$TcpFirewallRuleName' (TCP)" -Fix {
        Ensure-RdpFirewallRule -DisplayName $TcpFirewallRuleName -Protocol 'TCP'
    }

    $targetCount++
    Invoke-FixTarget -TargetName "Firewall rule '$UdpFirewallRuleName' (UDP)" -Fix {
        Ensure-RdpFirewallRule -DisplayName $UdpFirewallRuleName -Protocol 'UDP'
    }

    # --- Verify ---
    Write-RemediationLog "Performing post-remediation verification..." -Level 'Info'
    $verificationPassed = Test-FixApplied

    if ($targetCount -gt 0 -and $failedCount -ge $targetCount) {
        $verificationPassed = $false
    }

    # --- Report ---
    if ($verificationPassed) {
        $script:RemediationResult.Status = "Success"
        $script:RemediationResult.PostCheckStatus += "Verification passed after remediation"

        Write-Output "Remediation completed successfully"
        Write-Output "Targets processed: $targetCount (failed: $failedCount)"
        Write-Output ($remediationResult | ConvertTo-Json -Depth 6 -Compress)

        Finish-Script -ExitCode 0 -Message "Remote Desktop was enabled successfully and firewall access was configured for remote address '$(Get-EffectiveRemoteAddress)'" -Level 'SUCCESS'
    }
    else {
        $script:RemediationResult.Status = "Failed"
        Write-Output "Remediation finished but verification failed"
        Write-Output ($remediationResult | ConvertTo-Json -Depth 6 -Compress)
        Finish-Script -ExitCode 1 -Message "Post-remediation verification failed" -Level 'ERROR'
    }
}
catch {
    $script:RemediationResult.Status = "Error"
    $script:RemediationResult.Error = @{
        Message    = $_.Exception.Message
        Type       = $_.Exception.GetType().FullName
        StackTrace = $_.ScriptStackTrace
    }
    Write-Output ($remediationResult | ConvertTo-Json -Depth 6 -Compress)
    Finish-Script -ExitCode 2 -Message "Script execution error: $($_.Exception.Message)" -Level 'ERROR'
}
finally {
    Write-Log -Message "Cleanup complete." -Level 'DEBUG'
}
