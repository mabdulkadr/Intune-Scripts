<#
.SYNOPSIS
    Enables Remote Desktop and creates the expected firewall rules.

.DESCRIPTION
    This remediation script enables Remote Desktop, enables Network Level
    Authentication, enables RDP UDP support, and ensures inbound TCP/UDP 3389
    firewall rules exist for the configured remote address scope.

    Exit codes:
    - Exit 0: Completed successfully
    - Exit 1: Failed or requires further action

.RUN AS
    System or User (depending on Intune assignment and script requirements)

.EXAMPLE
    .\Enable-RemoteDesktop--Remediate.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.5
#>

#region ---------- Configuration ----------

$ScriptName            = 'Enable-RemoteDesktop--Remediate.ps1'
$SolutionName          = 'Enable-RemoteDesktop'
$ScriptMode            = 'Remediation'
$TerminalServerPath    = 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server'
$TerminalServerName    = 'fDenyTSConnections'
$TerminalServerValue   = 0
$ClientPolicyPath      = 'HKLM:\Software\Policies\Microsoft\Windows NT\Terminal Services\Client'
$ClientUdpName         = 'fClientDisableUDP'
$ClientUdpValue        = 0
$RdpTcpPath            = 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp'
$NlaRegistryName       = 'UserAuthentication'
$NlaRegistryValue      = 1
$TcpFirewallRuleName   = 'RDP (TCP)'
$UdpFirewallRuleName   = 'RDP (UDP)'
$RemoteAddress         = 'Any'

$SystemDrive = if ($env:SystemDrive) { $env:SystemDrive.TrimEnd('\') } else { [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\') }
$LogRoot     = Join-Path $SystemDrive "IntuneLogs\$SolutionName"
$LogFile     = Join-Path $LogRoot 'Enable-RemoteDesktop--Remediate.txt'
$BannerLine  = '=' * 78

#endregion ---------- Configuration ----------

#region ---------- Functions ----------

function Initialize-Log {
    try {
        if (-not (Test-Path -Path $LogRoot)) {
            New-Item -Path $LogRoot -ItemType Directory -Force -ErrorAction Stop | Out-Null
        }

        if (-not (Test-Path -Path $LogFile)) {
            New-Item -Path $LogFile -ItemType File -Force -ErrorAction Stop | Out-Null
        }

        return $true
    }
    catch {
        Write-Host "Logging initialization failed: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Write-Banner {
    $title = "{0} | {1}" -f $SolutionName, $ScriptMode
    $lines = @('', $BannerLine, $title, $BannerLine)

    foreach ($line in $lines) {
        if ($line -eq $title) {
            Write-Host $line -ForegroundColor White
        }
        else {
            Write-Host $line -ForegroundColor DarkGray
        }

        if ($script:LogReady) {
            try {
                Add-Content -Path $LogFile -Value $line -Encoding UTF8 -ErrorAction Stop
            }
            catch {
                $script:LogReady = $false
                Write-Host ("Log writing disabled: {0}" -f $_.Exception.Message) -ForegroundColor Yellow
            }
        }
    }
}

function Write-Log {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [ValidateSet('INFO', 'SUCCESS', 'WARNING', 'ERROR')]
        [string]$Level = 'INFO'
    )

    $line = '{0} | {1,-7} | {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message

    switch ($Level) {
        'SUCCESS' { Write-Host $line -ForegroundColor Green }
        'WARNING' { Write-Host $line -ForegroundColor Yellow }
        'ERROR'   { Write-Host $line -ForegroundColor Red }
        default   { Write-Host $line -ForegroundColor Cyan }
    }

    if ($script:LogReady) {
        try {
            Add-Content -Path $LogFile -Value $line -Encoding UTF8 -ErrorAction Stop
        }
        catch {
            $script:LogReady = $false
            Write-Host ("Log writing disabled: {0}" -f $_.Exception.Message) -ForegroundColor Yellow
        }
    }
}

function Finish-Script {
    param(
        [Parameter(Mandatory = $true)]
        [int]$ExitCode,

        [Parameter(Mandatory = $true)]
        [string]$Message,

        [ValidateSet('INFO', 'SUCCESS', 'WARNING', 'ERROR')]
        [string]$Level = 'INFO'
    )

    Write-Log -Message $Message -Level $Level
    exit $ExitCode
}

function Get-EffectiveRemoteAddress {
    if ([string]::IsNullOrWhiteSpace($RemoteAddress) -or $RemoteAddress -eq '*') {
        return 'Any'
    }

    return $RemoteAddress.Trim()
}

function Ensure-RegistryValue {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [int]$Value
    )

    if (-not (Test-Path -Path $Path)) {
        New-Item -Path $Path -Force -ErrorAction Stop | Out-Null
    }

    Write-Log -Message ("Setting '{0}' in '{1}' to '{2}'" -f $Name, $Path, $Value)
    Set-ItemProperty -Path $Path -Name $Name -Value $Value -Force -ErrorAction Stop

    $currentValue = Get-ItemPropertyValue -Path $Path -Name $Name -ErrorAction Stop
    if ($currentValue -ne $Value) {
        throw ("Registry update ran, but {0} is still {1}." -f $Name, $currentValue)
    }
}

function Ensure-FirewallRule {
    param(
        [Parameter(Mandatory = $true)]
        [string]$DisplayName,

        [Parameter(Mandatory = $true)]
        [ValidateSet('TCP', 'UDP')]
        [string]$Protocol
    )

    $effectiveRemoteAddress = Get-EffectiveRemoteAddress
    $existingRule = Get-NetFirewallRule -DisplayName $DisplayName -ErrorAction SilentlyContinue

    if ($existingRule) {
        Write-Log -Message ("Updating firewall rule '{0}' for protocol {1} with remote address '{2}'." -f $DisplayName, $Protocol, $effectiveRemoteAddress)
        Set-NetFirewallRule -DisplayName $DisplayName -Direction Inbound -Action Allow -Protocol $Protocol -LocalPort '3389' -RemoteAddress $effectiveRemoteAddress -Profile Any -Enabled True -ErrorAction Stop | Out-Null
        return
    }

    Write-Log -Message ("Creating firewall rule '{0}' for protocol {1} with remote address '{2}'." -f $DisplayName, $Protocol, $effectiveRemoteAddress)
    New-NetFirewallRule -DisplayName $DisplayName -Direction Inbound -Action Allow -Protocol $Protocol -LocalPort 3389 -RemoteAddress $effectiveRemoteAddress -Profile Any -Enabled True -ErrorAction Stop | Out-Null
}

#endregion ---------- Functions ----------

#region ---------- Main ----------

$script:LogReady = Initialize-Log
Write-Banner

if ($script:LogReady) {
    Write-Log -Message ("Log file ready: {0}" -f $LogFile)
}

try {
    Ensure-RegistryValue -Path $TerminalServerPath -Name $TerminalServerName -Value $TerminalServerValue
    Ensure-RegistryValue -Path $ClientPolicyPath -Name $ClientUdpName -Value $ClientUdpValue
    Ensure-RegistryValue -Path $RdpTcpPath -Name $NlaRegistryName -Value $NlaRegistryValue

    Ensure-FirewallRule -DisplayName $TcpFirewallRuleName -Protocol 'TCP'
    Ensure-FirewallRule -DisplayName $UdpFirewallRuleName -Protocol 'UDP'

    Finish-Script -ExitCode 0 -Level 'SUCCESS' -Message ("Remote Desktop was enabled successfully and firewall access was configured for remote address '{0}'." -f (Get-EffectiveRemoteAddress))
}
catch {
    Finish-Script -ExitCode 1 -Level 'ERROR' -Message ("Failed to enable Remote Desktop: {0}" -f $_.Exception.Message)
}

#endregion ---------- Main ----------
