<#
.TITLE
    Detection - Remote Desktop Enabled

.SYNOPSIS
    Verifies that Remote Desktop, Network Level Authentication, RDP UDP support,
    and the inbound RDP firewall rules are configured as expected.

.DESCRIPTION
    Evaluates five conditions required by the enterprise Remote Desktop baseline:
    (1) fDenyTSConnections=0 under the Terminal Server key, (2) fClientDisableUDP=0
    under the Terminal Services client policy key, (3) UserAuthentication=1 for
    RDP-Tcp (Network Level Authentication), (4) the inbound 'RDP (TCP)' firewall
    rule exists and is enabled, and (5) the inbound 'RDP (UDP)' firewall rule
    exists and is enabled. This script NEVER modifies the system.

    Exit contract:
    Exit 0 = compliant (no remediation needed)
    Exit 1 = non-compliant (Intune runs the paired remediation)
    Exit 2 = script error (Intune must NOT treat a crash as non-compliance)

.TAGS
    Remediation,Detection,RemoteDesktop,RDP

.REMEDIATIONTYPE
    Detection

.PAIRSCRIPT
    remediate-Enable-RemoteDesktop.ps1

.PLATFORM
    Windows

.MINROLE
    Intune Service Administrator

.PERMISSIONS
    None (local SYSTEM context) - reads registry values and firewall rules.

.AUTHOR
    Mohammad Abdelkader Omar

.VERSION
    2.0.0

.CHANGELOG
    2.0.0 (2026-08-26)
    - Migrated to Enterprise Standards canonical structure (header, logging, exit contract)
    - Detection errors now exit 2 instead of 1 so Intune never treats crashes as non-compliance
    1.4 - Legacy release

.LASTUPDATE
    2026-08-26

.EXAMPLE
    .\detect-Enable-RemoteDesktop.ps1
    Returns exit 0 when compliant; exit 1 when the paired remediation must run.

.EXAMPLE
    .\detect-Enable-RemoteDesktop.ps1
    Returns exit 2 when an unexpected error prevents evaluation.

.NOTES
    - Runs in SYSTEM context via Intune Proactive Remediations.
    - Keep detection under 30 seconds: registry reads and two firewall rule queries only.
    - Idempotent and read-only by definition.
    - Logs: <SystemDrive>\IntuneLogs\Enable-RemoteDesktop\Enable-RemoteDesktop-Detection.txt
#>

#Requires -Version 5.1

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# ============================================================================
# CONFIGURATION - solution identity and compliance target values.
# ============================================================================

$SolutionName = 'Enable-RemoteDesktop'
$ScriptMode   = 'Detection'

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
        [AllowEmptyString()]
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
        $denyValue = Get-ItemPropertyValue -LiteralPath $TerminalServerPath -Name $TerminalServerName -ErrorAction Stop
        Write-Log -Message "Current $TerminalServerName value: $denyValue" -Level 'DEBUG'

        if ($denyValue -ne $TerminalServerValue) {
            $reasons.Add("Remote Desktop is disabled - expected $TerminalServerName=$TerminalServerValue, found $denyValue")
        }
    }
    catch [System.Management.Automation.ItemNotFoundException] {
        $reasons.Add("Registry value missing: $TerminalServerPath\$TerminalServerName does not exist")
    }
    catch {
        throw "Failed to read ${TerminalServerName}: $($_.Exception.Message)"
    }

    try {
        $clientUdpValue = Get-ItemPropertyValue -LiteralPath $ClientPolicyPath -Name $ClientUdpName -ErrorAction Stop
        Write-Log -Message "Current $ClientUdpName value: $clientUdpValue" -Level 'DEBUG'

        if ($clientUdpValue -ne $ClientUdpValue) {
            $reasons.Add("RDP UDP support is misconfigured - expected $ClientUdpName=$ClientUdpValue, found $clientUdpValue")
        }
    }
    catch [System.Management.Automation.ItemNotFoundException] {
        $reasons.Add("Registry value missing: $ClientPolicyPath\$ClientUdpName does not exist")
    }
    catch {
        throw "Failed to read ${ClientUdpName}: $($_.Exception.Message)"
    }

    try {
        $nlaValue = Get-ItemPropertyValue -LiteralPath $RdpTcpPath -Name $NlaRegistryName -ErrorAction Stop
        Write-Log -Message "Current $NlaRegistryName value: $nlaValue" -Level 'DEBUG'

        if ($nlaValue -ne $NlaRegistryValue) {
            $reasons.Add("Network Level Authentication is misconfigured - expected $NlaRegistryName=$NlaRegistryValue, found $nlaValue")
        }
    }
    catch [System.Management.Automation.ItemNotFoundException] {
        $reasons.Add("Registry value missing: $RdpTcpPath\$NlaRegistryName does not exist")
    }
    catch {
        throw "Failed to read ${NlaRegistryName}: $($_.Exception.Message)"
    }

    $tcpRule = Get-NetFirewallRule -DisplayName $TcpFirewallRuleName -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($null -eq $tcpRule) {
        $reasons.Add("The inbound '$TcpFirewallRuleName' firewall rule does not exist")
    }
    elseif ($tcpRule.Enabled -ne 'True') {
        $reasons.Add("The inbound '$TcpFirewallRuleName' firewall rule exists but is disabled")
    }

    $udpRule = Get-NetFirewallRule -DisplayName $UdpFirewallRuleName -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($null -eq $udpRule) {
        $reasons.Add("The inbound '$UdpFirewallRuleName' firewall rule does not exist")
    }
    elseif ($udpRule.Enabled -ne 'True') {
        $reasons.Add("The inbound '$UdpFirewallRuleName' firewall rule exists but is disabled")
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
        Finish-Script -ExitCode 0 -Message "Compliant - Remote Desktop registry and firewall settings are configured as expected" -Level 'SUCCESS'
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
