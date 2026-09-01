<#
.TITLE
    Remediation - Enable Lenovo Secure Boot

.SYNOPSIS
    Enables Secure Boot via Lenovo WMI BIOS interface and suspends BitLocker for one reboot.

.DESCRIPTION
    Paired remediation for Enable-SecureBoot-Lenovo. Runs only when detection returns exit 1.
    Performs: (1) suspend BitLocker for one reboot (TPM PCR change guard), (2) set
    SecureBoot,Enable via Lenovo_SetBiosSetting, (3) save with Lenovo_SaveBiosSettings,
    (4) verify. Requires a Lenovo supervisor password if set - supply via $BiosPassword.

    Exit contract:
    Exit 0 = success (fix applied and verified)
    Exit 1 = failure
    Exit 2 = script error

.TAGS
    Remediation,Action,SecureBoot,Lenovo,BIOS,BitLocker

.REMEDIATIONTYPE
    Remediation

.PAIRSCRIPT
    detect-Enable-SecureBoot-Lenovo.ps1

.PLATFORM
    Windows

.MINROLE
    Intune Service Administrator

.PERMISSIONS
    None (local SYSTEM context) - writes Lenovo WMI BIOS setting and suspends BitLocker.

.AUTHOR
    Mohammad Abdelkader Omar

.VERSION
    1.0.0

.CHANGELOG
    1.0.0 (2026-08-31)
    - Initial release; BitLocker suspend + WMI BIOS enablement.

.LASTUPDATE
    2026-08-31

.EXAMPLE
    .\remediate-Enable-SecureBoot-Lenovo.ps1
    Enables Secure Boot and reboots required.

.NOTES
    - Runs in SYSTEM context via Intune Remediations.
    - Set $BiosPassword if supervisor password is configured: edit script or use env var LENOVO_BIOS_PASSWORD.
    - Logs: <SystemDrive>\IntuneLogs\Enable-SecureBoot-Lenovo\Enable-SecureBoot-Lenovo-Remediation.txt
#>

#Requires -Version 5.1

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$SolutionName = 'Enable-SecureBoot-Lenovo'
$ScriptMode   = 'Remediation'

# Set supervisor password here or via environment variable LENOVO_BIOS_PASSWORD.
$BiosPassword = if ($env:LENOVO_BIOS_PASSWORD) { $env:LENOVO_BIOS_PASSWORD } else { "" }

$remediationResult = @{
    Status = "Unknown"; PreCheckStatus = @(); RemediationActions = @(); PostCheckStatus = @()
    Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"; ComputerName = $env:COMPUTERNAME
}

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
function Write-RemediationLog {
    [CmdletBinding()] param([Parameter(Mandatory = $false)][AllowEmptyString()][string]$Message = "",[ValidateSet('Info','Warning','Error')][string]$Level = 'Info')
    if ([string]::IsNullOrEmpty($Message)) { return }; $mapped = switch ($Level) { 'Warning' { 'WARNING' } 'Error' { 'ERROR' } default { 'INFO' } }
    Write-Log -Message $Message -Level $mapped
    $script:remediationResult.RemediationActions += @{ Timestamp = (Get-Date -Format "yyyy-MM-dd HH:mm:ss"); Level = $Level; Message = $Message }
}

function Test-RemediationPrerequisites {
    try {
        $cs = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop
        if ($cs.Manufacturer -notmatch 'Lenovo') { throw "Not a Lenovo device - remediation not applicable" }
        $script:remediationResult.PreCheckStatus += "Lenovo device confirmed"
        return $true
    } catch { Write-RemediationLog "Pre-check error: $($_.Exception.Message)" -Level 'Error'; return $false }
}

function Test-FixApplied {
    try {
        $setting = Get-CimInstance -Namespace root/wmi -ClassName Lenovo_BiosSetting -ErrorAction Stop | Where-Object { $_.CurrentSetting -match 'SecureBoot' } | Select-Object -ExpandProperty CurrentSetting -First 1
        if (-not $setting) { $setting = Get-WmiObject -Class Lenovo_BiosSetting -Namespace root/WMI -ErrorAction Stop | Where-Object { $_.CurrentSetting -match 'SecureBoot' } | Select-Object -ExpandProperty CurrentSetting -First 1 }
        return ($setting -eq 'SecureBoot,Enable')
    } catch { return $false }
}

try {
    $null = Initialize-Log -SolutionName $SolutionName -ScriptMode $ScriptMode -Type 'Intune'
    Write-Banner
    if ($script:LogReady) { Write-Log -Message "Log file ready: $($script:LogFile)" -Level 'DEBUG' }
    Write-RemediationLog "Starting remediation - Lenovo Secure Boot enablement" -Level 'Info'
    if (-not (Test-RemediationPrerequisites)) { throw "Pre-remediation validation failed" }
    $script:failedCount = 0; $targetCount = 0
    Write-RemediationLog "Suspending BitLocker for one reboot (PCR guard)..." -Level 'Info'
    $targetCount++
    try {
        $bitLockerVolumes = Get-BitLockerVolume -ErrorAction SilentlyContinue | Where-Object { $_.ProtectionStatus -eq 'On' }
        foreach ($vol in $bitLockerVolumes) {
            try { Suspend-BitLocker -MountPoint $vol.MountPoint -RebootCount 1 -ErrorAction Stop; Write-RemediationLog "Suspended BitLocker on $($vol.MountPoint) for 1 reboot" -Level 'Info' } catch { Write-RemediationLog "BitLocker suspend warning on $($vol.MountPoint): $($_.Exception.Message)" -Level 'Warning' }
        }
    } catch { Write-RemediationLog "BitLocker check warning: $($_.Exception.Message)" -Level 'Warning' }

    Write-RemediationLog "Setting SecureBoot,Enable via WMI..." -Level 'Info'
    $targetCount++
    try {
        $passwordSuffix = if ($BiosPassword) { ",$BiosPassword,ascii,us" } else { "" }
        $setResult = (Get-CimInstance -Namespace root/wmi -ClassName Lenovo_SetBiosSetting -ErrorAction Stop | Invoke-CimMethod -MethodName SetBiosSetting -Arguments @{ Item = "SecureBoot,Enable$passwordSuffix" } -ErrorAction Stop)
        # Fallback to WMI if CIM fails
        if ($setResult.Return -and $setResult.Return -ne 'Success') { throw "SetBiosSetting returned $($setResult.Return)" }
        Write-RemediationLog "SetBiosSetting succeeded" -Level 'Info'
        $saveResult = (Get-CimInstance -Namespace root/wmi -ClassName Lenovo_SaveBiosSettings -ErrorAction Stop | Invoke-CimMethod -MethodName SaveBiosSettings -Arguments @{ Password = $BiosPassword } -ErrorAction Stop)
        if ($saveResult.Return -and $saveResult.Return -ne 'Success') { throw "SaveBiosSettings returned $($saveResult.Return)" }
        Write-RemediationLog "SaveBiosSettings succeeded - reboot required" -Level 'Info'
    } catch {
        # Try legacy WMI
        try {
            $wmiSet = (Get-WmiObject -Class Lenovo_SetBiosSetting -Namespace root/wmi -ErrorAction Stop).SetBiosSetting("SecureBoot,Enable$passwordSuffix")
            if ($wmiSet.return -ne 'Success') { throw "WMI SetBiosSetting: $($wmiSet.return)" }
            $wmiSave = (Get-WmiObject -Class Lenovo_SaveBiosSettings -Namespace root/wmi -ErrorAction Stop).SaveBiosSettings($BiosPassword)
            if ($wmiSave.return -ne 'Success') { throw "WMI SaveBiosSettings: $($wmiSave.return)" }
            Write-RemediationLog "WMI fallback succeeded - reboot required" -Level 'Info'
        } catch {
            $script:failedCount++; Write-RemediationLog "Failed to enable SecureBoot: $($_.Exception.Message)" -Level 'Error'
        }
    }

    Write-RemediationLog "Post-verification..." -Level 'Info'
    $verificationPassed = Test-FixApplied
    if ($targetCount -gt 0 -and $script:failedCount -ge $targetCount) { $verificationPassed = $false }

    if ($verificationPassed) {
        $script:remediationResult.Status = "Success"; $script:remediationResult.PostCheckStatus += "SecureBoot,Enable verified"
        Write-Output "Remediation completed - reboot required"
        Write-Output ($remediationResult | ConvertTo-Json -Depth 6 -Compress)
        Finish-Script -ExitCode 0 -Message "Remediation completed - reboot required" -Level 'SUCCESS'
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
