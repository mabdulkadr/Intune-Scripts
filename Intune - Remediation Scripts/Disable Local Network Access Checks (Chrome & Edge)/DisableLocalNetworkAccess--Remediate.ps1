<#
.SYNOPSIS
    Remediates local network access checks for Chrome and Edge.

.DESCRIPTION
    This remediation script updates the Local State files for Google Chrome
    and Microsoft Edge so the required local network access experiment flag
    is present.

    The script stops running browser processes, updates the flag, and leaves
    the browser to pick up the change on the next launch.

    Exit codes:
    - Exit 0: Completed successfully
    - Exit 1: Failed or requires further action

.RUN AS
    User

.EXAMPLE
    .\DisableLocalNetworkAccess--Remediate.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.1
#>

#region ---------- Configuration ----------

[CmdletBinding()]
param(
    # Try the older flag first if needed
    [switch]$ForceVariant2
)

# Script metadata
$ScriptName     = 'DisableLocalNetworkAccess--Remediate.ps1'
$ScriptBaseName = 'DisableLocalNetworkAccess--Remediate'
$SolutionName   = 'Disable Local Network Access Checks (Chrome & Edge)'

# Detect Windows system drive
$SystemDrive = if ($env:SystemDrive) {
    $env:SystemDrive.TrimEnd('\')
}
else {
    [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\')
}

# Flag variants
$PrimaryFlag  = if ($ForceVariant2) { 'local-network-access-check@2' } else { 'local-network-access-check@3' }
$FallbackFlag = if ($ForceVariant2) { 'local-network-access-check@3' } else { 'local-network-access-check@2' }

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

# Stop running browser processes before editing Local State
function Stop-BrowserProcesses {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$ProcessNames
    )

    foreach ($ProcessName in $ProcessNames) {
        Get-Process -Name $ProcessName -ErrorAction SilentlyContinue |
            Stop-Process -Force -ErrorAction SilentlyContinue
    }
}

# Wait until the file is unlocked
function Wait-FileUnlocked {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [int]$MaxWaitSeconds = 15
    )

    for ($i = 0; $i -lt $MaxWaitSeconds; $i++) {
        try {
            $Stream = [System.IO.File]::Open($Path, 'Open', 'ReadWrite', 'None')
            $Stream.Close()
            return $true
        }
        catch {
            Start-Sleep -Seconds 1
        }
    }

    return $false
}

# Make sure a nested object stays usable
function Convert-ToPSCustomObject {
    param(
        [Parameter(Mandatory = $true)]
        [ref]$ObjectRef
    )

    if ($ObjectRef.Value -is [hashtable]) {
        $ObjectRef.Value = [pscustomobject]$ObjectRef.Value
    }
}

# Update Local State with the required flag
function Set-BrowserFlag {
    param(
        [Parameter(Mandatory = $true)]
        [string]$LocalStatePath,

        [Parameter(Mandatory = $true)]
        [string]$BrowserName,

        [Parameter(Mandatory = $true)]
        [string]$FlagTry1,

        [Parameter(Mandatory = $true)]
        [string]$FlagTry2
    )

    # If the browser profile does not exist, treat it as not applicable
    if (-not (Test-Path -Path $LocalStatePath)) {
        Write-Log -Message "$BrowserName : Local State file not found. Browser may not be installed for this user." -Level 'INFO'
        return $null
    }

    if (-not (Wait-FileUnlocked -Path $LocalStatePath)) {
        Write-Log -Message "$BrowserName : File is locked: $LocalStatePath" -Level 'ERROR'
        return $false
    }

    $BackupPath = '{0}.bak_{1}' -f $LocalStatePath, (Get-Date -Format 'yyyyMMddHHmmss')

    try {
        Copy-Item -Path $LocalStatePath -Destination $BackupPath -Force -ErrorAction Stop
        Write-Log -Message "$BrowserName : Backup created: $BackupPath"
    }
    catch {
        Write-Log -Message "$BrowserName : Failed to create backup." -Level 'ERROR'
        return $false
    }

    try {
        $JsonData = Get-Content -Path $LocalStatePath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        Write-Log -Message "$BrowserName : Failed to read or parse Local State file." -Level 'ERROR'
        try {
            Copy-Item -Path $BackupPath -Destination $LocalStatePath -Force -ErrorAction SilentlyContinue
        }
        catch {}
        return $false
    }

    if (-not $JsonData.PSObject.Properties['browser']) {
        $JsonData | Add-Member -NotePropertyName 'browser' -NotePropertyValue ([pscustomobject]@{})
    }
    else {
        Convert-ToPSCustomObject -ObjectRef ([ref]$JsonData.browser)
    }

    if (-not $JsonData.browser.PSObject.Properties['enabled_labs_experiments']) {
        $JsonData.browser | Add-Member -NotePropertyName 'enabled_labs_experiments' -NotePropertyValue @()
    }

    if ($null -eq $JsonData.browser.enabled_labs_experiments) {
        $JsonData.browser.enabled_labs_experiments = @()
    }

    function Apply-Flag {
        param(
            [Parameter(Mandatory = $true)]
            [string]$Flag
        )

        $JsonData.browser.enabled_labs_experiments = @(
            $JsonData.browser.enabled_labs_experiments |
            Where-Object { $_ -notmatch '^local-network-access-check@' }
        )

        $JsonData.browser.enabled_labs_experiments += $Flag

        $JsonData | ConvertTo-Json -Depth 12 | Set-Content -Path $LocalStatePath -Encoding UTF8

        $VerifyData = Get-Content -Path $LocalStatePath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        return (@($VerifyData.browser.enabled_labs_experiments) -contains $Flag)
    }

    try {
        if (Apply-Flag -Flag $FlagTry1) {
            Write-Log -Message "$BrowserName : Applied flag successfully: $FlagTry1" -Level 'SUCCESS'
            return $true
        }

        Write-Log -Message "$BrowserName : Primary flag failed. Trying fallback: $FlagTry2" -Level 'WARNING'

        if (Apply-Flag -Flag $FlagTry2) {
            Write-Log -Message "$BrowserName : Applied fallback flag successfully: $FlagTry2" -Level 'SUCCESS'
            return $true
        }

        Write-Log -Message "$BrowserName : Failed to verify both flag variants." -Level 'ERROR'
        return $false
    }
    catch {
        Write-Log -Message "$BrowserName : Failed while updating Local State: $($_.Exception.Message)" -Level 'ERROR'

        try {
            Copy-Item -Path $BackupPath -Destination $LocalStatePath -Force -ErrorAction SilentlyContinue
        }
        catch {}

        return $false
    }
}

#endregion ---------- Functions ----------


#region ---------- Remediation Logic ----------

# Prepare logging
$LogReady = Initialize-Logging

Write-Log -Message "Starting remediation for $ScriptName"
Write-Log -Message "Flag preference: $PrimaryFlag then $FallbackFlag"
Write-Log -Message "Log file: $LogFile"

# Stop Chrome before editing
Write-Log -Message 'Stopping Chrome processes'
Stop-BrowserProcesses -ProcessNames @(
    'chrome',
    'GoogleCrashHandler',
    'GoogleCrashHandler64',
    'GoogleUpdate',
    'GoogleChromeElevationService'
)
cmd /c taskkill /IM chrome.exe /F > $null 2>&1

# Stop Edge before editing
Write-Log -Message 'Stopping Edge processes'
Stop-BrowserProcesses -ProcessNames @(
    'msedge',
    'MicrosoftEdgeUpdate',
    'MicrosoftEdgeElevationService'
)
cmd /c taskkill /IM msedge.exe /F > $null 2>&1

Start-Sleep -Seconds 1

# Update Chrome Local State
Write-Log -Message "Updating Chrome Local State: $ChromeLocalState"
$ChromeResult = Set-BrowserFlag -LocalStatePath $ChromeLocalState -BrowserName 'Chrome' -FlagTry1 $PrimaryFlag -FlagTry2 $FallbackFlag

# Update Edge Local State
Write-Log -Message "Updating Edge Local State: $EdgeLocalState"
$EdgeResult = Set-BrowserFlag -LocalStatePath $EdgeLocalState -BrowserName 'Edge' -FlagTry1 $PrimaryFlag -FlagTry2 $FallbackFlag

# Installed browser failed = remediation failure
$ChromeFailed = ($ChromeResult -eq $false)
$EdgeFailed   = ($EdgeResult -eq $false)

if (-not $ChromeFailed -and -not $EdgeFailed) {
    Write-Log -Message "Remediation completed successfully. Chrome=$ChromeResult, Edge=$EdgeResult" -Level 'SUCCESS'
    exit 0
}
else {
    Write-Log -Message "Remediation completed with issues. Chrome=$ChromeResult, Edge=$EdgeResult" -Level 'WARNING'
    exit 1
}

#endregion ---------- Remediation Logic ----------