<#
.SYNOPSIS
    Detect whether the required local network access flag is configured for Chrome and Edge.

.DESCRIPTION
    This detection script checks the `Local State` files for Google Chrome and
    Microsoft Edge, then verifies whether the required experiment flag is
    present in `browser.enabled_labs_experiments`.

    Exit codes:
    - Exit 0: Compliant
    - Exit 1: Not Compliant (remediation should run)

.RUN AS
    System or User, based on the Intune assignment configuration.

.EXAMPLE
    .\Disable-LocalNetworkAccessRestrictions--Detect.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.2
#>

#region ---------- Configuration ----------

$ScriptName       = 'Disable-LocalNetworkAccessRestrictions--Detect.ps1'
$SolutionName     = 'Disable-LocalNetworkAccessRestrictions'
$ScriptMode       = 'Detection'
$RequiredFlag     = 'local-network-access-check@3'
$ChromeLocalState = Join-Path $env:LOCALAPPDATA 'Google\Chrome\User Data\Local State'
$EdgeLocalState   = Join-Path $env:LOCALAPPDATA 'Microsoft\Edge\User Data\Local State'

$SystemDrive = if ($env:SystemDrive) { $env:SystemDrive.TrimEnd('\') } else { [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\') }
$LogRoot     = Join-Path $SystemDrive "IntuneLogs\$SolutionName"
$LogFile     = Join-Path $LogRoot 'Disable-LocalNetworkAccessRestrictions--Detect.txt'
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

# Test whether the required labs flag exists in the browser Local State file.
function Test-BrowserFlag {
    param(
        [Parameter(Mandatory = $true)]
        [string]$LocalStatePath,

        [Parameter(Mandatory = $true)]
        [string]$BrowserName
    )

    if (-not (Test-Path -Path $LocalStatePath)) {
        Write-Log -Message ("{0}: Local State was not found: {1}" -f $BrowserName, $LocalStatePath) -Level 'WARNING'
        return $false
    }

    try {
        $jsonData = Get-Content -Path $LocalStatePath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        Write-Log -Message ("{0}: Failed to read or parse Local State JSON." -f $BrowserName) -Level 'ERROR'
        return $false
    }

    if ($null -eq $jsonData.browser -or $null -eq $jsonData.browser.enabled_labs_experiments) {
        Write-Log -Message ("{0}: browser.enabled_labs_experiments is missing." -f $BrowserName) -Level 'WARNING'
        return $false
    }

    $experiments = @($jsonData.browser.enabled_labs_experiments)
    if ($experiments -contains $RequiredFlag) {
        Write-Log -Message ("{0}: Required flag is present: {1}" -f $BrowserName, $RequiredFlag) -Level 'SUCCESS'
        return $true
    }

    Write-Log -Message ("{0}: Required flag is missing: {1}" -f $BrowserName, $RequiredFlag) -Level 'WARNING'
    return $false
}

# Write the final result, emit the Intune compliance state, and exit.
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

Write-Log -Message ("Checking browser flag: {0}" -f $RequiredFlag)

$chromeOk = Test-BrowserFlag -LocalStatePath $ChromeLocalState -BrowserName 'Chrome'
$edgeOk   = Test-BrowserFlag -LocalStatePath $EdgeLocalState -BrowserName 'Edge'

if ($chromeOk -and $edgeOk) {
    Finish-Script -ExitCode 0 -Level 'SUCCESS' -ComplianceState 'Compliant' -Message 'Chrome and Edge both contain the required local network access flag.'
}

Finish-Script -ExitCode 1 -Level 'WARNING' -ComplianceState 'Not Compliant' -Message ("One or more browsers are missing the required flag. Chrome={0}; Edge={1}." -f $chromeOk, $edgeOk)

#endregion ---------- Main ----------
