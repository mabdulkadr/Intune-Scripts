<#
.TITLE
    Detection - Microsoft Store Not Pinned To Taskbar

.SYNOPSIS
    Verifies that the Microsoft Store app does not expose an Unpin-from-taskbar action.

.DESCRIPTION
    Opens the AppsFolder shell namespace through Shell.Application, locates the
    Microsoft Store app item by its exact display name, enumerates its shell
    verbs, and treats the presence of an "Unpin from taskbar" verb as evidence
    that the Store icon is currently pinned to the taskbar. This script NEVER
    modifies the system.

    Exit contract:
    Exit 0 = compliant (no remediation needed)
    Exit 1 = non-compliant (Intune runs the paired remediation)
    Exit 2 = script error (Intune must NOT treat a crash as non-compliance)

.TAGS
    Remediation,Detection,Taskbar,MicrosoftStore

.REMEDIATIONTYPE
    Detection

.PAIRSCRIPT
    remediate-Unpin-MicrosoftStore.ps1

.PLATFORM
    Windows

.MINROLE
    Intune Service Administrator

.PERMISSIONS
    None (local SYSTEM context) - enumerates shell verbs in the AppsFolder namespace.

.AUTHOR
    Mohammad Abdelkader Omar

.VERSION
    2.0.0

.CHANGELOG
    2.0.0 (2026-08-26)
    - Migrated to Enterprise Standards canonical structure (header, logging, exit contract)
    - Detection errors now exit 2 instead of 1 so Intune never treats crashes as non-compliance
    - Verb matching limited to English taskbar verbs for canonical English-only content
    1.2 (2025)
    - Logging and banner improvements
    1.0.0
    - Initial release

.LASTUPDATE
    2026-08-26

.EXAMPLE
    .\detect-Unpin-MicrosoftStore.ps1
    Returns exit 0 when compliant; exit 1 when the paired remediation must run.

.EXAMPLE
    .\detect-Unpin-MicrosoftStore.ps1
    Returns exit 2 when an unexpected error prevents evaluation.

.NOTES
    - The shell namespace reflects the interactive user's taskbar; run against user context when possible.
    - Keep detection under 30 seconds: one shell namespace enumeration only.
    - Read-only by definition; detection never invokes verbs.
    - Logs: <SystemDrive>\IntuneLogs\Unpin-MicrosoftStore\Unpin-MicrosoftStore-Detection.txt
#>

#Requires -Version 5.1

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# ============================================================================
# CONFIGURATION - solution identity and compliance target values.
# ============================================================================

$SolutionName = 'Unpin-MicrosoftStore'
$ScriptMode   = 'Detection'

$AppsFolderNamespace = 'shell:::{4234d49b-0245-4df3-b780-3893943456e1}'
$TargetAppName       = 'Microsoft Store'

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

# Resolves the Microsoft Store item inside the AppsFolder shell namespace.
function Get-StoreShellItem {
    $shell = New-Object -ComObject Shell.Application
    $folder = $shell.NameSpace($AppsFolderNamespace)
    if (-not $folder) {
        throw 'Unable to open the AppsFolder shell namespace.'
    }

    return $folder.Items() | Where-Object { $_.Name -eq $TargetAppName } | Select-Object -First 1
}

# Returns the first verb whose cleaned name matches the English unpin action.
function Get-UnpinVerb {
    param(
        [Parameter(Mandatory = $true)]
        $ShellItem
    )

    $verbs = @($ShellItem.Verbs())
    foreach ($verb in $verbs) {
        $name = ($verb.Name -replace '&', '').Trim()
        if ($name -match 'Unpin.+taskbar') {
            return $verb
        }
    }

    return $null
}

# Returns a reason string per unmet condition; empty output = compliant.
function Test-ComplianceState {
    $reasons = [System.Collections.Generic.List[string]]::new()

    try {
        Write-Log -Message 'Resolving Microsoft Store shell item' -Level 'DEBUG'

        $storeItem = Get-StoreShellItem
        if (-not $storeItem) {
            # No Store item means nothing can be pinned - treat as compliant.
            Write-Log -Message 'Microsoft Store shell item was not found' -Level 'DEBUG'
            return @($reasons)
        }

        $unpinVerb = Get-UnpinVerb -ShellItem $storeItem
        if ($unpinVerb) {
            $reasons.Add("Microsoft Store appears pinned - taskbar verb available: $(($unpinVerb.Name -replace '&', '').Trim())")
        }
        else {
            Write-Log -Message 'Microsoft Store does not expose an unpin taskbar action' -Level 'DEBUG'
        }
    }
    catch [System.Runtime.InteropServices.COMException] {
        throw "Shell automation failed: $($_.Exception.Message)"
    }
    catch {
        throw "Failed to inspect the taskbar pin state: $($_.Exception.Message)"
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
        Finish-Script -ExitCode 0 -Message "Compliant - Microsoft Store is not pinned to the taskbar" -Level 'SUCCESS'
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
