<#
.TITLE
    Detection - AnyDesk Presence and Residual Data

.SYNOPSIS
    Reports non-compliant when AnyDesk or its residual data is still present.

.DESCRIPTION
    Read-only detection for the UninstallAnyDesk Intune remediation pair.
    Checks the running AnyDesk process, the AnyDesk service, registry uninstall
    entries in HKLM (32-bit and 64-bit) and HKCU, known executable locations,
    and the residual AnyDesk folders under AppData and ProgramData. This script
    NEVER modifies the system; it only writes log entries and returns reasons.

    Exit contract:
    Exit 0 = compliant (AnyDesk and its data are absent)
    Exit 1 = non-compliant (Intune runs the paired remediation)
    Exit 2 = script error (Intune must NOT treat a crash as non-compliance)

.TAGS
    Remediation,Detection

.REMEDIATIONTYPE
    Detection

.PAIRSCRIPT
    remediate-Uninstall-AnyDesk.ps1

.PLATFORM
    Windows

.MINROLE
    Intune Service Administrator

.PERMISSIONS
    None (local SYSTEM context) - reads processes, services, registry uninstall entries and paths.

.AUTHOR
    Mohammad Abdelkader Omar

.VERSION
    1.0.0

.CHANGELOG
    1.0.0 (2026-11-22)
    - Initial release: read-only AnyDesk presence and residual data detection.

.LASTUPDATE
    2026-11-22

.EXAMPLE
    .\detect-Uninstall-AnyDesk.ps1
    Returns exit 0 when AnyDesk is absent; exit 1 when remediation must run.

.EXAMPLE
    .\detect-Uninstall-AnyDesk.ps1
    Returns exit 2 when an unexpected error prevents evaluation.

.NOTES
    - Runs in SYSTEM context via Intune Proactive Remediations.
    - Read-only and idempotent; no process, service, file or registry change.
    - Detection stays under 30 seconds: metadata reads only.
    - Logs: <SystemDrive>\IntuneLogs\UninstallAnyDesk\detect-Uninstall-AnyDesk.txt
#>

#Requires -Version 5.1

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# ============================================================================
# CONFIGURATION + CANONICAL CLI LOGGING (verbatim copy of scripts/Write-Log.ps1)
# Inlined so each half of the pair is self-contained on the target machine.
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

$SolutionName = 'UninstallAnyDesk'
$ScriptMode   = 'Detection'

# ============================================================================
# DETECTION LOGIC (read-only - never modify the system in this half of the pair)
# Returns one reason string per unmet condition; an empty list means compliant.
# ============================================================================

# Checks all AnyDesk artifacts and returns a reason string for each one found.
function Test-ComplianceState {
    [CmdletBinding()]
    param()

    $reasons = [System.Collections.Generic.List[string]]::new()

    if (Get-Process -Name 'AnyDesk' -ErrorAction SilentlyContinue) {
        $reasons.Add('AnyDesk process is running')
    }
    if (Get-Service -Name 'AnyDesk' -ErrorAction SilentlyContinue) {
        $reasons.Add('AnyDesk service is present')
    }

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
            if ($app.DisplayName -like 'AnyDesk*') {
                $reasons.Add(("AnyDesk uninstall entry found: {0}" -f $app.DisplayName))
            }
        }
    }

    $candidatePaths = @()
    if ($env:ProgramFiles) { $candidatePaths += Join-Path -Path $env:ProgramFiles -ChildPath 'AnyDesk\AnyDesk.exe' }
    if (${env:ProgramFiles(x86)}) { $candidatePaths += Join-Path -Path ${env:ProgramFiles(x86)} -ChildPath 'AnyDesk\AnyDesk.exe' }
    if ($env:LOCALAPPDATA) { $candidatePaths += Join-Path -Path $env:LOCALAPPDATA -ChildPath 'AnyDesk\AnyDesk.exe' }
    foreach ($candidate in $candidatePaths) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            $reasons.Add(("AnyDesk executable found: {0}" -f $candidate))
        }
    }

    $residualPaths = @()
    if ($env:APPDATA) { $residualPaths += Join-Path -Path $env:APPDATA -ChildPath 'AnyDesk' }
    if ($env:ProgramData) { $residualPaths += Join-Path -Path $env:ProgramData -ChildPath 'AnyDesk' }
    foreach ($residual in $residualPaths) {
        if (Test-Path -LiteralPath $residual) {
            $reasons.Add(("Residual AnyDesk folder found: {0}" -f $residual))
        }
    }

    return @($reasons)
}

# ============================================================================
# MAIN (init log -> banner -> read-only checks -> exit 0 / 1 / 2)
# Every terminal path uses Finish-Script so console and file logs stay aligned.
# ============================================================================

try {
    $null = Initialize-Log -SolutionName $SolutionName -ScriptMode $ScriptMode -Type 'Intune'
    Write-Banner
    if ($script:LogReady) {
        Write-Log -Message "Log file ready: $($script:LogFile)" -Level 'DEBUG'
    }
    Write-Log -Message 'Detection started' -Level 'INFO'

    $reasons = Test-ComplianceState

    if ($reasons.Count -eq 0) {
        Finish-Script -ExitCode 0 -Message 'Compliant - AnyDesk and its data are absent' -Level 'SUCCESS'
    }

    foreach ($reason in $reasons) {
        Write-Output $reason
        Write-Log -Message "Non-compliant: $reason" -Level 'WARNING'
    }
    Finish-Script -ExitCode 1 -Message "Non-compliant - $($reasons.Count) condition(s) found" -Level 'WARNING'
}
catch {
    Write-Output "Detection error: $($_.Exception.Message)"
    Finish-Script -ExitCode 2 -Message "Detection script error: $($_.Exception.Message)" -Level 'ERROR'
}
