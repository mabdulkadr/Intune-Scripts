<#
.TITLE
    Detection - Winget Upgrades Pending

.SYNOPSIS
    Verifies whether the Winget client reports pending package upgrades.

.DESCRIPTION
    Resolves the installed Winget client (App Installer package, WindowsApps
    fallback paths, PATH, then the per-user app execution shim), runs
    `winget upgrade --accept-source-agreements`, and evaluates the returned
    package rows to determine whether updates are available. When Winget
    itself cannot be resolved the legacy behavior is preserved and the device
    is reported compliant (no upgrades can be evaluated). This script NEVER
    modifies the system.

    Exit contract:
    Exit 0 = compliant (no remediation needed)
    Exit 1 = non-compliant (Intune runs the paired remediation)
    Exit 2 = script error (Intune must NOT treat a crash as non-compliance)

.TAGS
    Remediation,Detection,Winget,Updates

.REMEDIATIONTYPE
    Detection

.PAIRSCRIPT
    remediate-Update-WingetPackages.ps1

.PLATFORM
    Windows

.MINROLE
    Intune Service Administrator

.PERMISSIONS
    None (local SYSTEM context) - runs read-only Winget and AppX queries.

.AUTHOR
    Mohammad Abdelkader Omar

.VERSION
    2.1.0

.CHANGELOG
    2.1.0 (2026-08-26)
    - Merged enterprise exclusion handling: --disable-interactivity, synchronized $ExcludedIds filter with pin lifecycle in the paired remediate
    2.0.0 (2026-08-26)
    - Migrated to Enterprise Standards canonical structure (header, logging, exit contract)
    - Detection errors now exit 2 instead of 1 so Intune never treats crashes as non-compliance
    1.2 (2025)
    - Logging and banner improvements
    1.0.0
    - Initial release

.LASTUPDATE
    2026-08-26

.EXAMPLE
    .\detect-Update-WingetPackages.ps1
    Returns exit 0 when no upgrades are pending; exit 1 when remediation must run.

.EXAMPLE
    .\detect-Update-WingetPackages.ps1
    Returns exit 2 when an unexpected error prevents evaluation.

.NOTES
    - Requires the Winget client (App Installer) on the device.
    - `winget upgrade` performs network calls to configured sources but changes nothing.
    - Read-only by definition; detection never upgrades packages.
    - Logs: <SystemDrive>\IntuneLogs\Update-WingetPackages\Update-WingetPackages-Detection.txt
#>

#Requires -Version 5.1

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# ============================================================================
# CONFIGURATION - solution identity and compliance target values.
# ============================================================================

$SolutionName = 'Update-WingetPackages'
$ScriptMode   = 'Detection'

# Winget package IDs to ignore (managed elsewhere, e.g. by Intune apps or auto-updaters).
$script:ExcludedIds = @(
    "Microsoft.Office",
    "Microsoft.Teams"
)

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
        [AllowEmptyString()]
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
        [AllowEmptyString()]
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

# ============================================================================
# DETECTION LOGIC
# Return a list of reason strings so operators see every failure at once.
# Empty list = compliant. Never modify the system here.
# ============================================================================

# Resolves the Winget executable from the App Installer package, WindowsApps
# fallback patterns, PATH, or the per-user app execution shim.
function Resolve-WingetExecutable {
    $appInstallerPackage = Get-AppxPackage -Name 'Microsoft.DesktopAppInstaller' -ErrorAction SilentlyContinue |
        Sort-Object -Property Version -Descending |
        Select-Object -First 1

    if ($appInstallerPackage -and $appInstallerPackage.InstallLocation) {
        foreach ($fileName in 'winget.exe', 'AppInstallerCLI.exe') {
            $packageExecutable = Join-Path $appInstallerPackage.InstallLocation $fileName
            if (Test-Path -Path $packageExecutable) {
                return $packageExecutable
            }
        }
    }

    $patterns = @(
        (Join-Path $env:ProgramFiles 'WindowsApps\Microsoft.DesktopAppInstaller_*_x64__8wekyb3d8bbwe\winget.exe'),
        (Join-Path $env:ProgramFiles 'WindowsApps\Microsoft.DesktopAppInstaller_*_x64__8wekyb3d8bbwe\AppInstallerCLI.exe')
    )

    foreach ($pattern in $patterns) {
        $resolvedPath = Resolve-Path -Path $pattern -ErrorAction SilentlyContinue |
            Sort-Object -Property Path -Descending |
            Select-Object -First 1

        if ($resolvedPath) {
            return $resolvedPath.Path
        }
    }

    $command = Get-Command -Name 'winget.exe' -ErrorAction SilentlyContinue
    if ($command) {
        return $(if ($command.Source) { $command.Source } else { $command.Name })
    }

    $shimPath = Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps\winget.exe'
    if (Test-Path -Path $shimPath) {
        return 'winget.exe'
    }

    return $null
}

# Runs `winget upgrade` and classifies the returned rows into a snapshot object.
function Get-WingetUpgradeSnapshot {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ExecutablePath
    )

    $rawLines = & $ExecutablePath upgrade --accept-source-agreements --disable-interactivity 2>&1 | ForEach-Object { [string]$_ }
    $cleanLines = $rawLines | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    $packageLines = $cleanLines | Where-Object {
        $_ -match '^\S+\s+\S+\s+\S+\s+\S+' -and
        $_ -notmatch '^(Name|---|\d+\s+upgrades?\s+available|The following packages|No installed package|No newer package)'
    }

    # Filter out apps whose package IDs are on the exclusion list (managed elsewhere).
    if ($script:ExcludedIds -and $script:ExcludedIds.Count -gt 0) {
        $packageLines = @($packageLines | Where-Object {
            $packageId = ($_ -split '\s+' | Where-Object { $_ -match '^[\w-]+(\.[\w-]+)+$' } | Select-Object -First 1)
            $packageId -and ($script:ExcludedIds -notcontains $packageId)
        })
    } else {
        $packageLines = @($packageLines)
    }

    [pscustomobject]@{
        RawLines       = $cleanLines
        PackageLines   = $packageLines
        UpgradeCount   = @($packageLines).Count
        HasNoUpgrades  = ($cleanLines -match 'No newer package versions are available from the configured sources\.|No available upgrade found\.|No installed package found matching input criteria\.').Count -gt 0
    }
}

# Returns a reason string per unmet condition; empty output = compliant.
function Test-ComplianceState {
    $reasons = [System.Collections.Generic.List[string]]::new()

    try {
        $wingetPath = Resolve-WingetExecutable

        if (-not $wingetPath) {
            # Preserve legacy intent: without Winget there is nothing to evaluate.
            Write-Log -Message 'Winget was not found - no pending upgrades can be evaluated' -Level 'DEBUG'
            return @($reasons)
        }

        Write-Log -Message "Using Winget executable: $wingetPath" -Level 'DEBUG'
        $snapshot = Get-WingetUpgradeSnapshot -ExecutablePath $wingetPath

        if (-not $snapshot.HasNoUpgrades -and $snapshot.UpgradeCount -gt 0) {
            $reasons.Add("Winget reports $($snapshot.UpgradeCount) pending upgrade(s)")
            foreach ($packageLine in $snapshot.PackageLines) {
                $reasons.Add("Pending upgrade: $($packageLine.Trim())")
            }
        }
        else {
            Write-Log -Message 'No Winget upgrades detected' -Level 'DEBUG'
        }
    }
    catch {
        throw "Failed to evaluate pending Winget upgrades: $($_.Exception.Message)"
    }

    return @($reasons)
}

# ============================================================================
# MAIN
# ============================================================================
# Flow: init -> banner -> compliance checks -> exit 0 compliant / 1 non-compliant / 2 error.

try {
    $null = Initialize-Log -SolutionName $SolutionName -ScriptMode $ScriptMode -Type 'Intune'
    Write-Banner
    if ($script:LogReady) {
        Write-Log -Message "Log file ready: $($script:LogFile)" -Level 'DEBUG'
    }
    Write-Log -Message "Detection started" -Level 'INFO'

    $reasons = Test-ComplianceState

    if ($reasons.Count -eq 0) {
        Finish-Script -ExitCode 0 -Message "Compliant - no Winget upgrades are pending" -Level 'SUCCESS'
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
