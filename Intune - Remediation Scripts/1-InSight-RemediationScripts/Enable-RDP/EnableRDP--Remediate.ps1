<#
.SYNOPSIS
    Enable Remote Desktop and allow the Everyone SID in the Remote Desktop Users group.

.DESCRIPTION
    This remediation script enables Remote Desktop by setting
    `fDenyTSConnections` to `0`, disables Network Level Authentication through
    `Win32_TSGeneralSetting`, and ensures the `Everyone` SID (`S-1-1-0`) is a
    member of the built-in Remote Desktop Users group (`S-1-5-32-555`).

    The script preserves the original behavior exactly.

.RUN AS
    System

.EXAMPLE
    .\EnableRDP--Remediate.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.0
#>

#region ========================= CONFIGURATION =========================
# Use a fixed script name so logging stays consistent when Intune stages the script under a temporary local file name.
$ScriptName     = 'EnableRDP--Remediate.ps1'
$ScriptBaseName = 'EnableRDP--Remediate'

# Detect the Windows system drive automatically instead of hard-coding C:.
$SystemDrive = if ([string]::IsNullOrWhiteSpace($env:SystemDrive)) {
    [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\')
}
else {
    $env:SystemDrive.TrimEnd('\')
}

# Script-specific logging location.
$SolutionName = 'EnableRDP'
$BasePath     = Join-Path (Join-Path $SystemDrive 'Intune') $SolutionName
$LogFile      = Join-Path $BasePath ("{0}.txt" -f $ScriptBaseName)
#endregion ====================== CONFIGURATION ======================

#region ======================= HELPER FUNCTIONS =======================
# Ensure the log directory and log file exist before writing entries.
function Initialize-LogFile {
    if (-not (Test-Path -LiteralPath $BasePath)) {
        New-Item -Path $BasePath -ItemType Directory -Force | Out-Null
    }

    if (-not (Test-Path -LiteralPath $LogFile)) {
        New-Item -Path $LogFile -ItemType File -Force | Out-Null
    }
}

# Add a visual separator so each run is easier to scan in the same log file.
function Start-LogRun {
    Initialize-LogFile

    if (Test-Path -LiteralPath $LogFile) {
        $existingLog = Get-Item -LiteralPath $LogFile -ErrorAction SilentlyContinue
        if ($existingLog -and $existingLog.Length -gt 0) {
            Add-Content -Path $LogFile -Value '' -Encoding UTF8
        }
    }

    Add-Content -Path $LogFile -Value ('=' * 78) -Encoding UTF8
}

# Write a colorized console message and persist it to the log file.
function Write-Log {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [ValidateSet('INFO', 'OK', 'WARN', 'FAIL')]
        [string]$Level = 'INFO'
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $line = "[{0}] [{1}] {2}" -f $timestamp, $Level, $Message

    switch ($Level) {
        'OK' { Write-Host $line -ForegroundColor Green }
        'WARN' { Write-Host $line -ForegroundColor Yellow }
        'FAIL' { Write-Host $line -ForegroundColor Red }
        default { Write-Host $line -ForegroundColor Cyan }
    }

    Add-Content -Path $LogFile -Value $line -Encoding UTF8
}

# Check whether one SID is already a member of another local group SID.
function IsMember {
    param(
        [string]$GroupSID = '',
        [string]$UserSID = ''
    )

    $memebers = Get-LocalGroupMember -SID $GroupSID
    $isMember = $false

    foreach ($memeber in $memebers) {
        if ($memeber.SID -eq $UserSID) {
            $isMember = $true
        }
    }

    return $isMember
}
#endregion ==================== HELPER FUNCTIONS ====================

#region ==================== FIRST REMEDIATION BLOCK ====================
Start-LogRun
Write-Log -Message '=== Remediation START ==='
Write-Log -Message "Script: $ScriptName"
Write-Log -Message "Log file: $LogFile"

# Enable RDP exactly as the original script did.
Set-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\' -Name 'fDenyTSConnections' -Value 0
Write-Log -Message 'RDP registry setting was updated.'

# Disable Network Level Authentication exactly as the original script did.
(Get-WmiObject -Class Win32_TSGeneralSetting -Namespace root\cimv2\terminalservices -Filter "TerminalName='RDP-tcp'").SetUserAuthenticationRequired(0) | Out-Null
Write-Log -Message 'Network Level Authentication was updated.'

if (IsMember -GroupSID 'S-1-5-32-555' -UserSID 'S-1-1-0') {
    Write-Log -Message 'Everyone is already a member of the Remote Desktop Users group.'
}
else {
    Add-LocalGroupMember -SID 'S-1-5-32-555' -Member 'S-1-1-0'
    Write-Log -Message 'Everyone was added to the Remote Desktop Users group.' -Level 'OK'
}

Write-Log -Message '=== Remediation END ==='
#endregion ================= FIRST REMEDIATION BLOCK =================
