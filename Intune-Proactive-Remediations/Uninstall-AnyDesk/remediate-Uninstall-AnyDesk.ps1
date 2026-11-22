<#
.TITLE
    Remediation - AnyDesk Silent Removal and Residual Cleanup

.SYNOPSIS
    Silently removes AnyDesk and its residual data after detection reports non-compliance.

.DESCRIPTION
    Paired remediation for UninstallAnyDesk. Runs only when detect-Uninstall-AnyDesk.ps1
    returns exit 1. Stops the AnyDesk process and service, invokes the documented
    silent removal command, deletes leftover installation and data folders, then
    re-checks every condition the detector uses before declaring success.

    Exit contract:
    Exit 0 = success (fix applied and verified)
    Exit 1 = failure (verification failed after applying)
    Exit 2 = script error

.TAGS
    Remediation,Action,Uninstall

.REMEDIATIONTYPE
    Remediation

.PAIRSCRIPT
    detect-Uninstall-AnyDesk.ps1

.PLATFORM
    Windows

.MINROLE
    Intune Service Administrator

.PERMISSIONS
    None (local SYSTEM context) - stops AnyDesk, runs its uninstaller and removes AnyDesk folders.

.AUTHOR
    Mohammad Abdelkader Omar

.VERSION
    1.0.0

.CHANGELOG
    1.0.0 (2026-11-22)
    - Initial release: silent removal, residual cleanup and post-remediation verification.

.LASTUPDATE
    2026-11-22

.EXAMPLE
    .\remediate-Uninstall-AnyDesk.ps1
    Applies the fix and verifies it; exits 0 on verified success.

.EXAMPLE
    .\remediate-Uninstall-AnyDesk.ps1
    Exits 1 if verification fails, exit 2 on unexpected script error.

.NOTES
    - Runs in SYSTEM context via Intune Proactive Remediations.
    - Idempotent: safe to run repeatedly; verifies before and after the change.
    - Removing residual folders permanently deletes the device AnyDesk ID and Alias.
    - Logs: <SystemDrive>\IntuneLogs\UninstallAnyDesk\remediate-Uninstall-AnyDesk.txt
#>

#Requires -Version 5.1

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# ============================================================================
# CONFIGURATION - solution identity and structured audit result.
# ============================================================================

$SolutionName = 'UninstallAnyDesk'
$ScriptMode   = 'Remediation'

$remediationResult = @{
    Status             = "Unknown"
    PreCheckStatus     = @()
    RemediationActions = @()
    PostCheckStatus    = @()
    Timestamp          = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    ComputerName       = $env:COMPUTERNAME
}

# ============================================================================
# LOGGING BLOCK (verbatim copy of scripts/Write-Log.ps1 + canonical audit helper)
# Inlined so this half of the pair is self-contained on the target machine.
# ============================================================================

# --- Logging (CLI Configuration) --------------------------------------------
$script:SystemDrive = if ($env:SystemDrive) { $env:SystemDrive.TrimEnd('\') } else {
    [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\')
}
$script:LogRoot  = $null
$script:LogFile  = $null
$script:LogReady = $false

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

function Write-Banner {
    [CmdletBinding()]
    [Alias('Show-Banner')]
    param()

    # Clean enterprise banner: title includes live timestamp so file+console match
    # the user-facing shape:
    #   ==============================================================================
    #   Solution | Mode | yyyy-MM-dd HH:mm:ss
    #   ==============================================================================
    $title      = '{0} | {1} | {2}' -f $SolutionName, $ScriptMode, (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
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

function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [AllowEmptyString()]
        [string]$Message = "",
        [ValidateSet("INFO", "SUCCESS", "WARNING", "ERROR", "DEBUG")]
        [string]$Level = "INFO"
    )

    # Visual spacer support: callers commonly use `Write-Log -Message ""` to break
    # sections vertically. PowerShell's Mandatory binding treats an empty string
    # as a missing value, so the canonical helper MUST early-return on empty -
    # see Lesson 2026-08-30 | Find-IntunePolicyConflict | CLI logging / Mandatory parameter.
    if ([string]::IsNullOrEmpty($Message)) { return }

    # Console = clean, no timestamp/level prefix - color alone conveys severity.
    # File    = detailed - keeps [timestamp] [LEVEL] for fleet troubleshooting.
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $fileLine  = "[$timestamp] [$Level] $Message"

    $color = switch ($Level) {
        "DEBUG"   { "DarkGray" }
        "INFO"    { "Cyan" }
        "SUCCESS" { "Green" }
        "WARNING" { "Yellow" }
        "ERROR"   { "Red" }
    }
    Write-Host $Message -ForegroundColor $color

    if ($script:LogReady -and $script:LogFile) {
        Add-Content -LiteralPath $script:LogFile -Value $fileLine -Encoding UTF8 -ErrorAction SilentlyContinue -WhatIf:$false
    }
}

# Renders the canonical end-of-run summary: one colored status line followed by
# an aligned per-target result table. Accepts the aggregate array of result
# objects returned by Invoke-TargetAction (Target/Success/Skipped/Error). This
# is the single formatting helper so every generated CLI prints identical output.
function Write-Summary {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [object[]]$Results
    )

    $results = @($Results | Where-Object { $null -ne $_ })
    $ok      = @($results | Where-Object { $_.Success -and -not $_.Skipped }).Count
    $skipped = @($results | Where-Object { $_.Skipped }).Count
    $failed  = @($results | Where-Object { -not $_.Success }).Count

    $summary      = if ($failed -gt 0) { "FAILED" } elseif ($skipped -gt 0 -and $ok -eq 0) { "SKIPPED" } else { "OK" }
    $colorSummary = if ($failed -gt 0) { 'Red' } elseif ($skipped -gt 0 -and $ok -eq 0) { 'Yellow' } else { 'Green' }

    Write-Host ("  Summary : {0} ok, {1} skipped, {2} failed  ->  {3}" -f $ok, $skipped, $failed, $summary) -ForegroundColor $colorSummary

    $maxLen = 4
    if ($results.Count -gt 0) {
        $maxLen = [Math]::Max(($results | ForEach-Object { $_.Target.Length } | Measure-Object -Maximum).Maximum, 4)
    }
    Write-Host ("  {0,-$($maxLen + 2)} {1,-9} {2,-9} {3}" -f 'Target', 'Result', 'Skipped', 'Error') -ForegroundColor DarkGray
    Write-Host ("  {0}" -f ('-' * ($maxLen + 35))) -ForegroundColor DarkGray

    foreach ($r in $results) {
        if     ($r.Success) { $color = 'Green';  $resultText = 'OK' }
        elseif ($r.Skipped) { $color = 'Yellow'; $resultText = 'SKIPPED' }
        else               { $color = 'Red';    $resultText = 'FAILED' }
        $skippedText = if ($r.Skipped) { 'yes' } else { 'no' }
        $errorText   = if ($r.Error) { $r.Error } else { '' }
        Write-Host ("  {0,-$($maxLen + 2)} {1,-9} {2,-9} {3}" -f $r.Target, $resultText, $skippedText, $errorText) -ForegroundColor $color
    }
}

function Finish-Script {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [int]$ExitCode,
        [Parameter(Mandatory = $true)]
        [string]$Message,
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
        [Parameter(Mandatory = $false)]
        [AllowEmptyString()]
        [string]$Message = "",
        [ValidateSet('Info', 'Warning', 'Error')][string]$Level = 'Info'
    )
    # Visual spacer support: `Write-RemediationLog -Message ""` no-ops cleanly
    # (Lesson 2026-08-30 | Find-IntunePolicyConflict). Same AllowEmptyString
    # + early-return pattern as the canonical Write-Log helper.
    if ([string]::IsNullOrEmpty($Message)) { return }
    # Console/file via canonical Write-Log + structured record for JSON output.
    $mapped = switch ($Level) { 'Warning' { 'WARNING' } 'Error' { 'ERROR' } default { 'INFO' } }
    Write-Log -Message $Message -Level $mapped
    $script:remediationResult.RemediationActions += @{
        Timestamp = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        Level     = $Level
        Message   = $Message
    }
}

# ============================================================================
# PRE-REMEDIATION VALIDATION
# Gate check before any mutation - failures must not touch target state.
# ============================================================================

# Confirms the elevated context required to stop the service and run the uninstaller.
function Test-RemediationPrerequisites {
    try {
        $identity  = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = [Security.Principal.WindowsPrincipal]::new($identity)
        if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
            throw 'Administrator or SYSTEM context is required to remove AnyDesk.'
        }
        $script:remediationResult.PreCheckStatus += 'Elevated execution context confirmed'
        return $true
    }
    catch {
        Write-RemediationLog "Pre-remediation validation error: $($_.Exception.Message)" -Level 'Error'
        return $false
    }
}

# ============================================================================
# REMEDIATION ACTION (per-target pattern)
# Locates and removes AnyDesk using the documented silent CLI switches.
# ============================================================================

# Resolves AnyDesk.exe from ARP uninstall entries, then the standard install paths.
function Find-AnyDeskExecutable {
    [CmdletBinding()]
    param()

    $uninstallRoots = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall',
        'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall'
    )
    foreach ($root in $uninstallRoots) {
        if (-not (Test-Path -LiteralPath $root)) { continue }
        $entries = Get-ChildItem -LiteralPath $root -ErrorAction SilentlyContinue
        foreach ($entry in $entries) {
            $app = Get-ItemProperty -LiteralPath $entry.PSPath -ErrorAction SilentlyContinue
            if ($app.DisplayName -like 'AnyDesk*' -and $app.UninstallString) {
                # The quoted form keeps spaces in custom install paths; otherwise take the first token.
                $quotedPath = [regex]::Match([string]$app.UninstallString, '"([^"]+\.exe)"')
                $candidate = if ($quotedPath.Success) { $quotedPath.Groups[1].Value } else { ([string]$app.UninstallString).Split(' ')[0] }
                if (Test-Path -LiteralPath $candidate -PathType Leaf) { return $candidate }
            }
        }
    }

    $candidatePaths = @()
    if ($env:ProgramFiles) { $candidatePaths += Join-Path -Path $env:ProgramFiles -ChildPath 'AnyDesk\AnyDesk.exe' }
    if (${env:ProgramFiles(x86)}) { $candidatePaths += Join-Path -Path ${env:ProgramFiles(x86)} -ChildPath 'AnyDesk\AnyDesk.exe' }
    if ($env:LOCALAPPDATA) { $candidatePaths += Join-Path -Path $env:LOCALAPPDATA -ChildPath 'AnyDesk\AnyDesk.exe' }
    foreach ($candidate in $candidatePaths) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) { return $candidate }
    }
    return $null
}

# Stops the background service and any running AnyDesk processes before removal.
function Stop-AnyDeskProcess {
    [CmdletBinding()]
    param()
    Get-Process -Name 'AnyDesk' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Stop-Service -Name 'AnyDesk' -Force -ErrorAction SilentlyContinue
}

# Removes installation and user/system data folders left behind by the uninstaller.
function Remove-AnyDeskResidual {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$ExecutablePath
    )

    # These folders hold the device AnyDesk ID and Alias; deletion is permanent.
    $residualPaths = @()
    if ($ExecutablePath) { $residualPaths += Split-Path -Path $ExecutablePath -Parent }
    if ($env:ProgramFiles) { $residualPaths += Join-Path -Path $env:ProgramFiles -ChildPath 'AnyDesk' }
    if (${env:ProgramFiles(x86)}) { $residualPaths += Join-Path -Path ${env:ProgramFiles(x86)} -ChildPath 'AnyDesk' }
    if ($env:LOCALAPPDATA) { $residualPaths += Join-Path -Path $env:LOCALAPPDATA -ChildPath 'AnyDesk' }
    if ($env:APPDATA) { $residualPaths += Join-Path -Path $env:APPDATA -ChildPath 'AnyDesk' }
    if ($env:ProgramData) { $residualPaths += Join-Path -Path $env:ProgramData -ChildPath 'AnyDesk' }

    foreach ($residualPath in ($residualPaths | Sort-Object -Unique)) {
        if (Test-Path -LiteralPath $residualPath) {
            Remove-Item -LiteralPath $residualPath -Recurse -Force -ErrorAction SilentlyContinue
            Write-RemediationLog "Removed residual path: $residualPath" -Level 'Info'
        }
        else {
            Write-Log -Message "No residual path present: $residualPath" -Level 'DEBUG'
        }
    }
}

# Applies the fix to one target and returns a structured success/failure object.
function Invoke-FixTarget {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$TargetName,
        [Parameter(Mandatory = $true)][scriptblock]$Fix
    )
    # Returns $true when the fix was applied for this target.
    try {
        & $Fix
        return $true
    }
    catch {
        $script:failedCount++
        Write-RemediationLog "Target FAILED: $TargetName - $($_.Exception.Message)" -Level 'Warning'
        return $false
    }
}

# ============================================================================
# POST-REMEDIATION VERIFICATION
# Re-checks the exact conditions the detection script reports on.
# ============================================================================

# Returns $true only when every AnyDesk artifact the detector checks is absent.
function Test-FixApplied {
    [CmdletBinding()]
    param()

    if (Get-Process -Name 'AnyDesk' -ErrorAction SilentlyContinue) { return $false }
    if (Get-Service -Name 'AnyDesk' -ErrorAction SilentlyContinue) { return $false }

    $uninstallRoots = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall',
        'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall'
    )
    foreach ($root in $uninstallRoots) {
        if (-not (Test-Path -LiteralPath $root)) { continue }
        $entries = Get-ChildItem -LiteralPath $root -ErrorAction SilentlyContinue
        foreach ($entry in $entries) {
            $app = Get-ItemProperty -LiteralPath $entry.PSPath -ErrorAction SilentlyContinue
            if ($app.DisplayName -like 'AnyDesk*') { return $false }
        }
    }

    $candidatePaths = @()
    if ($env:ProgramFiles) { $candidatePaths += Join-Path -Path $env:ProgramFiles -ChildPath 'AnyDesk\AnyDesk.exe' }
    if (${env:ProgramFiles(x86)}) { $candidatePaths += Join-Path -Path ${env:ProgramFiles(x86)} -ChildPath 'AnyDesk\AnyDesk.exe' }
    if ($env:LOCALAPPDATA) { $candidatePaths += Join-Path -Path $env:LOCALAPPDATA -ChildPath 'AnyDesk\AnyDesk.exe' }
    if ($env:APPDATA) { $candidatePaths += Join-Path -Path $env:APPDATA -ChildPath 'AnyDesk' }
    if ($env:ProgramData) { $candidatePaths += Join-Path -Path $env:ProgramData -ChildPath 'AnyDesk' }
    foreach ($candidate in $candidatePaths) {
        if (Test-Path -LiteralPath $candidate) { return $false }
    }
    return $true
}

# ============================================================================
# MAIN (init -> pre-checks -> fix -> post-verify -> exit 0 / 1 / 2)
# Every terminal path uses Finish-Script so console and file logs stay aligned.
# ============================================================================

try {
    $null = Initialize-Log -SolutionName $SolutionName -ScriptMode $ScriptMode -Type 'Intune'
    Write-Banner
    if ($script:LogReady) {
        Write-Log -Message "Log file ready: $($script:LogFile)" -Level 'DEBUG'
    }
    Write-RemediationLog 'Starting remediation...' -Level 'Info'

    # --- Pre-checks ---
    Write-RemediationLog 'Performing pre-remediation checks...' -Level 'Info'
    if (-not (Test-RemediationPrerequisites)) {
        throw 'Pre-remediation validation failed - aborting before any change.'
    }

    # --- Fix (per-target failure tracking) ---
    $script:failedCount = 0
    $targetCount        = 0

    Write-RemediationLog 'Executing remediation actions...' -Level 'Info'
    $targetCount++
    $fixApplied = Invoke-FixTarget -TargetName 'AnyDesk installation' -Fix {
        $anyDeskPath = Find-AnyDeskExecutable
        Stop-AnyDeskProcess
        if ($anyDeskPath) {
            # --remove is the documented silent switch; --uninstall would open a GUI wizard.
            Start-Process -FilePath $anyDeskPath -ArgumentList @('--silent', '--remove') -Wait -ErrorAction Stop
            Write-RemediationLog "Silent removal completed for $anyDeskPath" -Level 'Info'
        }
        else {
            Write-RemediationLog 'No executable found; removing residual folders only' -Level 'Info'
        }
        Remove-AnyDeskResidual -ExecutablePath $anyDeskPath
    }

    # --- Verify ---
    Write-RemediationLog 'Performing post-remediation verification...' -Level 'Info'
    $verificationPassed = Test-FixApplied

    if ($targetCount -gt 0 -and $script:failedCount -ge $targetCount) {
        $verificationPassed = $false
    }

    # --- Report ---
    if ($verificationPassed -and $fixApplied) {
        $script:remediationResult.Status = "Success"
        $script:remediationResult.PostCheckStatus += "Verification passed after remediation"

        Write-Output "Remediation completed successfully"
        Write-Output "Targets processed: $targetCount (failed: $script:failedCount)"
        Write-Output ($remediationResult | ConvertTo-Json -Depth 6 -Compress)

        Finish-Script -ExitCode 0 -Message "Remediation completed successfully" -Level 'SUCCESS'
    }
    else {
        $script:remediationResult.Status = "Failed"
        $script:remediationResult.PostCheckStatus += "Verification failed after remediation"
        Write-Output "Remediation finished but verification failed"
        Write-Output ($remediationResult | ConvertTo-Json -Depth 6 -Compress)
        Finish-Script -ExitCode 1 -Message "Post-remediation verification failed" -Level 'ERROR'
    }
}
catch {
    $script:remediationResult.Status = "Error"
    $script:remediationResult.Error = @{
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
