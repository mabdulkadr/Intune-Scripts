<#
.SYNOPSIS
    Detect which Windows Hello for Business sign-in methods are enrolled for the current user.

.DESCRIPTION
    This detection-only script checks the current user's Windows Hello for
    Business (WHfB) enrollment state by reading:

        HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Authentication\Credential Providers\{D6886603-9D2F-4EB2-B667-1971041FA96B}\<UserSID>
        HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WinBio\AccountInfo\<UserSID>

    The script first verifies whether a PIN is available. If it is, it then
    checks whether biometric enrollment exists and reports the enrolled method:
    - PIN configured
    - Face configured
    - Fingerprint configured
    - Face and Fingerprint configured
    - Unknown Biometric configured

    Exit codes:
    - Exit 0: A Windows Hello sign-in method is enrolled
    - Exit 1: Windows Hello is not configured or the enrollment state cannot be read

.RUN AS
    User

.EXAMPLE
    .\GetWH4BEnrolledMethods--Detect.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.0
#>

#region ========================= CONFIGURATION =========================
# Use a fixed script name so logging stays consistent when Intune stages the script under a temporary local file name.
$ScriptName     = 'GetWH4BEnrolledMethods--Detect.ps1'
$ScriptBaseName = 'GetWH4BEnrolledMethods--Detect'

# Store the user-context log under the current user's temp folder.
$LogRoot      = Join-Path $env:TEMP 'Logs'
$SolutionName = 'GetWH4BEnrolledMethods'
$BasePath     = Join-Path $LogRoot $SolutionName
$LogFile      = Join-Path $BasePath ("{0}_{1}.txt" -f $env:COMPUTERNAME, $ScriptBaseName)

# Registry values used by the original script.
$LoggedOnUserSID = [System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value
$PinKeyPath      = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Authentication\Credential Providers\{D6886603-9D2F-4EB2-B667-1971041FA96B}\$LoggedOnUserSID"
$BioKeyPath      = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WinBio\AccountInfo\$LoggedOnUserSID"
$BioValueName    = 'EnrolledFactors'
$PinValueName    = 'LogonCredsAvailable'
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
    $line      = "[$timestamp] [$Level] $Message"

    switch ($Level) {
        'OK'   { Write-Host $line -ForegroundColor Green }
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

$exitCode    = 1
$exitMessage = 'Uncaught error'

try {
    # Check whether Windows Hello PIN enrollment exists for the current user.
    $pinSetup = Get-ItemProperty -Path $PinKeyPath -Name $PinValueName -ErrorAction Continue

    if ([int]$pinSetup.LogonCredsAvailable -eq 1) {
        # If biometric enrollment exists, identify which enrolled factors are present.
        if (Test-Path -Path $BioKeyPath) {
            $bioMetrics = Get-ItemProperty -Path $BioKeyPath -Name $BioValueName -ErrorAction Continue

            if ($bioMetrics) {
                $exitCode = 0

                switch ($bioMetrics.EnrolledFactors) {
                    0xa { $exitMessage = 'Face and Fingerprint configured' }
                    0x2 { $exitMessage = 'Face configured' }
                    0x8 { $exitMessage = 'Fingerprint configured' }
                    default { $exitMessage = 'Unknown Biometric configured' }
                }
            }
            else {
                $exitMessage = 'LogonCredsAvailable Value is not there'
                Write-Log -Message $exitMessage -Level 'WARN'
                $exitCode = 1
            }
        }
        else {
            $exitMessage = 'PIN configured'
            $exitCode = 0
        }
    }
    else {
        $exitMessage = 'Windows Hello not configured'
        Write-Log -Message $exitMessage -Level 'WARN'
        $exitCode = 1
    }
}
catch {
    if ([string]$_.Exception -like '*Cannot find path*') {
        $exitMessage = 'Windows Hello not configured'
        Write-Log -Message $exitMessage -Level 'WARN'
        $exitCode = 1
    }
    else {
        $exitMessage = 'Something went wrong: ' + $_
        Write-Log -Message $exitMessage -Level 'FAIL'
        $exitCode = 1
    }
}

if ($exitCode -eq 0) {
    Write-Log -Message $exitMessage -Level 'OK'
}
elseif ($exitMessage -notin @('Windows Hello not configured', 'LogonCredsAvailable Value is not there')) {
    Write-Log -Message $exitMessage -Level 'WARN'
}

Write-Host $exitMessage
Write-Log -Message "=== Detection END (Exit $exitCode) ==="
exit $exitCode
#endregion ================== FIRST DETECTION BLOCK ==================
