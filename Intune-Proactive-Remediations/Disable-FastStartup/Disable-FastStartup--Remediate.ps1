<#
.SYNOPSIS
    Disables Fast Startup.

.DESCRIPTION
    The script sets `HiberbootEnabled` to `0`.

.RUN AS
    System or User

.EXAMPLE
    .\Disable-FastStartup--Remediate.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.2
#>

#region ---------- Configuration ----------

$ScriptName   = 'Disable-FastStartup--Remediate.ps1'
$SolutionName = 'Disable-FastStartup'
$ScriptMode   = 'Remediation'

$RegistryPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power'
$RegistryName = 'HiberbootEnabled'
$DesiredValue = 0

$SystemDrive = if ($env:SystemDrive) { $env:SystemDrive.TrimEnd('\') } else { [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\') }
$LogRoot     = Join-Path $SystemDrive "IntuneLogs\$SolutionName"
$LogFile     = Join-Path $LogRoot 'Disable-FastStartup--Remediate.txt'
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

Write-Log -Message ("Setting '{0}' in '{1}' to '{2}'" -f $RegistryName, $RegistryPath, $DesiredValue)

try {
    $beforeValue = Get-ItemPropertyValue -Path $RegistryPath -Name $RegistryName -ErrorAction SilentlyContinue
    if ($null -ne $beforeValue) {
        Write-Log -Message ("Current {0} value: {1}" -f $RegistryName, $beforeValue)
    }

    Set-ItemProperty -Path $RegistryPath -Name $RegistryName -Value $DesiredValue -Type DWord -Force -ErrorAction Stop
    $afterValue = Get-ItemPropertyValue -Path $RegistryPath -Name $RegistryName -ErrorAction Stop

    if ($afterValue -eq $DesiredValue) {
        Finish-Script -ExitCode 0 -Level 'SUCCESS' -Message 'Fast Startup was disabled successfully.'
    }

    Finish-Script -ExitCode 1 -Level 'WARNING' -Message ("Registry update ran, but {0} is still {1}." -f $RegistryName, $afterValue)
}
catch {
    Finish-Script -ExitCode 1 -Level 'ERROR' -Message ("Failed to disable Fast Startup: {0}" -f $_.Exception.Message)
}

#endregion ---------- Main ----------
