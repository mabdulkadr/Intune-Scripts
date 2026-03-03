<#!
.SYNOPSIS
    Remediate LNA DisableLocalNetworkAccessChecks based on defined conditions.

.DESCRIPTION
    This remediation script applies corrective actions for LNA DisableLocalNetworkAccessChecks.
    Use with Intune Proactive Remediations or on-demand execution.

    Exit codes:
    - Exit 0: Completed successfully
    - Exit 1: Failed or requires further action

.RUN AS
    System or User (according to assignment settings and script requirements).

.EXAMPLE
    .\Remediate-LNA-DisableLocalNetworkAccessChecks.ps1

.NOTES
    Script  : Remediate-LNA-DisableLocalNetworkAccessChecks.ps1
    Path    : Intune-Scripts\Intune - Remediation Scripts\Disable Local Network Access Checks (Chrome & Edge)\Remediate-LNA-DisableLocalNetworkAccessChecks.ps1
    Updated : 2026-02-15
#>
#region ============================ MAIN ======================================
[CmdletBinding()]
param()

# ============================== PATHS & LOGGING ==============================
$SolutionName = "Disable Local Network Access Checks (Chrome & Edge)"
$BasePath     = Join-Path "C:\Intune" $SolutionName
$LogFile      = Join-Path $BasePath "Remediate-Disable-LNA-Chrome-Edge.txt"

# Function: Initialize-Logging
function Initialize-Logging {
    try {
        if (-not (Test-Path $LogFile)) {
            New-Item -Path $LogFile -ItemType File -Force -ErrorAction Stop | Out-Null
        }
        return $true
    }
    catch {
        return $false
    }
}

$LogReady = Initialize-Logging

# Function: Write-Log
function Write-Log {
    param(
        [Parameter(Mandatory=$true)][string]$Message,
        [ValidateSet("INFO","OK","WARN","FAIL")]
        [string]$Level = "INFO"
    )

    $ts   = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[{0}] [{1}] {2}" -f $ts, $Level, $Message

    switch ($Level) {
        "OK"   { Write-Host $line -ForegroundColor Green }
        "WARN" { Write-Host $line -ForegroundColor Yellow }
        "FAIL" { Write-Host $line -ForegroundColor Red }
        default { Write-Host $line -ForegroundColor Cyan }
    }

    if ($LogReady) {
        try { Add-Content -Path $LogFile -Value $line -ErrorAction SilentlyContinue } catch {}
    }
}

# ============================== CONSTANTS ==============================
$RequiredFlag = "local-network-access-check@3"
$RuntimeArgs  = "--disable-features=LocalNetworkAccessChecks,LocalNetworkAccessCheck"

$ChromeLocalState = Join-Path $env:LOCALAPPDATA "Google\Chrome\User Data\Local State"
$EdgeLocalState   = Join-Path $env:LOCALAPPDATA "Microsoft\Edge\User Data\Local State"

# ============================== HELPER FUNCTIONS ==============================

# Stops browser processes to prevent Local State lock issues.
function Stop-BrowserProcesses {
    param([string[]]$Names)

    foreach ($Name in $Names) {
        Get-Process -Name $Name -ErrorAction SilentlyContinue |
            Stop-Process -Force -ErrorAction SilentlyContinue
    }
}

# Waits until a file is unlocked (best effort) to avoid write failures.
function Wait-FileUnlocked {
    param(
        [Parameter(Mandatory=$true)][string]$Path,
        [int]$MaxWaitSeconds = 15
    )

    for ($i = 0; $i -lt $MaxWaitSeconds; $i++) {
        try {
            $fs = [System.IO.File]::Open($Path,'Open','Write','None')
            $fs.Close()
            return $true
        }
        catch {
            Start-Sleep -Seconds 1
        }
    }
    return $false
}

# Some Chromium builds may return hashtables for nested objects after ConvertFrom-Json.
# For safety (especially Edge scenarios), ensure the object is a PSCustomObject.
function Ensure-PSCustomObject {
    param([ref]$ObjectRef)

    if ($ObjectRef.Value -is [hashtable]) {
        $ObjectRef.Value = [pscustomobject]$ObjectRef.Value
    }
}

# Enforces ONLY local-network-access-check@3 in the Local State file with rollback safety.
function Set-LnaFlagV3Only {
    param(
        [Parameter(Mandatory=$true)][string]$LocalStatePath,
        [Parameter(Mandatory=$true)][string]$BrowserName
    )

    # Ensure Local State exists
    if (-not (Test-Path $LocalStatePath)) {
        Write-Log -Level "WARN" -Message ("{0}: Local State not found: {1}" -f $BrowserName, $LocalStatePath)
        return $false
    }

    # Ensure file is not locked
    if (-not (Wait-FileUnlocked -Path $LocalStatePath -MaxWaitSeconds 15)) {
        Write-Log -Level "FAIL" -Message ("{0}: Local State appears locked: {1}" -f $BrowserName, $LocalStatePath)
        return $false
    }

    # Backup for rollback safety
    $Backup = "$LocalStatePath.bak_{0}" -f (Get-Date -Format 'yyyyMMddHHmmss')
    try {
        Copy-Item -Path $LocalStatePath -Destination $Backup -Force -ErrorAction Stop
        Write-Log -Level "INFO" -Message ("{0}: Backup created: {1}" -f $BrowserName, $Backup)
    }
    catch {
        Write-Log -Level "FAIL" -Message ("{0}: Failed to create backup." -f $BrowserName)
        return $false
    }

    # Parse JSON
    try {
        $raw  = Get-Content -Path $LocalStatePath -Raw -ErrorAction Stop
        $json = $raw | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        Write-Log -Level "FAIL" -Message ("{0}: JSON parse failed. Restoring backup." -f $BrowserName)
        Copy-Item -Path $Backup -Destination $LocalStatePath -Force -ErrorAction SilentlyContinue
        return $false
    }

    # Ensure browser object exists and is PSCustomObject
    if (-not ($json.PSObject.Properties['browser'])) {
        $json | Add-Member -NotePropertyName browser -NotePropertyValue ([pscustomobject]@{})
    }
    else {
        Ensure-PSCustomObject ([ref]$json.browser)
    }

    # Ensure enabled_labs_experiments exists
    if (-not ($json.browser.PSObject.Properties['enabled_labs_experiments'])) {
        $json.browser | Add-Member -NotePropertyName enabled_labs_experiments -NotePropertyValue @()
    }
    if ($null -eq $json.browser.enabled_labs_experiments) {
        $json.browser.enabled_labs_experiments = @()
    }

    # Remove any existing LNA variants and add ONLY @3
    $json.browser.enabled_labs_experiments = @(
        $json.browser.enabled_labs_experiments |
        Where-Object { $_ -notmatch '^local-network-access-check@' }
    )
    $json.browser.enabled_labs_experiments += $RequiredFlag

    # Write updated JSON back to Local State
    try {
        ($json | ConvertTo-Json -Depth 12) | Set-Content -Path $LocalStatePath -Encoding UTF8 -ErrorAction Stop
        Write-Log -Level "INFO" -Message ("{0}: Local State updated." -f $BrowserName)
    }
    catch {
        Write-Log -Level "FAIL" -Message ("{0}: Failed to write Local State. Restoring backup." -f $BrowserName)
        Copy-Item -Path $Backup -Destination $LocalStatePath -Force -ErrorAction SilentlyContinue
        return $false
    }

    # Verify the flag is present after write; rollback if not
    try {
        $verify = Get-Content -Path $LocalStatePath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        if ($verify.browser.enabled_labs_experiments -contains $RequiredFlag) {
            Write-Log -Level "OK" -Message ("{0}: Verified required flag present: {1}" -f $BrowserName, $RequiredFlag)
            return $true
        }

        Write-Log -Level "FAIL" -Message ("{0}: Verification failed (flag missing). Restoring backup." -f $BrowserName)
        Copy-Item -Path $Backup -Destination $LocalStatePath -Force -ErrorAction SilentlyContinue
        return $false
    }
    catch {
        Write-Log -Level "FAIL" -Message ("{0}: Verification read/parse failed. Restoring backup." -f $BrowserName)
        Copy-Item -Path $Backup -Destination $LocalStatePath -Force -ErrorAction SilentlyContinue
        return $false
    }
}

# Finds browser EXE path in common locations (system install + user install).
function Get-BrowserExe {
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("Chrome","Edge")]
        [string]$Browser
    )

    if ($Browser -eq "Chrome") {
        $Candidates = @(
            "C:\Program Files\Google\Chrome\Application\chrome.exe",
            "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe",
            (Join-Path $env:LOCALAPPDATA "Google\Chrome\Application\chrome.exe")
        )
    }
    else {
        $Candidates = @(
            "C:\Program Files\Microsoft\Edge\Application\msedge.exe",
            "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
            (Join-Path $env:LOCALAPPDATA "Microsoft\Edge\Application\msedge.exe")
        )
    }

    return ($Candidates | Where-Object { Test-Path $_ } | Select-Object -First 1)
}

# Relaunches a browser with runtime flags (best effort).
function Relaunch-Browser {
    param(
        [Parameter(Mandatory=$true)][string]$ExePath,
        [Parameter(Mandatory=$true)][string]$BrowserName
    )

    try {
        Write-Log -Level "INFO" -Message ("Relaunching {0} with args: {1}" -f $BrowserName, $RuntimeArgs)
        Start-Process -FilePath $ExePath -ArgumentList $RuntimeArgs -WindowStyle Normal -ErrorAction Stop | Out-Null
        Write-Log -Level "OK" -Message ("{0}: Relaunched successfully." -f $BrowserName)
        return $true
    }
    catch {
        Write-Log -Level "WARN" -Message ("{0}: Relaunch failed: {1}" -f $BrowserName, $_.Exception.Message)
        return $false
    }
}

# ============================== EXECUTION ==============================
Write-Log -Level "INFO" -Message ("=== Remediation START | {0} ===" -f $SolutionName)
Write-Log -Level "INFO" -Message ("LogFile: {0}" -f $LogFile)

# 1) Stop browsers to avoid file lock issues
Write-Log -Level "INFO" -Message "Stopping Chrome & Edge processes..."
Stop-BrowserProcesses @("chrome","chrome.exe","GoogleCrashHandler","GoogleCrashHandler64","GoogleUpdate","GoogleUpdate.exe","GoogleChromeElevationService")
Stop-BrowserProcesses @("msedge","msedge.exe","MicrosoftEdgeUpdate","MicrosoftEdgeUpdate.exe","MicrosoftEdgeElevationService")

# Taskkill as additional enforcement (handles stubborn child processes)
cmd /c taskkill /IM chrome.exe /F > $null 2>&1
cmd /c taskkill /IM msedge.exe /F > $null 2>&1
Start-Sleep -Seconds 1

# 2) Update Local State for both browsers
Write-Log -Level "INFO" -Message "Enforcing flag in Chrome Local State..."
$ChromeOK = Set-LnaFlagV3Only -LocalStatePath $ChromeLocalState -BrowserName "Chrome"

Write-Log -Level "INFO" -Message "Enforcing flag in Edge Local State..."
$EdgeOK = Set-LnaFlagV3Only -LocalStatePath $EdgeLocalState -BrowserName "Edge"

# 3) Relaunch browsers with runtime flags (best effort)
$ChromeLaunchOK = $false
$EdgeLaunchOK   = $false

if ($ChromeOK) {
    $ChromeExe = Get-BrowserExe -Browser "Chrome"
    if ($ChromeExe) {
        $ChromeLaunchOK = Relaunch-Browser -ExePath $ChromeExe -BrowserName "Chrome"
    }
    else {
        Write-Log -Level "WARN" -Message "Chrome executable not found. Relaunch skipped."
    }
}
else {
    Write-Log -Level "WARN" -Message "Chrome update failed. Relaunch skipped."
}

if ($EdgeOK) {
    $EdgeExe = Get-BrowserExe -Browser "Edge"
    if ($EdgeExe) {
        $EdgeLaunchOK = Relaunch-Browser -ExePath $EdgeExe -BrowserName "Edge"
    }
    else {
        Write-Log -Level "WARN" -Message "Edge executable not found. Relaunch skipped."
    }
}
else {
    Write-Log -Level "WARN" -Message "Edge update failed. Relaunch skipped."
}

# 4) Output verification hints (useful for IT operations)
Write-Host ""
Write-Host "Verify (manual):"
Write-Host " - Chrome: chrome://version  -> Command Line includes: $RuntimeArgs"
Write-Host " -   Edge: edge://version    -> Command Line includes: $RuntimeArgs"
Write-Host ""

# 5) Intune result
if ($ChromeOK -and $EdgeOK) {
    Write-Log -Level "OK" -Message ("Remediation complete: Chrome=True Edge=True | Relaunch: Chrome={0} Edge={1}" -f $ChromeLaunchOK, $EdgeLaunchOK)
    Write-Log -Level "INFO" -Message "=== Remediation END (Exit 0) ==="
    exit 0
}
else {
    Write-Log -Level "FAIL" -Message ("Remediation failed: Chrome={0} Edge={1} | Relaunch: Chrome={2} Edge={3}" -f $ChromeOK, $EdgeOK, $ChromeLaunchOK, $EdgeLaunchOK)
    Write-Log -Level "INFO" -Message "=== Remediation END (Exit 1) ==="
    exit 1
}
#endregion =====================================================================
