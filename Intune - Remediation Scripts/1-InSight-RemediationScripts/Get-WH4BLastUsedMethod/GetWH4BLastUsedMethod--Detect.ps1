<#
.SYNOPSIS
    Detect the last Windows Hello for Business sign-in method used on the device.

.DESCRIPTION
    This detection-only script reads the `LastLoggedOnProvider` value from:

        HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Authentication\LogonUI

    It maps the provider GUID to a friendly authentication method such as:
    - PIN
    - Fingerprint
    - Facial recognition
    - Password
    - FIDO

    A recognized provider is treated as a normal state and returns `0`. Missing
    or unreadable values return `1`.

.RUN AS
    User

.EXAMPLE
    .\GetWH4BLastUsedMethod--Detect.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.0
#>

#region ========================= CONFIGURATION =========================
# Use a fixed script name so logging stays consistent when Intune stages the script under a temporary local file name.
$ScriptName     = 'GetWH4BLastUsedMethod--Detect.ps1'
$ScriptBaseName = 'GetWH4BLastUsedMethod--Detect'

# Store the user-context log under the current user's temp folder.
$LogRoot      = Join-Path $env:TEMP 'Logs'
$SolutionName = 'GetWH4BLastUsedMethod'
$BasePath     = Join-Path $LogRoot $SolutionName
$LogFile      = Join-Path $BasePath ("{0}_{1}.txt" -f $env:COMPUTERNAME, $ScriptBaseName)

# Registry values used by the original script.
$LastLogin      = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Authentication\LogonUI'
$LastLoginValue = 'LastLoggedOnProvider'
#endregion ====================== CONFIGURATION ======================

#region ======================= HELPER FUNCTIONS =======================
# Ensure the log directory and log file exist before writing entries.
function Initialize-LogFile {
    if (-not (Test-Path -LiteralPath $LogRoot)) {
        New-Item -Path $LogRoot -ItemType Directory -Force | Out-Null
    }

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
#endregion ==================== HELPER FUNCTIONS ====================

#region ===================== FIRST DETECTION BLOCK =====================
Start-LogRun
Write-Log -Message '=== Detection START ==='
Write-Log -Message "Script: $ScriptName"
Write-Log -Message "Log file: $LogFile"
Write-Log -Message "Registry path: $LastLogin"
Write-Log -Message "Registry value: $LastLoginValue"

$exitcode = 1
$exitmessage = ''

Try {
    # Check the last authentication provider used by LogonUI.
    if (Test-Path -Path $LastLogin) {
        $LoginMetrics = Get-ItemProperty -Path $LastLogin -Name $LastLoginValue -ErrorAction Continue
        if ($LoginMetrics) {
            $exitcode = 0
            switch ($LoginMetrics.LastLoggedOnProvider) {
                '{D6886603-9D2F-4EB2-B667-1971041FA96B}' { $exitmessage = 'Pin authentication' }
                '{BEC09223-B018-416D-A0AC-523971B639F5}' { $exitmessage = 'Fingerprint authentication' }
                '{8AF662BF-65A0-4D0A-A540-A338A999D36F}' { $exitmessage = 'Facial authentication' }
                '{60B78E88-EAD8-445C-9CFD-0B87F74EA6CD}' { $exitmessage = 'Password authentication' }
                '{F8A1793B-7873-4046-B2A7-1F318747F427}' { $exitmessage = 'FIDO authentication' }
                default { $exitmessage = 'Unknown device authentication' }
            }
        }
        else {
            $exitmessage = 'LastLoggedOnProvider Value is not there'
            Write-Warning $exitmessage
            $exitcode = 1
        }
    }
}
catch {
    if ($_ -contains 'Cannot find path') {
        $exitmessage = 'Authentication method cannot be checked'
        Write-Warning $exitmessage
        $exitcode = 1
    }
    else {
        $exitmessage = 'Something went wrong:' + $_
        Write-Error $exitmessage
        $exitcode = 1
    }
}

if ($exitcode -eq 0) {
    Write-Log -Message $exitmessage -Level 'OK'
    Write-Log -Message '=== Detection END (Exit 0) ==='
}
else {
    Write-Log -Message $exitmessage -Level 'WARN'
    Write-Log -Message '=== Detection END (Exit 1) ==='
}

Write-Host $exitmessage
Exit $exitcode
#endregion ================== FIRST DETECTION BLOCK ==================
