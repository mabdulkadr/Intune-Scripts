<#
.SYNOPSIS
    Enables and validates the WinRM service on the local device.

.DESCRIPTION
    This remediation script ensures that the WinRM service exists, is configured
    with the correct startup type, is running, and that PowerShell Remoting is enabled.

    The script performs the following actions:
    - Validates that the WinRM service exists
    - Sets the WinRM startup type to Automatic
    - Starts the WinRM service if it is not running
    - Runs Enable-PSRemoting with SkipNetworkProfileCheck
    - Verifies local WSMan availability after remediation

    Exit codes:
    - Exit 0: Remediation completed successfully
    - Exit 1: Remediation failed

.RUN AS
    System

.EXAMPLE
    .\Enable-WinRMService--Remediate.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.1
#>

#region -- BOOTSTRAP -----------------------------------------------------------

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

#endregion -- BOOTSTRAP --------------------------------------------------------

#region -- CONFIGURATION -------------------------------------------------------

$ScriptName   = 'Enable-WinRMService--Remediate.ps1'
$SolutionName = 'Enable-WinRMService'
$ScriptMode   = 'Remediation'
$ServiceName  = 'WinRM'
$BannerLine   = '=' * 78

$SystemDrive = if ($env:SystemDrive) {
    $env:SystemDrive.TrimEnd('\')
}
elseif ($env:SystemRoot) {
    [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\')
}
else {
    'C:'
}

$LogRoot = Join-Path $SystemDrive "IntuneLogs\$SolutionName"
$LogFile = Join-Path $LogRoot 'Enable-WinRMService--Remediate.txt'

#endregion -- CONFIGURATION ----------------------------------------------------

#region -- FUNCTIONS -----------------------------------------------------------

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
        Write-Host ("Logging initialization failed: {0}" -f $_.Exception.Message) -ForegroundColor Red
        return $false
    }
}

function Write-Banner {
    $Title = '{0} | {1}' -f $SolutionName, $ScriptMode
    $Lines = @(
        ''
        $BannerLine
        $Title
        $BannerLine
    )

    foreach ($Line in $Lines) {
        if ($Line -eq $Title) {
            Write-Host $Line -ForegroundColor White
        }
        else {
            Write-Host $Line -ForegroundColor DarkGray
        }

        if ($script:LogReady) {
            try {
                Add-Content -Path $LogFile -Value $Line -Encoding UTF8
            }
            catch {}
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

    $Line = '{0} | {1,-7} | {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message

    switch ($Level) {
        'SUCCESS' { Write-Host $Line -ForegroundColor Green }
        'WARNING' { Write-Host $Line -ForegroundColor Yellow }
        'ERROR'   { Write-Host $Line -ForegroundColor Red }
        default   { Write-Host $Line -ForegroundColor Cyan }
    }

    if ($script:LogReady) {
        try {
            Add-Content -Path $LogFile -Value $Line -Encoding UTF8
        }
        catch {}
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

function Get-WinRMService {
    try {
        return Get-Service -Name $ServiceName -ErrorAction Stop
    }
    catch {
        throw "Service '$ServiceName' was not found. $($_.Exception.Message)"
    }
}

function Set-WinRMStartupType {
    try {
        $Service = Get-CimInstance -ClassName Win32_Service -Filter "Name='$ServiceName'" -ErrorAction Stop

        if ($Service.StartMode -ne 'Auto') {
            Write-Log -Message "WinRM startup type is '$($Service.StartMode)'. Changing it to Automatic."
            Set-Service -Name $ServiceName -StartupType Automatic -ErrorAction Stop
            Write-Log -Level 'SUCCESS' -Message 'WinRM startup type set to Automatic.'
        }
        else {
            Write-Log -Message 'WinRM startup type is already Automatic.'
        }
    }
    catch {
        throw "Failed to set WinRM startup type. $($_.Exception.Message)"
    }
}

function Start-WinRMService {
    try {
        $Service = Get-WinRMService

        if ($Service.Status -ne 'Running') {
            Write-Log -Message 'WinRM service is not running. Starting the service.'
            Start-Service -Name $ServiceName -ErrorAction Stop

            $Service.WaitForStatus('Running', (New-TimeSpan -Seconds 15))
            Write-Log -Level 'SUCCESS' -Message 'WinRM service started successfully.'
        }
        else {
            Write-Log -Message 'WinRM service is already running.'
        }
    }
    catch {
        throw "Failed to start WinRM service. $($_.Exception.Message)"
    }
}

function Enable-WinRMRemoting {
    try {
        Write-Log -Message 'Enabling PowerShell Remoting with SkipNetworkProfileCheck.'
        Enable-PSRemoting -Force -SkipNetworkProfileCheck -ErrorAction Stop
        Write-Log -Level 'SUCCESS' -Message 'PowerShell Remoting enabled successfully.'
    }
    catch {
        throw "Enable-PSRemoting failed. $($_.Exception.Message)"
    }
}

function Test-LocalWSMan {
    try {
        Write-Log -Message 'Validating local WSMan connectivity.'
        Test-WSMan -ComputerName localhost -ErrorAction Stop | Out-Null
        Write-Log -Level 'SUCCESS' -Message 'Local WSMan test succeeded.'
    }
    catch {
        throw "Local WSMan validation failed. $($_.Exception.Message)"
    }
}

#endregion -- FUNCTIONS --------------------------------------------------------

#region -- MAIN ----------------------------------------------------------------

$script:LogReady = Initialize-Log
Write-Banner

if ($script:LogReady) {
    Write-Log -Message ("Log file ready: {0}" -f $LogFile)
}

try {
    Write-Log -Message ("Checking service: {0}" -f $ServiceName)

    $Service = Get-WinRMService
    Write-Log -Message ("Current WinRM state | Status: {0}" -f $Service.Status)

    Set-WinRMStartupType
    Start-WinRMService
    Enable-WinRMRemoting
    Test-LocalWSMan

    Finish-Script -ExitCode 0 -Level 'SUCCESS' -Message 'WinRM remediation completed successfully.'
}
catch {
    Finish-Script -ExitCode 1 -Level 'ERROR' -Message ("WinRM remediation failed: {0}" -f $_.Exception.Message)
}

#endregion -- MAIN -------------------------------------------------------------