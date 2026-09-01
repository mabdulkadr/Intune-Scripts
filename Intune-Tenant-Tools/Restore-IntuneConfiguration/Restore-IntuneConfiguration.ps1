<#
.TITLE
    Restore Intune Configuration

.SYNOPSIS
    Restores Intune configuration profiles, compliance policies, ADMX policies, and platform scripts from a JSON backup created by backup-intune-configuration.

.DESCRIPTION
    This script reads a backup folder produced by backup-intune-configuration.ps1 and
    recreates the exported objects in the target tenant: device configuration profiles,
    settings catalog policies, compliance policies, administrative template (ADMX)
    policies with their definition values, and platform scripts. Objects are always
    created as new entries (no in-place overwrite), read-only properties are stripped
    from the payloads, and every create supports -WhatIf preview. Assignment restore is
    optional and off by default because group IDs from the source tenant may not exist
    in the target tenant. Supports both interactive sign-in (delegated) and app-only authentication (client secret or certificate) on the workstation. Workstation-only execution.

.TAGS
    Configuration

.PLATFORM
    Windows

.MINROLE
    Intune Administrator

.PERMISSIONS
    DeviceManagementConfiguration.ReadWrite.All

.AUTHOR
    Mohammad Abdelkader Omar

.VERSION
    1.2.1

.CHANGELOG
    1.2.1 (2026-08-26)
    - Migrated to Enterprise Admin standards (canonical header order, structured logging, PS 5.1 contract)
    1.2 - Added Azure Automation contract validation, portal-safe boolean parameters, beta Graph endpoints, and terminating paging errors
    1.1 - Azure Automation now records script progress, outcomes, and summaries in job history
    1.0 - Initial release

.LASTUPDATE
    2026-08-26

.EXAMPLE
    .\restore-intune-configuration.ps1 -BackupPath ".\IntuneConfigBackup_2026-07-20_10-00-00" -WhatIf
    Previews everything that would be created without writing to the tenant

.EXAMPLE
    .\restore-intune-configuration.ps1 -BackupPath ".\IntuneConfigBackup_2026-07-20_10-00-00" -Areas CompliancePolicies
    Restores only the compliance policies from the backup

.EXAMPLE
    .\restore-intune-configuration.ps1 -BackupPath ".\IntuneConfigBackup_2026-07-20_10-00-00" -RestoreAssignments "true"
    Restores all areas including group assignments (same-tenant restore)

.NOTES
    - Requires Microsoft.Graph.Authentication module (auto-installed if missing)
    - Uses beta Graph endpoints because the full Intune configuration surface is not exposed on v1.0
    - Objects are created as new entries; existing policies with the same name are not touched, so a re-run creates duplicates
    - Compliance policies are created with their exported scheduledActionsForRule; if a backup predates that field, a default block rule is added because Graph rejects policies without one
    - Secret values (encrypted OMA-URI settings, passwords, certificates) are never present in Graph exports and must be re-entered manually after restore
    - ADMX presentation values referencing definitions that do not exist in the target tenant are skipped with a warning
    - Assignment restore requires the original group IDs to exist in the target tenant; failures are reported per policy and do not stop the restore
    - Interactive sign-in uses the MgGraphCommunity module to avoid the Graph SDK's mandatory WAM broker on Windows if present, with fallback to Microsoft.Graph.Authentication
    - Workstation dual-mode: interactive (delegated) or app-only via -TenantId, -ClientId and -ClientSecret or -CertificateThumbprint
    - Logs: %ProgramData%\restore-intune-configuration\Logs\
#>

#Requires -Version 5.1

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true, HelpMessage = "Path to a folder created by backup-intune-configuration.ps1")]
    [ValidateNotNullOrEmpty()]
    [string]$BackupPath,

    [Parameter(Mandatory = $false, HelpMessage = "Configuration areas to restore")]
    [ValidateSet("DeviceConfigurations", "SettingsCatalog", "CompliancePolicies", "AdmxPolicies", "PlatformScripts")]
    [string[]]$Areas = @("DeviceConfigurations", "SettingsCatalog", "CompliancePolicies", "AdmxPolicies", "PlatformScripts"),

    [Parameter(Mandatory = $false, HelpMessage = "Also restore group assignments (requires source group IDs to exist)")]
    [ValidateSet("true", "false", "1", "0", '$true', '$false')]
    [string]$RestoreAssignments,

    [Parameter(Mandatory = $false, HelpMessage = "Prefix added to restored object names, e.g. 'Restored - '")]
    [string]$NamePrefix = "",

    [Parameter(Mandatory = $false, HelpMessage = "Force module installation without prompting")]
    [ValidateSet("true", "false", "1", "0", '$true', '$false')]
    [string]$ForceModuleInstall,

    [Parameter(Mandatory = $false, HelpMessage = "Entra tenant ID for app-only authentication")]
    [ValidateNotNullOrEmpty()]
    [string]$TenantId,

    [Parameter(Mandatory = $false, HelpMessage = "App registration client ID for app-only authentication")]
    [ValidateNotNullOrEmpty()]
    [string]$ClientId,

    [Parameter(Mandatory = $false, HelpMessage = "Client secret for app-only authentication")]
    [string]$ClientSecret,

    [Parameter(Mandatory = $false, HelpMessage = "Certificate thumbprint for app-only authentication")]
    [string]$CertificateThumbprint
)

$ErrorActionPreference = 'Stop'

# Normalize the local module-install override for workstation parameter binding.
$forceModuleInstallRaw = [string]$ForceModuleInstall
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

# Workstation string boolean normalization. Normalize the
# public boolean parameters once so workstation execution uses real booleans.
foreach ($runbookBooleanParameter in @('RestoreAssignments')) {
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

# ============================================================================
# CONFIGURATION - solution identity for structured logging.
# ============================================================================

$SolutionName = 'restore-intune-configuration'
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
# MODULE SETUP (workstation)
# ============================================================================

function Initialize-RequiredModule {
    param(
        [string[]]$ModuleNames,
        [bool]$ForceInstall = $false
    )

    foreach ($ModuleName in $ModuleNames) {
        Write-Verbose "Checking module: $ModuleName"

        $module = Get-Module -ListAvailable -Name $ModuleName | Select-Object -First 1

        if (-not $module) {
            Write-Information "Module '$ModuleName' not found. Installing..." -InformationAction Continue

            if (-not $ForceInstall) {
                $response = Read-Host "Install module '$ModuleName'? (Y/N)"
                if ($response -notmatch '^[Yy]') {
                    throw "Module '$ModuleName' is required but installation was declined."
                }
            }

            try {
                $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
                $scope = if ($isAdmin) { "AllUsers" } else { "CurrentUser" }

                Install-Module -Name $ModuleName -Scope $scope -Force -AllowClobber -Repository PSGallery
                Write-Information "✓ Successfully installed '$ModuleName'" -InformationAction Continue
            }
            catch {
                throw "Failed to install module '$ModuleName': $($_.Exception.Message)"
            }
        }

        Import-Module -Name $ModuleName -Force -ErrorAction Stop
    }
}

# Initialize required modules (workstation - auto-install Microsoft.Graph.Authentication if missing)
$RequiredModules = @("Microsoft.Graph.Authentication", "MgGraphCommunity")

try {
    Initialize-RequiredModule -ModuleNames $RequiredModules -ForceInstall $ForceModuleInstall
    Write-Verbose "✓ All required modules are available"
}
catch {
    Write-Error "Module initialization failed: $_"
    exit 1
}

# ============================================================================
# AUTHENTICATION (workstation dual-mode: interactive or app-only)
# ============================================================================

try {
    $isAppOnly = (-not [string]::IsNullOrWhiteSpace($TenantId) -and -not [string]::IsNullOrWhiteSpace($ClientId) -and (-not [string]::IsNullOrWhiteSpace($ClientSecret) -or -not [string]::IsNullOrWhiteSpace($CertificateThumbprint)))
    if ($isAppOnly) {
        Write-Output "Connecting to Microsoft Graph (app-only)..."
        if (-not [string]::IsNullOrWhiteSpace($CertificateThumbprint)) {
            Connect-MgGraph -TenantId $TenantId -ClientId $ClientId -CertificateThumbprint $CertificateThumbprint -NoWelcome -ErrorAction Stop
        }
        else {
            $secureSecret = ConvertTo-SecureString -String $ClientSecret -AsPlainText -Force
            Connect-MgGraph -TenantId $TenantId -ClientId $ClientId -ClientSecret $secureSecret -NoWelcome -ErrorAction Stop
        }
    }
    else {
        Write-Output "Connecting to Microsoft Graph (interactive)..."
        $Scopes = @(
            "DeviceManagementConfiguration.ReadWrite.All"
        )
        try {
            if (Get-Module -ListAvailable -Name MgGraphCommunity) {
                Connect-MgGraphCommunity -Scopes $Scopes -NoWelcome -ErrorAction Stop
            }
            else {
                Connect-MgGraph -Scopes $Scopes -NoWelcome -ErrorAction Stop
            }
        }
        catch {
            Connect-MgGraph -Scopes $Scopes -NoWelcome -ErrorAction Stop
        }
    }
    Write-Output "✓ Successfully connected to Microsoft Graph"
}
catch {
    Write-Error "Failed to connect to Microsoft Graph: $($_.Exception.Message)"
    exit 1
}

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

function ConvertTo-Hashtable {
    param([object]$InputObject)

    # ConvertFrom-Json gives PSCustomObjects; Graph payloads are easier to
    # sanitize as nested hashtables
    if ($null -eq $InputObject) { return $null }

    if ($InputObject -is [System.Collections.IEnumerable] -and $InputObject -isnot [string]) {
        return @($InputObject | ForEach-Object { ConvertTo-Hashtable -InputObject $_ })
    }

    if ($InputObject -is [PSCustomObject]) {
        $hash = [ordered]@{}
        foreach ($property in $InputObject.PSObject.Properties) {
            $hash[$property.Name] = ConvertTo-Hashtable -InputObject $property.Value
        }
        return $hash
    }

    return $InputObject
}

function Remove-ReadOnlyProperty {
    param(
        [hashtable]$Payload,
        [string[]]$ExtraProperties = @()
    )

    $readOnly = @(
        "id", "createdDateTime", "lastModifiedDateTime", "version",
        "assignments", "assignments@odata.context", "@odata.context",
        "settingCount", "priorityMetaData", "supportsScopeTags",
        "creationSource", "policyConfigurationIngestionType",
        "scriptSurface", "definitionValues", "settings@odata.context"
    ) + $ExtraProperties

    foreach ($property in $readOnly) {
        $Payload.Remove($property)
    }

    # Expanded navigation annotations (xyz@odata.context) are metadata, not payload
    foreach ($key in @($Payload.Keys)) {
        if ($key -like "*@odata.context" -or $key -like "*@odata.count") {
            $Payload.Remove($key)
        }
    }

    return $Payload
}

function Invoke-AssignmentRestore {
    param(
        [string]$AssignUri,
        [string]$AssignmentsPropertyName,
        [object[]]$Assignments,
        [string]$DisplayName
    )

    if (-not $Assignments -or @($Assignments).Count -eq 0) {
        return
    }

    $cleanAssignments = foreach ($assignment in $Assignments) {
        $a = ConvertTo-Hashtable -InputObject $assignment
        $a.Remove("id")
        $a.Remove("sourceId")
        $a
    }

    $body = @{ $AssignmentsPropertyName = @($cleanAssignments) }

    try {
        $null = Invoke-MgGraphRequest -Uri $AssignUri -Method POST -Body ($body | ConvertTo-Json -Depth 15) -ContentType "application/json"
        Write-Information "  ✓ Restored $(@($cleanAssignments).Count) assignments for '$DisplayName'" -InformationAction Continue
    }
    catch {
        Write-Warning "  Could not restore assignments for '$DisplayName' (groups may not exist in this tenant): $($_.Exception.Message)"
    }
}

function Get-BackupFile {
    param([string]$AreaFolder)

    $folder = Join-Path $BackupPath $AreaFolder
    if (-not (Test-Path $folder)) {
        Write-Warning "Backup folder '$AreaFolder' not found in $BackupPath - skipping"
        return @()
    }

    return @(Get-ChildItem -Path $folder -Filter "*.json" -File)
}

# ============================================================================
# MAIN SCRIPT LOGIC
# ============================================================================
# Flow: log init -> banner -> validate backup -> recreate each area -> summary.

try {
    $null = Initialize-Log -SolutionName $SolutionName -ScriptMode $ScriptMode -Type 'General'
    Write-Banner
    if ($script:LogReady) {
        Write-Log -Message "Log file ready: $($script:LogFile)" -Level 'DEBUG'
    }
    Write-Log -Message "Intune configuration restore started" -Level 'INFO'

    if (-not (Test-Path $BackupPath)) {
        throw "Backup path '$BackupPath' does not exist"
    }

    Write-Output "Starting Intune configuration restore from: $BackupPath"

    $restored = 0
    $failed = 0

    # ----- Classic device configuration profiles -----
    if ($Areas -contains "DeviceConfigurations") {
        foreach ($file in (Get-BackupFile -AreaFolder "DeviceConfigurations")) {
            $source = Get-Content -Path $file.FullName -Raw | ConvertFrom-Json
            $displayName = "$NamePrefix$($source.displayName)"
            $assignments = $source.assignments

            $payload = Remove-ReadOnlyProperty -Payload (ConvertTo-Hashtable -InputObject $source)
            $payload.displayName = $displayName

            if ($PSCmdlet.ShouldProcess($displayName, "Create device configuration profile")) {
                try {
                    $created = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceConfigurations" -Method POST -Body ($payload | ConvertTo-Json -Depth 25) -ContentType "application/json"
                    Write-Output "✓ Created profile: $displayName"
                    $restored++

                    if ($RestoreAssignments) {
                        Invoke-AssignmentRestore -AssignUri "https://graph.microsoft.com/beta/deviceManagement/deviceConfigurations/$($created.id)/assign" -AssignmentsPropertyName "assignments" -Assignments $assignments -DisplayName $displayName
                    }
                }
                catch {
                    Write-Warning "Failed to create profile '$displayName': $($_.Exception.Message)"
                    $failed++
                }
            }
        }
    }

    # ----- Settings catalog policies -----
    if ($Areas -contains "SettingsCatalog") {
        foreach ($file in (Get-BackupFile -AreaFolder "SettingsCatalog")) {
            $source = Get-Content -Path $file.FullName -Raw | ConvertFrom-Json
            $displayName = "$NamePrefix$($source.name)"
            $assignments = $source.assignments

            $settings = foreach ($setting in @($source.settings)) {
                $s = ConvertTo-Hashtable -InputObject $setting
                $s.Remove("id")
                $s
            }

            $payload = @{
                name         = $displayName
                description  = [string]$source.description
                platforms    = $source.platforms
                technologies = $source.technologies
                settings     = @($settings)
            }
            if ($source.roleScopeTagIds) { $payload.roleScopeTagIds = @($source.roleScopeTagIds) }
            if ($source.templateReference -and $source.templateReference.templateId) {
                $payload.templateReference = @{ templateId = $source.templateReference.templateId }
            }

            if ($PSCmdlet.ShouldProcess($displayName, "Create settings catalog policy")) {
                try {
                    $created = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies" -Method POST -Body ($payload | ConvertTo-Json -Depth 30) -ContentType "application/json"
                    Write-Output "✓ Created settings catalog policy: $displayName"
                    $restored++

                    if ($RestoreAssignments) {
                        Invoke-AssignmentRestore -AssignUri "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies/$($created.id)/assign" -AssignmentsPropertyName "assignments" -Assignments $assignments -DisplayName $displayName
                    }
                }
                catch {
                    Write-Warning "Failed to create settings catalog policy '$displayName': $($_.Exception.Message)"
                    $failed++
                }
            }
        }
    }

    # ----- Compliance policies -----
    if ($Areas -contains "CompliancePolicies") {
        foreach ($file in (Get-BackupFile -AreaFolder "CompliancePolicies")) {
            $source = Get-Content -Path $file.FullName -Raw | ConvertFrom-Json
            $displayName = "$NamePrefix$($source.displayName)"
            $assignments = $source.assignments

            $payload = Remove-ReadOnlyProperty -Payload (ConvertTo-Hashtable -InputObject $source) -ExtraProperties @("deviceCompliancePolicyScript")
            $payload.displayName = $displayName

            # Graph rejects compliance policies created without a scheduled action rule
            if ($payload.scheduledActionsForRule) {
                $payload.scheduledActionsForRule = @(foreach ($rule in @($payload.scheduledActionsForRule)) {
                        $rule.Remove("id")
                        if ($rule.scheduledActionConfigurations) {
                            $rule.scheduledActionConfigurations = @(foreach ($config in @($rule.scheduledActionConfigurations)) {
                                    $config.Remove("id")
                                    $config
                                })
                        }
                        $rule
                    })
            }
            else {
                $payload.scheduledActionsForRule = @(
                    @{
                        ruleName                      = "PasswordRequired"
                        scheduledActionConfigurations = @(
                            @{ actionType = "block"; gracePeriodHours = 0; notificationTemplateId = ""; notificationMessageCCList = @() }
                        )
                    }
                )
            }

            if ($PSCmdlet.ShouldProcess($displayName, "Create compliance policy")) {
                try {
                    $created = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceCompliancePolicies" -Method POST -Body ($payload | ConvertTo-Json -Depth 25) -ContentType "application/json"
                    Write-Output "✓ Created compliance policy: $displayName"
                    $restored++

                    if ($RestoreAssignments) {
                        Invoke-AssignmentRestore -AssignUri "https://graph.microsoft.com/beta/deviceManagement/deviceCompliancePolicies/$($created.id)/assign" -AssignmentsPropertyName "assignments" -Assignments $assignments -DisplayName $displayName
                    }
                }
                catch {
                    Write-Warning "Failed to create compliance policy '$displayName': $($_.Exception.Message)"
                    $failed++
                }
            }
        }
    }

    # ----- Administrative template (ADMX) policies -----
    if ($Areas -contains "AdmxPolicies") {
        foreach ($file in (Get-BackupFile -AreaFolder "AdmxPolicies")) {
            $source = Get-Content -Path $file.FullName -Raw | ConvertFrom-Json
            $displayName = "$NamePrefix$($source.displayName)"
            $assignments = $source.assignments

            $payload = @{
                displayName = $displayName
                description = [string]$source.description
            }

            if ($PSCmdlet.ShouldProcess($displayName, "Create administrative template policy")) {
                try {
                    $created = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceManagement/groupPolicyConfigurations" -Method POST -Body ($payload | ConvertTo-Json) -ContentType "application/json"
                    Write-Output "✓ Created administrative template policy: $displayName"
                    $restored++

                    # Definition values are created one by one against the new policy
                    foreach ($definitionValue in @($source.definitionValues)) {
                        if (-not $definitionValue.definition -or -not $definitionValue.definition.id) {
                            Write-Warning "  Skipping a definition value without definition reference in '$displayName'"
                            continue
                        }

                        $dvPayload = @{
                            enabled                 = [bool]$definitionValue.enabled
                            "definition@odata.bind" = "https://graph.microsoft.com/beta/deviceManagement/groupPolicyDefinitions('$($definitionValue.definition.id)')"
                        }

                        if ($definitionValue.presentationValues) {
                            $dvPayload.presentationValues = @(foreach ($presentationValue in @($definitionValue.presentationValues)) {
                                    $pv = ConvertTo-Hashtable -InputObject $presentationValue
                                    $presentationId = $null
                                    if ($presentationValue.presentation -and $presentationValue.presentation.id) {
                                        $presentationId = $presentationValue.presentation.id
                                    }
                                    $pv.Remove("id")
                                    $pv.Remove("createdDateTime")
                                    $pv.Remove("lastModifiedDateTime")
                                    $pv.Remove("presentation")
                                    if ($presentationId) {
                                        $pv["presentation@odata.bind"] = "https://graph.microsoft.com/beta/deviceManagement/groupPolicyDefinitions('$($definitionValue.definition.id)')/presentations('$presentationId')"
                                    }
                                    $pv
                                })
                        }

                        try {
                            $null = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceManagement/groupPolicyConfigurations/$($created.id)/definitionValues" -Method POST -Body ($dvPayload | ConvertTo-Json -Depth 15) -ContentType "application/json"
                        }
                        catch {
                            Write-Warning "  Could not restore setting '$($definitionValue.definition.displayName)' in '$displayName': $($_.Exception.Message)"
                        }
                    }

                    if ($RestoreAssignments) {
                        Invoke-AssignmentRestore -AssignUri "https://graph.microsoft.com/beta/deviceManagement/groupPolicyConfigurations/$($created.id)/assign" -AssignmentsPropertyName "assignments" -Assignments $assignments -DisplayName $displayName
                    }
                }
                catch {
                    Write-Warning "Failed to create administrative template policy '$displayName': $($_.Exception.Message)"
                    $failed++
                }
            }
        }
    }

    # ----- Platform scripts -----
    if ($Areas -contains "PlatformScripts") {
        foreach ($file in (Get-BackupFile -AreaFolder "PlatformScripts")) {
            $source = Get-Content -Path $file.FullName -Raw | ConvertFrom-Json
            $displayName = "$NamePrefix$($source.displayName)"
            $assignments = $source.assignments
            $surface = if ($source.scriptSurface) { $source.scriptSurface } else { "deviceManagementScripts" }

            if (-not $source.scriptContent) {
                Write-Warning "Skipping platform script '$displayName': backup contains no script content (was -SkipScriptContent used?)"
                continue
            }

            $payload = Remove-ReadOnlyProperty -Payload (ConvertTo-Hashtable -InputObject $source)
            $payload.displayName = $displayName

            if ($PSCmdlet.ShouldProcess($displayName, "Create platform script ($surface)")) {
                try {
                    $created = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceManagement/$surface" -Method POST -Body ($payload | ConvertTo-Json -Depth 10) -ContentType "application/json"
                    Write-Output "✓ Created platform script: $displayName"
                    $restored++

                    if ($RestoreAssignments) {
                        # Both script surfaces use the same assign action property name
                        Invoke-AssignmentRestore -AssignUri "https://graph.microsoft.com/beta/deviceManagement/$surface/$($created.id)/assign" -AssignmentsPropertyName "deviceManagementScriptAssignments" -Assignments $assignments -DisplayName $displayName
                    }
                }
                catch {
                    Write-Warning "Failed to create platform script '$displayName': $($_.Exception.Message)"
                    $failed++
                }
            }
        }
    }

    # ----- Summary -----
    Write-Output "`n========================================"
    Write-Output "Restore Summary"
    Write-Output "========================================"
    Write-Output "Objects created: $restored"
    Write-Output "Objects failed:  $failed"
    Write-Output "========================================"

    if ($failed -gt 0) {
        Write-Warning "Some objects failed to restore - review the warnings above"
    }
    Write-Log -Message "Restore completed: $restored created, $failed failed" -Level $(if ($failed -gt 0) { 'WARNING' } else { 'SUCCESS' })
}
catch {
    Write-Log -Message "Script execution failed: $($_.Exception.Message)" -Level 'ERROR'
    Write-Error "Script execution failed: $($_.Exception.Message)"
    exit 1
}
finally {
    try {
        $null = Disconnect-MgGraph
        Write-Output "✓ Disconnected from Microsoft Graph"
    }
    catch {
        Write-Verbose "Graph disconnection completed"
    }
}
