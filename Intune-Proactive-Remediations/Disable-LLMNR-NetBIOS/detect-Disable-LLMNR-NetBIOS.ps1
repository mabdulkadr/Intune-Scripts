<#
.TITLE
    Detection - LLMNR and NetBIOS Disabled

.SYNOPSIS
    Verifies that LLMNR and NetBIOS are disabled per CIS L1 hardening.

.DESCRIPTION
    Checks:
    1. LLMNR disabled via HKLM\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient\EnableMulticast = 0
    2. NetBIOS disabled on all active adapters (NetbiosOptions = 2 in Tcpip interfaces)
    CIS L1 and Microsoft 25H2 baseline recommend both disabled to prevent name spoofing.
    This script NEVER modifies the system.

    Exit contract:
    Exit 0 = compliant
    Exit 1 = non-compliant
    Exit 2 = script error

.TAGS
    Remediation,Detection,Hardening,LLMNR,NetBIOS,CIS

.REMEDIATIONTYPE
    Detection

.PAIRSCRIPT
    remediate-Disable-LLMNR-NetBIOS.ps1

.PLATFORM
    Windows

.MINROLE
    Intune Service Administrator

.PERMISSIONS
    None (local SYSTEM context) - reads registry.

.AUTHOR
    Mohammad Abdelkader Omar

.VERSION
    1.0.0

.CHANGELOG
    1.0.0 (2026-08-31)
    - Initial release; CIS L1 LLMNR/NetBIOS hardening.

.LASTUPDATE
    2026-08-31

.EXAMPLE
    .\detect-Disable-LLMNR-NetBIOS.ps1
    Returns exit 0 when compliant; exit 1 when remediation must run.

.NOTES
    - Runs in SYSTEM context via Intune Remediations.
    - Logs: <SystemDrive>\IntuneLogs\Disable-LLMNR-NetBIOS\Disable-LLMNR-NetBIOS-Detection.txt
#>

#Requires -Version 5.1

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$SolutionName = 'Disable-LLMNR-NetBIOS'
$ScriptMode   = 'Detection'

$LlmnrRegPath  = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient'
$NetBtBasePath = 'HKLM:\SYSTEM\CurrentControlSet\Services\NetBT\Parameters\Interfaces'

$script:SystemDrive = if ($env:SystemDrive) { $env:SystemDrive.TrimEnd('\') } else { [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\') }
$script:LogRoot = $null; $script:LogFile = $null; $script:LogReady = $false
function Initialize-Log {
    [CmdletBinding()] param([string]$SolutionName = 'EnterpriseAdminTool',[string]$ScriptMode = 'run',[ValidateSet('Intune','General')][string]$Type = 'General')
    try {
        if ($Type -eq 'Intune') { $script:LogRoot = Join-Path $script:SystemDrive "IntuneLogs\$SolutionName"; $script:LogFile = Join-Path $script:LogRoot "$SolutionName-$ScriptMode.txt" }
        else { $script:LogRoot = Join-Path $env:ProgramData "$SolutionName\Logs"; $script:LogFile = Join-Path $script:LogRoot "$SolutionName`_$(Get-Date -Format 'yyyyMMdd_HHmmss').log" }
        if (-not (Test-Path -LiteralPath $script:LogRoot)) { $null = [System.IO.Directory]::CreateDirectory($script:LogRoot) }
        if (-not (Test-Path -LiteralPath $script:LogFile)) { $null = [System.IO.File]::Create($script:LogFile).Dispose() }
        $script:LogReady = $true; return $true
    } catch { Write-Host "Log init failed: $($_.Exception.Message)" -ForegroundColor Red; $script:LogReady = $false; return $false }
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

function Test-ComplianceState {
    $reasons = [System.Collections.Generic.List[string]]::new()
    try {
        # 1) LLMNR must be disabled: EnableMulticast = 0
        $llmnrCompliant = $false
        if (Test-Path -LiteralPath $LlmnrRegPath) {
            try {
                $val = Get-ItemProperty -LiteralPath $LlmnrRegPath -Name EnableMulticast -ErrorAction Stop
                if ($val.EnableMulticast -eq 0) { $llmnrCompliant = $true; Write-Log -Message "LLMNR disabled (EnableMulticast=0)" -Level 'DEBUG' }
                else { $reasons.Add("LLMNR is enabled (EnableMulticast=$($val.EnableMulticast), expected 0)") }
            } catch { $reasons.Add("LLMNR registry value EnableMulticast not found at $LlmnrRegPath") }
        } else { $reasons.Add("LLMNR policy not configured - missing registry path $LlmnrRegPath") }

        # 2) NetBIOS disabled on all interfaces: NetbiosOptions = 2 (0=DHCP default, 1=enabled, 2=disabled)
        if (Test-Path -LiteralPath $NetBtBasePath) {
            $interfaces = Get-ChildItem -LiteralPath $NetBtBasePath -ErrorAction SilentlyContinue
            $checked = 0; $nonCompliant = 0
            foreach ($iface in $interfaces) {
                try {
                    $props = Get-ItemProperty -LiteralPath $iface.PSPath -ErrorAction SilentlyContinue
                    if ($null -ne $props.NetbiosOptions) {
                        $checked++
                        if ($props.NetbiosOptions -ne 2) { $nonCompliant++; Write-Log -Message "NetBIOS not disabled on $($iface.PSChildName): NetbiosOptions=$($props.NetbiosOptions)" -Level 'DEBUG' }
                    }
                } catch [System.Exception] { Write-Log -Message $_.Exception.Message -Level 'DEBUG' }
            }
            if ($checked -eq 0) { Write-Log -Message "No NetbiosOptions values found - checking via adapter method" -Level 'DEBUG'
                # Fallback: check via WMI adapter config
                try {
                    $adapters = Get-CimInstance -ClassName Win32_NetworkAdapterConfiguration -Filter "IPEnabled=True" -ErrorAction SilentlyContinue
                    foreach ($a in $adapters) { if ($a.TcpipNetbiosOptions -ne 2) { $nonCompliant++ } ; $checked++ }
                } catch [System.Exception] { Write-Log -Message $_.Exception.Message -Level 'DEBUG' }
            }
            if ($nonCompliant -gt 0) { $reasons.Add("NetBIOS not disabled on $nonCompliant interface(s) (expected NetbiosOptions=2)") }
            elseif ($checked -gt 0) { Write-Log -Message "NetBIOS disabled on all $checked interface(s)" -Level 'DEBUG' }
        }
    } catch { throw "Failed to evaluate LLMNR/NetBIOS: $($_.Exception.Message)" }
    return @($reasons)
}

try {
    $null = Initialize-Log -SolutionName $SolutionName -ScriptMode $ScriptMode -Type 'Intune'
    Write-Banner
    if ($script:LogReady) { Write-Log -Message "Log file ready: $($script:LogFile)" -Level 'DEBUG' }
    Write-Log -Message "Detection started - LLMNR/NetBIOS" -Level 'INFO'
    $reasons = Test-ComplianceState
    if ($reasons.Count -eq 0) { Finish-Script -ExitCode 0 -Message "Compliant - LLMNR and NetBIOS disabled" -Level 'SUCCESS' }
    foreach ($reason in $reasons) { Write-Output $reason; Write-Log -Message "Non-compliant: $reason" -Level 'WARNING' }
    Finish-Script -ExitCode 1 -Message "Non-compliant - $($reasons.Count) condition(s) found" -Level 'WARNING'
}
catch {
    Write-Output "Detection error: $($_.Exception.Message)"
    Finish-Script -ExitCode 2 -Message "Detection script error: $($_.Exception.Message)" -Level 'ERROR'
}
