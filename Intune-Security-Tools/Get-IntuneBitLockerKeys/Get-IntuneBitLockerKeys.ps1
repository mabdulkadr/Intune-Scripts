<#
.TITLE
    Intune BitLocker Keys

.SYNOPSIS
    Retrieves BitLocker recovery keys from Entra ID for Intune managed devices.

.DESCRIPTION
    Operates in two modes: 1. LOOKUP - Retrieve BitLocker recovery key(s) for a specific
    device by name, serial number, or Entra device ID. Designed for helpdesk key recovery. 2.
    AUDIT - Scan all Windows managed devices and report which ones have recovery keys escrowed
    to Entra ID and which are missing. Designed for security compliance auditing.

.TAGS
    Intune,BitLocker,KeyVault,Security,Audit

.PLATFORM
    Windows

.MINROLE
    Security Administrator

.PERMISSIONS
    DeviceManagementManagedDevices.Read.All,BitlockerKey.Read.All,Device.Read.All,Directory.Read.All,Group.Read.All,GroupMember.Read.All

.AUTHOR
    Mohammad Abdelkader Omar

.VERSION
    1.1.0

.CHANGELOG
    1.1.0 (2026-08-26)
    - Migrated to Enterprise Standards canonical structure (header, logging, banner, ErrorActionPreference, full cmdlet names, typed catches)
    1.0.0
    - Initial release

.LASTUPDATE
    2026-08-26

.EXAMPLE
    .\Get-IntuneBitLockerKeys.ps1 -DeviceName "L-PF4Z0HM0" -ShowKeys
    Retrieve and display recovery keys for a specific device

.EXAMPLE
    .\Get-IntuneBitLockerKeys.ps1 -SerialNumber "PF4Z0HM0"
    Look up by serial number

.EXAMPLE
    .\Get-IntuneBitLockerKeys.ps1 -Audit -ExportPath "C:\temp\bitlocker_audit.csv"
    Audit all Windows devices for escrowed keys

.NOTES
    - Requires Microsoft.Graph.Authentication module
    - Requires BitlockerKey.Read.All permission; retrieval is audited
    - Logs: %ProgramData%\get-intune-bitlocker-keys\Logs\<timestamp>.log
#>

#Requires -Version 5.1

[CmdletBinding(DefaultParameterSetName = 'ByName')]
param(
    [Parameter(Mandatory, ParameterSetName = 'ByName')]
    [string]$DeviceName,

    [Parameter(Mandatory, ParameterSetName = 'BySerial')]
    [string]$SerialNumber,

    [Parameter(Mandatory, ParameterSetName = 'Audit')]
    [switch]$Audit,

    [Parameter(ParameterSetName = 'Audit')]
    [string]$GroupName,

    [Parameter()]
    [switch]$ShowKeys,

    [Parameter()]
    [string]$ExportPath
)

$ErrorActionPreference = 'Stop'

# ============================================================================
# CONFIGURATION - solution identity for the embedded logging block.
# ============================================================================

$SolutionName = 'get-intune-bitlocker-keys'
$ScriptMode   = 'run'

# ============================================================================
# LOGGING BLOCK (embedded canonical scripts/Write-Log.ps1 - copy VERBATIM)
# Single source of truth: Initialize-Log / Write-Banner / Write-Log / Finish-Script.
# ============================================================================

# --- Logging (CLI Configuration) --------------------------------------------
$script:SystemDrive = if ($env:SystemDrive) { $env:SystemDrive.TrimEnd('\') } else {
    [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\')
}
$script:LogRoot  = $null
$script:LogFile  = $null
$script:LogReady = $false

# Creates the Intune log folder/file and reports readiness.
function Initialize-Log {
    [CmdletBinding()]
    param(
        [string]$SolutionName = 'EnterpriseAdminTool',
        [string]$ScriptMode = 'run',
        [ValidateSet('Intune', 'General')]
        [string]$Type = 'General'
    )

    try {
        if ($Type -eq 'Intune') {
            $script:LogRoot = Join-Path $script:SystemDrive "IntuneLogs\$SolutionName"
            $script:LogFile = Join-Path $script:LogRoot "$SolutionName-$ScriptMode.txt"
        } else {
            $script:LogRoot = Join-Path $env:ProgramData "$SolutionName\Logs"
            $script:LogFile = Join-Path $script:LogRoot "$SolutionName`_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
        }

        if (-not (Test-Path -LiteralPath $script:LogRoot)) {
            $null = [System.IO.Directory]::CreateDirectory($script:LogRoot)
        }
        if (-not (Test-Path -LiteralPath $script:LogFile)) {
            $null = [System.IO.File]::Create($script:LogFile).Dispose()
        }

        $script:LogReady = $true
        return $true
    }
    catch {
        Write-Host "Log initialization failed: $($_.Exception.Message)" -ForegroundColor Red
        $script:LogReady = $false
        return $false
    }
}

# Writes the solution banner to console and log file.
function Write-Banner {
    [CmdletBinding()]
    [Alias('Show-Banner')]
    param()

    $title      = '{0} | {1}' -f $SolutionName, $ScriptMode
    $bannerLine = '=' * 78
    $lines      = @('', $bannerLine, $title, $bannerLine)

    foreach ($line in $lines) {
        if ($line -eq $title) {
            Write-Host $line -ForegroundColor White
        } else {
            Write-Host $line -ForegroundColor DarkGray
        }

        if ($script:LogReady -and $script:LogFile) {
            Add-Content -LiteralPath $script:LogFile -Value $line -Encoding UTF8 -ErrorAction SilentlyContinue -WhatIf:$false
        }
    }
}

# Writes one timestamped, level-colored line to console and log file.
function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Message = "",
        [ValidateSet("INFO", "SUCCESS", "WARNING", "ERROR", "DEBUG")]
        [string]$Level = "INFO"
    )

    # Visual spacer support: callers use Write-Log -Message "" to break sections; early-return on empty.
    if ([string]::IsNullOrEmpty($Message)) { return }

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logLine = "[$timestamp] [$Level] $Message"

    $color = switch ($Level) {
        "DEBUG"   { "DarkGray" }
        "INFO"    { "Cyan" }
        "SUCCESS" { "Green" }
        "WARNING" { "Yellow" }
        "ERROR"   { "Red" }
    }
    Write-Host $logLine -ForegroundColor $color

    if ($script:LogReady -and $script:LogFile) {
        Add-Content -LiteralPath $script:LogFile -Value $logLine -Encoding UTF8 -ErrorAction SilentlyContinue -WhatIf:$false
    }
}

# Logs the final message and terminates with the given exit code.
function Finish-Script {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [int]$ExitCode,
        [Parameter(Mandatory = $false)]
        [string]$Message = "",
        [ValidateSet("INFO", "SUCCESS", "WARNING", "ERROR", "DEBUG")]
        [string]$Level = "INFO",
        [switch]$NoExit
    )

    Write-Log -Message $Message -Level $Level
    if (-not $NoExit) {
        exit $ExitCode
    }
}
# ============================================================================
# MAIN ENTRY LOGGING INITIALIZATION
# Flow: init -> banner -> modules -> Graph connection -> report generation.
# ============================================================================

$null = Initialize-Log -SolutionName $SolutionName -ScriptMode $ScriptMode -Type 'General'
Write-Banner
if ($script:LogReady) {
    Write-Log -Message "Log file ready: $($script:LogFile)" -Level 'DEBUG'
}
Write-Log -Message "Script started" -Level 'INFO'
# ============================================================================
# REPORT OUTPUT ANCHORING
# Anchor relative output paths beside the script so CSV exports land in a
# predictable location regardless of the caller's current directory.
# Fallback chain: $PSScriptRoot -> $PSCommandPath -> $MyInvocation -> Get-Location.
# ============================================================================

$scriptDirectory = if ($PSScriptRoot) {
    $PSScriptRoot
}
elseif ($PSCommandPath) {
    Split-Path -Parent $PSCommandPath
}
elseif ($MyInvocation.MyCommand.Path) {
    Split-Path -Parent $MyInvocation.MyCommand.Path
}
else {
    (Get-Location).Path
}

if ($ExportPath -and -not [System.IO.Path]::IsPathRooted($ExportPath)) {
    $ExportPath = [System.IO.Path]::GetFullPath((Join-Path $scriptDirectory $ExportPath))
}

#region --- Helpers ---
function Write-Status { param([string]$Msg,[string]$Color='Cyan'); $level = switch ($Color) { 'Red'{'ERROR'} 'Yellow'{'WARNING'} 'Green'{'SUCCESS'} 'DarkYellow'{'WARNING'} 'DarkGray'{'DEBUG'} default{'INFO'} }; Write-Log -Message $Msg -Level $level }
function Write-Section { param([string]$Msg); Write-Log -Message "=== $Msg ===" -Level 'INFO' }

function Get-MgGraphAllPages {
    param([string]$Uri, [string]$Method = 'GET')
    try {
        $response = Invoke-MgGraphRequest -Uri $Uri -Method $Method -ErrorAction Stop
        $results = @()
        if ($null -ne $response.value) { $results += $response.value }
        elseif ($response) { $results += $response }
        while ($response.'@odata.nextLink') {
            $response = Invoke-MgGraphRequest -Uri $response.'@odata.nextLink' -Method GET -ErrorAction Stop
            if ($null -ne $response.value) { $results += $response.value }
        }
        return ,$results
    }
    catch [System.Exception] {
        Write-Verbose "Graph call failed for $Uri : $_"
        return @()
    }
}

function Mask-RecoveryKey {
    param([string]$Key)
    if (-not $Key -or $Key.Length -lt 10) { return '********' }
    return $Key.Substring(0,6) + '****-****-****-****-****-****-' + $Key.Substring($Key.Length - 6)
}

function Get-BitLockerKeysForDevice {
    param([string]$EntraObjectId, [string]$DeviceDisplayName)

    $keys = @()
    try {
        # Get BitLocker recovery keys associated with this device
        $recoveryKeys = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/v1.0/informationProtection/bitlocker/recoveryKeys?`$filter=deviceId eq '$EntraObjectId'"

        foreach ($rk in $recoveryKeys) {
            # Fetch the actual key value
            $keyDetail = $null
            try {
                $keyDetail = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/informationProtection/bitlocker/recoveryKeys/$($rk.id)?`$select=key" -Method GET -ErrorAction Stop
            } catch [System.Exception] {
                Write-Verbose "Could not retrieve key value for key ID $($rk.id): $_"
            }

            $keys += @{
                KeyId         = $rk.id
                CreatedDateTime = $rk.createdDateTime
                VolumeType    = $rk.volumeType
                RecoveryKey   = if ($keyDetail -and $keyDetail.key) { $keyDetail.key } else { '(Access denied or unavailable)' }
            }
        }
    } catch [System.Exception] {
        Write-Verbose "Failed to retrieve BitLocker keys for device $DeviceDisplayName : $_"
    }

    return $keys
}
#endregion

#region --- Authentication ---
Write-Section "AUTHENTICATION"
$context = Get-MgContext
if (-not $context) {
    Write-Status "Connecting to Microsoft Graph..." "White"
    Connect-MgGraph -Scopes @(
        'DeviceManagementManagedDevices.Read.All',
        'BitlockerKey.Read.All',
        'Device.Read.All',
        'Directory.Read.All',
        'Group.Read.All',
        'GroupMember.Read.All'
    ) -ErrorAction Stop
    $context = Get-MgContext
}
Write-Status "Signed in as: $($context.Account)" "Green"
Write-Log -Message "" -Level 'INFO'
Write-Log -Message "  NOTE: BitLockerKey.Read.All permission is required." -Level 'DEBUG'
Write-Log -Message "  Key retrieval is audited in the Entra ID audit log." -Level 'DEBUG'
#endregion

if ($Audit) {
    #region --- Audit Mode ---
    Write-Section "BITLOCKER KEY AUDIT"

    # Get target devices
    $targetDevices = @()

    if ($GroupName) {
        Write-Status "Resolving group: $GroupName"
        $groups = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/v1.0/groups?`$filter=displayName eq '$($GroupName -replace "'","''")'"
        if ($groups.Count -eq 0) {
            Write-Log -Message "  ERROR: Group '$GroupName' not found." -Level 'ERROR'
            return
        }
        $groupId = $groups[0].id
        Write-Status "Group: $($groups[0].displayName)"

        $members = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/v1.0/groups/$groupId/members?`$select=id,deviceId,displayName,@odata.type"
        $deviceMembers = $members | Where-Object { $_.'@odata.type' -eq '#microsoft.graph.device' }

        if ($deviceMembers.Count -gt 0) {
            foreach ($dm in $deviceMembers) {
                if ($dm.deviceId) {
                    $md = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceManagement/managedDevices?`$filter=azureADDeviceId eq '$($dm.deviceId)' and operatingSystem eq 'Windows'"
                    $targetDevices += $md
                }
            }
        } else {
            $userMembers = $members | Where-Object { $_.'@odata.type' -eq '#microsoft.graph.user' }
            foreach ($um in $userMembers) {
                $ud = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceManagement/managedDevices?`$filter=userId eq '$($um.id)' and operatingSystem eq 'Windows'"
                $targetDevices += $ud
            }
        }
    } else {
        Write-Status "Fetching all Windows managed devices..."
        $targetDevices = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceManagement/managedDevices?`$filter=operatingSystem eq 'Windows'&`$select=id,deviceName,azureADDeviceId,userPrincipalName,serialNumber,complianceState,isEncrypted,operatingSystem,osVersion,model,lastSyncDateTime"
    }

    Write-Status "$($targetDevices.Count) Windows devices to audit" "Green"

    # Build Entra device lookup
    Write-Status "Loading Entra ID device records..."
    $entraDevices = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/v1.0/devices?`$select=id,deviceId,displayName"
    $entraLookup = @{}
    foreach ($ed in $entraDevices) {
        if ($ed.deviceId) { $entraLookup[$ed.deviceId] = $ed }
    }

    # Get all BitLocker recovery keys in the tenant
    Write-Status "Fetching all BitLocker recovery keys from Entra ID..."
    $allKeys = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/v1.0/informationProtection/bitlocker/recoveryKeys?`$select=id,createdDateTime,deviceId,volumeType"
    Write-Status "$($allKeys.Count) recovery keys found in tenant" "Green"

    # Build a set of Entra object IDs that have keys
    $devicesWithKeys = @{}
    foreach ($k in $allKeys) {
        if ($k.deviceId) {
            if (-not $devicesWithKeys.ContainsKey($k.deviceId)) {
                $devicesWithKeys[$k.deviceId] = @()
            }
            $devicesWithKeys[$k.deviceId] += $k
        }
    }

    $auditReport = [System.Collections.Generic.List[PSCustomObject]]::new()
    $hasKeyCount = 0
    $missingKeyCount = 0
    $noEntraCount = 0
    $deviceIndex = 0

    foreach ($device in $targetDevices) {
        $deviceIndex++
        if ($deviceIndex % 50 -eq 0) {
            Write-Progress -Activity "Auditing BitLocker keys" -Status "$deviceIndex of $($targetDevices.Count)" -PercentComplete (($deviceIndex / $targetDevices.Count) * 100)
        }

        $entraRecord = if ($device.azureADDeviceId) { $entraLookup[$device.azureADDeviceId] } else { $null }

        if (-not $entraRecord) {
            $noEntraCount++
            $auditReport.Add([PSCustomObject]@{
                DeviceName        = $device.deviceName
                UserPrincipalName = $device.userPrincipalName
                SerialNumber      = $device.serialNumber
                OSVersion         = $device.osVersion
                Model             = $device.model
                IsEncrypted       = $device.isEncrypted
                ComplianceState   = $device.complianceState
                KeyStatus         = 'NO ENTRA RECORD'
                KeyCount          = 0
                LatestKeyDate     = '-'
                VolumeTypes       = '-'
                LastSync          = $device.lastSyncDateTime
                IntuneDeviceId    = $device.id
                EntraDeviceId     = $device.azureADDeviceId
            })
            continue
        }

        $entraObjectId = $entraRecord.id
        $deviceKeys = $devicesWithKeys[$entraObjectId]

        if ($deviceKeys -and $deviceKeys.Count -gt 0) {
            $hasKeyCount++
            $latestKey = ($deviceKeys | Sort-Object createdDateTime -Descending | Select-Object -First 1).createdDateTime
            $volumeTypes = ($deviceKeys | Select-Object -ExpandProperty volumeType -Unique) -join ', '

            $auditReport.Add([PSCustomObject]@{
                DeviceName        = $device.deviceName
                UserPrincipalName = $device.userPrincipalName
                SerialNumber      = $device.serialNumber
                OSVersion         = $device.osVersion
                Model             = $device.model
                IsEncrypted       = $device.isEncrypted
                ComplianceState   = $device.complianceState
                KeyStatus         = 'KEY ESCROWED'
                KeyCount          = $deviceKeys.Count
                LatestKeyDate     = $latestKey
                VolumeTypes       = $volumeTypes
                LastSync          = $device.lastSyncDateTime
                IntuneDeviceId    = $device.id
                EntraDeviceId     = $device.azureADDeviceId
            })
        } else {
            $missingKeyCount++
            $auditReport.Add([PSCustomObject]@{
                DeviceName        = $device.deviceName
                UserPrincipalName = $device.userPrincipalName
                SerialNumber      = $device.serialNumber
                OSVersion         = $device.osVersion
                Model             = $device.model
                IsEncrypted       = $device.isEncrypted
                ComplianceState   = $device.complianceState
                KeyStatus         = 'KEY MISSING'
                KeyCount          = 0
                LatestKeyDate     = '-'
                VolumeTypes       = '-'
                LastSync          = $device.lastSyncDateTime
                IntuneDeviceId    = $device.id
                EntraDeviceId     = $device.azureADDeviceId
            })
        }
    }

    Write-Progress -Activity "Auditing BitLocker keys" -Completed

    # Summary
    Write-Section "BITLOCKER AUDIT SUMMARY"
    Write-Log -Message "" -Level 'INFO'
    Write-Log -Message "  Total Windows devices  : $($targetDevices.Count)" -Level 'INFO'
    Write-Log -Message "  Keys escrowed          : $hasKeyCount" -Level 'SUCCESS'
    Write-Log -Message "  Keys MISSING           : $missingKeyCount" -Level 'WARNING'
    Write-Log -Message "  No Entra record        : $noEntraCount" -Level 'WARNING'

    if ($targetDevices.Count -gt 0) {
        $escrowRate = [math]::Round(($hasKeyCount / $targetDevices.Count) * 100, 1)
        $rateColor = if ($escrowRate -ge 95) { 'Green' } elseif ($escrowRate -ge 80) { 'Yellow' } else { 'Red' }
        Write-Log -Message "" -Level 'INFO'
        Write-Log -Message "  Key Escrow Rate        : $escrowRate%" -Level 'INFO'
    }

    # Show devices missing keys
    $missingDevices = $auditReport | Where-Object { $_.KeyStatus -eq 'KEY MISSING' }
    if ($missingDevices.Count -gt 0) {
        Write-Section "DEVICES MISSING BITLOCKER KEYS ($($missingDevices.Count))"
        Write-Log -Message "" -Level 'INFO'
        foreach ($md in ($missingDevices | Select-Object -First 20)) {
            $encColor = if ($md.IsEncrypted -eq $true) { 'Yellow' } else { 'Red' }
            $encText  = if ($md.IsEncrypted -eq $true) { 'Encrypted (key not escrowed)' } else { 'NOT encrypted' }
            Write-Log -Message "    $($md.DeviceName)" -Level 'INFO'
            Write-Log -Message " | $($md.UserPrincipalName)" -Level 'INFO'
            Write-Log -Message " | $encText" -Level 'INFO'
        }
        if ($missingDevices.Count -gt 20) {
            Write-Log -Message "    ... and $($missingDevices.Count - 20) more (see CSV export)" -Level 'DEBUG'
        }
        Write-Log -Message "" -Level 'INFO'
    }

    # Encrypted but no key - worst case
    $encryptedNoKey = $missingDevices | Where-Object { $_.IsEncrypted -eq $true }
    if ($encryptedNoKey.Count -gt 0) {
        Write-Log -Message "  WARNING: $($encryptedNoKey.Count) device(s) are encrypted but have NO recovery key escrowed!" -Level 'ERROR'
        Write-Log -Message "  If these devices lose their TPM or OS, recovery will be impossible." -Level 'ERROR'
        Write-Log -Message "" -Level 'INFO'
    }

    # Export
    if ($auditReport.Count -gt 0) {
        if ($ExportPath) {
            $auditReport | Export-Csv -Path $ExportPath -NoTypeInformation -Encoding UTF8
            Write-Status "Exported $($auditReport.Count) rows to: $ExportPath" "Green"
        } else {
            $scopeSafe = if ($GroupName) { $GroupName -replace '[^\w\-]','_' } else { 'AllWindows' }
            $defaultPath = Join-Path $env:TEMP "$scopeSafe`_BitLockerAudit_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
            $auditReport | Export-Csv -Path $defaultPath -NoTypeInformation -Encoding UTF8
            Write-Status "Auto-exported $($auditReport.Count) rows to: $defaultPath" "Green"
        }
    }
    #endregion

} else {
    #region --- Lookup Mode ---
    Write-Section "BITLOCKER KEY LOOKUP"

    # Resolve the device
    if ($DeviceName) {
        Write-Status "Searching for device: $DeviceName"
        $devices = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceManagement/managedDevices?`$filter=deviceName eq '$DeviceName'&`$select=id,deviceName,azureADDeviceId,userPrincipalName,serialNumber,operatingSystem,osVersion,model,manufacturer,isEncrypted,complianceState"
    } else {
        Write-Status "Searching for serial number: $SerialNumber"
        $devices = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceManagement/managedDevices?`$filter=serialNumber eq '$SerialNumber'&`$select=id,deviceName,azureADDeviceId,userPrincipalName,serialNumber,operatingSystem,osVersion,model,manufacturer,isEncrypted,complianceState"
    }

    if ($devices.Count -eq 0) {
        $searchTerm = if ($DeviceName) { $DeviceName } else { $SerialNumber }
        Write-Log -Message "  ERROR: Device '$searchTerm' not found in Intune." -Level 'ERROR'
        return
    }

    $device = $devices[0]

    Write-Log -Message "" -Level 'INFO'
    Write-Log -Message "  Device Name    : $($device.deviceName)" -Level 'INFO'
    Write-Log -Message "  Serial Number  : $($device.serialNumber)" -Level 'INFO'
    Write-Log -Message "  User           : $($device.userPrincipalName)" -Level 'INFO'
    Write-Log -Message "  OS             : $($device.operatingSystem) $($device.osVersion)" -Level 'INFO'
    Write-Log -Message "  Model          : $($device.manufacturer) $($device.model)" -Level 'INFO'
    Write-Log -Message "  Encrypted      : $($device.isEncrypted)" -Level 'WARNING'
    Write-Log -Message "  Compliance     : $($device.complianceState)" -Level 'WARNING'

    # Resolve to Entra device object
    $entraDeviceId = $device.azureADDeviceId
    if (-not $entraDeviceId) {
        Write-Log -Message "" -Level 'INFO'
        Write-Log -Message "  ERROR: Device has no Azure AD Device ID. Cannot retrieve BitLocker keys." -Level 'ERROR'
        return
    }

    $entraDevices = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/v1.0/devices?`$filter=deviceId eq '$entraDeviceId'&`$select=id,deviceId,displayName"
    if ($entraDevices.Count -eq 0) {
        Write-Log -Message "" -Level 'INFO'
        Write-Log -Message "  ERROR: No matching Entra ID device record found." -Level 'ERROR'
        return
    }

    $entraObjectId = $entraDevices[0].id

    # Retrieve keys
    Write-Status "Retrieving BitLocker recovery keys..."
    $keys = Get-BitLockerKeysForDevice -EntraObjectId $entraObjectId -DeviceDisplayName $device.deviceName

    $keyReport = [System.Collections.Generic.List[PSCustomObject]]::new()

    if ($keys.Count -eq 0) {
        Write-Log -Message "" -Level 'INFO'
        Write-Log -Message "  No BitLocker recovery keys found for this device in Entra ID." -Level 'WARNING'
        if ($device.isEncrypted) {
            Write-Log -Message "  WARNING: Device reports as encrypted but no key is escrowed!" -Level 'ERROR'
        }
    } else {
        Write-Log -Message "" -Level 'INFO'
        Write-Log -Message "  Found $($keys.Count) recovery key(s):" -Level 'SUCCESS'
        Write-Log -Message "" -Level 'INFO'

        foreach ($key in ($keys | Sort-Object CreatedDateTime -Descending)) {
            $displayKey = if ($ShowKeys) { $key.RecoveryKey } else { Mask-RecoveryKey $key.RecoveryKey }

            Write-Log -Message "    Volume     : $($key.VolumeType)" -Level 'INFO'
            Write-Log -Message "    Key ID     : $($key.KeyId)" -Level 'INFO'
            Write-Log -Message "    Created    : $($key.CreatedDateTime)" -Level 'INFO'
            Write-Log -Message "    Key        : $displayKey" -Level 'WARNING'
            if (-not $ShowKeys) {
                Write-Log -Message "                 (use -ShowKeys to display full recovery key)" -Level 'DEBUG'
            }
            Write-Log -Message "" -Level 'INFO'

            $keyReport.Add([PSCustomObject]@{
                DeviceName    = $device.deviceName
                SerialNumber  = $device.serialNumber
                UserPrincipalName = $device.userPrincipalName
                VolumeType    = $key.VolumeType
                KeyId         = $key.KeyId
                RecoveryKey   = $key.RecoveryKey
                CreatedDateTime = $key.CreatedDateTime
                IsEncrypted   = $device.isEncrypted
                OSVersion     = $device.osVersion
                Model         = "$($device.manufacturer) $($device.model)"
            })
        }
    }

    # Export
    if ($keyReport.Count -gt 0) {
        if ($ExportPath) {
            $keyReport | Export-Csv -Path $ExportPath -NoTypeInformation -Encoding UTF8
            Write-Status "Exported to: $ExportPath" "Green"
            Write-Log -Message "  WARNING: CSV contains full recovery keys. Store securely!" -Level 'WARNING'
        } else {
            $safeName = $device.deviceName -replace '[^\w\-]','_'
            $defaultPath = Join-Path $env:TEMP "$safeName`_BitLockerKeys_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
            $keyReport | Export-Csv -Path $defaultPath -NoTypeInformation -Encoding UTF8
            Write-Status "Auto-exported to: $defaultPath" "Green"
            Write-Log -Message "  WARNING: CSV contains full recovery keys. Store securely!" -Level 'WARNING'
        }
    }
    #endregion
}

Write-Log -Message "`n$('='*60)" -Level 'DEBUG'
