<#
.TITLE
    Delivery Optimization Troubleshooting

.SYNOPSIS
    Verifies and repairs the local Windows Delivery Optimization stack (service, ports, Teredo, endpoints, bandwidth policies, connectivity, firewall).

.DESCRIPTION
    Runs a full set of local health probes for Delivery Optimization: it checks the DoSvc service
    (starting it when stopped), tests required TCP/UDP ports, inspects and repairs the Teredo state,
    lists active Delivery Optimization jobs, probes Microsoft delivery endpoints over HTTP, reads the
    Delivery Optimization bandwidth policy registry key, pings a general connectivity target, and
    enumerates Delivery Optimization firewall rules.

    This is a purely local tool - it never calls Microsoft Graph. It DOES modify the system when a
    component is unhealthy: Start-Service on DoSvc and "netsh interface teredo set state enterpriseclient".

.TAGS
    Windows,Networking,DeliveryOptimization,Troubleshooting,Diagnostics

.PLATFORM
    Windows

.MINROLE
    None (standalone tool)

.PERMISSIONS
    None (local SYSTEM context) - inspects services, firewall rules, registry and network reachability; starts DoSvc and reconfigures Teredo when unhealthy; run from an elevated console.

.AUTHOR
    Mohammad Abdelkader Omar

.VERSION
    2.0.0

.CHANGELOG
    2.0.0 (2026-08-26)
    - Migrated to Enterprise Standards canonical structure (header, logging, typed catches)
    - Console output now mirrored to C:\ProgramData\DeliveryOptimization\Logs\
    1.0.0 (legacy)
    - Initial release (date unknown)

.LASTUPDATE
    2026-08-26

.EXAMPLE
    .\Set-DeliveryOptimization.ps1
    Runs every check in sequence and reports each result in the console and log file.

.EXAMPLE
    .\Set-DeliveryOptimization.ps1
    Run from an elevated prompt after Delivery Optimization download stalls to repair DoSvc/Teredo automatically.

.NOTES
    - Mutating actions are limited to starting DoSvc and switching Teredo to enterpriseclient mode.
    - Port tests probe www.microsoft.com; endpoint tests probe four Microsoft delivery URLs with a 10 second timeout.
    - Exit 0 = all checks executed; exit 1 = an unexpected error aborted the run. Individual check failures are logged and do not abort.
    - Logs: C:\ProgramData\DeliveryOptimization\Logs\
#>

#Requires -Version 5.1

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# ============================================================================
# CONFIGURATION - solution identity and probe targets.
# ============================================================================

$SolutionName = 'DeliveryOptimization'
$ScriptMode   = 'Troubleshooting'

$DORegistryPath   = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config'
$ConnectivityHost = '8.8.8.8'
$PortTestHost     = 'www.microsoft.com'

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
# SERVICE CHECKS
# Verifies the Delivery Optimization service and repairs a stopped state.
# ============================================================================

# Confirms DoSvc is running and starts it when stopped.
function Test-DOService {
    Write-Log -Message "Checking Delivery Optimization Service (DoSvc)" -Level 'INFO'
    try {
        $Service = Get-Service -Name DoSvc -ErrorAction Stop
        if ($Service.Status -eq "Running") {
            Write-Log -Message "Delivery Optimization service is running." -Level 'SUCCESS'
        } else {
            Write-Log -Message "Delivery Optimization service is NOT running. Attempting to start..." -Level 'WARNING'
            Start-Service -Name DoSvc
            Write-Log -Message "Delivery Optimization service started successfully." -Level 'SUCCESS'
        }
    }
    catch {
        Write-Log -Message "Error checking or starting Delivery Optimization service: $($_.Exception.Message)" -Level 'ERROR'
    }
}

# ============================================================================
# PORT AND TEREDO CHECKS
# Probes the required Delivery Optimization ports and repairs Teredo.
# ============================================================================

# Tests the required TCP ports and hands UDP coverage to the Teredo check.
function Test-DOPorts {
    Write-Log -Message "Testing Delivery Optimization Required Ports" -Level 'INFO'
    $Ports = @(
        @{ Name = "TCP - 7680 (P2P)"; Port = 7680; Protocol = "TCP" },
        @{ Name = "UDP - 3544 (Teredo)"; Port = 3544; Protocol = "UDP" },
        @{ Name = "TCP - 443 (HTTPS)"; Port = 443; Protocol = "TCP" }
    )

    foreach ($Port in $Ports) {
        Write-Log -Message "Testing $($Port.Name)..." -Level 'INFO'
        if ($Port.Protocol -eq "TCP") {
            $Result = Test-NetConnection -ComputerName $PortTestHost -Port $Port.Port
            if ($Result.TcpTestSucceeded) {
                Write-Log -Message "$($Port.Name) is reachable and functional." -Level 'SUCCESS'
            } else {
                Write-Log -Message "$($Port.Name) is NOT reachable. Check firewall or network configuration." -Level 'ERROR'
            }
        } elseif ($Port.Protocol -eq "UDP") {
            Write-Log -Message "Testing UDP Port 3544 (Teredo NAT Traversal)..." -Level 'WARNING'
            Repair-TeredoState
        }
    }
}

# Reads the Teredo state and switches it to enterpriseclient when not qualified.
function Repair-TeredoState {
    Write-Log -Message "Checking Teredo Status (UDP Port 3544)" -Level 'INFO'
    try {
        $TeredoState = netsh interface teredo show state | Select-String "State"
        if ($TeredoState -match "qualified") {
            Write-Log -Message "Teredo is enabled and in a qualified state." -Level 'SUCCESS'
        } else {
            Write-Log -Message "Teredo is NOT in a qualified state. Attempting to enable it..." -Level 'WARNING'
            netsh interface teredo set state enterpriseclient
            Write-Log -Message "Teredo has been enabled. Verify its status by rerunning this script." -Level 'SUCCESS'
        }
    }
    catch {
        Write-Log -Message "Error checking Teredo status: $($_.Exception.Message)" -Level 'ERROR'
    }
}

# ============================================================================
# JOB AND ENDPOINT CHECKS
# Lists active Delivery Optimization jobs and probes Microsoft endpoints.
# ============================================================================

# Reports every active (downloading or uploading) Delivery Optimization job.
function Get-DOActiveJobs {
    Write-Log -Message "Checking Delivery Optimization Jobs" -Level 'INFO'
    try {
        $Jobs = Get-DeliveryOptimizationStatus | Where-Object { $_.State -eq "Downloading" -or $_.State -eq "Uploading" }
        if ($Jobs) {
            Write-Log -Message "Active Delivery Optimization jobs found:" -Level 'SUCCESS'
            $Jobs | Format-Table -AutoSize | Out-Host
        } else {
            Write-Log -Message "No active Delivery Optimization jobs." -Level 'WARNING'
        }
    }
    catch {
        Write-Log -Message "Error retrieving Delivery Optimization jobs: $($_.Exception.Message)" -Level 'ERROR'
    }
}

# Probes connectivity to the Microsoft Delivery Optimization endpoints.
function Test-DOEndpoints {
    Write-Log -Message "Testing Connectivity to Microsoft Delivery Optimization Endpoints" -Level 'INFO'
    $Endpoints = @(
        "http://download.microsoft.com",
        "http://tlu.dl.delivery.mp.microsoft.com",
        "http://geo.delivery.mp.microsoft.com",
        "http://*.do.dsp.mp.microsoft.com"
    )

    foreach ($Endpoint in $Endpoints) {
        Write-Log -Message "Testing connection to $Endpoint..." -Level 'INFO'
        try {
            Invoke-WebRequest -Uri $Endpoint -UseBasicParsing -TimeoutSec 10 | Out-Null
            Write-Log -Message "Successfully connected to $Endpoint." -Level 'SUCCESS'
        }
        catch [System.Exception] {
            Write-Log -Message "Failed to connect to $Endpoint : $($_.Exception.Message)" -Level 'ERROR'
        }
    }
}

# ============================================================================
# POLICY AND NETWORK CHECKS
# Reads DO bandwidth policy state and general internet reachability.
# ============================================================================

# Dumps the Delivery Optimization bandwidth policy registry values.
function Get-DOBandwidthPolicies {
    Write-Log -Message "Checking Delivery Optimization Bandwidth Policies" -Level 'INFO'
    try {
        $DOGroupPolicy = Get-ItemProperty -Path $DORegistryPath -ErrorAction Stop
        Write-Log -Message "Bandwidth Policy Settings:" -Level 'SUCCESS'
        $DOGroupPolicy | Format-Table -AutoSize | Out-Host
    }
    catch [System.Management.Automation.ItemNotFoundException] {
        Write-Log -Message "No Delivery Optimization bandwidth policies found. Default settings may be in use." -Level 'WARNING'
    }
    catch {
        Write-Log -Message "Error reading Delivery Optimization bandwidth policies: $($_.Exception.Message)" -Level 'ERROR'
    }
}

# Pings an external target to confirm general internet connectivity.
function Test-NetworkConnectivity {
    Write-Log -Message "Checking General Network Connectivity" -Level 'INFO'
    try {
        $PingTest = Test-Connection -ComputerName $ConnectivityHost -Count 3 -Quiet
        if ($PingTest) {
            Write-Log -Message "General network connectivity is healthy." -Level 'SUCCESS'
        } else {
            Write-Log -Message "General network connectivity is unavailable. Check your internet connection." -Level 'ERROR'
        }
    }
    catch {
        Write-Log -Message "Error testing general network connectivity: $($_.Exception.Message)" -Level 'ERROR'
    }
}

# Lists firewall rules that reference Delivery Optimization by display name.
function Get-DOFirewallRules {
    Write-Log -Message "Checking Firewall Rules for Delivery Optimization" -Level 'INFO'
    try {
        $Rules = Get-NetFirewallRule | Where-Object { $_.DisplayName -like "*Delivery Optimization*" }
        if ($Rules) {
            Write-Log -Message "Delivery Optimization firewall rules found:" -Level 'SUCCESS'
            $Rules | Format-Table -AutoSize | Out-Host
        } else {
            Write-Log -Message "No firewall rules found for Delivery Optimization. Check your firewall configuration." -Level 'WARNING'
        }
    }
    catch {
        Write-Log -Message "Error retrieving firewall rules: $($_.Exception.Message)" -Level 'ERROR'
    }
}

# ============================================================================
# MAIN
# Flow: init -> banner -> run every check in legacy order -> exit 0/1.
# ============================================================================

try {
    $null = Initialize-Log -SolutionName $SolutionName -ScriptMode $ScriptMode -Type 'General'
    Write-Banner
    if ($script:LogReady) {
        Write-Log -Message "Log file ready: $($script:LogFile)" -Level 'DEBUG'
    }

    Write-Log -Message "Starting Comprehensive Delivery Optimization Troubleshooting" -Level 'INFO'

    Test-DOService
    Get-DOActiveJobs
    Test-DOPorts
    Repair-TeredoState
    Test-DOEndpoints
    Get-DOBandwidthPolicies
    Test-NetworkConnectivity
    Get-DOFirewallRules

    Finish-Script -ExitCode 0 -Message "Delivery Optimization Troubleshooting Completed" -Level 'SUCCESS'
}
catch {
    Finish-Script -ExitCode 1 -Message "Script error: $($_.Exception.Message)" -Level 'ERROR'
}
