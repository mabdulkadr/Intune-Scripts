<#
.TITLE
    Remediation - Windows Restart Notification (English)

.SYNOPSIS
    Shows an English WPF restart prompt with immediate, 1-hour, and 2-hour options.

.DESCRIPTION
    Paired remediation for WinUptimeRestartNotification. Runs only when
    detect-WindowsUptimeRestartNotification.ps1 returns exit 1. Presents a topmost,
    borderless WPF dialog in English telling the user a restart is required
    (pending servicing reboot and/or uptime threshold reached). The user can
    restart now, schedule in 1 hour or 2 hours, minimize, or dismiss. A forced
    scheduled restart is optional via $ForceRestartWhenPending.

    Exit contract:
    Exit 0 = success (notification delivered/handled, or none required)
    Exit 1 = failure (dialog could not be shown and fallback scheduling failed)
    Exit 2 = script error

.TAGS
    Remediation,Action,Uptime,Restart,Notification

.REMEDIATIONTYPE
    Remediation

.PAIRSCRIPT
    detect-WindowsUptimeRestartNotification.ps1

.PLATFORM
    Windows

.MINROLE
    Intune Service Administrator

.PERMISSIONS
    None (local SYSTEM context) - reads registry/CIM state, shows interactive UI,
    and may invoke shutdown.exe for user-chosen or policy-forced restarts.

.AUTHOR
    Mohammad Abdelkader Omar

.VERSION
    2.0.0

.CHANGELOG
    2.0.0 (2026-08-26)
    - Migrated to Enterprise Standards canonical structure (header, logging, exit contract)
    - Replaced symbol-font glyphs with SVG Path icons (ICON LAW)
    - Replaced empty catch blocks with typed, commented handlers (ERROR LAW)
    - Log output moved to <SystemDrive>\IntuneLogs\WindowsUptimeRestartNotification\
    1.2 (2025)
    - English variant introduced alongside Arabic variant
    1.1 (2025)
    - Pending-reboot and uptime threshold signals
    1.0.0
    - Initial release

.LASTUPDATE
    2026-08-26

.EXAMPLE
    .\remediate-WindowsUptimeRestartNotification.ps1
    Shows the restart dialog when a reboot is pending or uptime exceeded.

.EXAMPLE
    .\remediate-WindowsUptimeRestartNotification-Ar.ps1
    Exits 0 without showing UI when neither condition applies; exits 1 only if the
    dialog cannot be shown AND forced-restart scheduling fails.

.NOTES
    - Intune deployment: Run this script using logged-on credentials = Yes (interactive WPF dialog).
    - English user-facing variant; the paired -Ar file carries the Arabic dialog.
    - Idempotent: exits cleanly when no restart is required.
    - Logs: <SystemDrive>\IntuneLogs\WindowsUptimeRestartNotification\
#>

#Requires -Version 5.1

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# ============================================================================
# CONFIGURATION - solution identity, restart policy, and user-facing dialog text.
# ============================================================================

$SolutionName = 'WindowsUptimeRestartNotification'
$ScriptMode   = 'Remediation'

# Keep this value aligned with the detection script.
$MaxUptimeDays = 14

# Restart behavior
$ForceRestartWhenPending = $false
$GraceSeconds            = 3600
$ShutdownReason          = 'A restart is required to complete system updates (Intune Remediation).'

# UI text
$Txt_HeaderTitle    = 'IT Notification'
$Txt_HeaderSubTitle = 'Please review the notice and choose an action'
$Txt_Footer         = 'For assistance, please contact IT support.'
$Txt_DeployedBy     = 'Delivered via Microsoft Intune'

$Txt_BtnRestartNow = 'Restart Now'
$Txt_BtnRestart1H  = 'Restart in 1 Hour'
$Txt_BtnRestart2H  = 'Restart in 2 Hours'
$Txt_BtnClose      = 'Close'

# Branding
$Brand_LogoFile = 'logo.png'
$LogoBase64     = '<PASTE-YOUR-CURRENT-BASE64-HERE>'

# Window settings
$TopMost      = $true
$WinWidth     = 900
$WinHeight    = 450
$MaxWinHeight = 700

# SVG icon path data (ICON LAW - no symbol fonts). Material Design, MIT-licensed.
$MinimizeIconData = 'M19 13H5v-2h14v2z'
$CloseIconData    = 'M19 6.41L17.59 5 12 10.59 6.41 5 5 6.41 10.59 12 5 17.59 6.41 19 12 13.41 17.59 19 19 17.59 13.41 12z'

# Structured result emitted as JSON diagnostics at every exit point.
$remediationResult = @{
    Status             = "Unknown"
    PendingReboot      = $false
    UptimeDays         = $null
    DialogShown        = $false
    ForcedScheduled    = $false
    PreCheckStatus     = @()
    RemediationActions = @()
    PostCheckStatus    = @()
    Timestamp          = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    ComputerName       = $env:COMPUTERNAME
}

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

# Appends structured remediation entries to the audit trail and JSON result.
# The consecutive-duplicate guard mirrors the GUI Add-LogLine contract (Identity Lock).
$script:LastLogKey = $null

function Write-RemediationLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)][AllowEmptyString()][string]$Message = "",
        [ValidateSet('Info', 'Warning', 'Error')][string]$Level = 'Info'
    )
    # Console/file via canonical Write-Log + structured record for JSON output.
    $mapped = switch ($Level) { 'Warning' { 'WARNING' } 'Error' { 'ERROR' } default { 'INFO' } }
    $dedupeKey = '{0}|{1}' -f $mapped, $Message
    if ($dedupeKey -eq $script:LastLogKey) { return }
    $script:LastLogKey = $dedupeKey
    Write-Log -Message $Message -Level $mapped
    $remediationResult.RemediationActions += @{
        Timestamp = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        Level     = $Level
        Message   = $Message
    }
}

# ============================================================================
# CONCURRENCY GUARD (embedded canonical scripts/Guard-Action.ps1 - Pattern H)
# ============================================================================

$script:IsBusy = $false

# Blocks re-entrant actions while another is still in progress.
function Guard-Action {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$ActionName = 'Action'
    )

    if ($script:IsBusy) {
        $msg = "Operation in progress - please wait: $ActionName"
        Write-Warning $msg
        return $false
    }
    $script:IsBusy = $true
    return $true
}

# Clears the busy flag after a guarded action completes.
function Release-Action {
    [CmdletBinding()]
    param()

    $script:IsBusy = $false
}

# ============================================================================
# STATE PROBES (shared with detection logic)
# ============================================================================

# Returns the pending reboot state with human-readable servicing sources.
function Get-PendingRebootInfo {
    $reasons = @()

    if (Test-Path -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired') {
        $reasons += 'Windows Update'
    }

    if (Test-Path -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending') {
        $reasons += 'Component Based Servicing'
    }

    try {
        $pendingRename = Get-ItemProperty `
            -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' `
            -Name 'PendingFileRenameOperations' `
            -ErrorAction Stop

        if ($pendingRename -and $pendingRename.PendingFileRenameOperations) {
            $reasons += 'Pending File Rename'
        }
    }
    catch [System.Management.Automation.PSArgumentException] {
        # Value absent means nothing is queued for rename - not an error state.
        Write-Log -Message "PendingFileRenameOperations not present" -Level 'DEBUG'
    }

    $uniqueReasons = @($reasons | Select-Object -Unique)

    return [pscustomobject]@{
        Pending = ($uniqueReasons.Count -gt 0)
        Reasons = $uniqueReasons
    }
}

# Returns uptime in whole days, or $null when it cannot be read.
function Get-UptimeDays {
    try {
        $operatingSystem = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
        return [math]::Floor(((Get-Date) - $operatingSystem.LastBootUpTime).TotalDays)
    }
    catch {
        Write-Log -Message "Failed to read uptime: $($_.Exception.Message)" -Level 'WARNING'
        return $null
    }
}

# ============================================================================
# RESTART ACTIONS
# ============================================================================

# Attempts an immediate forced restart via Restart-Computer with shutdown.exe fallback.
function Try-RestartNow {
    try {
        Restart-Computer -Force -ErrorAction Stop
        return $true
    }
    catch [System.InvalidOperationException] {
        try {
            Start-Process -FilePath "$env:SystemRoot\System32\shutdown.exe" `
                -ArgumentList "/r /t 0 /f /c `"$ShutdownReason`"" `
                -WindowStyle Hidden
            return $true
        }
        catch {
            Write-RemediationLog "shutdown.exe fallback failed: $($_.Exception.Message)" -Level 'Error'
            return $false
        }
    }
}

# Aborts any pending shutdown request then schedules a new forced restart.
function Schedule-Restart {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [int]$Seconds
    )

    # Best-effort cancel of an earlier countdown; failure here is harmless.
    Start-Process -FilePath "$env:SystemRoot\System32\shutdown.exe" `
        -ArgumentList '/a' `
        -WindowStyle Hidden `
        -ErrorAction SilentlyContinue | Out-Null

    try {
        Start-Process -FilePath "$env:SystemRoot\System32\shutdown.exe" `
            -ArgumentList "/r /t $Seconds /f /c `"$ShutdownReason`"" `
            -WindowStyle Hidden | Out-Null
        return $true
    }
    catch {
        Write-RemediationLog "Failed to schedule restart: $($_.Exception.Message)" -Level 'Error'
        return $false
    }
}

# ============================================================================
# IMAGE HELPERS (logo loading)
# ============================================================================

# Decodes base64 image data into a frozen BitmapImage; returns $null on failure.
function Get-BitmapImageFromBase64 {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Base64String
    )

    try {
        $cleanBase64 = $Base64String.Trim()

        if ($cleanBase64 -match 'base64,') {
            $cleanBase64 = ($cleanBase64 -split 'base64,')[-1].Trim()
        }

        $bytes = [Convert]::FromBase64String($cleanBase64)

        # WEBP is unsupported by BitmapImage - let file/fallback rendering take over.
        if ($bytes.Length -ge 12) {
            $header1 = [Text.Encoding]::ASCII.GetString($bytes, 0, 4)
            $header2 = [Text.Encoding]::ASCII.GetString($bytes, 8, 4)

            if ($header1 -eq 'RIFF' -and $header2 -eq 'WEBP') {
                return $null
            }
        }

        $memoryStream = New-Object System.IO.MemoryStream(,$bytes)
        $bitmap = New-Object System.Windows.Media.Imaging.BitmapImage
        $bitmap.BeginInit()
        $bitmap.CacheOption  = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
        $bitmap.StreamSource = $memoryStream
        $bitmap.EndInit()
        $bitmap.Freeze()
        $memoryStream.Dispose()

        return $bitmap
    }
    catch {
        Write-Log -Message "Embedded logo could not be decoded: $($_.Exception.Message)" -Level 'DEBUG'
        return $null
    }
}

# Loads an image file into a frozen BitmapImage; returns $null on failure.
function Get-BitmapImageFromFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    try {
        $bitmap = New-Object System.Windows.Media.Imaging.BitmapImage
        $bitmap.BeginInit()
        $bitmap.CacheOption = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
        $bitmap.UriSource   = New-Object System.Uri($Path)
        $bitmap.EndInit()
        $bitmap.Freeze()
        return $bitmap
    }
    catch {
        Write-Log -Message "Logo file could not be loaded: $($_.Exception.Message)" -Level 'DEBUG'
        return $null
    }
}

# ============================================================================
# MAIN
# ============================================================================
# Flow: init -> evaluate conditions -> show dialog / enforce -> JSON summary -> exit 0 / 1 / 2.

try {
    Add-Type -AssemblyName PresentationFramework
    Add-Type -AssemblyName WindowsBase

    $null = Initialize-Log -SolutionName $SolutionName -ScriptMode $ScriptMode -Type 'Intune'
    Write-Banner
    if ($script:LogReady) {
        Write-Log -Message "Log file ready: $($script:LogFile)" -Level 'DEBUG'
    }
    Write-RemediationLog "Starting remediation..." -Level 'Info'
    Write-RemediationLog "Maximum uptime threshold: $MaxUptimeDays day(s)" -Level 'Info'
    Write-RemediationLog "Force restart when pending reboot: $ForceRestartWhenPending" -Level 'Info'

    # --- Evaluate conditions (pre-checks) ---
    $pendingInfo   = Get-PendingRebootInfo
    $pendingReboot = $pendingInfo.Pending
    $uptimeDays    = Get-UptimeDays

    $remediationResult.PendingReboot = $pendingReboot
    $remediationResult.UptimeDays    = $uptimeDays

    Write-RemediationLog "Pending reboot detected: $pendingReboot" -Level 'Info'
    if ($pendingInfo.Reasons.Count -gt 0) {
        Write-Log -Message ("Pending reboot sources detected ({0} signal(s))" -f $pendingInfo.Reasons.Count) -Level 'DEBUG'
    }
    if ($null -ne $uptimeDays) {
        Write-RemediationLog "Current uptime: $uptimeDays day(s)" -Level 'Info'
    }
    else {
        Write-RemediationLog "Current uptime could not be determined." -Level 'Warning'
    }

    $needNotice = $false
    $needForce  = $false

    if ($pendingReboot) {
        $needNotice = $true
        $needForce  = $ForceRestartWhenPending
    }
    elseif (($null -ne $uptimeDays) -and ($uptimeDays -ge $MaxUptimeDays)) {
        $needNotice = $true
    }

    if (-not $needNotice) {
        $remediationResult.Status = "Success"
        $remediationResult.PostCheckStatus += "Verification passed - device needs no restart notification"
        Write-Output "No restart notification is required"
        Write-Output ($remediationResult | ConvertTo-Json -Depth 6 -Compress)
        Finish-Script -ExitCode 0 -Message "No restart notification is required. PendingReboot=$pendingReboot | UptimeDays=$uptimeDays" -Level 'SUCCESS'
    }

    # --- Build user-facing message ---
    $txtMessageTitle = 'A device restart is required'
    $sections = @()

    if ($pendingInfo.Reasons.Count -gt 0) {
        $reasonText = ' (' + ($pendingInfo.Reasons -join ', ') + ')'
        $sections += "- Updates or system changes are waiting for a restart$reasonText."
    }

    if (($null -ne $uptimeDays) -and ($uptimeDays -ge $MaxUptimeDays)) {
        $sections += "- This device has been running for more than $MaxUptimeDays days without a restart."
    }

    if ($sections.Count -eq 0) {
        $sections += '- A restart is required to complete pending requirements.'
    }

    $messageLines = @()
    $messageLines += $sections
    $messageLines += ''
    $messageLines += '- Please save your work before continuing.'
    $messageLines += '- You can restart now,'
    $messageLines += '- or schedule the restart in one hour,'
    $messageLines += '- or schedule the restart in two hours.'

    $txtMessageBody = $messageLines -join "`n"

    # --- Resolve logo path beside the script (Report Path Law fallback chain) ---
    $scriptBase = if ($PSScriptRoot) { $PSScriptRoot } elseif ($PSCommandPath) { Split-Path -Parent $PSCommandPath } elseif ($MyInvocation.MyCommand.Path) { Split-Path -Parent $MyInvocation.MyCommand.Path } else { (Get-Location).Path }
    $logoPath   = Join-Path $scriptBase $Brand_LogoFile

    # --- XAML definition ---
    [xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Notice"
        Width="$WinWidth"
        MinHeight="$WinHeight"
        MaxHeight="$MaxWinHeight"
        SizeToContent="Height"
        WindowStartupLocation="CenterScreen"
        ResizeMode="NoResize"
        WindowStyle="None"
        AllowsTransparency="True"
        Background="Transparent"
        Topmost="$TopMost"
        ShowInTaskbar="True"
        FlowDirection="LeftToRight">

    <Window.Resources>

        <SolidColorBrush x:Key="BackgroundBrush" Color="#E5E5E5"/>
        <SolidColorBrush x:Key="BorderBrush" Color="#FFFFFFFF"/>
        <SolidColorBrush x:Key="TextPrimaryBrush" Color="#FF0F172A"/>
        <SolidColorBrush x:Key="TextMutedBrush" Color="#FF64748B"/>
        <SolidColorBrush x:Key="TextBodyBrush" Color="#FF334155"/>
        <SolidColorBrush x:Key="SurfaceBrush" Color="#FFFFFFFF"/>

        <SolidColorBrush x:Key="BtnSecondaryBg" Color="#FFFFFFFF"/>
        <SolidColorBrush x:Key="BtnSecondaryBorder" Color="#FF94A3B8"/>
        <SolidColorBrush x:Key="BtnSecondaryHoverBg" Color="#FFF1F5F9"/>

        <SolidColorBrush x:Key="CloseHoverBg" Color="#FFFEE2E2"/>
        <SolidColorBrush x:Key="CloseHoverBorder" Color="#FFFCA5A5"/>

        <SolidColorBrush x:Key="BadgeBg" Color="#FFF1F5F9"/>
        <SolidColorBrush x:Key="BadgeBorder" Color="#FFE2E8F0"/>

        <LinearGradientBrush x:Key="PrimaryBrush" StartPoint="0,0" EndPoint="1,0">
            <GradientStop Color="#FF2563EB" Offset="0"/>
            <GradientStop Color="#FF4F46E5" Offset="1"/>
        </LinearGradientBrush>

        <LinearGradientBrush x:Key="PrimaryHoverBrush" StartPoint="0,0" EndPoint="1,0">
            <GradientStop Color="#FF1D4ED8" Offset="0"/>
            <GradientStop Color="#FF4338CA" Offset="1"/>
        </LinearGradientBrush>

        <LinearGradientBrush x:Key="HeaderBrush" StartPoint="0,0" EndPoint="1,0">
            <GradientStop Color="#FF35537C" Offset="0"/>
            <GradientStop Color="#FF2C5C64" Offset="1"/>
        </LinearGradientBrush>

        <LinearGradientBrush x:Key="AccentBrush" StartPoint="0,0" EndPoint="0,1">
            <GradientStop Color="#FF38BDF8" Offset="0"/>
            <GradientStop Color="#FF6366F1" Offset="1"/>
        </LinearGradientBrush>

        <Style x:Key="BtnBase" TargetType="Button">
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="FontSize" Value="13"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="Height" Value="40"/>
            <Setter Property="Padding" Value="16,0"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="Bd"
                                CornerRadius="10"
                                Background="{TemplateBinding Background}"
                                BorderBrush="{TemplateBinding BorderBrush}"
                                BorderThickness="{TemplateBinding BorderThickness}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="Bd" Property="RenderTransformOrigin" Value="0.5,0.5"/>
                                <Setter TargetName="Bd" Property="RenderTransform">
                                    <Setter.Value>
                                        <ScaleTransform ScaleX="0.98" ScaleY="0.98"/>
                                    </Setter.Value>
                                </Setter>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style x:Key="PrimaryButton" TargetType="Button" BasedOn="{StaticResource BtnBase}">
            <Setter Property="Foreground" Value="White"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Background" Value="{StaticResource PrimaryBrush}"/>
            <Style.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter Property="Background" Value="{StaticResource PrimaryHoverBrush}"/>
                </Trigger>
            </Style.Triggers>
        </Style>

        <Style x:Key="SecondaryButton" TargetType="Button" BasedOn="{StaticResource BtnBase}">
            <Setter Property="Foreground" Value="{StaticResource TextPrimaryBrush}"/>
            <Setter Property="Background" Value="{StaticResource BtnSecondaryBg}"/>
            <Setter Property="BorderBrush" Value="{StaticResource BtnSecondaryBorder}"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Style.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter Property="Background" Value="{StaticResource BtnSecondaryHoverBg}"/>
                </Trigger>
            </Style.Triggers>
        </Style>

        <!-- Canonical identity keys (Identity Lock) - Card styles the dialog shell;
             NavBtnBase is reserved by the design system and unused in this popup. -->
        <Style x:Key="Card" TargetType="Border">
            <Setter Property="Background" Value="{StaticResource BackgroundBrush}"/>
            <Setter Property="BorderBrush" Value="{StaticResource BorderBrush}"/>
            <Setter Property="BorderThickness" Value="2"/>
            <Setter Property="CornerRadius" Value="10"/>
        </Style>

        <Style x:Key="NavBtnBase" TargetType="Button" BasedOn="{StaticResource BtnBase}"/>

        <Style x:Key="IconButton" TargetType="Button">
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Width" Value="38"/>
            <Setter Property="Height" Value="38"/>
            <Setter Property="Background" Value="#FFFFFFFF"/>
            <Setter Property="BorderBrush" Value="#FF94A3B8"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="Bd"
                                CornerRadius="10"
                                Background="{TemplateBinding Background}"
                                BorderBrush="{TemplateBinding BorderBrush}"
                                BorderThickness="{TemplateBinding BorderThickness}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="Bd" Property="Background" Value="#FFF1F5F9"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="Bd" Property="Background" Value="#FFE2E8F0"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

    </Window.Resources>

    <Grid Margin="18">
        <Border Style="{StaticResource Card}">
            <Border.Effect>
                <DropShadowEffect BlurRadius="25" ShadowDepth="0" Opacity="0.50" Color="#000000"/>
            </Border.Effect>

            <Grid>
                <Grid.RowDefinitions>
                    <RowDefinition Height="84"/>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="Auto"/>
                </Grid.RowDefinitions>

                <Border Grid.Row="0" CornerRadius="10,10,0,0" Background="{StaticResource HeaderBrush}">
                    <Grid Margin="18,14">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="Auto"/>
                            <ColumnDefinition Width="12"/>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="Auto"/>
                            <ColumnDefinition Width="10"/>
                            <ColumnDefinition Width="Auto"/>
                        </Grid.ColumnDefinitions>

                        <Border Grid.Column="0" Width="54" Height="54" CornerRadius="10"
                                Background="#FFFFFFFF" BorderBrush="#FF94A3B8" BorderThickness="1">
                            <Grid>
                                <TextBlock Name="TxtLogoFallback"
                                           Text="IT"
                                           FontSize="16"
                                           FontWeight="SemiBold"
                                           Foreground="#FF2563EB"
                                           VerticalAlignment="Center"
                                           HorizontalAlignment="Center"/>
                                <Image Name="ImgLogo" Stretch="Uniform" Margin="8" Visibility="Collapsed"/>
                            </Grid>
                        </Border>

                        <StackPanel Grid.Column="2" VerticalAlignment="Center">
                            <TextBlock Name="TxtHeadline"
                                       FontSize="20"
                                       FontWeight="SemiBold"
                                       Foreground="#FFFFFFFF"
                                       Text="$Txt_HeaderTitle"/>
                            <TextBlock Name="TxtSubHeadline"
                                       FontSize="13"
                                       Foreground="#FFE2E8F0"
                                       Margin="0,4,0,0"
                                       Text="$Txt_HeaderSubTitle"/>
                        </StackPanel>

                        <Button Name="BtnMin" Grid.Column="3" Style="{StaticResource IconButton}">
                            <Path Data="$MinimizeIconData" Fill="#FF0F172A" Width="16" Height="16" Stretch="Uniform"/>
                        </Button>

                        <Button Name="BtnX" Grid.Column="5">
                            <Button.Style>
                                <Style TargetType="Button" BasedOn="{StaticResource IconButton}">
                                    <Style.Triggers>
                                        <Trigger Property="IsMouseOver" Value="True">
                                            <Setter Property="Background" Value="{StaticResource CloseHoverBg}"/>
                                            <Setter Property="BorderBrush" Value="{StaticResource CloseHoverBorder}"/>
                                        </Trigger>
                                    </Style.Triggers>
                                </Style>
                            </Button.Style>
                            <Path Data="$CloseIconData" Fill="#FF0F172A" Width="16" Height="16" Stretch="Uniform"/>
                        </Button>
                    </Grid>
                </Border>

                <Grid Grid.Row="1" Margin="22,18,22,0">
                    <Border CornerRadius="10"
                            Background="{StaticResource SurfaceBrush}"
                            BorderBrush="#FFD7E6FA"
                            BorderThickness="1"
                            Padding="14">
                        <StackPanel>
                            <TextBlock Name="TxtMessageTitle"
                                       FontSize="16"
                                       FontWeight="SemiBold"
                                       Foreground="{StaticResource TextPrimaryBrush}"
                                       Margin="0,0,0,6"
                                       TextAlignment="Left"/>
                            <TextBlock Name="TxtMessageBody"
                                       xml:space="preserve"
                                       TextWrapping="Wrap"
                                       TextAlignment="Left"
                                       LineHeight="22"
                                       LineStackingStrategy="BlockLineHeight"
                                       FontSize="14"
                                       Foreground="{StaticResource TextBodyBrush}"
                                       Margin="4,0,4,0"/>
                        </StackPanel>
                    </Border>
                </Grid>

                <Grid Grid.Row="2" Margin="22,12,22,10">
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="10"/>
                        <RowDefinition Height="Auto"/>
                    </Grid.RowDefinitions>

                    <Grid Grid.Row="0">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="Auto"/>
                        </Grid.ColumnDefinitions>

                        <TextBlock Grid.Column="0"
                                   VerticalAlignment="Center"
                                   FontSize="13"
                                   Foreground="{StaticResource TextMutedBrush}"
                                   Text="$Txt_Footer"/>

                        <Border Grid.Column="1"
                                Padding="10,6"
                                CornerRadius="10"
                                Background="{StaticResource BadgeBg}"
                                BorderBrush="{StaticResource BadgeBorder}"
                                BorderThickness="1">
                            <TextBlock Name="TxtDeployedByCtrl"
                                       FontSize="12"
                                       Foreground="{StaticResource TextMutedBrush}"
                                       Text="$Txt_DeployedBy"/>
                        </Border>
                    </Grid>

                    <StackPanel Grid.Row="2"
                                Orientation="Horizontal"
                                HorizontalAlignment="Left"
                                FlowDirection="LeftToRight">

                        <Button Name="BtnRestartNow"
                                Style="{StaticResource PrimaryButton}"
                                MinWidth="160"
                                Content="$Txt_BtnRestartNow"/>

                        <Border Width="10" Background="Transparent"/>

                        <Button Name="BtnRestart1H"
                                Style="{StaticResource SecondaryButton}"
                                MinWidth="190"
                                Content="$Txt_BtnRestart1H"/>

                        <Border Width="10" Background="Transparent"/>

                        <Button Name="BtnRestart2H"
                                Style="{StaticResource SecondaryButton}"
                                MinWidth="190"
                                Content="$Txt_BtnRestart2H"/>

                        <Border Width="10" Background="Transparent"/>

                        <Button Name="BtnClose"
                                Style="{StaticResource SecondaryButton}"
                                MinWidth="110"
                                Content="$Txt_BtnClose"/>
                    </StackPanel>
                </Grid>

                <Border Width="7"
                        HorizontalAlignment="Left"
                        CornerRadius="10,0,0,0"
                        Background="{StaticResource AccentBrush}"/>
            </Grid>
        </Border>
    </Grid>
</Window>
"@

    # --- Build window ---
    try {
        $reader = New-Object System.Xml.XmlNodeReader $xaml
        $window = [Windows.Markup.XamlReader]::Load($reader)
    }
    catch [System.Windows.Markup.XamlParseException] {
        throw "XAML load failed: $($_.Exception.Message)"
    }

    # Map XAML controls
    $imgLogo             = $window.FindName('ImgLogo')
    $txtLogoFallback     = $window.FindName('TxtLogoFallback')
    $txtMessageTitleCtrl = $window.FindName('TxtMessageTitle')
    $txtMessageBodyCtrl  = $window.FindName('TxtMessageBody')

    $btnRestartNow = $window.FindName('BtnRestartNow')
    $btnRestart1H  = $window.FindName('BtnRestart1H')
    $btnRestart2H  = $window.FindName('BtnRestart2H')
    $btnClose      = $window.FindName('BtnClose')
    $btnX          = $window.FindName('BtnX')
    $btnMin        = $window.FindName('BtnMin')

    if ($txtMessageTitleCtrl) { $txtMessageTitleCtrl.Text = $txtMessageTitle }
    if ($txtMessageBodyCtrl)  { $txtMessageBodyCtrl.Text  = $txtMessageBody }

    # --- Load logo (embedded base64 first, then side-by-side file) ---
    $loadedBitmap = $null

    if ($LogoBase64 -and ($LogoBase64 -notlike '<PASTE-*') -and ($LogoBase64.Trim().Length -gt 50)) {
        $loadedBitmap = Get-BitmapImageFromBase64 -Base64String $LogoBase64
    }

    if (-not $loadedBitmap -and (Test-Path -LiteralPath $logoPath)) {
        $loadedBitmap = Get-BitmapImageFromFile -Path $logoPath
    }

    if ($imgLogo -and $loadedBitmap) {
        $imgLogo.Source = $loadedBitmap
        $imgLogo.Visibility = 'Visible'

        if ($txtLogoFallback) {
            $txtLogoFallback.Visibility = 'Collapsed'
        }
    }
    else {
        if ($imgLogo) {
            $imgLogo.Visibility = 'Collapsed'
        }

        if ($txtLogoFallback) {
            $txtLogoFallback.Visibility = 'Visible'
        }
    }

    # --- Enforcement (policy-driven scheduled restart before dialog shows) ---
    if ($pendingReboot -and $needForce) {
        $scheduled = Schedule-Restart -Seconds $GraceSeconds
        $remediationResult.ForcedScheduled = [bool]$scheduled
        Write-RemediationLog "Pending reboot detected. Restart scheduled in $GraceSeconds second(s). Scheduled=$scheduled" -Level 'Warning'
    }

    # --- UI events ---
    # Allow dragging the borderless window.
    $window.Add_MouseLeftButtonDown({
        try {
            $window.DragMove()
        }
        catch [System.InvalidOperationException] {
            # Mouse button was already released - dragging is a no-op.
        }
    })

    if ($btnRestartNow) {
        $btnRestartNow.Add_Click({
            if (-not (Guard-Action 'Restart Now')) { return }
            try {
                # Cancel any pending countdown before forcing an immediate restart.
                Start-Process -FilePath "$env:SystemRoot\System32\shutdown.exe" `
                    -ArgumentList '/a' `
                    -WindowStyle Hidden `
                    -ErrorAction SilentlyContinue | Out-Null

                $restarted = Try-RestartNow
                Write-RemediationLog "Restart now clicked. RestartTriggered=$restarted" -Level 'Info'

                try {
                    $window.Close()
                }
                catch [System.InvalidOperationException] {
                    # Window already closing - nothing to do.
                }
            }
            finally {
                Release-Action
            }
        })
    }

    if ($btnRestart1H) {
        $btnRestart1H.Add_Click({
            if (-not (Guard-Action 'Restart in 1 hour')) { return }
            try {
                $scheduled = Schedule-Restart -Seconds 3600
                Write-RemediationLog "Restart after 1 hour clicked. Scheduled=$scheduled" -Level 'Info'

                try {
                    $window.Close()
                }
                catch [System.InvalidOperationException] {
                    # Window already closing - nothing to do.
                }
            }
            finally {
                Release-Action
            }
        })
    }

    if ($btnRestart2H) {
        $btnRestart2H.Add_Click({
            if (-not (Guard-Action 'Restart in 2 hours')) { return }
            try {
                $scheduled = Schedule-Restart -Seconds 7200
                Write-RemediationLog "Restart after 2 hours clicked. Scheduled=$scheduled" -Level 'Info'

                try {
                    $window.Close()
                }
                catch [System.InvalidOperationException] {
                    # Window already closing - nothing to do.
                }
            }
            finally {
                Release-Action
            }
        })
    }

    if ($btnClose) {
        $btnClose.Add_Click({
            Write-RemediationLog "Dialog closed by user." -Level 'Info'
            try {
                $window.Close()
            }
            catch [System.InvalidOperationException] {
                # Window already closing - nothing to do.
            }
        })
    }

    if ($btnX) {
        $btnX.Add_Click({
            Write-RemediationLog "Dialog closed from X button." -Level 'Info'
            try {
                $window.Close()
            }
            catch [System.InvalidOperationException] {
                # Window already closing - nothing to do.
            }
        })
    }

    if ($btnMin) {
        $btnMin.Add_Click({
            Write-RemediationLog "Dialog minimized by user." -Level 'Info'
            try {
                $window.WindowState = 'Minimized'
            }
            catch [System.InvalidOperationException] {
                # Window state transition raced with close - nothing to do.
            }
        })
    }

    # --- Show (blocks until the user handles the dialog) ---
    $null = $window.ShowDialog()
    $remediationResult.DialogShown = $true
    $remediationResult.Status = "Success"
    $remediationResult.PostCheckStatus += "Verification passed after remediation - restart notification was delivered"

    Write-Output "Restart notification delivered to the logged-on user"
    Write-Output ($remediationResult | ConvertTo-Json -Depth 6 -Compress)
    Finish-Script -ExitCode 0 -Message "Remediation finished. PendingReboot=$pendingReboot | UptimeDays=$uptimeDays" -Level 'SUCCESS'
}
catch {
    $remediationResult.Status = "Error"
    $remediationResult.Error = @{
        Message    = $_.Exception.Message
        Type       = $_.Exception.GetType().FullName
        StackTrace = $_.ScriptStackTrace
    }

    # Fallback: when enforcement is mandatory and the dialog cannot be shown,
    # schedule a delayed restart so the device still converges.
    if ($remediationResult.PendingReboot -and $ForceRestartWhenPending) {
        $scheduled = Schedule-Restart -Seconds 900
        $remediationResult.ForcedScheduled = [bool]$scheduled
        Write-RemediationLog "Dialog failed; fallback restart scheduling attempted for 900 second(s). Scheduled=$scheduled" -Level 'Warning'

        if ($scheduled) {
            Write-Output ($remediationResult | ConvertTo-Json -Depth 6 -Compress)
            Finish-Script -ExitCode 0 -Message "Dialog failed but fallback restart was scheduled" -Level 'WARNING'
        }
    }

    Write-Output ($remediationResult | ConvertTo-Json -Depth 6 -Compress)
    Finish-Script -ExitCode 2 -Message "Script execution error: $($_.Exception.Message)" -Level 'ERROR'
}

