<#
.SYNOPSIS
    Checks whether Fast Startup is disabled.

.DESCRIPTION
    The script reads `HiberbootEnabled` from the Power registry key.

    Exit codes:
    - Exit 0: Fast Startup is already disabled
    - Exit 1: Fast Startup is enabled or could not be verified

.RUN AS
    System or User

.EXAMPLE
    .\Disable-FastStartup--Detect.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.2
#>

#region ---------- Configuration ----------

$ScriptName   = 'Disable-FastStartup--Detect.ps1'
$SolutionName = 'Disable-FastStartup'
$ScriptMode   = 'Detection'

$RegistryPath  = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power'
$RegistryName  = 'HiberbootEnabled'
$ExpectedValue = 0

$SystemDrive = if ($env:SystemDrive) { $env:SystemDrive.TrimEnd('\') } else { [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\') }
$LogRoot     = Join-Path $SystemDrive "IntuneLogs\$SolutionName"
$LogFile     = Join-Path $LogRoot 'Disable-FastStartup--Detect.txt'
$BannerLine  = '=' * 78

#endregion ---------- Configuration ----------

#region ---------- Functions ----------

# Create the log folder and file when needed.
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

# Write the same banner to the console and the log file.
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

# Write one formatted log line.
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

# Write the final message and exit with the right code.
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

#endregion ---------- Functions ----------

#region ---------- Main ----------

$script:LogReady = Initialize-Log
Write-Banner

if ($script:LogReady) {
    Write-Log -Message ("Log file ready: {0}" -f $LogFile)
}

Write-Log -Message ("Reading registry value '{0}' from '{1}'" -f $RegistryName, $RegistryPath)

try {
    $currentValue = Get-ItemPropertyValue -Path $RegistryPath -Name $RegistryName -ErrorAction Stop
    Write-Log -Message ("Current {0} value: {1}" -f $RegistryName, $currentValue)

    if ($currentValue -eq $ExpectedValue) {
        Finish-Script -ExitCode 0 -Level 'SUCCESS' -ComplianceState 'Compliant' -Message 'Fast Startup is already disabled.'
    }

    Finish-Script -ExitCode 1 -Level 'WARNING' -ComplianceState 'Not Compliant' -Message ("Fast Startup is enabled. Expected {0}, found {1}." -f $ExpectedValue, $currentValue)
}
catch {
    Finish-Script -ExitCode 1 -Level 'ERROR' -ComplianceState 'Not Compliant' -Message ("Failed to read {0}: {1}" -f $RegistryName, $_.Exception.Message)
}

#endregion ---------- Main ----------
