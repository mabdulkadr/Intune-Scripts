<#
.TITLE
    Remediation - Disable Browser Local Network Access Restrictions

.SYNOPSIS
    Adds the required local-network-access experiment flag to Chrome and Edge Local State files.

.DESCRIPTION
    Paired remediation for Disable-LocalNetworkAccessRestrictions. Runs only when
    detect-Disable-LocalNetworkAccessRestrictions.ps1 returns exit 1. Stops both browsers, updates
    each browser's 'Local State' JSON with the required flag (primary variant with fallback support,
    backup before write, restore on failure), then relaunches each browser with the required runtime
    switch. Performs: (1) pre-remediation validation, (2) per-browser update with failure tracking,
    (3) post-remediation verification, (4) structured JSON result output for Intune diagnostics.
    Optional switch -ForceVariant2 prefers the older local-network-access-check@2 variant instead of @3.

    Exit contract:
    Exit 0 = success (fix applied and verified)
    Exit 1 = failure (verification failed after applying)
    Exit 2 = script error

.TAGS
    Remediation,Action,Browser,Chrome,Edge

.REMEDIATIONTYPE
    Remediation

.PAIRSCRIPT
    detect-Disable-LocalNetworkAccessRestrictions.ps1

.PLATFORM
    Windows

.MINROLE
    Intune Service Administrator

.PERMISSIONS
    None (local SYSTEM context) - edits browser Local State files under the user profile after stopping the browsers.

.AUTHOR
    Mohammad Abdelkader Omar

.VERSION
    2.0.0

.CHANGELOG
    2.0.0 (2026-08-26)
    - Migrated to Enterprise Standards canonical structure (header, logging, exit contract)
    - Added pre-check / per-target fix / post-verify flow with JSON result output
    1.x - Legacy release

.LASTUPDATE
    2026-08-26

.EXAMPLE
    .\remediate-Disable-LocalNetworkAccessRestrictions.ps1
    Applies the flag to Chrome and Edge, relaunches them, verifies; exits 0 on success.

.EXAMPLE
    .\remediate-Disable-LocalNetworkAccessRestrictions.ps1 -ForceVariant2
    Prefers the older local-network-access-check@2 flag variant; exits 1 if verification fails.

.NOTES
    - Runs in SYSTEM or assigned user context via Intune Proactive Remediations; assign in user context so $env:LOCALAPPDATA resolves per profile.
    - Stops running Chrome and Edge processes before editing Local State files.
    - Idempotent: re-applying an existing flag is a no-op that still verifies successfully.
    - Logs: <SystemDrive>\IntuneLogs\Disable-LocalNetworkAccessRestrictions\Disable-LocalNetworkAccessRestrictions-Remediation.txt
#>

#Requires -Version 5.1

[CmdletBinding()]
param(
    [switch]$ForceVariant2
)

$ErrorActionPreference = 'Stop'

# ============================================================================
# CONFIGURATION - solution identity and desired state values.
# ============================================================================

$SolutionName = 'Disable-LocalNetworkAccessRestrictions'
$ScriptMode   = 'Remediation'

$PrimaryFlag      = if ($ForceVariant2) { 'local-network-access-check@2' } else { 'local-network-access-check@3' }
$FallbackFlag     = if ($ForceVariant2) { 'local-network-access-check@3' } else { 'local-network-access-check@2' }
$LaunchArgument   = '--disable-features=LocalNetworkAccessChecks,LocalNetworkAccessCheck'
$ChromeLocalState = Join-Path $env:LOCALAPPDATA 'Google\Chrome\User Data\Local State'
$EdgeLocalState   = Join-Path $env:LOCALAPPDATA 'Microsoft\Edge\User Data\Local State'

$remediationResult = @{
    Status             = "Unknown"
    PreCheckStatus     = @()
    RemediationActions = @()
    PostCheckStatus    = @()
    Timestamp          = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    ComputerName       = $env:COMPUTERNAME
}

# ============================================================================
# LOGGING BLOCK (embedded canonical scripts/Write-Log.ps1 - copy VERBATIM)
# Single source of truth: Initialize-Log / Write-Banner / Write-Log / Finish-Script.
# ============================================================================

# --- Logging (CLI Configuration) --------------------------------------------
$script:SystemDrive = if ($env:SystemDrive) { $env:SystemDrive.TrimEnd('\') } else {
    [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\')
}
$script:LogRoot  = $null
$script:LogFile  = $null
$script:LogReady = $false

# Creates the Intune log folder/file and reports readiness.
function Initialize-Log {
    [CmdletBinding()]
    param(
        [string]$SolutionName = 'EnterpriseAdminTool',
        [string]$ScriptMode = 'run',
        [ValidateSet('Intune', 'General')]
        [string]$Type = 'General'
    )

    try {
        if ($Type -eq 'Intune') {
            $script:LogRoot = Join-Path $script:SystemDrive "IntuneLogs\$SolutionName"
            $script:LogFile = Join-Path $script:LogRoot "$SolutionName-$ScriptMode.txt"
        } else {
            $script:LogRoot = Join-Path $env:ProgramData "$SolutionName\Logs"
            $script:LogFile = Join-Path $script:LogRoot "$SolutionName`_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
        }

        if (-not (Test-Path -LiteralPath $script:LogRoot)) {
            $null = [System.IO.Directory]::CreateDirectory($script:LogRoot)
        }
        if (-not (Test-Path -LiteralPath $script:LogFile)) {
            $null = [System.IO.File]::Create($script:LogFile).Dispose()
        }

        $script:LogReady = $true
        return $true
    }
    catch {
        Write-Host "Log initialization failed: $($_.Exception.Message)" -ForegroundColor Red
        $script:LogReady = $false
        return $false
    }
}

# Writes the solution banner to console and log file.
function Write-Banner {
    [CmdletBinding()]
    [Alias('Show-Banner')]
    param()

    $title      = '{0} | {1}' -f $SolutionName, $ScriptMode
    $bannerLine = '=' * 78
    $lines      = @('', $bannerLine, $title, $bannerLine)

    foreach ($line in $lines) {
        if ($line -eq $title) {
            Write-Host $line -ForegroundColor White
        } else {
            Write-Host $line -ForegroundColor DarkGray
        }

        if ($script:LogReady -and $script:LogFile) {
            Add-Content -LiteralPath $script:LogFile -Value $line -Encoding UTF8 -ErrorAction SilentlyContinue -WhatIf:$false
        }
    }
}

# Writes one timestamped, level-colored line to console and log file.
function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Message = "",
        [ValidateSet("INFO", "SUCCESS", "WARNING", "ERROR", "DEBUG")]
        [string]$Level = "INFO"
    )

    # Visual spacer support: callers use Write-Log -Message "" to break sections; early-return on empty.
    if ([string]::IsNullOrEmpty($Message)) { return }

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logLine = "[$timestamp] [$Level] $Message"

    $color = switch ($Level) {
        "DEBUG"   { "DarkGray" }
        "INFO"    { "Cyan" }
        "SUCCESS" { "Green" }
        "WARNING" { "Yellow" }
        "ERROR"   { "Red" }
    }
    Write-Host $logLine -ForegroundColor $color

    if ($script:LogReady -and $script:LogFile) {
        Add-Content -LiteralPath $script:LogFile -Value $logLine -Encoding UTF8 -ErrorAction SilentlyContinue -WhatIf:$false
    }
}

# Logs the final message and terminates with the given exit code.
function Finish-Script {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [int]$ExitCode,
        [Parameter(Mandatory = $false)]
        [string]$Message = "",
        [ValidateSet("INFO", "SUCCESS", "WARNING", "ERROR", "DEBUG")]
        [string]$Level = "INFO",
        [switch]$NoExit
    )

    Write-Log -Message $Message -Level $Level
    if (-not $NoExit) {
        exit $ExitCode
    }
}

# Appends structured per-target remediation entries to the audit trail.
function Write-RemediationLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)][AllowEmptyString()][string]$Message = "",
        [ValidateSet('Info', 'Warning', 'Error')][string]$Level = 'Info'
    )
    # Console/file via canonical Write-Log + structured record for JSON output.
    $mapped = switch ($Level) { 'Warning' { 'WARNING' } 'Error' { 'ERROR' } default { 'INFO' } }
    Write-Log -Message $Message -Level $mapped
    $script:RemediationResult.RemediationActions += @{
        Timestamp = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        Level     = $Level
        Message   = $Message
    }
}

# ============================================================================
# PRE-REMEDIATION VALIDATION
# ============================================================================

# Gate check before any mutation - failures must not touch target state.
function Test-RemediationPrerequisites {
    try {
        # Browser data paths resolve under the user profile; LOCALAPPDATA is required.
        if (-not $env:LOCALAPPDATA) {
            throw "Required environment variable not found: LOCALAPPDATA"
        }

        $script:RemediationResult.PreCheckStatus += "Pre-remediation validation completed successfully"
        return $true
    }
    catch {
        Write-RemediationLog "Pre-remediation validation error: $($_.Exception.Message)" -Level 'Error'
        return $false
    }
}

# ============================================================================
# BROWSER UPDATE HELPERS (migrated legacy logic)
# ============================================================================

# Stop running processes by name.
function Stop-Processes {
    [CmdletBinding()]
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
    [CmdletBinding()]
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
            # File is still locked by the browser - wait one second and retry.
            Start-Sleep -Seconds 1
        }
    }

    return $false
}

# Update the target Local State file and verify that one of the flag variants is present.
function Set-BrowserFlag {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$LocalStatePath,

        [Parameter(Mandatory = $true)]
        [string]$BrowserName
    )

    if (-not (Test-Path -LiteralPath $LocalStatePath)) {
        # Expected absence - the browser has never run for this user.
        Write-RemediationLog ("{0}: Local State was not found: {1}" -f $BrowserName, $LocalStatePath) -Level 'Warning'
        return $false
    }

    if (-not (Wait-FileUnlocked -Path $LocalStatePath)) {
        Write-RemediationLog ("{0}: Local State is still locked: {1}" -f $BrowserName, $LocalStatePath) -Level 'Error'
        return $false
    }

    $backupPath = '{0}.bak_{1}' -f $LocalStatePath, (Get-Date -Format 'yyyyMMddHHmmss')
    Copy-Item -LiteralPath $LocalStatePath -Destination $backupPath -Force -ErrorAction Stop
    Write-RemediationLog ("{0}: Backup created: {1}" -f $BrowserName, $backupPath) -Level 'Info'

    try {
        $jsonData = Get-Content -LiteralPath $LocalStatePath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop

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

            $jsonData | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $LocalStatePath -Encoding UTF8
            $verifyData = Get-Content -LiteralPath $LocalStatePath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop

            if (@($verifyData.browser.enabled_labs_experiments) -contains $flag) {
                Write-RemediationLog ("{0}: Required flag applied successfully: {1}" -f $BrowserName, $flag) -Level 'Info'
                return $true
            }

            Write-RemediationLog ("{0}: Flag variant was not accepted, trying next option." -f $BrowserName) -Level 'Warning'
        }
    }
    catch {
        Write-RemediationLog ("{0}: Failed to update Local State: {1}" -f $BrowserName, $_.Exception.Message) -Level 'Error'
    }

    try {
        Copy-Item -LiteralPath $backupPath -Destination $LocalStatePath -Force -ErrorAction Stop
        Write-RemediationLog ("{0}: Original Local State was restored from backup." -f $BrowserName) -Level 'Warning'
    }
    catch {
        Write-RemediationLog ("{0}: Failed to restore Local State from backup: {1}" -f $BrowserName, $_.Exception.Message) -Level 'Error'
    }

    return $false
}

# Return the first browser executable found in common install locations.
function Get-BrowserExecutable {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$CandidatePaths
    )

    return $CandidatePaths | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
}

# Launch the browser with the required runtime switch when possible.
function Start-Browser {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$BrowserName,

        [Parameter(Mandatory = $true)]
        [string]$ExecutablePath
    )

    try {
        Start-Process -FilePath $ExecutablePath -ArgumentList $LaunchArgument -ErrorAction Stop | Out-Null
        Write-RemediationLog ("{0}: Browser was relaunched successfully." -f $BrowserName) -Level 'Info'
    }
    catch {
        Write-RemediationLog ("{0}: Failed to relaunch browser: {1}" -f $BrowserName, $_.Exception.Message) -Level 'Warning'
    }
}

# Returns $true when the Local State file contains a local-network-access experiment flag.
function Test-AcceptedFlag {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$LocalStatePath
    )

    if (-not (Test-Path -LiteralPath $LocalStatePath)) {
        return $false
    }

    try {
        $jsonData = Get-Content -LiteralPath $LocalStatePath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        Write-RemediationLog "Verification could not parse: $LocalStatePath" -Level 'Error'
        return $false
    }

    if ($null -eq $jsonData.browser -or $null -eq $jsonData.browser.enabled_labs_experiments) {
        return $false
    }

    $acceptedFlags = @($jsonData.browser.enabled_labs_experiments | Where-Object { $_ -match '^local-network-access-check@' })
    return ($acceptedFlags.Count -gt 0)
}

# ============================================================================
# REMEDIATION ACTION (per-target pattern)
# ============================================================================

# Applies the fix to ONE target and returns a structured success/failure object.
function Invoke-FixTarget {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$TargetName,
        [Parameter(Mandatory = $true)][scriptblock]$Fix
    )
    # Returns $true when the fix was applied AND verified for this target.
    try {
        & $Fix
        return $true
    }
    catch {
        $script:FailedCount++
        Write-RemediationLog "Target FAILED: $TargetName - $($_.Exception.Message)" -Level 'Warning'
        return $false
    }
}

# ============================================================================
# POST-REMEDIATION VERIFICATION
# ============================================================================

# Post-fix verification - trust-but-verify before declaring exit 0.
function Test-FixApplied {
    try {
        # Re-read both Local State files; compliant only when each contains an accepted
        # local-network-access flag variant.
        $chromeOk = Test-AcceptedFlag -LocalStatePath $ChromeLocalState
        $edgeOk   = Test-AcceptedFlag -LocalStatePath $EdgeLocalState
        return ($chromeOk -and $edgeOk)
    }
    catch {
        Write-RemediationLog "Verification could not read the browser Local State files: $($_.Exception.Message)" -Level 'Error'
        return $false
    }
}

# ============================================================================
# MAIN
# ============================================================================
# Flow: init -> pre-checks -> per-target fix -> post-verify -> exit 0 / 1 / 2.

try {
    $null = Initialize-Log -SolutionName $SolutionName -ScriptMode $ScriptMode -Type 'Intune'
    Write-Banner
    if ($script:LogReady) {
        Write-Log -Message "Log file ready: $($script:LogFile)" -Level 'DEBUG'
    }
    Write-RemediationLog "Starting remediation..." -Level 'Info'

    # --- Pre-checks ---
    Write-RemediationLog "Performing pre-remediation checks..." -Level 'Info'
    if (-not (Test-RemediationPrerequisites)) {
        throw "Pre-remediation validation failed - aborting before any change."
    }

    Write-RemediationLog ("Flag preference: primary '{0}', fallback '{1}'" -f $PrimaryFlag, $FallbackFlag) -Level 'Info'
    Write-RemediationLog "Stopping Chrome and Edge before editing Local State files." -Level 'Info'
    Stop-Processes -Names @('chrome', 'chrome.exe', 'GoogleCrashHandler', 'GoogleCrashHandler64', 'GoogleUpdate', 'GoogleUpdate.exe', 'GoogleChromeElevationService')
    Stop-Processes -Names @('msedge', 'msedge.exe', 'MicrosoftEdgeUpdate', 'MicrosoftEdgeUpdate.exe', 'MicrosoftEdgeElevationService')
    Start-Sleep -Seconds 1

    # --- Fix (per-target failure tracking) ---
    $script:FailedCount = 0
    $targetCount        = 0

    Write-RemediationLog "Executing remediation actions..." -Level 'Info'

    $targetCount++
    $chromeOk = Invoke-FixTarget -TargetName 'Chrome Local State' -Fix {
        Set-BrowserFlag -LocalStatePath $ChromeLocalState -BrowserName 'Chrome'
    }

    $targetCount++
    $edgeOk = Invoke-FixTarget -TargetName 'Edge Local State' -Fix {
        Set-BrowserFlag -LocalStatePath $EdgeLocalState -BrowserName 'Edge'
    }

    # Relaunch each installed browser with the required runtime switch (best effort).
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
        Write-RemediationLog 'Chrome executable was not found.' -Level 'Warning'
    }

    if ($edgeExe) {
        Start-Browser -BrowserName 'Edge' -ExecutablePath $edgeExe
    }
    else {
        Write-RemediationLog 'Edge executable was not found.' -Level 'Warning'
    }

    # --- Verify ---
    Write-RemediationLog "Performing post-remediation verification..." -Level 'Info'
    $verificationPassed = Test-FixApplied

    if ($targetCount -gt 0 -and $failedCount -ge $targetCount) {
        $verificationPassed = $false
    }

    # --- Report ---
    if ($verificationPassed) {
        $script:RemediationResult.Status = "Success"
        $script:RemediationResult.PostCheckStatus += "Verification passed after remediation"

        Write-Output "Remediation completed successfully"
        Write-Output "Targets processed: $targetCount (failed: $failedCount)"
        Write-Output ($remediationResult | ConvertTo-Json -Depth 6 -Compress)

        Finish-Script -ExitCode 0 -Message "Chrome and Edge were remediated successfully." -Level 'SUCCESS'
    }
    else {
        $script:RemediationResult.Status = "Failed"
        Write-Output "Remediation finished but verification failed"
        Write-Output ($remediationResult | ConvertTo-Json -Depth 6 -Compress)
        Finish-Script -ExitCode 1 -Message ("Remediation completed with issues. Chrome={0}; Edge={1}." -f $chromeOk, $edgeOk) -Level 'ERROR'
    }
}
catch {
    $script:RemediationResult.Status = "Error"
    $script:RemediationResult.Error = @{
        Message    = $_.Exception.Message
        Type       = $_.Exception.GetType().FullName
        StackTrace = $_.ScriptStackTrace
    }
    Write-Output ($remediationResult | ConvertTo-Json -Depth 6 -Compress)
    Finish-Script -ExitCode 2 -Message "Script execution error: $($_.Exception.Message)" -Level 'ERROR'
}
finally {
    Write-Log -Message "Cleanup complete." -Level 'DEBUG'
}
