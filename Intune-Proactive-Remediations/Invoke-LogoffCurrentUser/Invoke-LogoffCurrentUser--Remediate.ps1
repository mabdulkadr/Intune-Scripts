<#
.SYNOPSIS
    Shows a warning, waits for the configured timeout, and then logs off the current user.

.DESCRIPTION
    This remediation script displays a warning to the interactive user, waits for the
    configured countdown period, and then signs out the current user by using shutdown.exe /l.

    Notes:
    - shutdown.exe /l does not support /t or /f.
    - The delay is handled inside PowerShell by Start-Sleep.
    - This script is intended for an interactive user session.

.RUN AS
    User or interactive context

.EXAMPLE
    .\Invoke-LogoffCurrentUser--Remediate.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.3
#>

#region -- BOOTSTRAP -----------------------------------------------------------

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

#endregion -- BOOTSTRAP --------------------------------------------------------

#region -- CONFIGURATION -------------------------------------------------------

$ScriptName     = 'Invoke-LogoffCurrentUser--Remediate.ps1'
$SolutionName   = 'Invoke-LogoffCurrentUser'
$ScriptMode     = 'Remediation'
$TimeoutSeconds = 60

$SystemDrive = if ($env:SystemDrive) {
    $env:SystemDrive.TrimEnd('\')
}
elseif ($env:SystemRoot) {
    [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\')
}
else {
    'C:'
}

$LogRoot    = Join-Path $SystemDrive "IntuneLogs\$SolutionName"
$LogFile    = Join-Path $LogRoot 'Invoke-LogoffCurrentUser--Remediate.txt'
$BannerLine = '=' * 78

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
        [string]$Level = 'INFO',

        [string]$OutputMessage
    )

    Write-Log -Message $Message -Level $Level

    if (-not [string]::IsNullOrWhiteSpace($OutputMessage)) {
        Write-Output $OutputMessage
    }

    exit $ExitCode
}

function Get-ExecutionIdentity {
    try {
        $CurrentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()

        if ($CurrentIdentity.IsSystem) {
            return 'NT AUTHORITY\SYSTEM'
        }

        return $CurrentIdentity.Name
    }
    catch {
        return $env:USERNAME
    }
}

function Show-LogoffWarning {
    try {
        Add-Type -AssemblyName PresentationFramework -ErrorAction Stop

        $Message = "You will be signed out in $TimeoutSeconds seconds. Please save your work now."
        $Caption = 'Logoff Warning'

        [System.Windows.MessageBox]::Show($Message, $Caption, 'OK', 'Warning') | Out-Null
        Write-Log -Message 'Displayed logoff warning dialog.'
    }
    catch {
        throw "Failed to display warning dialog. $($_.Exception.Message)"
    }
}

function Start-LogoffCountdown {
    param(
        [Parameter(Mandatory = $true)]
        [int]$Seconds
    )

    Write-Log -Level 'WARNING' -Message ("Waiting {0} second(s) before sign-out." -f $Seconds)
    Start-Sleep -Seconds $Seconds
}

function Start-UserLogoff {
    $ShutdownPath = Join-Path $env:SystemRoot 'System32\shutdown.exe'

    if (-not (Test-Path -Path $ShutdownPath)) {
        throw 'shutdown.exe was not found.'
    }

    Write-Log -Level 'WARNING' -Message 'Issuing sign-out command using shutdown.exe /l.'

    $Process = Start-Process -FilePath $ShutdownPath -ArgumentList '/l' -WindowStyle Hidden -PassThru -Wait -ErrorAction Stop

    if ($null -ne $Process.ExitCode -and $Process.ExitCode -ne 0) {
        throw ("shutdown.exe returned exit code {0}." -f $Process.ExitCode)
    }
}

#endregion -- FUNCTIONS --------------------------------------------------------

#region -- MAIN ----------------------------------------------------------------

$script:LogReady = Initialize-Log
Write-Banner

if ($script:LogReady) {
    Write-Log -Message ("Log file ready: {0}" -f $LogFile)
}

Write-Log -Level 'WARNING' -Message ("Starting logoff workflow with a {0}-second timeout." -f $TimeoutSeconds)

try {
    Write-Log -Message ("Running as: {0}" -f (Get-ExecutionIdentity))

    Show-LogoffWarning
    Start-LogoffCountdown -Seconds $TimeoutSeconds
    Start-UserLogoff

    Finish-Script -ExitCode 0 -Level 'SUCCESS' -Message 'Current-user sign-out was initiated successfully.' -OutputMessage 'Logoff started'
}
catch {
    Finish-Script -ExitCode 1 -Level 'ERROR' -Message ("Failed to initiate current-user logoff: {0}" -f $_.Exception.Message) -OutputMessage 'Logoff failed'
}

#endregion -- MAIN -------------------------------------------------------------