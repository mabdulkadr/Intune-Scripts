<#
.SYNOPSIS
    Create a local admin account with a randomized password for Windows LAPS scenarios.

.DESCRIPTION
    This remediation script creates the local user account defined by
    `$LocalAdminName` with a randomized password.

    It resolves the built-in Administrators group by SID and adds the new
    account to that group so it can be managed by Windows LAPS afterward.

.RUN AS
    System

.EXAMPLE
    .\CreateLocalAdminLAPS--Remediate.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.0
#>

#region ========================= CONFIGURATION =========================
# Local user name to create.
$LocalAdminName = ''

# Generate a randomized password and convert it to a secure string.
$Password = -join ((65..90) + (97..122) + (48..57) + (35..38) + (40..47) | Get-Random -Count 35 | ForEach-Object { [char]$_ }) | ConvertTo-SecureString -AsPlainText -Force

# Resolve the localized Administrators group by SID.
$LocalAdminGroupName = (Get-LocalGroup -SID 'S-1-5-32-544').Name

# Use a fixed script name so logging stays consistent when Intune stages the script under a temporary local file name.
$ScriptName     = 'CreateLocalAdminLAPS--Remediate.ps1'
$ScriptBaseName = 'CreateLocalAdminLAPS--Remediate'

# Store logs under the system drive instead of hard-coding C:.
$SystemDrive = if ($env:SystemDrive) { $env:SystemDrive.TrimEnd('\') } else { 'C:' }

# Script-specific logging location.
$SolutionName = 'CreateLocalAdminLAPS'
$BasePath     = Join-Path (Join-Path $SystemDrive 'Intune') $SolutionName
$LogFile      = Join-Path $BasePath ('{0}.txt' -f $ScriptBaseName)
#endregion ====================== CONFIGURATION ======================

#region ========================= HELPER FUNCTIONS =========================
function Initialize-LogFile {
    if (-not (Test-Path -LiteralPath $BasePath)) {
        New-Item -Path $BasePath -ItemType Directory -Force | Out-Null
    }
    if (-not (Test-Path -LiteralPath $LogFile)) {
        New-Item -Path $LogFile -ItemType File -Force | Out-Null
    }
}

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

function Write-Log {
    param(
        [Parameter(Mandatory = $true)][string]$Message,
        [ValidateSet('INFO', 'OK', 'WARN', 'FAIL')][string]$Level = 'INFO'
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $line = "[$timestamp] [$Level] $Message"

    switch ($Level) {
        'OK'   { Write-Host $line -ForegroundColor Green }
        'WARN' { Write-Host $line -ForegroundColor Yellow }
        'FAIL' { Write-Host $line -ForegroundColor Red }
        default { Write-Host $line -ForegroundColor Cyan }
    }

    try { Add-Content -Path $LogFile -Value $line -Encoding UTF8 } catch {}
}
#endregion ====================== HELPER FUNCTIONS ======================

Start-LogRun
Write-Log -Level 'INFO' -Message '=== Remediation START ==='
Write-Log -Level 'INFO' -Message ('Script: {0}' -f $ScriptName)
Write-Log -Level 'INFO' -Message ('Log file: {0}' -f $LogFile)

#region ==================== FIRST REMEDIATION BLOCK ====================
New-LocalUser "$LocalAdminName" -Password $Password -FullName "$LocalAdminName" -Description 'LAPS account'
Add-LocalGroupMember -Group $LocalAdminGroupName -Member "$LocalAdminName"

Write-Log -Level 'OK' -Message 'The randomized local admin account was created and added to the Administrators group.'
Write-Log -Level 'INFO' -Message '=== Remediation END ==='
#endregion ================= FIRST REMEDIATION BLOCK =================
