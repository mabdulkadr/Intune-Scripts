<#
.SYNOPSIS
    Remediate local network access checks for Chrome and Edge.

.DESCRIPTION
    This remediation script updates the `Local State` files for Google Chrome
    and Microsoft Edge so the required local network access experiment flag is
    present.

    The script stops both browsers, updates the flag with fallback support,
    then relaunches each browser with the required runtime switch.

    Exit codes:
    - Exit 0: Completed successfully
    - Exit 1: Failed or requires further action

.RUN AS
    System or User, based on the Intune assignment configuration.

.EXAMPLE
    .\Disable-LocalNetworkAccessRestrictions--Remediate.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.2
#>

#region ---------- Configuration ----------

[CmdletBinding()]
param(
    [switch]$ForceVariant2
)

$ScriptName       = 'Disable-LocalNetworkAccessRestrictions--Remediate.ps1'
$SolutionName     = 'Disable-LocalNetworkAccessRestrictions'
$ScriptMode       = 'Remediation'
$PrimaryFlag      = if ($ForceVariant2) { 'local-network-access-check@2' } else { 'local-network-access-check@3' }
$FallbackFlag     = if ($ForceVariant2) { 'local-network-access-check@3' } else { 'local-network-access-check@2' }
$LaunchArgument   = '--disable-features=LocalNetworkAccessChecks,LocalNetworkAccessCheck'
$ChromeLocalState = Join-Path $env:LOCALAPPDATA 'Google\Chrome\User Data\Local State'
$EdgeLocalState   = Join-Path $env:LOCALAPPDATA 'Microsoft\Edge\User Data\Local State'

$SystemDrive = if ($env:SystemDrive) { $env:SystemDrive.TrimEnd('\') } else { [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\') }
$LogRoot     = Join-Path $SystemDrive "IntuneLogs\$SolutionName"
$LogFile     = Join-Path $LogRoot 'Disable-LocalNetworkAccessRestrictions--Remediate.txt'
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

# Stop running processes by name.
function Stop-Processes {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Names
    )

    foreach ($name in $Names) {
        Get-Process -Name $name -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    }
}

# Wait until a file can be opened for write access.
function Wait-FileUnlocked {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [int]$MaxWaitSeconds = 15
    )

    for ($i = 0; $i -lt $MaxWaitSeconds; $i++) {
        try {
            $stream = [System.IO.File]::Open($Path, 'Open', 'Write', 'None')
            $stream.Close()
            return $true
        }
        catch {
            Start-Sleep -Seconds 1
        }
    }

    return $false
}

# Update the target Local State file and verify that one of the flag variants is present.
function Set-BrowserFlag {
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

    if (-not (Wait-FileUnlocked -Path $LocalStatePath)) {
        Write-Log -Message ("{0}: Local State is still locked: {1}" -f $BrowserName, $LocalStatePath) -Level 'ERROR'
        return $false
    }

    $backupPath = '{0}.bak_{1}' -f $LocalStatePath, (Get-Date -Format 'yyyyMMddHHmmss')
    Copy-Item -Path $LocalStatePath -Destination $backupPath -Force -ErrorAction Stop
    Write-Log -Message ("{0}: Backup created: {1}" -f $BrowserName, $backupPath)

    try {
        $jsonData = Get-Content -Path $LocalStatePath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop

        if (-not $jsonData.PSObject.Properties['browser']) {
            $jsonData | Add-Member -NotePropertyName browser -NotePropertyValue ([pscustomobject]@{})
        }

        if (-not $jsonData.browser.PSObject.Properties['enabled_labs_experiments']) {
            $jsonData.browser | Add-Member -NotePropertyName enabled_labs_experiments -NotePropertyValue @()
        }

        if ($null -eq $jsonData.browser.enabled_labs_experiments) {
            $jsonData.browser.enabled_labs_experiments = @()
        }

        foreach ($flag in @($PrimaryFlag, $FallbackFlag)) {
            $jsonData.browser.enabled_labs_experiments = @(
                $jsonData.browser.enabled_labs_experiments |
                Where-Object { $_ -notmatch '^local-network-access-check@' }
            )
            $jsonData.browser.enabled_labs_experiments += $flag

            $jsonData | ConvertTo-Json -Depth 12 | Set-Content -Path $LocalStatePath -Encoding UTF8
            $verifyData = Get-Content -Path $LocalStatePath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop

            if (@($verifyData.browser.enabled_labs_experiments) -contains $flag) {
                Write-Log -Message ("{0}: Required flag applied successfully: {1}" -f $BrowserName, $flag) -Level 'SUCCESS'
                return $true
            }

            Write-Log -Message ("{0}: Flag variant was not accepted, trying next option." -f $BrowserName) -Level 'WARNING'
        }
    }
    catch {
        Write-Log -Message ("{0}: Failed to update Local State: {1}" -f $BrowserName, $_.Exception.Message) -Level 'ERROR'
    }

    try {
        Copy-Item -Path $backupPath -Destination $LocalStatePath -Force -ErrorAction Stop
        Write-Log -Message ("{0}: Original Local State was restored from backup." -f $BrowserName) -Level 'WARNING'
    }
    catch {
        Write-Log -Message ("{0}: Failed to restore Local State from backup: {1}" -f $BrowserName, $_.Exception.Message) -Level 'ERROR'
    }

    return $false
}

# Return the first browser executable found in common install locations.
function Get-BrowserExecutable {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$CandidatePaths
    )

    return $CandidatePaths | Where-Object { Test-Path -Path $_ } | Select-Object -First 1
}

# Launch the browser with the required runtime switch when possible.
function Start-Browser {
    param(
        [Parameter(Mandatory = $true)]
        [string]$BrowserName,

        [Parameter(Mandatory = $true)]
        [string]$ExecutablePath
    )

    try {
        Start-Process -FilePath $ExecutablePath -ArgumentList $LaunchArgument -ErrorAction Stop | Out-Null
        Write-Log -Message ("{0}: Browser was relaunched successfully." -f $BrowserName) -Level 'SUCCESS'
    }
    catch {
        Write-Log -Message ("{0}: Failed to relaunch browser: {1}" -f $BrowserName, $_.Exception.Message) -Level 'WARNING'
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

Write-Log -Message ("Flag preference: primary '{0}', fallback '{1}'" -f $PrimaryFlag, $FallbackFlag)

Write-Log -Message 'Stopping Chrome and Edge before editing Local State files.'
Stop-Processes -Names @('chrome', 'chrome.exe', 'GoogleCrashHandler', 'GoogleCrashHandler64', 'GoogleUpdate', 'GoogleUpdate.exe', 'GoogleChromeElevationService')
Stop-Processes -Names @('msedge', 'msedge.exe', 'MicrosoftEdgeUpdate', 'MicrosoftEdgeUpdate.exe', 'MicrosoftEdgeElevationService')
Start-Sleep -Seconds 1

$chromeOk = Set-BrowserFlag -LocalStatePath $ChromeLocalState -BrowserName 'Chrome'
$edgeOk   = Set-BrowserFlag -LocalStatePath $EdgeLocalState -BrowserName 'Edge'

$programFilesPaths = @($env:ProgramFiles, ${env:ProgramFiles(x86)}) | Where-Object { $_ }
$chromeCandidates  = @()
$edgeCandidates    = @()

foreach ($path in $programFilesPaths) {
    $chromeCandidates += Join-Path $path 'Google\Chrome\Application\chrome.exe'
    $edgeCandidates   += Join-Path $path 'Microsoft\Edge\Application\msedge.exe'
}

$chromeCandidates += Join-Path $env:LOCALAPPDATA 'Google\Chrome\Application\chrome.exe'
$edgeCandidates   += Join-Path $env:LOCALAPPDATA 'Microsoft\Edge\Application\msedge.exe'

$chromeExe = Get-BrowserExecutable -CandidatePaths $chromeCandidates
$edgeExe   = Get-BrowserExecutable -CandidatePaths $edgeCandidates

if ($chromeExe) {
    Start-Browser -BrowserName 'Chrome' -ExecutablePath $chromeExe
}
else {
    Write-Log -Message 'Chrome executable was not found.' -Level 'WARNING'
}

if ($edgeExe) {
    Start-Browser -BrowserName 'Edge' -ExecutablePath $edgeExe
}
else {
    Write-Log -Message 'Edge executable was not found.' -Level 'WARNING'
}

if ($chromeOk -and $edgeOk) {
    Finish-Script -ExitCode 0 -Level 'SUCCESS' -Message 'Chrome and Edge were remediated successfully.'
}

Finish-Script -ExitCode 1 -Level 'WARNING' -Message ("Remediation completed with issues. Chrome={0}; Edge={1}." -f $chromeOk, $edgeOk)

#endregion ---------- Main ----------
