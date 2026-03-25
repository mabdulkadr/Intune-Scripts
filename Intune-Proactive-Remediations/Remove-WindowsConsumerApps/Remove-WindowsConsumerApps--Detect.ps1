<#
.SYNOPSIS
    Detects whether the targeted AppX packages are still installed.

.DESCRIPTION
    This detection script queries installed AppX packages by using
    `Get-AppxPackage`, then filters the results against the package names
    configured in the script.

    It returns a non-zero result when one or more targeted packages are still
    present so remediation can remove them.

    Exit codes:
    - Exit 0: None of the targeted AppX packages are installed
    - Exit 1: One or more targeted AppX packages are still installed

.RUN AS
    System or User (depending on Intune assignment and script requirements)

.EXAMPLE
    .\Remove-WindowsConsumerApps--Detect.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.2
#>

#region ---------- Configuration ----------

$ScriptName   = 'Remove-WindowsConsumerApps--Detect.ps1'
$SolutionName = 'Remove-WindowsConsumerApps'
$ScriptMode   = 'Detection'

$ConsumerApps = @{
    'Microsoft.XboxApp'                      = 'Xbox App'
    'Microsoft.XboxGameOverlay'              = 'Xbox Game Overlay'
    'Microsoft.Xbox.TCUI'                    = 'Xbox TCUI'
    'Microsoft.MicrosoftSolitaireCollection' = 'Solitaire Collection'
    'Microsoft.549981C3F5F10'                = 'Cortana'
}

$SystemDrive = if ($env:SystemDrive) { $env:SystemDrive.TrimEnd('\') } else { [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\') }
$LogRoot     = Join-Path $SystemDrive "IntuneLogs\$SolutionName"
$LogFile     = Join-Path $LogRoot 'Remove-WindowsConsumerApps--Detect.txt'
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
        try { Add-Content -Path $LogFile -Value $line -Encoding UTF8 } catch {}
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

Write-Log -Message ("Targeted consumer apps: {0}" -f (($ConsumerApps.GetEnumerator() | ForEach-Object { $_.Key }) -join ', '))

try {
    $installedPackages = @(Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $ConsumerApps.ContainsKey($_.Name) })

    foreach ($package in $installedPackages) {
        Write-Log -Message ("Detected installed package: {0} ({1})" -f $package.Name, $ConsumerApps[$package.Name])
    }

    if ($installedPackages.Count -gt 0) {
        Finish-Script -ExitCode 1 -Level 'WARNING' -Message ("One or more targeted consumer apps are still installed: {0}" -f $installedPackages.Count)
    }

    Finish-Script -ExitCode 0 -Level 'SUCCESS' -Message 'None of the targeted consumer apps are installed.'
}
catch {
    Finish-Script -ExitCode 1 -Level 'ERROR' -Message ("Failed to detect targeted consumer apps: {0}" -f $_.Exception.Message)
}

#endregion ---------- Main ----------
