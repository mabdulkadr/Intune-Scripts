<#
.TITLE
    Detection - Lenovo Secure Boot Enabled

.SYNOPSIS
    Verifies that Secure Boot is enabled via Lenovo WMI BIOS interface.

.DESCRIPTION
    Evaluates Lenovo Secure Boot state by querying root\WMI Lenovo_BiosSetting where
    CurrentSetting matches SecureBoot. On non-Lenovo hardware the script exits 0
    (not applicable) so the remediation does not run on Dell/HP. This script NEVER
    modifies the system.

    Exit contract:
    Exit 0 = compliant or not applicable (no remediation)
    Exit 1 = non-compliant (Lenovo device with Secure Boot disabled)
    Exit 2 = script error

.TAGS
    Remediation,Detection,SecureBoot,Lenovo,BIOS,UEFI

.REMEDIATIONTYPE
    Detection

.PAIRSCRIPT
    remediate-Enable-SecureBoot-Lenovo.ps1

.PLATFORM
    Windows

.MINROLE
    Intune Service Administrator

.PERMISSIONS
    None (local SYSTEM context) - reads WMI BIOS setting.

.AUTHOR
    Mohammad Abdelkader Omar

.VERSION
    1.0.0

.CHANGELOG
    1.0.0 (2026-08-31)
    - Initial release; WMI detection for Lenovo SecureBoot with non-Lenovo bypass.

.LASTUPDATE
    2026-08-31

.EXAMPLE
    .\detect-Enable-SecureBoot-Lenovo.ps1
    Returns exit 0 when compliant or not Lenovo; exit 1 when remediation needed.

.NOTES
    - Runs in SYSTEM context via Intune Remediations.
    - Assign with a filter: Device manufacturer = Lenovo.
    - Logs: <SystemDrive>\IntuneLogs\Enable-SecureBoot-Lenovo\Enable-SecureBoot-Lenovo-Detection.txt
#>

#Requires -Version 5.1

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$SolutionName = 'Enable-SecureBoot-Lenovo'
$ScriptMode   = 'Detection'

$script:SystemDrive = if ($env:SystemDrive) { $env:SystemDrive.TrimEnd('\') } else {
    [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\')
}
$script:LogRoot  = $null
$script:LogFile  = $null
$script:LogReady = $false

function Initialize-Log {
    [CmdletBinding()]
    param([string]$SolutionName = 'EnterpriseAdminTool',[string]$ScriptMode = 'run',[ValidateSet('Intune','General')][string]$Type = 'General')
    try {
        if ($Type -eq 'Intune') {
            $script:LogRoot = Join-Path $script:SystemDrive "IntuneLogs\$SolutionName"
            $script:LogFile = Join-Path $script:LogRoot "$SolutionName-$ScriptMode.txt"
        } else {
            $script:LogRoot = Join-Path $env:ProgramData "$SolutionName\Logs"
            $script:LogFile = Join-Path $script:LogRoot "$SolutionName`_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
        }
        if (-not (Test-Path -LiteralPath $script:LogRoot)) { $null = [System.IO.Directory]::CreateDirectory($script:LogRoot) }
        if (-not (Test-Path -LiteralPath $script:LogFile)) { $null = [System.IO.File]::Create($script:LogFile).Dispose() }
        $script:LogReady = $true; return $true
    } catch { Write-Host "Log initialization failed: $($_.Exception.Message)" -ForegroundColor Red; $script:LogReady = $false; return $false }
}
function Write-Banner {
    [CmdletBinding()][Alias('Show-Banner')] param()
    $title = '{0} | {1}' -f $SolutionName, $ScriptMode; $bannerLine = '=' * 78; $lines = @('', $bannerLine, $title, $bannerLine)
    foreach ($line in $lines) { if ($line -eq $title) { Write-Host $line -ForegroundColor White } else { Write-Host $line -ForegroundColor DarkGray }
        if ($script:LogReady -and $script:LogFile) { Add-Content -LiteralPath $script:LogFile -Value $line -Encoding UTF8 -ErrorAction SilentlyContinue -WhatIf:$false } }
}
function Write-Log {
    [CmdletBinding()] param([Parameter(Mandatory = $false)][AllowEmptyString()][string]$Message = "",[ValidateSet("INFO","SUCCESS","WARNING","ERROR","DEBUG")][string]$Level = "INFO")
    if ([string]::IsNullOrEmpty($Message)) { return }; $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"; $logLine = "[$timestamp] [$Level] $Message"
    $color = switch ($Level) { "DEBUG" { "DarkGray" } "INFO" { "Cyan" } "SUCCESS" { "Green" } "WARNING" { "Yellow" } "ERROR" { "Red" } }
    Write-Host $logLine -ForegroundColor $color
    if ($script:LogReady -and $script:LogFile) { Add-Content -LiteralPath $script:LogFile -Value $logLine -Encoding UTF8 -ErrorAction SilentlyContinue -WhatIf:$false }
}
function Finish-Script {
    [CmdletBinding()] param([Parameter(Mandatory = $true)][int]$ExitCode,[Parameter(Mandatory = $false)][AllowEmptyString()][string]$Message = "",[ValidateSet("INFO","SUCCESS","WARNING","ERROR","DEBUG")][string]$Level = "INFO",[switch]$NoExit)
    Write-Log -Message $Message -Level $Level; if (-not $NoExit) { exit $ExitCode }
}

function Test-IsLenovoDevice {
    try {
        $cs = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop
        return ($cs.Manufacturer -match 'Lenovo')
    } catch { return $false }
}

function Test-ComplianceState {
    $reasons = [System.Collections.Generic.List[string]]::new()
    try {
        if (-not (Test-IsLenovoDevice)) {
            Write-Log -Message "Not a Lenovo device - not applicable, exiting compliant" -Level 'DEBUG'
            return @($reasons)
        }
        Write-Log -Message "Lenovo device detected" -Level 'DEBUG'
        try {
            $biosSetting = Get-CimInstance -Namespace root/wmi -ClassName Lenovo_BiosSetting -ErrorAction Stop | Where-Object { $_.CurrentSetting -match 'SecureBoot' } | Select-Object -ExpandProperty CurrentSetting -First 1
        } catch {
            # Legacy WMI fallback.
            $biosSetting = Get-WmiObject -Class Lenovo_BiosSetting -Namespace root/WMI -ErrorAction Stop | Where-Object { $_.CurrentSetting -match 'SecureBoot' } | Select-Object -ExpandProperty CurrentSetting -First 1
        }
        if (-not $biosSetting) {
            $reasons.Add("Lenovo SecureBoot setting not found via WMI - BIOS may not expose SecureBoot")
            return @($reasons)
        }
        Write-Log -Message "Current BIOS setting: $biosSetting" -Level 'DEBUG'
        if ($biosSetting -ne 'SecureBoot,Enable') {
            $reasons.Add("Lenovo SecureBoot is not enabled (current: $biosSetting)")
        }
    } catch {
        throw "Failed to evaluate Lenovo SecureBoot: $($_.Exception.Message)"
    }
    return @($reasons)
}

try {
    $null = Initialize-Log -SolutionName $SolutionName -ScriptMode $ScriptMode -Type 'Intune'
    Write-Banner
    if ($script:LogReady) { Write-Log -Message "Log file ready: $($script:LogFile)" -Level 'DEBUG' }
    Write-Log -Message "Detection started - Lenovo Secure Boot" -Level 'INFO'
    $reasons = Test-ComplianceState
    if ($reasons.Count -eq 0) { Finish-Script -ExitCode 0 -Message "Compliant - Lenovo SecureBoot enabled or not applicable" -Level 'SUCCESS' }
    foreach ($reason in $reasons) { Write-Output $reason; Write-Log -Message "Non-compliant: $reason" -Level 'WARNING' }
    Finish-Script -ExitCode 1 -Message "Non-compliant - $($reasons.Count) condition(s) found" -Level 'WARNING'
}
catch {
    Write-Output "Detection error: $($_.Exception.Message)"
    Finish-Script -ExitCode 2 -Message "Detection script error: $($_.Exception.Message)" -Level 'ERROR'
}
