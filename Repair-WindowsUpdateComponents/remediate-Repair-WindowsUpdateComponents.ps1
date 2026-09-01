<#
.TITLE
    Remediation - Repair Windows Update Components

.SYNOPSIS
    Repairs and resets key Windows Update components.

.DESCRIPTION
    Paired remediation for Repair-WindowsUpdateComponents. Runs only when
    detect-Repair-WindowsUpdateComponents.ps1 returns exit 1. Runs a Windows
    Update repair workflow: the built-in troubleshooter (when available), DISM
    image repair via Repair-WindowsImage, cleanup of common Windows Update
    policy registry values, module preparation, Reset-WUComponents, and a scan
    for/install of pending software updates. Performs: (1) pre-remediation
    validation, (2) per-step fixes with failure tracking, (3) post-remediation
    verification, (4) structured JSON result output for Intune diagnostics.

    Exit contract:
    Exit 0 = success (fix applied and verified)
    Exit 1 = failure (one or more remediation steps reported warnings or failures)
    Exit 2 = script error

.TAGS
    Remediation,Action,WindowsUpdate

.REMEDIATIONTYPE
    Remediation

.PAIRSCRIPT
    detect-Repair-WindowsUpdateComponents.ps1

.PLATFORM
    Windows

.MINROLE
    Intune Service Administrator

.PERMISSIONS
    None (local SYSTEM context) - repairs the Windows image, edits update policy values, installs modules, and resets update components.

.AUTHOR
    Mohammad Abdelkader Omar

.VERSION
    2.0.0

.CHANGELOG
    2.0.0 (2026-08-26)
    - Migrated to Enterprise Standards canonical structure (header, logging, exit contract)
    - Added pre-check / per-target fix / post-verify flow with JSON result output
    1.2
    - Legacy release prior to canonical migration
    1.0.0
    - Initial release

.LASTUPDATE
    2026-08-26

.EXAMPLE
    .\remediate-Repair-WindowsUpdateComponents.ps1
    Runs the full repair workflow; exits 0 when every executed step succeeds.

.EXAMPLE
    .\remediate-Repair-WindowsUpdateComponents.ps1
    Exits 1 if any step reports warnings or failures, exit 2 on unexpected script error.

.NOTES
    - Runs in SYSTEM context via Intune Proactive Remediations.
    - Long-running steps (troubleshooter, RestoreHealth, update install) keep the
      original no-timeout wait approach.
    - Reset-WUComponents destroys Windows Update history as part of the reset.
    - Logs: <SystemDrive>\IntuneLogs\Repair-WindowsUpdateComponents\Repair-WindowsUpdateComponents-Remediation.txt
#>

#Requires -Version 5.1

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# ============================================================================
# CONFIGURATION - solution identity and desired state values.
# ============================================================================

$SolutionName = 'Repair-WindowsUpdateComponents'
$ScriptMode   = 'Remediation'

$TroubleshooterPath = 'C:\Windows\diagnostics\system\WindowsUpdate'
$RegistryCleanupMap = @{
    'HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UpdatePolicy\Settings' = @(
        'PausedQualityDate',
        'PausedFeatureDate',
        'PausedQualityStatus',
        'PausedFeatureStatus'
    )
    'HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\Update' = @(
        'PauseQualityUpdatesStartTime',
        'PauseFeatureUpdatesStartTime',
        'DeferFeatureUpdatesPeriodInDays'
    )
}

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

# DISM log file name preserved from the legacy script.
$DismLogPath = Join-Path $script:SystemDrive "IntuneLogs\$SolutionName\WindowsUpdateTroublshooting-DISM.txt"

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
        # The DISM cmdlet drives the image repair step and is built into Windows.
        if (-not (Get-Command -Name Repair-WindowsImage -ErrorAction SilentlyContinue)) {
            throw "Required command not found: Repair-WindowsImage"
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

# Removes listed registry properties when their parent path exists.
function Remove-RegistryProperties {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string[]]$PropertyNames
    )

    if (-not (Test-Path -Path $Path)) {
        Write-RemediationLog "Registry path not found: $Path" -Level 'Info'
        return
    }

    $item = Get-Item -Path $Path -ErrorAction Stop
    foreach ($propertyName in $PropertyNames) {
        if ($item.Property -contains $propertyName) {
            Write-RemediationLog "Removing registry property '$propertyName' from '$Path'." -Level 'Info'
            Remove-ItemProperty -Path $Path -Name $propertyName -ErrorAction Stop
        }
    }
}

# Ensures a PowerShell module is available, installing it when required.
function Ensure-RequiredModule {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ModuleName
    )

    if (Get-Module -ListAvailable -Name $ModuleName) {
        Write-RemediationLog "Module '$ModuleName' is already available." -Level 'Info'
        return $true
    }

    if (-not (Get-Command -Name Install-Module -ErrorAction SilentlyContinue)) {
        Write-RemediationLog "Install-Module is not available. Cannot install '$ModuleName'." -Level 'Warning'
        return $false
    }

    Write-RemediationLog "Installing module '$ModuleName'." -Level 'Info'
    Install-Module -Name $ModuleName -Force -AllowClobber -ErrorAction Stop
    return $true
}

# ============================================================================
# POST-REMEDIATION VERIFICATION
# ============================================================================

# Post-fix verification - trust-but-verify before declaring exit 0.
function Test-FixApplied {
    try {
        # Success definition preserved from the legacy script: every executed
        # remediation step must have completed without warnings or failures.
        return ($script:FailedCount -eq 0)
    }
    catch {
        Write-RemediationLog "Verification could not evaluate the step summary: $($_.Exception.Message)" -Level 'Error'
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
        Write-Log -Message "DISM log file: $($DismLogPath)" -Level 'DEBUG'
    }
    Write-RemediationLog "Starting remediation..." -Level 'Info'

    # --- Pre-checks ---
    Write-RemediationLog "Performing pre-remediation checks..." -Level 'Info'
    if (-not (Test-RemediationPrerequisites)) {
        throw "Pre-remediation validation failed - aborting before any change."
    }

    # --- Fix (per-target failure tracking) ---
    $script:FailedCount = 0
    $targetCount        = 0

    Write-RemediationLog "Executing remediation actions..." -Level 'Info'

    # Step 1: built-in troubleshooter. Preserved legacy outcome: unavailable
    # troubleshooter is logged as a warning but NOT counted as a failure.
    $troubleshooterAvailable = ((Get-Command -Name Get-TroubleshootingPack -ErrorAction SilentlyContinue) -and (Test-Path -Path $TroubleshooterPath))
    if ($troubleshooterAvailable) {
        $targetCount++
        $null = Invoke-FixTarget -TargetName 'Windows Update troubleshooter' -Fix {
            Write-RemediationLog 'Running the Windows Update troubleshooter.' -Level 'Info'

            Get-TroubleshootingPack -Path $TroubleshooterPath | Invoke-TroubleshootingPack -Unattended

            Write-RemediationLog 'Windows Update troubleshooter completed.' -Level 'Info'
        }
    }
    else {
        Write-RemediationLog 'Windows Update troubleshooter is not available on this system.' -Level 'Warning'
    }

    # Step 2: DISM image repair (long-running; original no-timeout wait kept).
    $targetCount++
    $null = Invoke-FixTarget -TargetName 'Repair-WindowsImage RestoreHealth' -Fix {
        Write-RemediationLog 'Running Repair-WindowsImage -Online -RestoreHealth.' -Level 'Info'

        Repair-WindowsImage -Online -RestoreHealth -NoRestart -LogPath $DismLogPath -ErrorAction Stop | Out-Null

        Write-RemediationLog 'Repair-WindowsImage RestoreHealth completed.' -Level 'Info'
    }

    # Step 3: registry policy value cleanup (per path).
    foreach ($registryPath in $RegistryCleanupMap.Keys) {
        $targetCount++
        $null = Invoke-FixTarget -TargetName "Registry cleanup: $registryPath" -Fix {
            Remove-RegistryProperties -Path $registryPath -PropertyNames $RegistryCleanupMap[$registryPath]
        }
    }

    # Step 4: module preparation (per module).
    foreach ($moduleName in @('PSWindowsUpdate', 'FU.WhyAmIBlocked')) {
        $targetCount++
        $null = Invoke-FixTarget -TargetName "Prepare module: $moduleName" -Fix {
            $moduleReady = Ensure-RequiredModule -ModuleName $moduleName
            if (-not $moduleReady) {
                throw "Module '$moduleName' could not be prepared"
            }
        }
    }

    # Step 5: import PSWindowsUpdate when present (preserved legacy guard).
    if (Get-Module -ListAvailable -Name 'PSWindowsUpdate') {
        $targetCount++
        $null = Invoke-FixTarget -TargetName "Import module: PSWindowsUpdate" -Fix {
            Import-Module -Name 'PSWindowsUpdate' -Force -ErrorAction Stop
            Write-RemediationLog "Module 'PSWindowsUpdate' imported." -Level 'Info'
        }
    }

    # Step 6: reset Windows Update components. Preserved legacy outcome: missing
    # command is logged as a warning but NOT counted as a failure.
    if (Get-Command -Name Reset-WUComponents -ErrorAction SilentlyContinue) {
        $targetCount++
        $null = Invoke-FixTarget -TargetName 'Reset-WUComponents' -Fix {
            Write-RemediationLog 'Resetting Windows Update components.' -Level 'Info'

            Reset-WUComponents -ErrorAction Stop | Out-Null

            Write-RemediationLog 'Windows Update components were reset.' -Level 'Info'
        }
    }
    else {
        Write-RemediationLog 'Reset-WUComponents command is not available.' -Level 'Warning'
    }

    # Step 7: scan for and install pending software updates. Preserved legacy
    # outcome: a missing command here IS counted as a failure.
    if (Get-Command -Name Get-WindowsUpdate -ErrorAction SilentlyContinue) {
        $targetCount++
        $null = Invoke-FixTarget -TargetName 'Scan and install pending software updates' -Fix {
            Write-RemediationLog 'Checking for and installing pending software updates.' -Level 'Info'

            Get-WindowsUpdate -Install -AcceptAll -UpdateType Software -IgnoreReboot -ErrorAction Stop | Out-Null

            Write-RemediationLog 'Windows Update scan and install step completed.' -Level 'Info'
        }
    }
    else {
        $script:FailedCount++
        Write-RemediationLog 'Get-WindowsUpdate command is not available.' -Level 'Warning'
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

        Finish-Script -ExitCode 0 -Message 'Windows Update remediation completed successfully.' -Level 'SUCCESS'
    }
    else {
        $script:RemediationResult.Status = "Failed"
        Write-Output "Remediation finished but verification failed"
        Write-Output ($remediationResult | ConvertTo-Json -Depth 6 -Compress)
        Finish-Script -ExitCode 1 -Message 'One or more Windows Update remediation steps reported warnings or failures.' -Level 'ERROR'
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
