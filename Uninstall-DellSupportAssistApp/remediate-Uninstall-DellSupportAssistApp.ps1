<#
.TITLE
    Remediation - Remove Dell SupportAssist

.SYNOPSIS
    Uninstalls Dell SupportAssist using the removal method advertised in its uninstall registry entry.

.DESCRIPTION
    Paired remediation for Uninstall-DellSupportAssistApp. Runs only when
    detect-Uninstall-DellSupportAssistApp.ps1 returns exit 1. Reads the uninstall
    registry data for 'Dell SupportAssist' and uses one of the supported uninstall
    methods: msiexec.exe with an extracted product GUID, or
    SupportAssistUninstaller.exe with '/arp /S'. Performs: (1) pre-remediation
    validation, (2) uninstall with failure tracking, (3) post-remediation
    verification, (4) structured JSON result output for Intune diagnostics.

    Exit contract:
    Exit 0 = success (fix applied and verified)
    Exit 1 = failure (verification failed after applying)
    Exit 2 = script error

.TAGS
    Remediation,Action,Dell,SupportAssist

.REMEDIATIONTYPE
    Remediation

.PAIRSCRIPT
    detect-Uninstall-DellSupportAssistApp.ps1

.PLATFORM
    Windows

.MINROLE
    Intune Service Administrator

.PERMISSIONS
    None (local SYSTEM context) - runs the vendor uninstaller or msiexec against the detected product.

.AUTHOR
    Mohammad Abdelkader Omar

.VERSION
    2.0.0

.CHANGELOG
    2.0.0 (2026-08-26)
    - Migrated to Enterprise Standards canonical structure (header, logging, exit contract)
    - Added pre-check / per-target fix / post-verify flow with JSON result output
    1.2 (2025)
    - Logging and banner improvements
    1.0.0
    - Initial release

.LASTUPDATE
    2026-08-26

.EXAMPLE
    .\remediate-Uninstall-DellSupportAssistApp.ps1
    Applies the uninstall and verifies it; exits 0 on verified success.

.EXAMPLE
    .\remediate-Uninstall-DellSupportAssistApp.ps1
    Exits 1 if verification fails, exit 2 on unexpected script error.

.NOTES
    - Runs in SYSTEM context via Intune Proactive Remediations.
    - Idempotent: safe to run repeatedly; verify-before-and-after.
    - Dell SupportAssist is OEM-supported software - removing it may affect Dell diagnostic tooling.
    - Logs: <SystemDrive>\IntuneLogs\Uninstall-DellSupportAssistApp\Uninstall-DellSupportAssistApp-Remediation.txt
#>

#Requires -Version 5.1

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# ============================================================================
# CONFIGURATION - solution identity and desired state values.
# ============================================================================

$SolutionName = 'Uninstall-DellSupportAssistApp'
$ScriptMode   = 'Remediation'

$UninstallPaths = @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
    'HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
)
$TargetDisplayName = 'Dell SupportAssist'

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
        # The parent uninstall keys must exist before entries can be queried or removed.
        foreach ($path in $UninstallPaths) {
            $parentKey = $path -replace '\\\*$', ''
            if (-not (Test-Path -LiteralPath $parentKey)) {
                throw "Required registry key not found: $parentKey"
            }
        }

        # Resolve the target entry once so the fix phase works against known state.
        $script:TargetApp = Get-ItemProperty -Path $UninstallPaths -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName -eq $TargetDisplayName } |
            Select-Object -First 1 DisplayName, UninstallString, PSPath

        if ($script:TargetApp) {
            Write-RemediationLog "Dell SupportAssist found: $($script:TargetApp.DisplayName)" -Level 'Info'
        }
        else {
            Write-RemediationLog "Dell SupportAssist was not found. Nothing to remediate." -Level 'Info'
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

# Resolves the supported silent uninstall command from an uninstall string.
function Get-UninstallCommand {
    param(
        [Parameter(Mandatory = $true)]
        [string]$UninstallString
    )

    if ($UninstallString -match 'msiexec(\.exe)?' -and $UninstallString -match '\{[A-Za-z0-9\-]+\}') {
        $productCode = $matches[0]
        return [pscustomobject]@{
            FilePath     = 'msiexec.exe'
            ArgumentList = "/x $productCode /qn /norestart"
        }
    }

    if ($UninstallString -match 'SupportAssistUninstaller\.exe') {
        $exePath = [regex]::Match($UninstallString, '^\s*"?(?<path>[^"]*SupportAssistUninstaller\.exe)"?').Groups['path'].Value
        if (-not $exePath) {
            throw 'Unable to parse SupportAssistUninstaller.exe path from the uninstall string.'
        }

        return [pscustomobject]@{
            FilePath     = $exePath
            ArgumentList = '/arp /S'
        }
    }

    throw 'Unsupported uninstall method for Dell SupportAssist.'
}

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
        # Re-run the same query the detector used. Return $true only when the
        # observed state now matches the compliant definition (entry absent).
        $remaining = Get-ItemProperty -Path $UninstallPaths -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName -eq $TargetDisplayName } |
            Select-Object -First 1 DisplayName, UninstallString, PSPath
        return ($null -eq $remaining)
    }
    catch {
        Write-RemediationLog "Verification could not query the uninstall registry: $($_.Exception.Message)" -Level 'Error'
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

    # --- Fix (per-target failure tracking) ---
    $script:FailedCount = 0
    $targetCount        = 1

    Write-RemediationLog "Executing remediation actions..." -Level 'Info'

    if (-not $script:TargetApp) {
        # Absence is the desired end state - nothing to remove.
        Write-RemediationLog "No installation entry present - skipping uninstall" -Level 'Info'
    }
    else {
        Invoke-FixTarget -TargetName $TargetDisplayName -Fix {
            if ([string]::IsNullOrWhiteSpace($script:TargetApp.UninstallString)) {
                throw "Found '$($script:TargetApp.DisplayName)' but no uninstall string is available."
            }

            $command = Get-UninstallCommand -UninstallString $script:TargetApp.UninstallString
            Write-RemediationLog "Starting uninstall using $($command.FilePath) $($command.ArgumentList)" -Level 'Info'

            $process = Start-Process -FilePath $command.FilePath -ArgumentList $command.ArgumentList -Wait -PassThru -WindowStyle Hidden -ErrorAction Stop
            if ($process.ExitCode -ne 0) {
                throw "Uninstaller process exited with code $($process.ExitCode)"
            }
        }
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

        Finish-Script -ExitCode 0 -Message "Remediation completed successfully" -Level 'SUCCESS'
    }
    else {
        $script:RemediationResult.Status = "Failed"
        Write-Output "Remediation finished but verification failed"
        Write-Output ($remediationResult | ConvertTo-Json -Depth 6 -Compress)
        Finish-Script -ExitCode 1 -Message "Post-remediation verification failed" -Level 'ERROR'
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
