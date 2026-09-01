<#
.TITLE
    Remediation - Disable LLMNR and NetBIOS

.SYNOPSIS
    Disables LLMNR and NetBIOS per CIS L1 hardening recommendations.

.DESCRIPTION
    Paired remediation for Disable-LLMNR-NetBIOS. Performs: (1) set
    EnableMulticast=0 at DNSClient policy path, (2) set NetbiosOptions=2 on all
    NetBT interfaces. Verifies both before reporting success.

    Exit contract:
    Exit 0 = success
    Exit 1 = failure
    Exit 2 = script error

.TAGS
    Remediation,Action,Hardening,LLMNR,NetBIOS

.REMEDIATIONTYPE
    Remediation

.PAIRSCRIPT
    detect-Disable-LLMNR-NetBIOS.ps1

.PLATFORM
    Windows

.MINROLE
    Intune Service Administrator

.PERMISSIONS
    None (local SYSTEM context) - writes registry.

.AUTHOR
    Mohammad Abdelkader Omar

.VERSION
    1.0.0

.CHANGELOG
    1.0.0 (2026-08-31)
    - Initial release; disables LLMNR and NetBIOS.

.LASTUPDATE
    2026-08-31

.EXAMPLE
    .\remediate-Disable-LLMNR-NetBIOS.ps1
    Disables LLMNR and NetBIOS and verifies.

.NOTES
    - Runs in SYSTEM context via Intune Remediations.
    - Logs: <SystemDrive>\IntuneLogs\Disable-LLMNR-NetBIOS\Disable-LLMNR-NetBIOS-Remediation.txt
#>

#Requires -Version 5.1

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$SolutionName = 'Disable-LLMNR-NetBIOS'
$ScriptMode   = 'Remediation'

$LlmnrRegPath  = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient'
$NetBtBasePath = 'HKLM:\SYSTEM\CurrentControlSet\Services\NetBT\Parameters\Interfaces'

$remediationResult = @{ Status = "Unknown"; PreCheckStatus = @(); RemediationActions = @(); PostCheckStatus = @(); Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"; ComputerName = $env:COMPUTERNAME }

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
function Write-RemediationLog {
    [CmdletBinding()] param([Parameter(Mandatory = $false)][AllowEmptyString()][string]$Message = "",[ValidateSet('Info','Warning','Error')][string]$Level = 'Info')
    if ([string]::IsNullOrEmpty($Message)) { return }; $mapped = switch ($Level) { 'Warning' { 'WARNING' } 'Error' { 'ERROR' } default { 'INFO' } }
    Write-Log -Message $Message -Level $mapped
    $script:remediationResult.RemediationActions += @{ Timestamp = (Get-Date -Format "yyyy-MM-dd HH:mm:ss"); Level = $Level; Message = $Message }
}

function Test-RemediationPrerequisites {
    try { $script:remediationResult.PreCheckStatus += "Pre-check passed"; return $true } catch { Write-RemediationLog "Pre-check error: $($_.Exception.Message)" -Level 'Error'; return $false }
}
function Test-FixApplied {
    try {
        $llmnrOk = $false
        if (Test-Path -LiteralPath $LlmnrRegPath) {
            $v = Get-ItemProperty -LiteralPath $LlmnrRegPath -Name EnableMulticast -ErrorAction SilentlyContinue
            if ($v -and $v.EnableMulticast -eq 0) { $llmnrOk = $true }
        }
        $netBiosOk = $true
        if (Test-Path -LiteralPath $NetBtBasePath) {
            $ifaces = Get-ChildItem -LiteralPath $NetBtBasePath -ErrorAction SilentlyContinue
            foreach ($iface in $ifaces) {
                $props = Get-ItemProperty -LiteralPath $iface.PSPath -ErrorAction SilentlyContinue
                if ($null -ne $props.NetbiosOptions -and $props.NetbiosOptions -ne 2) { $netBiosOk = $false; break }
            }
        }
        return ($llmnrOk -and $netBiosOk)
    } catch { return $false }
}

try {
    $null = Initialize-Log -SolutionName $SolutionName -ScriptMode $ScriptMode -Type 'Intune'
    Write-Banner
    if ($script:LogReady) { Write-Log -Message "Log file ready: $($script:LogFile)" -Level 'DEBUG' }
    Write-RemediationLog "Starting remediation - LLMNR/NetBIOS hardening" -Level 'Info'
    if (-not (Test-RemediationPrerequisites)) { throw "Pre-check failed" }
    $script:failedCount = 0; $targetCount = 0

    # LLMNR
    $targetCount++
    try {
        if (-not (Test-Path -LiteralPath $LlmnrRegPath)) { $null = New-Item -Path $LlmnrRegPath -Force -ErrorAction Stop }
        $null = New-ItemProperty -LiteralPath $LlmnrRegPath -Name EnableMulticast -Value 0 -PropertyType DWord -Force -ErrorAction Stop
        Write-RemediationLog "Disabled LLMNR (EnableMulticast=0)" -Level 'Info'
    } catch { $script:failedCount++; Write-RemediationLog "Failed to disable LLMNR: $($_.Exception.Message)" -Level 'Error' }

    # NetBIOS
    $targetCount++
    try {
        if (Test-Path -LiteralPath $NetBtBasePath) {
            $ifaces = Get-ChildItem -LiteralPath $NetBtBasePath -ErrorAction SilentlyContinue
            foreach ($iface in $ifaces) {
                try { $null = New-ItemProperty -LiteralPath $iface.PSPath -Name NetbiosOptions -Value 2 -PropertyType DWord -Force -ErrorAction Stop } catch { Write-RemediationLog "NetBIOS set warning on $($iface.PSChildName): $($_.Exception.Message)" -Level 'Warning' }
            }
            Write-RemediationLog "Disabled NetBIOS (NetbiosOptions=2) on $($ifaces.Count) interface(s)" -Level 'Info'
        }
        # Also set via WMI for consistency
        try {
            $adapters = Get-CimInstance -ClassName Win32_NetworkAdapterConfiguration -Filter "IPEnabled=True" -ErrorAction SilentlyContinue
            foreach ($a in $adapters) { try { $null = Invoke-CimMethod -InputObject $a -MethodName SetTcpipNetbios -Arguments @{ TcpipNetbiosOptions = 2 } -ErrorAction SilentlyContinue } catch {} }
        } catch {}
    } catch { $script:failedCount++; Write-RemediationLog "Failed to disable NetBIOS: $($_.Exception.Message)" -Level 'Error' }

    Write-RemediationLog "Post-verification..." -Level 'Info'
    $verificationPassed = Test-FixApplied
    if ($targetCount -gt 0 -and $script:failedCount -ge $targetCount) { $verificationPassed = $false }

    if ($verificationPassed) {
        $script:remediationResult.Status = "Success"; $script:remediationResult.PostCheckStatus += "LLMNR and NetBIOS verified disabled"
        Write-Output "Remediation completed successfully"
        Write-Output ($remediationResult | ConvertTo-Json -Depth 6 -Compress)
        Finish-Script -ExitCode 0 -Message "Remediation completed successfully" -Level 'SUCCESS'
    } else {
        $script:remediationResult.Status = "Failed"
        Write-Output "Remediation finished but verification failed"
        Write-Output ($remediationResult | ConvertTo-Json -Depth 6 -Compress)
        Finish-Script -ExitCode 1 -Message "Post-remediation verification failed" -Level 'ERROR'
    }
}
catch {
    $script:remediationResult.Status = "Error"
    $script:remediationResult.Error = @{ Message = $_.Exception.Message; Type = $_.Exception.GetType().FullName; StackTrace = $_.ScriptStackTrace }
    Write-Output ($remediationResult | ConvertTo-Json -Depth 6 -Compress)
    Finish-Script -ExitCode 2 -Message "Script execution error: $($_.Exception.Message)" -Level 'ERROR'
}
finally { Write-Log -Message "Cleanup complete" -Level 'DEBUG' }
