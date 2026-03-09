<#
.SYNOPSIS
    Detects whether the required local network access flag is configured for Chrome and Edge.

.DESCRIPTION
    This detection script checks the Local State files for Google Chrome and
    Microsoft Edge and verifies whether the required experiment flag exists
    in browser.enabled_labs_experiments.

    Exit codes:
    - Exit 0: Compliant
    - Exit 1: Not compliant

.RUN AS
    User

.EXAMPLE
    .\DisableLocalNetworkAccess--Detect.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.1
#>

#region ---------- Configuration ----------

[CmdletBinding()]
param()

# Script metadata
$ScriptName     = 'DisableLocalNetworkAccess--Detect.ps1'
$ScriptBaseName = 'DisableLocalNetworkAccess--Detect'
$SolutionName   = 'Disable Local Network Access Checks (Chrome & Edge)'

# Required browser flag
$RequiredFlag = 'local-network-access-check@3'

# Detect Windows system drive
$SystemDrive = if ($env:SystemDrive) {
    $env:SystemDrive.TrimEnd('\')
}
else {
    [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\')
}

# Browser Local State files
$ChromeLocalState = Join-Path $env:LOCALAPPDATA 'Google\Chrome\User Data\Local State'
$EdgeLocalState   = Join-Path $env:LOCALAPPDATA 'Microsoft\Edge\User Data\Local State'

# Logging path
$BasePath = Join-Path $SystemDrive "Intune\$SolutionName"
$LogFile  = Join-Path $BasePath "$ScriptBaseName.txt"

#endregion ---------- Configuration ----------


#region ---------- Functions ----------

# Create log folder and file if needed
function Initialize-Logging {
    try {
        if (-not (Test-Path -Path $BasePath)) {
            New-Item -Path $BasePath -ItemType Directory -Force | Out-Null
        }

        if (-not (Test-Path -Path $LogFile)) {
            New-Item -Path $LogFile -ItemType File -Force | Out-Null
        }

        return $true
    }
    catch {
        return $false
    }
}

# Write a message to console and log file
function Write-Log {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [ValidateSet('INFO','SUCCESS','WARNING','ERROR')]
        [string]$Level = 'INFO'
    )

    $TimeStamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $Line = "[$TimeStamp] [$Level] $Message"

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

# Check whether the required flag exists in the browser Local State file
function Test-BrowserFlag {
    param(
        [Parameter(Mandatory = $true)]
        [string]$LocalStatePath,

        [Parameter(Mandatory = $true)]
        [string]$BrowserName
    )

    # If the browser profile does not exist, treat it as not applicable
    if (-not (Test-Path -Path $LocalStatePath)) {
        Write-Log -Message "$BrowserName : Local State file not found. Browser may not be installed for this user." -Level 'INFO'
        return $null
    }

    try {
        $JsonData = Get-Content -Path $LocalStatePath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        Write-Log -Message "$BrowserName : Failed to read or parse Local State file." -Level 'ERROR'
        return $false
    }

    if ($null -eq $JsonData.browser -or $null -eq $JsonData.browser.enabled_labs_experiments) {
        Write-Log -Message "$BrowserName : browser.enabled_labs_experiments was not found." -Level 'WARNING'
        return $false
    }

    $Experiments = @($JsonData.browser.enabled_labs_experiments)

    if ($Experiments -contains $RequiredFlag) {
        Write-Log -Message "$BrowserName : Required flag found: $RequiredFlag" -Level 'SUCCESS'
        return $true
    }

    Write-Log -Message "$BrowserName : Required flag not found: $RequiredFlag" -Level 'WARNING'
    return $false
}

#endregion ---------- Functions ----------


#region ---------- Detection Logic ----------

# Prepare logging
$LogReady = Initialize-Logging

Write-Log -Message "Starting detection for $ScriptName"
Write-Log -Message "Required flag: $RequiredFlag"
Write-Log -Message "Log file: $LogFile"

$ChromeResult = Test-BrowserFlag -LocalStatePath $ChromeLocalState -BrowserName 'Chrome'
$EdgeResult   = Test-BrowserFlag -LocalStatePath $EdgeLocalState -BrowserName 'Edge'

# Browser installed and missing flag = non-compliant
$ChromeNeedsFix = ($ChromeResult -eq $false)
$EdgeNeedsFix   = ($EdgeResult -eq $false)

if (-not $ChromeNeedsFix -and -not $EdgeNeedsFix) {
    Write-Log -Message "Compliant: Chrome=$ChromeResult, Edge=$EdgeResult" -Level 'SUCCESS'
    exit 0
}
else {
    Write-Log -Message "Not compliant: Chrome=$ChromeResult, Edge=$EdgeResult" -Level 'WARNING'
    exit 1
}

#endregion ---------- Detection Logic ----------