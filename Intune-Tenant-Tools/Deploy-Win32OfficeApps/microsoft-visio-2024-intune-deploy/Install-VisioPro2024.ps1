<#
.TITLE
    Install-VisioPro2024

.SYNOPSIS
    Silent installer for Microsoft Visio Professional 2024 (volume) via the Office Deployment Tool.

.DESCRIPTION
    PowerShell wrapper for `setup.exe /configure Install-VisioPro2024-<arch>-<lang>.xml` designed to run
    under an Intune Win32 app assignment (SYSTEM context) or an elevated prompt.
    - Anchors every path to the script folder (dot-source safe, $PSScriptRoot fallback).
    - Detects the installed Office Click-to-Run architecture and selects the matching Visio
      configuration (x64 / x86); overridable with -Architecture. Defaults to x64 when no Office
      is present.
    - Installs in the OS language (MatchOS) via Install-VisioPro2024-<arch>.xml; one config per architecture.
    - Refuses to run without elevation and fails fast when bundle files are missing.
    - Invokes ODT synchronously and forwards its real exit code to Intune (0 = success).
    - Writes a dedicated transcript to <SystemDrive>\IntuneLogs\VisioPro2024\.

.TAGS
    Intune,Win32App,Office,Visio,Deployment,Install

.PLATFORM
    Windows 10, Windows 11

.PERMISSIONS
    None (local SYSTEM context) - installs Click-to-Run product locally; no Graph calls.

.AUTHOR
    Mohammad Abdelkader Omar | GitHub @mabdulkadr | momar.tech

.VERSION
    1.6.0

.CHANGELOG
    1.6.0 (2026-09-17) - Consolidated to one config per architecture
                          (Install-VisioPro2024-x64.xml / -x86.xml) with MatchOS
                          language; removed the -Language parameter.
    1.5.0 (2026-09-17) - Added -Language Bilingual (x64 en-us + ar-sa in one install);
                          hardened all XML configs (MigrateArch on x64, pinned Updates
                          channel, ODT Logging, AllowCdnFallback).
    1.4.0 (2026-09-16) - Added -Language Auto (default) that detects the OS UI culture
                         via InstalledUICulture and selects English or Arabic accordingly.
                         Explicit -Language English|Arabic overrides still available.
    1.3.0 (2026-09-16) - Removed Bilingual language variant. -Language now accepts
                         English (default) or Arabic; deleted the *-Bilingual.xml configs.
    1.2.0 (2026-09-16) - Migrated from VisioPro2019Volume to VisioPro2024Volume
                         (PerpetualVL2024 channel); renamed XML configs to
                         Install-VisioPro2024-<arch>-<lang>.xml; logs to
                         <SystemDrive>\IntuneLogs\VisioPro2024\.
    1.1.0 (2026-09-16) - Canonical rewrite: correct ProductReleaseIds (VisioPro2019Volume),
                         auto-detect architecture, -Language parameter (Bilingual/English/Arabic),
                         and canonical logging to <SystemDrive>\IntuneLogs\VisioPro2019\.
    1.0.0 (2023)        - Original architecture-detection package.

.LASTUPDATE
    2026-09-17

.PARAMETER Architecture
    Override the detected architecture: x64 or x86. Defaults to '' (auto-detect from the installed
    Office Click-to-Run Platform; falls back to x64 when no Office product is present).

.PARAMETER ConfigurationPath
    Path to Install-VisioPro2024-<arch>.xml. Defaults to the file beside this script.

.PARAMETER SetupPath
    Path to setup.exe (Office Deployment Tool). Defaults to the file beside this script.

.EXAMPLE
    powershell.exe -ExecutionPolicy Bypass -NoProfile -File .\Install-VisioPro2024.ps1
    Auto-detects architecture and installs Visio Professional 2024 in the OS language (MatchOS).

.EXAMPLE
    powershell.exe -ExecutionPolicy Bypass -NoProfile -File .\Install-VisioPro2024.ps1 -Architecture x86
    Forces the 32-bit config.

.NOTES
    - Intune Win32 app install command; runs as System.
    - Product installed: VisioPro2024Volume (perpetual volume, KMS activation).
      Replace the placeholder PIDKEY in the XML with your organization's KMS GVLK.
    - Returns the Office Deployment Tool exit code (0 = success).
    - The packaged .intunewin files are legacy snapshots built before this fix - repackage
      this folder with IntuneWinAppUtil.exe before pushing to production.
#>

#Requires -Version 5.1

[CmdletBinding()]
param(
    [ValidateSet('', 'x64', 'x86')]
    [string]$Architecture = '',
    [string]$ConfigurationPath = '',
    [string]$SetupPath = ''
)

$ErrorActionPreference = 'Stop'
$SolutionName = 'VisioPro2024'
$ScriptMode   = 'install'

# --- Script-location anchoring (Law 12) --------------------------------------
# Resolves the script folder even when dot-sourced (leaving $PSScriptRoot empty).
$scriptBase = if ($PSScriptRoot) { $PSScriptRoot }
elseif ($PSCommandPath) { Split-Path -Parent $PSCommandPath }
elseif ($MyInvocation.MyCommand.Path) { Split-Path -Parent $MyInvocation.MyCommand.Path }
else { (Get-Location).Path }

if (-not $SetupPath) { $SetupPath = Join-Path $scriptBase 'setup.exe' }

# --- Logging (CLI Configuration) ---------------------------------------------
# Canonical CLI logging helpers, copied verbatim (self-contained: no dot-sourcing).
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
    param()

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
    # sections vertically. Mandatory binding treats an empty string as a missing
    # value, so the canonical helper MUST early-return on empty (Pitfall 30).
    if ([string]::IsNullOrEmpty($Message)) { return }

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

# --- Elevation probe ---------------------------------------------------------
# Detects the current process token; Intune SYSTEM context always passes.
function Test-IsElevated {
    $identity   = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $principal  = New-Object System.Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Resolves the installed Office Click-to-Run platform (x64/x86); $null when absent.
# -ErrorAction SilentlyContinue overrides the Stop preference: a missing key is a
# normal condition (no Office product present), not an error path.
function Get-OfficeArchitecture {
    $platform = (Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Office\ClickToRun\Configuration' -ErrorAction SilentlyContinue).Platform
    if ($platform) { return ([string]$platform).ToLowerInvariant() }
    return $null
}

# --- Main --------------------------------------------------------------------
$null = Initialize-Log -SolutionName $SolutionName -ScriptMode $ScriptMode -Type 'Intune'
Write-Banner

if (-not (Test-IsElevated)) {
    Write-Log -Message 'Elevation required - run as Administrator or via Intune (SYSTEM).' -Level 'ERROR'
    exit 1
}

# Resolve architecture: explicit override -> detected Office platform -> x64 default.
if ($Architecture) {
    $arch = $Architecture
    Write-Log -Message "Architecture override: $arch" -Level 'INFO'
} elseif ($detectedArch = Get-OfficeArchitecture) {
    $arch = $detectedArch
    Write-Log -Message "Detected existing Office platform: $arch" -Level 'INFO'
} else {
    $arch = 'x64'
    Write-Log -Message 'No Office Click-to-Run detected - defaulting to x64.' -Level 'INFO'
}

# Language is MatchOS inside the XML itself: one config per architecture.
Write-Log -Message 'Language: MatchOS (resolved by ODT from the OS language).' -Level 'INFO'

if (-not $ConfigurationPath) {
    $ConfigurationPath = Join-Path $scriptBase "Install-VisioPro2024-$arch.xml"
    Write-Log -Message "Configuration file resolved: $ConfigurationPath" -Level 'DEBUG'
}

if (-not (Test-Path -LiteralPath $SetupPath)) {
    Write-Log -Message "Office Deployment Tool not found: $SetupPath" -Level 'ERROR'
    exit 1
}
if (-not (Test-Path -LiteralPath $ConfigurationPath)) {
    Write-Log -Message "Configuration file not found: $ConfigurationPath (verify Install-VisioPro2024-$arch.xml is packaged beside this script)" -Level 'ERROR'
    exit 1
}

Write-Log -Message "Installing Visio Professional 2024 ($arch, MatchOS) with: $ConfigurationPath" -Level 'INFO'

$exitCode = 1
try {
    & $SetupPath /configure $ConfigurationPath
    $exitCode = $LASTEXITCODE
    if ($exitCode -eq 0) {
        Write-Log -Message 'Visio Professional 2024 installed successfully.' -Level 'SUCCESS'
    } else {
        Write-Log -Message "setup.exe exited with code $exitCode - see %temp% for ODT logs." -Level 'ERROR'
    }
}
catch {
    Write-Log -Message "Install failed: $($_.Exception.Message)" -Level 'ERROR'
    $exitCode = 2
}

exit $exitCode