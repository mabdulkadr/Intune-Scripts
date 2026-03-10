<#
.SYNOPSIS
    Stop Microsoft Teams and clear the current user's Teams cache.

.DESCRIPTION
    This remediation script stops the current Microsoft Teams process and then
    removes the cache files from the current user's Teams package cache path.

    It is intended to reset local Teams cache data when the cache folder is
    present and the paired detection script triggers remediation.

.RUN AS
    User

.EXAMPLE
    .\ClearTeamsCache--Remediate.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.0
#>

#region ========================= CONFIGURATION =========================
# Teams package cache path used for cleanup.
$TeamsCachePath = Join-Path $env:USERPROFILE 'AppData\Local\Packages\MSTeams_8wekyb3d8bbwe\LocalCache\Microsoft\MSTeams'

# Teams process name used by the original script.
$TeamsProcessName = 'ms-teams'

# Use a fixed script name so logging stays consistent when Intune stages the script under a temporary local file name.
$ScriptName     = 'ClearTeamsCache--Remediate.ps1'
$ScriptBaseName = 'ClearTeamsCache--Remediate'

# Store logs under the system drive instead of hard-coding C:.
$SystemDrive = if ($env:SystemDrive) { $env:SystemDrive.TrimEnd('\') } else { 'C:' }

# Script-specific logging location.
$SolutionName = 'ClearTeamsCache'
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
Write-Host 'Microsoft Teams will be quit now in order to clear the cache.'
try {
    Get-Process -ProcessName $TeamsProcessName | Stop-Process -Force
    Start-Sleep -Seconds 5
    Write-Host 'Microsoft Teams has been successfully quit.'
    Write-Log -Level 'OK' -Message 'Microsoft Teams was stopped successfully.'
}
catch {
    Write-Output $_
    Write-Log -Level 'WARN' -Message ('Teams stop operation returned: {0}' -f $_.Exception.Message)
}

# The cache is now being cleared.
try {
    Get-ChildItem -Path $TeamsCachePath | Remove-Item -Confirm:$false -Recurse -Force
    Write-Log -Level 'OK' -Message 'The Teams cache files were removed.'
}
catch {
    Write-Output $_
    Write-Log -Level 'WARN' -Message ('Teams cache cleanup returned: {0}' -f $_.Exception.Message)
}

Write-Host 'The Microsoft Teams cache has been successfully cleared.'
Write-Log -Level 'INFO' -Message '=== Remediation END ==='
#endregion ================= FIRST REMEDIATION BLOCK =================
