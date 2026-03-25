<#
.SYNOPSIS
    Restarts the configured Windows service.

.DESCRIPTION
    This remediation script is a template that forcibly restarts the service
    defined in `$servicename`.

.RUN AS
    System or User (depending on Intune assignment and script requirements)

.EXAMPLE
    .\Restart-SystemService--Remediate.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.2
#>

#region ---------- Configuration ----------

$ScriptName   = 'Restart-SystemService--Remediate.ps1'
$SolutionName = 'Restart-SystemService'
$ScriptMode   = 'Remediation'

$servicename  = 'ServiceName' # Replace with the actual service name to restart (not display name)

$SystemDrive = if ($env:SystemDrive) { $env:SystemDrive.TrimEnd('\') } else { [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\') }
$LogRoot     = Join-Path $SystemDrive "IntuneLogs\$SolutionName"
$LogFile     = Join-Path $LogRoot 'Restart-SystemService--Remediate.txt'
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
        [string]$Level = 'INFO'
    )

    Write-Log -Message $Message -Level $Level
    exit $ExitCode
}

#endregion ---------- Functions ----------

#region ---------- Main ----------

$script:LogReady = Initialize-Log
Write-Banner

if ($script:LogReady) {
    Write-Log -Message ("Log file ready: {0}" -f $LogFile)
}

if ([string]::IsNullOrWhiteSpace($servicename) -or $servicename -eq 'ServiceName') {
    Finish-Script -ExitCode 1 -Level 'ERROR' -Message 'Template placeholder is still in use. Replace ServiceName before production use.'
}

try {
    Write-Log -Message ("Restarting configured service: {0}" -f $servicename)
    Restart-Service -Name $servicename -Force -ErrorAction Stop
    Write-Log -Message ("Restart-Service completed for: {0}" -f $servicename) -Level 'SUCCESS'

    $service = Get-Service -Name $servicename -ErrorAction Stop
    if ($service.Status -eq 'Running') {
        Finish-Script -ExitCode 0 -Level 'SUCCESS' -Message ("Service restart completed successfully. Current state: {0}" -f $service.Status)
    }

    Finish-Script -ExitCode 1 -Level 'WARNING' -Message ("Service restart completed, but the service is not running. Current state: {0}" -f $service.Status)
}
catch {
    Finish-Script -ExitCode 1 -Level 'ERROR' -Message ("Failed to restart the configured service: {0}" -f $_.Exception.Message)
}

#endregion ---------- Main ----------
