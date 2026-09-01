<#
.TITLE
    Sync Devices

.SYNOPSIS
    Trigger synchronization on specific managed devices in Intune or devices in an Entra ID group.

.DESCRIPTION
    This script connects to Microsoft Graph and triggers synchronization operations on targeted devices.
    You can target devices by specific names, device IDs, or by Entra ID group membership.
    The script provides real-time feedback on sync operations and handles errors gracefully.

    Workstation authentication modes:
    - Interactive (default): auto-installs Microsoft.Graph.Authentication if missing and connects with delegated scopes via Connect-MgGraph / Connect-MgGraphCommunity (WAM-free when available).
    - App-only (optional): provide -TenantId, -ClientId and either -ClientSecret or -CertificateThumbprint for unattended service-principal authentication.
    Pass -TenantId, -ClientId and -ClientSecret (or -CertificateThumbprint) together to use app-only; otherwise interactive delegated authentication is used.
.TAGS
    Operational,Devices

.PLATFORM
    Windows

.MINROLE
    Intune Administrator

.PERMISSIONS
    DeviceManagementManagedDevices.PrivilegedOperations.All,DeviceManagementManagedDevices.Read.All,GroupMember.Read.All

.AUTHOR
    Mohammad Abdelkader Omar

.VERSION
    1.8.1

.CHANGELOG
    1.8.1 (2026-08-26)
    - Migrated to Enterprise Admin standards (canonical header order, structured logging, PS 5.1 contract)
    1.8 - Let the finally block own Graph disconnection so early exits do not emit a second-disconnect error
    1.7 - Ignore empty string-array values supplied by workstation when validating the selected target
    1.6 - Added a portal-safe DryRun mode and records an empty target group as a successful no-op
    1.5 - Added workstation contract validation, portal-safe boolean parameters, beta Graph endpoints, and terminating paging errors
    1.4 - workstation now records script progress, outcomes, and summaries in job history
    1.3 - Exit code 1 when any sync fails; 429 retry with 60s wait on sync calls; group matching now falls back to userPrincipalName/mail so user-membership groups work; group lookup failures abort with a distinct error; added field projections (`$select`) to managed device queries
    1.2 - Local runs now use MgGraphCommunity for WAM-free interactive sign-in (auto-installed if missing)
    1.1 - Improved authentication scopes and fixed group device members search
        - added `DeviceManagementManagedDevices.PrivilegedOperations.All` scope for interactive Graph auth
        - fixed `Get-DevicesByEntraGroup` to correctly match devices by `azureADDeviceId`
        - replaced `+=` with `[System.Collections.Generic.List[Object]]` for faster result handling
        - standardized string quoting to single quotes
        - optimized `Get-MgGraphAllPages` with strongly typed list
        - replaced `Out-Null` with `$null =` assignment for cleaner output suppression
        - improved consistency in logging and error handling
    1.0 - Initial release

.LASTUPDATE
    2026-08-26

.EXAMPLE
    .\sync-devices.ps1 -DeviceNames "LAPTOP001","DESKTOP002"
    Synchronizes specific devices by name

.EXAMPLE
    .\sync-devices.ps1 -DeviceIds "12345678-1234-1234-1234-123456789012","87654321-4321-4321-4321-210987654321"
    Synchronizes specific devices by their Intune device IDs

.EXAMPLE
    .\sync-devices.ps1 -EntraGroupName "IT Department Devices"
    Synchronizes all devices belonging to users in the specified Entra ID group

.EXAMPLE
    .\sync-devices.ps1 -EntraGroupName "Sales Team" -ForceSync "true"
    Forces synchronization of all devices for users in the Sales Team group

.EXAMPLE
    .\sync-devices.ps1 -EntraGroupName "Sales Team" -DryRun "true"
    Lists the target devices without sending a synchronization action

.NOTES
    - Supports workstation dual-mode authentication: interactive (default) or app-only via -TenantId/-ClientId/-ClientSecret or -CertificateThumbprint
    - Local execution: Uses interactive authentication with specified scopes
    - workstation: Uses Managed Identity authentication
    - Requires Microsoft.Graph.Authentication module (auto-installs if missing in local environment)
    - Use -ForceModuleInstall to skip installation prompts in local environment
    - Requires appropriate permissions in Entra ID
    - Sync operations are triggered immediately but may take time to complete on the device
    - Use -ForceSync to override the 1-hour sync threshold
    - The script will show real-time progress and results
    - Local interactive sign-in uses the MgGraphCommunity module to avoid the Graph SDK's mandatory WAM broker on Windows
#>

#Requires -Version 5.1

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string[]]$DeviceNames,

    [Parameter(Mandatory = $false)]
    [string[]]$DeviceIds,

    [Parameter(Mandatory = $false)]
    [string]$EntraGroupName,

    [Parameter(Mandatory = $false)]
    [ValidateSet("true", "false", "1", "0", '$true', '$false')]
    [string]$ForceSync,

    [Parameter(Mandatory = $false, HelpMessage = "Preview target devices without synchronizing them")]
    [ValidateSet("true", "false", "1", "0", '$true', '$false')]
    [string]$DryRun,

    [Parameter(Mandatory = $false)]
    [int]$SyncDelaySeconds = 2,

    [Parameter(Mandatory = $false, HelpMessage = 'Force module installation without prompting')]
    [ValidateSet("true", "false", "1", "0", '$true', '$false')]
    [string]$ForceModuleInstall,

    [Parameter(Mandatory = $false, HelpMessage = "Tenant ID for app-only authentication")]
    [string]$TenantId,

    [Parameter(Mandatory = $false, HelpMessage = "Client ID for app-only authentication")]
    [string]$ClientId,

    [Parameter(Mandatory = $false, HelpMessage = "Client secret for app-only authentication")]
    [string]$ClientSecret,

    [Parameter(Mandatory = $false, HelpMessage = "Certificate thumbprint for app-only authentication")]
    [string]$CertificateThumbprint
)

$ErrorActionPreference = 'Stop'

# Normalize the local module-install override for workstation parameter binding.
$forceModuleInstallRaw = [string]$ForceModuleInstall,

    [Parameter(Mandatory = $false, HelpMessage = "Tenant ID for app-only authentication")]
    [string]$TenantId,

    [Parameter(Mandatory = $false, HelpMessage = "Client ID for app-only authentication")]
    [string]$ClientId,

    [Parameter(Mandatory = $false, HelpMessage = "Client secret for app-only authentication")]
    [string]$ClientSecret,

    [Parameter(Mandatory = $false, HelpMessage = "Certificate thumbprint for app-only authentication")]
    [string]$CertificateThumbprint
Remove-Variable -Name ForceModuleInstall
if ([string]::IsNullOrWhiteSpace($forceModuleInstallRaw)) {
    $ForceModuleInstall = $false
}
elseif ($forceModuleInstallRaw.Trim().ToLowerInvariant() -in @("true", "1", '$true')) {
    $ForceModuleInstall = $true
}
elseif ($forceModuleInstallRaw.Trim().ToLowerInvariant() -in @("false", "0", '$false')) {
    $ForceModuleInstall = $false
}
else {
    throw "Parameter 'ForceModuleInstall' accepts only true, false, 1, 0, $true, or $false."
}

# workstation supplies portal parameter values as strings. Normalize the
# public boolean parameters once so local and runbook execution use real booleans.
foreach ($runbookBooleanParameter in @('ForceSync', 'DryRun')) {
    $runbookBooleanRaw = [string](Get-Variable -Name $runbookBooleanParameter -ValueOnly)
    Remove-Variable -Name $runbookBooleanParameter

    if ([string]::IsNullOrWhiteSpace($runbookBooleanRaw)) {
        Set-Variable -Name $runbookBooleanParameter -Value $false
        continue
    }

    switch ($runbookBooleanRaw.Trim().ToLowerInvariant()) {
        { $_ -in @("true", "1", '$true') } {
            Set-Variable -Name $runbookBooleanParameter -Value $true
        }
        { $_ -in @("false", "0", '$false') } {
            Set-Variable -Name $runbookBooleanParameter -Value $false
        }
        default {
            throw "Parameter '$runbookBooleanParameter' accepts only true, false, 1, 0, $true, or $false."
        }
    }
}

$DeviceNames = @($DeviceNames | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
$DeviceIds = @($DeviceIds | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })

$selectedTargets = @(
    if ($DeviceNames.Count -gt 0) { 'DeviceNames' }
    if ($DeviceIds.Count -gt 0) { 'DeviceIds' }
    if (-not [string]::IsNullOrWhiteSpace($EntraGroupName)) { 'EntraGroup' }
)
if ($selectedTargets.Count -ne 1) {
    throw "Specify exactly one target: DeviceNames, DeviceIds, or EntraGroupName."
}
$TargetMode = $selectedTargets[0]

# ============================================================================
# CONFIGURATION - solution identity used by the logging helpers.
# ============================================================================

$SolutionName = 'sync-devices'
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
# ENVIRONMENT DETECTION AND SETUP
# ============================================================================

function Initialize-RequiredModule {
    <#
    .SYNOPSIS
    Ensures required modules are available and loaded
    #>
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string[]]$ModuleNames,

        [Parameter(Mandatory = $false)]
        [bool]$ForceInstall = $false
    )

    foreach ($ModuleName in $ModuleNames) {
        Write-Verbose "Checking module: $ModuleName"

        $module = Get-Module -ListAvailable -Name $ModuleName | Select-Object -First 1

        if (-not $module) {
            Write-Information "Module '$ModuleName' not found. Attempting to install..." -InformationAction Continue

            if (-not $ForceInstall) {
                $response = Read-Host "Install module '$ModuleName'? (Y/N)"
                if ($response -notmatch '^[Yy]') {
                    throw "Module '$ModuleName' is required but installation was declined."
                }
            }

            try {
                $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
                $scope = if ($isAdmin) { "AllUsers" } else { "CurrentUser" }

                Write-Information "Installing '$ModuleName' in scope '$scope'..." -InformationAction Continue
                Install-Module -Name $ModuleName -Scope $scope -Force -AllowClobber -Repository PSGallery
                Write-Information "Successfully installed '$ModuleName'" -InformationAction Continue
            }
            catch {
                throw "Failed to install module '$ModuleName': $($_.Exception.Message)"
            }
        }

        try {
            Write-Verbose "Importing module: $ModuleName"
            Import-Module -Name $ModuleName -Force -ErrorAction Stop
            Write-Verbose "Successfully imported '$ModuleName'"
        }
        catch {
            throw "Failed to import module '$ModuleName': $($_.Exception.Message)"
        }
    }
}

# Workstation execution (no runbook detection)

# Initialize required modules
$RequiredModules = @('Microsoft.Graph.Authentication')
# MgGraphCommunity gives WAM-free interactive sign-in for local runs
$RequiredModules += "MgGraphCommunity"

try {
    Initialize-RequiredModule -ModuleNames $RequiredModules -ForceInstall $ForceModuleInstall
    Write-Verbose '✓ All required modules are available'
}
catch {
    Write-Error "Module initialization failed: $_"
    exit 1
}

# ============================================================================
# AUTHENTICATION (workstation dual-mode: interactive or app-only)
# ============================================================================

try {
    if ($TenantId -and $ClientId -and ($ClientSecret -or $CertificateThumbprint)) {
        Write-Output "Connecting to Microsoft Graph with app-only authentication..."
        if ($CertificateThumbprint) {
            Connect-MgGraph -TenantId $TenantId -ClientId $ClientId -CertificateThumbprint $CertificateThumbprint -NoWelcome -ErrorAction Stop
        }
        else {
            $ClientSecretSecure = ConvertTo-SecureString -String $ClientSecret -AsPlainText -Force
            $ClientSecretCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $ClientId, $ClientSecretSecure
            Connect-MgGraph -TenantId $TenantId -ClientSecretCredential $ClientSecretCredential -NoWelcome -ErrorAction Stop
        }
        Write-Output "Successfully connected to Microsoft Graph with app-only authentication."
    }
    else {
        Write-Output "Connecting to Microsoft Graph with interactive authentication..."
        $scopes = @('DeviceManagementManagedDevices.PrivilegedOperations.All', 'DeviceManagementManagedDevices.Read.All')
        if ($TargetMode -eq 'EntraGroup') {
            $scopes += "GroupMember.Read.All"
        }
        Connect-MgGraphCommunity -Scopes $scopes -NoWelcome -ErrorAction Stop
        Write-Output "Successfully connected to Microsoft Graph."
    }
}
catch {
    Write-Error "Failed to connect to Microsoft Graph: $($_.Exception.Message)"
    exit 1
}

# Function to get all pages of results
function Get-MgGraphAllPages {
    param(
        [string]$Uri,
        [int]$DelayMs = 100
    )

    [System.Collections.Generic.List[PSCustomObject]]$allResults = @()
    $nextLink = $Uri
    $requestCount = 0

    do {
        try {
            # Add delay to respect rate limits
            if ($requestCount -gt 0) {
                Start-Sleep -Milliseconds $DelayMs
            }

            $response = Invoke-MgGraphRequest -Uri $nextLink -Method GET
            $requestCount++

            if ($null -ne $response.value) {
                $response.value | ForEach-Object {
                    $allResults.Add($_)
                }
            }
            else {
                $allResults.Add($response)
            }

            $nextLink = $response.'@odata.nextLink'
        }
        catch {
            if ($_.Exception.Message -like '*429*' -or $_.Exception.Message -like '*throttled*') {
                Write-Information "`nRate limit hit, waiting 60 seconds..." -InformationAction Continue
                Start-Sleep -Seconds 60
                continue
            }
            throw "Error fetching data from $nextLink : $($_.Exception.Message)"
        }
    } while ($nextLink)

    return $allResults
}

# Function to trigger device sync
function Invoke-DeviceSync {
    param(
        [string]$DeviceId,
        [string]$DeviceName
    )

    try {
        $syncUri = "https://graph.microsoft.com/beta/deviceManagement/managedDevices('$DeviceId')/syncDevice"
        Invoke-MgGraphRequest -Uri $syncUri -Method POST
        Write-Information "✓ Sync triggered successfully for device: $DeviceName" -InformationAction Continue
        return $true
    }
    catch {
        if ($_.Exception.Message -like '*429*' -or $_.Exception.Message -like '*throttled*') {
            Write-Information "Rate limit hit for device $DeviceName, waiting 60 seconds before retry..." -InformationAction Continue
            Start-Sleep -Seconds 60
            try {
                Invoke-MgGraphRequest -Uri $syncUri -Method POST
                Write-Information "✓ Sync triggered successfully for device: $DeviceName" -InformationAction Continue
                return $true
            }
            catch {
                Write-Information "✗ Failed to sync device $DeviceName after retry: $($_.Exception.Message)" -InformationAction Continue
                return $false
            }
        }
        Write-Information "✗ Failed to sync device $DeviceName : $($_.Exception.Message)" -InformationAction Continue
        return $false
    }
}

# Function to get devices by Entra ID group
function Get-DevicesByEntraGroup {
    param([string]$GroupName)

    try {
        Write-Information "Finding Entra ID group: $GroupName..." -InformationAction Continue

        # Find the group
        $groupUri = "https://graph.microsoft.com/beta/groups?`$filter=displayName eq '$GroupName'"
        $groups = @(Get-MgGraphAllPages -Uri $groupUri)

        if ($groups.Count -eq 0) {
            throw "Group '$GroupName' not found"
        }
        elseif ($groups.Count -gt 1) {
            throw "Multiple groups found with name '$GroupName'. Please use a more specific name."
        }

        $group = $groups[0]
        Write-Information "✓ Found group: $($group.displayName) (ID: $($group.id))" -InformationAction Continue

        # Get group members
        Write-Information 'Retrieving group members...' -InformationAction Continue
        $membersUri = "https://graph.microsoft.com/beta/groups/$($group.id)/members"
        $members = @(Get-MgGraphAllPages -Uri $membersUri)

        Write-Information "✓ Found $($members.Count) members in group" -InformationAction Continue

        # Get all managed devices
        Write-Information 'Retrieving managed devices...' -InformationAction Continue
        $devicesUri = "https://graph.microsoft.com/beta/deviceManagement/managedDevices?`$select=id,deviceName,azureADDeviceId,userPrincipalName,operatingSystem,osVersion,model,lastSyncDateTime"
        $allDevices = @(Get-MgGraphAllPages -Uri $devicesUri)

        # Filter devices by group members (device membership first, then user membership fallback)
        [System.Collections.Generic.List[PSCustomObject]]$targetDevices = @()
        foreach ($device in $allDevices) {
            $deviceInGroup = $false
            if ($device.azureADDeviceId -and $members.deviceId -contains $device.azureADDeviceId) {
                $deviceInGroup = $true
            }
            elseif ($device.userPrincipalName) {
                $userInGroup = $members | Where-Object { $_.userPrincipalName -eq $device.userPrincipalName -or $_.mail -eq $device.userPrincipalName }
                if ($userInGroup) {
                    $deviceInGroup = $true
                }
            }
            if ($deviceInGroup) {
                $targetDevices.Add($device)
            }
        }

        Write-Information "✓ Found $($targetDevices.Count) devices belonging to group members" -InformationAction Continue
        return $targetDevices
    }
    catch {
        throw "Failed to get devices by Entra ID group: $($_.Exception.Message)"
    }
}

# ============================================================================
# MAIN SCRIPT LOGIC
# ============================================================================

try {
    $null = Initialize-Log -SolutionName $SolutionName -ScriptMode $ScriptMode -Type 'General'
    Write-Banner
    if ($script:LogReady) {
        Write-Log -Message "Log file ready: $($script:LogFile)" -Level 'DEBUG'
    }
    Write-Log -Message "Device synchronization operation started (target mode: $TargetMode)" -Level 'INFO'

    # Get target devices based on parameter set
    $targetDevices = @()

    switch ($TargetMode) {
        'DeviceNames' {
            Write-Output 'Retrieving devices by names...'
            $devicesUri = "https://graph.microsoft.com/beta/deviceManagement/managedDevices?`$select=id,deviceName,azureADDeviceId,userPrincipalName,operatingSystem,osVersion,model,lastSyncDateTime"
            $allDevices = Get-MgGraphAllPages -Uri $devicesUri

            foreach ($deviceName in $DeviceNames) {
                $matchingDevices = $allDevices | Where-Object { $_.deviceName -eq $deviceName }
                if ($matchingDevices) {
                    $targetDevices += $matchingDevices
                    Write-Output "✓ Found device: $deviceName"
                }
                else {
                    Write-Warning "Device not found: $deviceName"
                }
            }
        }

        'DeviceIds' {
            Write-Output 'Retrieving devices by IDs...'
            foreach ($deviceId in $DeviceIds) {
                try {
                    $deviceUri = "https://graph.microsoft.com/beta/deviceManagement/managedDevices/$deviceId`?`$select=id,deviceName,azureADDeviceId,userPrincipalName,operatingSystem,osVersion,model,lastSyncDateTime"
                    $device = Invoke-MgGraphRequest -Uri $deviceUri -Method GET
                    $targetDevices += $device
                    Write-Output "✓ Found device: $($device.deviceName)"
                }
                catch {
                    Write-Warning "Device not found with ID: $deviceId"
                }
            }
        }

        'EntraGroup' {
            $targetDevices = Get-DevicesByEntraGroup -GroupName $EntraGroupName
        }
    }

    if ($targetDevices.Count -eq 0) {
        Write-Output 'No target devices found. No synchronization action is required.'
        exit 0
    }

    # Display target information
    Write-Output "`n📱 TARGET DEVICES SUMMARY"
    Write-Output '========================='
    Write-Output "Total devices to process: $($targetDevices.Count)"

    if ($DryRun) {
        foreach ($device in $targetDevices) {
            Write-Output "• $($device.deviceName) [$($device.id)]"
        }
        Write-Output "✓ Dry run completed. No synchronization actions were sent."
        Write-Log -Message "Dry run completed - no synchronization actions were sent" -Level 'INFO'
        exit 0
    }

    # Process sync operations
    $successfulSyncs = 0
    $failedSyncs = 0
    $skippedSyncs = 0
    $processedDevices = 0

    Write-Output "`nProcessing device synchronization..."

    foreach ($device in $targetDevices) {
        $processedDevices++
        Write-Progress -Activity 'Synchronizing Devices' -Status "Processing device $processedDevices of $($targetDevices.Count): $($device.deviceName)" -PercentComplete (($processedDevices / $targetDevices.Count) * 100)

        # Calculate time since last sync
        $hoursSinceSync = if ($device.lastSyncDateTime) {
            [math]::Round(((Get-Date) - [DateTime]$device.lastSyncDateTime).TotalHours, 1)
        }
        else {
            999
        }

        # Determine if sync should be triggered
        $shouldSync = $ForceSync -or $hoursSinceSync -gt 1 -or $null -eq $device.lastSyncDateTime

        if ($shouldSync) {
            $syncSuccessful = Invoke-DeviceSync -DeviceId $device.id -DeviceName $device.deviceName

            if ($syncSuccessful) {
                $successfulSyncs++
            }
            else {
                $failedSyncs++
            }

            # Add delay between sync operations to avoid overwhelming the service
            if ($processedDevices -lt $targetDevices.Count) {
                Start-Sleep -Seconds $SyncDelaySeconds
            }
        }
        else {
            Write-Output "⏭️  Skipping $($device.deviceName) - synced $hoursSinceSync hours ago"
            $skippedSyncs++
        }
    }

    Write-Progress -Activity 'Synchronizing Devices' -Completed

    # Display final summary
    Write-Output "`n🔄 SYNC OPERATION SUMMARY"
    Write-Output '========================='
    Write-Output "Total Devices Processed: $($targetDevices.Count)"
    Write-Output "Successful Syncs: $successfulSyncs"
    Write-Output "Failed Syncs: $failedSyncs"
    Write-Output "Skipped Devices: $skippedSyncs"

    # Show failed devices if any
    if ($failedSyncs -gt 0) {
        Write-Output "`n❌ Failed sync operations require manual review."
        Write-Log -Message "Sync operation finished with $failedSyncs failure(s) out of $($targetDevices.Count) device(s)" -Level 'WARNING'
        exit 1
    }

    Write-Output "`n🎉 Device synchronization completed successfully!"
    Write-Log -Message "Device synchronization completed successfully - $successfulSyncs sync(s), $skippedSyncs skipped" -Level 'SUCCESS'

}
catch {
    Write-Log -Message "Script execution failed: $($_.Exception.Message)" -Level 'ERROR'
    Write-Error "Script execution failed: $($_.Exception.Message)"
    exit 1
}
finally {
    # Disconnect from Microsoft Graph
    try {
        if (Get-MgContext) {
            $null = Disconnect-MgGraph -ErrorAction SilentlyContinue
            Write-Output '✓ Disconnected from Microsoft Graph'
        }
    }
    catch {
        # Ignore disconnection errors - this is expected behavior when already disconnected
        Write-Verbose 'Graph disconnection completed (may have already been disconnected)'
    }
}
