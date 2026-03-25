<#
.SYNOPSIS
    Checks whether .NET Framework 3.5 is enabled.

.DESCRIPTION
    This detection script uses `Get-WindowsOptionalFeature` to check the local
    state of the `NetFx3` feature.

    Exit codes:
    - Exit 0: NetFx3 is enabled
    - Exit 1: NetFx3 is disabled or could not be verified

.RUN AS
    System or User (depending on Intune assignment and script requirements)

.EXAMPLE
    .\Install-DotNetFramework35--Detect.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.2
#>

#region ---------- Configuration ----------

$ScriptName      = 'Install-DotNetFramework35--Detect.ps1'
$SolutionName    = 'Install-DotNetFramework35'
$ScriptMode      = 'Detection'
$FeatureName     = 'NetFx3'
$ExpectedState   = 'Enabled'
$TranscriptFile  = Join-Path $env:TEMP 'NetFx3.log'

$SystemDrive = if ($env:SystemDrive) { $env:SystemDrive.TrimEnd('\') } else { [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\') }
$LogRoot     = Join-Path $SystemDrive "IntuneLogs\$SolutionName"
$LogFile     = Join-Path $LogRoot 'Install-DotNetFramework35--Detect.txt'
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
            Add-Content -Path $LogFile -Value $line -Encoding UTF8
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
            Add-Content -Path $LogFile -Value $line -Encoding UTF8
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

    if ($OutputMessage) {
        Write-Output $OutputMessage
    }

    exit $ExitCode
}

#endregion ---------- Functions ----------

#region ---------- Main ----------

$script:LogReady = Initialize-Log
Write-Banner

if ($script:LogReady) {
    Write-Log -Message ("Log file ready: {0}" -f $LogFile)
}

Start-Transcript -Path $TranscriptFile -Append | Out-Null

try {
    Write-Log -Message ("Transcript file ready: {0}" -f $TranscriptFile)
    Write-Log -Message ("Checking optional feature state: {0}" -f $FeatureName)

    $feature = Get-WindowsOptionalFeature -Online -FeatureName $FeatureName -ErrorAction Stop
    Write-Log -Message ("Current feature state: {0}" -f $feature.State)

    if ($feature.State -eq $ExpectedState) {
        Finish-Script -ExitCode 0 -Level 'SUCCESS' -Message '.NET Framework 3.5 is enabled.'
    }

    Finish-Script -ExitCode 1 -Level 'WARNING' -Message (".NET Framework 3.5 is not enabled. Current state: {0}" -f $feature.State)
}
catch {
    Finish-Script -ExitCode 1 -Level 'ERROR' -Message ("Failed to read NetFx3 feature state: {0}" -f $_.Exception.Message)
}
finally {
    try {
        Stop-Transcript | Out-Null
    }
    catch {}
}

#endregion ---------- Main ----------
