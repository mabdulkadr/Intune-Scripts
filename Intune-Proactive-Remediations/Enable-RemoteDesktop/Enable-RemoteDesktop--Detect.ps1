<#
.SYNOPSIS
    Checks whether the Remote Desktop configuration is present.

.DESCRIPTION
    This detection script checks five conditions:

    1. `fDenyTSConnections` under the Terminal Server registry key
    2. `fClientDisableUDP` under the Terminal Services client policy key
    3. `UserAuthentication` for `RDP-Tcp`
    4. The inbound `RDP (TCP)` firewall rule exists and is enabled
    5. The inbound `RDP (UDP)` firewall rule exists and is enabled

    Exit codes:
    - Exit 0: The expected Remote Desktop configuration is present
    - Exit 1: One or more required settings are missing or incorrect

.RUN AS
    System or User (depending on Intune assignment and script requirements)

.EXAMPLE
    .\Enable-RemoteDesktop--Detect.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.4
#>

#region ---------- Configuration ----------

$ScriptName          = 'Enable-RemoteDesktop--Detect.ps1'
$SolutionName        = 'Enable-RemoteDesktop'
$ScriptMode          = 'Detection'
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

$SystemDrive = if ($env:SystemDrive) { $env:SystemDrive.TrimEnd('\') } else { [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\') }
$LogRoot     = Join-Path $SystemDrive "IntuneLogs\$SolutionName"
$LogFile     = Join-Path $LogRoot 'Enable-RemoteDesktop--Detect.txt'
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
        [string]$Level = 'INFO',

        [string]$ComplianceState
    )

    Write-Log -Message $Message -Level $Level

    if ($ComplianceState) {
        Write-Output $ComplianceState
    }

    exit $ExitCode
}

function Test-RegistryValue {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [int]$ExpectedValue
    )

    try {
        Write-Log -Message ("Reading registry value '{0}' from '{1}'" -f $Name, $Path)
        $currentValue = Get-ItemPropertyValue -Path $Path -Name $Name -ErrorAction Stop
        Write-Log -Message ("Current {0} value: {1}" -f $Name, $currentValue)

        return ($currentValue -eq $ExpectedValue)
    }
    catch {
        Write-Log -Message ("Required registry value '{0}' was not found in '{1}'." -f $Name, $Path) -Level 'WARNING'
        return $false
    }
}

function Test-FirewallRuleEnabled {
    param(
        [Parameter(Mandatory = $true)]
        [string]$DisplayName
    )

    Write-Log -Message ("Checking firewall rule '{0}'" -f $DisplayName)
    $rule = Get-NetFirewallRule -DisplayName $DisplayName -ErrorAction SilentlyContinue | Select-Object -First 1

    if ($null -eq $rule) {
        return $false
    }

    return ($rule.Enabled -eq 'True')
}

#endregion ---------- Functions ----------

#region ---------- Main ----------

$script:LogReady = Initialize-Log
Write-Banner

if ($script:LogReady) {
    Write-Log -Message ("Log file ready: {0}" -f $LogFile)
}

try {
    if (-not (Test-RegistryValue -Path $TerminalServerPath -Name $TerminalServerName -ExpectedValue $TerminalServerValue)) {
        Finish-Script -ExitCode 1 -Level 'WARNING' -ComplianceState 'Not Compliant' -Message 'Remote Desktop is disabled.'
    }

    if (-not (Test-RegistryValue -Path $ClientPolicyPath -Name $ClientUdpName -ExpectedValue $ClientUdpValue)) {
        Finish-Script -ExitCode 1 -Level 'WARNING' -ComplianceState 'Not Compliant' -Message 'RDP UDP support is not configured as expected.'
    }

    if (-not (Test-RegistryValue -Path $RdpTcpPath -Name $NlaRegistryName -ExpectedValue $NlaRegistryValue)) {
        Finish-Script -ExitCode 1 -Level 'WARNING' -ComplianceState 'Not Compliant' -Message 'Network Level Authentication is not configured as expected.'
    }

    if (-not (Test-FirewallRuleEnabled -DisplayName $TcpFirewallRuleName)) {
        Finish-Script -ExitCode 1 -Level 'WARNING' -ComplianceState 'Not Compliant' -Message 'The inbound RDP TCP firewall rule is missing or disabled.'
    }

    if (-not (Test-FirewallRuleEnabled -DisplayName $UdpFirewallRuleName)) {
        Finish-Script -ExitCode 1 -Level 'WARNING' -ComplianceState 'Not Compliant' -Message 'The inbound RDP UDP firewall rule is missing or disabled.'
    }

    Finish-Script -ExitCode 0 -Level 'SUCCESS' -ComplianceState 'Compliant' -Message 'Remote Desktop registry and firewall settings are configured as expected.'
}
catch {
    Finish-Script -ExitCode 1 -Level 'ERROR' -ComplianceState 'Not Compliant' -Message ("Failed to detect Remote Desktop state: {0}" -f $_.Exception.Message)
}

#endregion ---------- Main ----------
