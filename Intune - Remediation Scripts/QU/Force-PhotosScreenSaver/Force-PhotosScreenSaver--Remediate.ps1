<#
.SYNOPSIS
    Remediate the Photos screen saver configuration for the current user.

.DESCRIPTION
    This remediation script applies the required Photos screen saver settings
    for the current user by writing:
    - Standard screen saver values to `HKCU:\Control Panel\Desktop`
    - Policy-enforced values to `HKCU:\Software\Policies\Microsoft\Windows\Control Panel\Desktop`
    - Photos screen saver values to `HKCU:\Software\Microsoft\Windows Photo Viewer\Slideshow\Screensaver`

    It also refreshes user system parameters so the changes appear in the UI.

    Exit codes:
    - Exit 0: Completed successfully
    - Exit 1: Failed or requires further action

.RUN AS
    User. In Intune, run this script using the logged-on credentials.

.EXAMPLE
    .\Force-PhotosScreenSaver--Remediate.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.0
#>

#region ========================= CONFIGURATION =========================
# Use a fixed script name so logging stays consistent when Intune stages the script under a temporary local file name.
$ScriptName     = 'Force-PhotosScreenSaver--Remediate.ps1'
$ScriptBaseName = 'Force-PhotosScreenSaver--Remediate'

# Detect the Windows system drive automatically instead of hard-coding C:.
$SystemDrive = if ([string]::IsNullOrWhiteSpace($env:SystemDrive)) {
    [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\')
}
else {
    $env:SystemDrive.TrimEnd('\')
}

# Expected Photos screen saver values.
$EncryptedPIDL = @"
FAAfWA0aLPAhvlBDiLBzZ/yW7zy7AAAAtQC7r5M7pwAEAAAAAAAtAAAAMVNQU3ND
5Qq+Q61PheRp3IYzmG4RAAAACwAAAAALAAAA//8AAAAAAABJAAAAMVNQUzDxJbfv
RxoQpfECYIye66wtAAAACgAAAAAfAAAADgAAAFEAYQBzAHMAaQBtAFUALgBsAG8A
YwBhAGwAAAAAAAAALQAAADFTUFM6pL3eszeDQ5HnRJjaKZWrEQAAAAMAAAAAEwAA
AAAAAAAAAAAAAAAAAAAARADDAcVcXFFhc3NpbVUubG9jYWxcU1lTVk9MAE1pY3Jv
c29mdCBOZXR3b3JrAExvZ29uIHNlcnZlciBzaGFyZSAAAgBoADEAAAAAAD5acToQ
BFFBU1NJTX4xLkxPQwAATAAJAAQA774+WnE6PlpxOi4AAACvuAEAAAADAAAAAAAD
AACgAAAAAAAA5UUdAFEAYQBzAHMAaQBtAFUALgBsAG8AYwBhAGwAAAAcAGwAMQAA
AAAAWFyPQBAAU0NSRUVOfjEAAFQACQAEAO++WFx6QFhcj0AuAAAA2W0BAAAA+yIA
AAAAAAAAAAAAAAAAAC275wBTAGMAcgBlAGUAbgBTAGEAdgBlAHIAUABoAG8AdABv
AHMAAAAYAAAA
"@ -replace "\r?\n",""

$TimeOutSeconds  = 600
$RequirePassword = 0
$Shuffle         = 1
$Speed           = 1
$ScreenSaverExe  = "%SystemRoot%\System32\PhotoScreensaver.scr"

#endregion ====================== CONFIGURATION ======================
#region ========================= PATHS AND LOGGING =========================
# Script-specific logging location.
$SolutionName = "Force-PhotosScreenSaver"
$BasePath     = Join-Path (Join-Path $SystemDrive 'Intune') $SolutionName

# Remediation-specific log file.
$LogFile      = Join-Path $BasePath ("{0}.txt" -f $ScriptBaseName)
#endregion ====================== PATHS AND LOGGING ======================
#region ========================= HELPER FUNCTIONS =========================
# Ensure the log directory and file exist before any write attempts.
function Initialize-Logging {
    try {
        if (-not (Test-Path -Path $BasePath)) {
            New-Item -Path $BasePath -ItemType Directory -Force -ErrorAction Stop | Out-Null
        }
        if (-not (Test-Path -Path $LogFile)) {
            New-Item -Path $LogFile -ItemType File -Force -ErrorAction Stop | Out-Null
        }
        return $true
    }
    catch {
        # If logging init fails, the script still continues with console output.
        return $false
    }
}

function Start-LogRun {
    # Add a visual separator so each run is easier to scan in the same log file.
    if (Get-Command -Name Initialize-LogFile -ErrorAction SilentlyContinue) {
        Initialize-LogFile
    }
    elseif (Get-Command -Name Initialize-Logging -ErrorAction SilentlyContinue) {
        Initialize-Logging | Out-Null
    }
    $logTarget = $null
    foreach ($name in @('LogFile', 'LogFilePath')) {
        $var = Get-Variable -Name $name -Scope Script -ErrorAction SilentlyContinue
        if ($var -and -not [string]::IsNullOrWhiteSpace([string]$var.Value)) {
            $logTarget = [string]$var.Value
            break
        }
    }
    if ([string]::IsNullOrWhiteSpace($logTarget)) {
        return
    }
    if (Test-Path -LiteralPath $logTarget) {
        $existingLog = Get-Item -LiteralPath $logTarget -ErrorAction SilentlyContinue
        if ($existingLog -and $existingLog.Length -gt 0) {
            Add-Content -Path $logTarget -Value '' -Encoding UTF8
        }
    }
    Add-Content -Path $logTarget -Value ('=' * 78) -Encoding UTF8
}

$LogReady = Initialize-Logging

# Write colored console output and persist the same line to the log file.
function Write-Log {
    param(
        [Parameter(Mandatory = $true)][string]$Message,
        [ValidateSet("INFO", "OK", "WARN", "FAIL")]
        [string]$Level = "INFO"
    )

    $ts   = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[{0}] [{1}] {2}" -f $ts, $Level, $Message

    switch ($Level) {
        "OK"   { Write-Host $line -ForegroundColor Green }
        "WARN" { Write-Host $line -ForegroundColor Yellow }
        "FAIL" { Write-Host $line -ForegroundColor Red }
        default { Write-Host $line -ForegroundColor Cyan }
    }

    if ($LogReady) {
        try { Add-Content -Path $LogFile -Value $line -ErrorAction SilentlyContinue } catch {}
    }
}

# Create or update a registry value, creating the key first if needed.
function New-OrSetRegValue {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)]$Value,
        [Parameter(Mandatory = $true)][ValidateSet('String', 'ExpandString', 'DWord')][string]$Type
    )

    if (-not (Test-Path -Path $Path)) {
        New-Item -Path $Path -Force -ErrorAction Stop | Out-Null
    }

    New-ItemProperty -Path $Path -Name $Name -Value $Value -PropertyType $Type -Force -ErrorAction Stop | Out-Null
}

# Refresh user system parameters so the new settings appear in the user interface.
function Refresh-UserSystemParameters {
    try {
        rundll32.exe user32.dll,UpdatePerUserSystemParameters 1, $true | Out-Null
    }
    catch {
        # This refresh is best effort and should not fail the remediation.
    }
}
#endregion ====================== HELPER FUNCTIONS ======================
#region ========================= FIRST REMEDIATION BLOCK =========================
Write-Log -Level "INFO" -Message "=== Remediation START ==="
Write-Log -Level "INFO" -Message ("Script: {0}" -f $ScriptName)
Write-Log -Level "INFO" -Message ("Log file: {0}" -f $LogFile)

try {
    $DesktopKey = "HKCU:\Control Panel\Desktop"
    $PolicyKey  = "HKCU:\Software\Policies\Microsoft\Windows\Control Panel\Desktop"
    $PhotosKey  = "HKCU:\Software\Microsoft\Windows Photo Viewer\Slideshow\Screensaver"

    # Apply the standard user desktop screen saver settings.
    New-OrSetRegValue -Path $DesktopKey -Name "ScreenSaveActive" -Value "1" -Type String
    New-OrSetRegValue -Path $DesktopKey -Name "ScreenSaveTimeOut" -Value ([string]$TimeOutSeconds) -Type String
    New-OrSetRegValue -Path $DesktopKey -Name "SCRNSAVE.EXE" -Value $ScreenSaverExe -Type ExpandString
    New-OrSetRegValue -Path $DesktopKey -Name "ScreenSaverIsSecure" -Value ([string]$RequirePassword) -Type String
    Write-Log -Level "OK" -Message "Standard HKCU screen saver settings applied."

    # Apply the policy-enforced desktop settings, which override standard HKCU values.
    New-OrSetRegValue -Path $PolicyKey -Name "ScreenSaveActive" -Value "1" -Type String
    New-OrSetRegValue -Path $PolicyKey -Name "ScreenSaveTimeOut" -Value ([string]$TimeOutSeconds) -Type String
    New-OrSetRegValue -Path $PolicyKey -Name "SCRNSAVE.EXE" -Value $ScreenSaverExe -Type ExpandString
    New-OrSetRegValue -Path $PolicyKey -Name "ScreenSaverIsSecure" -Value ([string]$RequirePassword) -Type String
    Write-Log -Level "OK" -Message "Policy HKCU screen saver settings applied."

    # Apply the Photos screen saver-specific values.
    New-OrSetRegValue -Path $PhotosKey -Name "EncryptedPIDL" -Value $EncryptedPIDL -Type String
    New-OrSetRegValue -Path $PhotosKey -Name "Shuffle" -Value ([int]$Shuffle) -Type DWord
    New-OrSetRegValue -Path $PhotosKey -Name "Speed" -Value ([int]$Speed) -Type DWord
    Write-Log -Level "OK" -Message "Photos screen saver settings applied."

    # Refresh the user interface state after writing the new values.
    Refresh-UserSystemParameters
    Write-Log -Level "OK" -Message "User system parameters refreshed."

    Write-Output "Remediation completed successfully for current user."
    Write-Log -Level "INFO" -Message "=== Remediation END (Exit 0) ==="
    exit 0
}
catch {
    Write-Log -Level "FAIL" -Message ("Remediation failed: {0}" -f $_.Exception.Message)
    Write-Output ("Remediation failed: {0}" -f $_.Exception.Message)
    Write-Log -Level "INFO" -Message "=== Remediation END (Exit 1) ==="
    exit 1
}

#endregion ====================== FIRST REMEDIATION BLOCK ======================
