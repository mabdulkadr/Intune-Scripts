<#!
.SYNOPSIS
    Display an Arabic restart prompt and perform optional restart scheduling actions.

.DESCRIPTION
    This script is designed for Intune Proactive Remediations.
    It shows a custom Arabic WPF dialog when either condition is met:
    - A Windows update reboot is pending.
    - Device uptime is greater than or equal to the configured threshold.

    The user can restart now, postpone restart, or close the prompt.
    Forced restart is optional and controlled by settings.

    For Intune Proactive Remediations:
    - Run script using logged-on credentials = Yes (required for WPF UI).
    - Save as UTF-8 with BOM for Arabic in PS 5.1.

.EXAMPLE
    .\WinUptimeRestartNotification--Remediate.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.0
#>

#region ============================ SETTINGS ===================================
# Keep this value aligned with the detection script.
$MaxUptimeDays   = 14

# Restart behavior controls
$ForceRestartWhenPending = $false         # When true, pending update reboot will be scheduled automatically
$GraceSeconds            = 3600           # Grace period in seconds before forced restart executes
$ShutdownReason          = "إعادة تشغيل مطلوبة لإكمال تحديثات النظام (Intune Remediation)."

# UI branding and message text
$Txt_HeaderTitle    = "إشعار من تقنية المعلومات"
$Txt_HeaderSubTitle = "يرجى مراجعة التنبيه واتخاذ الإجراء المناسب"

$Txt_Footer     = "للمساعدة، يرجى التواصل مع الدعم الفني."
$Txt_DeployedBy = "مرسل عبر Microsoft Intune"

$Txt_BtnRestartNow  = "إعادة تشغيل الآن"
$Txt_BtnRestart1H   = "إعادة التشغيل بعد ساعة"
$Txt_BtnRestart2H   = "إعادة التشغيل بعد ساعتين"
$Txt_BtnClose       = "إغلاق"

# Optional logo source (file and/or embedded base64)
$Brand_LogoFile = "logo.png"
$LogoBase64 = "/9j/4QAYRXhpZgAASUkqAAgAAAAAAAAAAAAAAP/sABFEdWNreQABAAQAAABLAAD/4QMpaHR0cDovL25zLmFkb2JlLmNvbS94YXAvMS4wLwA8P3hwYWNrZXQgYmVnaW49Iu+7vyIgaWQ9Ilc1TTBNcENlaGlIenJlU3pOVGN6a2M5ZCI/PiA8eDp4bXBtZXRhIHhtbG5zOng9ImFkb2JlOm5zOm1ldGEvIiB4OnhtcHRrPSJBZG9iZSBYTVAgQ29yZSA1LjAtYzA2MCA2MS4xMzQ3NzcsIDIwMTAvMDIvMTItMTc6MzI6MDAgICAgICAgICI+IDxyZGY6UkRGIHhtbG5zOnJkZj0iaHR0cDovL3d3dy53My5vcmcvMTk5OS8wMi8yMi1yZGYtc3ludGF4LW5zIyI+IDxyZGY6RGVzY3JpcHRpb24gcmRmOmFib3V0PSIiIHhtbG5zOnhtcD0iaHR0cDovL25zLmFkb2JlLmNvbS94YXAvMS4wLyIgeG1sbnM6eG1wTU09Imh0dHA6Ly9ucy5hZG9iZS5jb20veGFwLzEuMC9tbS8iIHhtbG5zOnN0UmVmPSJodHRwOi8vbnMuYWRvYmUuY29tL3hhcC8xLjAvc1R5cGUvUmVzb3VyY2VSZWYjIiB4bXA6Q3JlYXRvclRvb2w9IkFkb2JlIFBob3Rvc2hvcCBDUzUgV2luZG93cyIgeG1wTU06SW5zdGFuY2VJRD0ieG1wLmlpZDpERUI4M0M2NUMzNTcxMUVFQkMwOUZDNTNBN0Q2MTgyNiIgeG1wTU06RG9jdW1lbnRJRD0ieG1wLmRpZDpERUI4M0M2NkMzNTcxMUVFQkMwOUZDNTNBN0Q2MTgyNiI+IDx4bXBNTTpEZXJpdmVkRnJvbSBzdFJlZjppbnN0YW5jZUlEPSJ4bXAuaWlkOkRFQjgzQzYzQzM1NzExRUVCQzA5RkM1M0E3RDYxODI2IiBzdFJlZjpkb2N1bWVudElEPSJ4bXAuZGlkOkRFQjgzQzY0QzM1NzExRUVCQzA5RkM1M0E3RDYxODI2Ii8+IDwvcmRmOkRlc2NyaXB0aW9uPiA8L3JkZjpSREY+IDwveDp4bXBtZXRhPiA8P3hwYWNrZXQgZW5kPSJyIj8+/+4ADkFkb2JlAGTAAAAAAf/bAIQAAwICAgICAwICAwUDAwMFBQQDAwQF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"

# Window behavior and dimensions
$TopMost   = $true
$WinWidth     = 900
$WinHeight    = 450   # Used as minimum height when SizeToContent is enabled
$MaxWinHeight = 700   # Maximum height to avoid oversized window

# Use fixed names so Intune staging does not change the log file name.
$SystemDrive    = if ([string]::IsNullOrWhiteSpace($env:SystemDrive)) { 'C:' } else { $env:SystemDrive }
$ScriptName     = 'WinUptimeRestartNotification--Remediate.ps1'
$ScriptBaseName = 'WinUptimeRestartNotification--Remediate'
$LogDirectory   = Join-Path -Path $SystemDrive -ChildPath 'Intune\WindowsUptimeRestartNotification'
$LogFile        = Join-Path -Path $LogDirectory -ChildPath "$ScriptBaseName.txt"
#endregion =====================================================================

#region ============================ WPF LOAD ==================================
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName WindowsBase
#endregion =====================================================================

#region ============================ HELPERS ===================================
function Initialize-LogFile {
    # Create the log directory only when it is needed.
    if (-not (Test-Path -LiteralPath $LogDirectory)) {
        New-Item -Path $LogDirectory -ItemType Directory -Force | Out-Null
    }
}

function Write-Log {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [ValidateSet('INFO', 'OK', 'WARN', 'FAIL')]
        [string]$Level = 'INFO'
    )

    Initialize-LogFile

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $line = "[$timestamp] [$Level] $Message"

    Add-Content -Path $LogFile -Value $line -Encoding UTF8
    Write-Output $line
}

function Get-PendingRebootInfo {
    # Detect update-related reboot requirements from Windows servicing keys.
    $updateReasons = New-Object System.Collections.Generic.List[string]

    if (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired") {
        $updateReasons.Add("تحديثات Windows")
    }
    if (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending") {
        $updateReasons.Add("مكوّنات النظام (CBS)")
    }

    $u = $updateReasons | Select-Object -Unique
    $hasUpdates = ($u -and $u.Count -gt 0)
    $pending = $hasUpdates

    return [pscustomobject]@{
        Pending       = $pending
        HasUpdates    = $hasUpdates
        UpdateReasons = $u
    }
}

function Get-UptimeDays {
    # Return full days since last boot. Falls back to 0 if uptime cannot be read.
    try {
        $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
        $boot = $os.LastBootUpTime
        $span = (Get-Date) - $boot
        return [Math]::Floor($span.TotalDays)
    } catch { return 0 }
}

function Try-RestartNow {
    # Try Restart-Computer first, then shutdown.exe
    try {
        Restart-Computer -Force -ErrorAction Stop
        return $true
    } catch {
        try {
            Start-Process -FilePath "$env:SystemRoot\System32\shutdown.exe" -ArgumentList "/r /t 0 /f /c `"$ShutdownReason`"" -WindowStyle Hidden
            return $true
        } catch { return $false }
    }
}

function Schedule-Restart {
    param([int]$Seconds)

    # Cancel any previously scheduled shutdown first (best effort).
    try { Start-Process "$env:SystemRoot\System32\shutdown.exe" -ArgumentList "/a" -WindowStyle Hidden -ErrorAction SilentlyContinue } catch { }

    $args = "/r /t $Seconds /f /c `"$ShutdownReason`""
    try {
        Start-Process -FilePath "$env:SystemRoot\System32\shutdown.exe" -ArgumentList $args -WindowStyle Hidden
        return $true
    } catch { return $false }
}

function Get-BitmapImageFromBase64 {
    param([Parameter(Mandatory=$true)][string]$Base64String)
    try {
        $b64 = $Base64String.Trim()
        if ($b64 -match 'base64,') { $b64 = ($b64 -split 'base64,')[-1].Trim() }

        $bytes = [Convert]::FromBase64String($b64)

        # WebP is not supported by default WPF image codecs.
        if ($bytes.Length -ge 12) {
            $h0 = [Text.Encoding]::ASCII.GetString($bytes, 0, 4)  # RIFF
            $h1 = [Text.Encoding]::ASCII.GetString($bytes, 8, 4)  # WEBP
            if ($h0 -eq 'RIFF' -and $h1 -eq 'WEBP') { return $null }
        }

        $ms = New-Object System.IO.MemoryStream(,$bytes)
        $bmp = New-Object System.Windows.Media.Imaging.BitmapImage
        $bmp.BeginInit()
        $bmp.CacheOption  = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
        $bmp.StreamSource = $ms
        $bmp.EndInit()
        $bmp.Freeze()
        $ms.Dispose()
        return $bmp
    } catch { return $null }
}

function Get-BitmapImageFromFile {
    param([Parameter(Mandatory=$true)][string]$Path)
    try {
        $bmp = New-Object System.Windows.Media.Imaging.BitmapImage
        $bmp.BeginInit()
        $bmp.CacheOption = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
        $bmp.UriSource = New-Object System.Uri($Path)
        $bmp.EndInit()
        $bmp.Freeze()
        return $bmp
    } catch { return $null }
}
#endregion =====================================================================

#region ============================ DECISION ==================================
# Evaluate detection signals once, then decide whether to show the notice.
Write-Log "=== Remediation START ==="
Write-Log "Script: $ScriptName"
Write-Log "Log file: $LogFile"
Write-Log "Maximum uptime threshold: $MaxUptimeDays day(s)"
Write-Log "Force restart when pending reboot: $ForceRestartWhenPending"

$PendingInfo  = Get-PendingRebootInfo
$PendingReboot = $PendingInfo.Pending
$UptimeDays    = Get-UptimeDays

$needNotice = $false
$needForce  = $false

if ($PendingReboot) {
    $needNotice = $true
    $needForce  = $ForceRestartWhenPending
}
elseif ($UptimeDays -ge $MaxUptimeDays) {
    $needNotice = $true
    $needForce  = $false
}

if (-not $needNotice) {
    Write-Log "No restart notification is required. PendingReboot=$PendingReboot | UptimeDays=$UptimeDays" 'OK'
    Write-Log "=== Remediation END (Exit 0) ==="
    exit 0
}

# Build message body based on the active trigger(s).
$Txt_MessageTitle = "يلزم إعادة تشغيل الجهاز"
$sections = New-Object System.Collections.Generic.List[string]

if ($PendingInfo.HasUpdates) {
    $detail = ""
    if ($PendingInfo.UpdateReasons -and $PendingInfo.UpdateReasons.Count -gt 0) {
        $detail = " (" + ($PendingInfo.UpdateReasons -join "، ") + ")"
    }
    $sections.Add("• توجد تحديثات نظام معلّقة وتتطلب إعادة تشغيل$detail.")
}

if ($UptimeDays -ge $MaxUptimeDays) {
    $sections.Add("• تجاوزت مدة تشغيل الجهاز $MaxUptimeDays أيام دون إعادة تشغيل.")
}

if ($sections.Count -eq 0) {
    $sections.Add("• يلزم إعادة تشغيل الجهاز لإكمال المتطلبات.")
}
$lines = New-Object System.Collections.Generic.List[string]
foreach ($s in $sections) { $lines.Add($s) }
$lines.Add("")
$lines.Add("• يُرجى حفظ عملك قبل المتابعة.")
$lines.Add("• يمكنك إعادة التشغيل الآن.")
$lines.Add("• أو جدولة إعادة التشغيل بعد ساعة.")
$lines.Add("• أو جدولة إعادة التشغيل بعد ساعتين.")
$Txt_MessageBody = $lines -join "`n"
#endregion =====================================================================

#region ============================ XAML ======================================
$LogoPath = Join-Path -Path $PSScriptRoot -ChildPath $Brand_LogoFile

[xml]$Xaml = @"
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
        FlowDirection="RightToLeft">

    <Window.Resources>

        <SolidColorBrush x:Key="CardBg" Color="#E5E5E5"/>
        <SolidColorBrush x:Key="Border" Color="#FFFFFFFF"/>
        <SolidColorBrush x:Key="TextDark" Color="#FF0F172A"/>
        <SolidColorBrush x:Key="TextMuted" Color="#FF64748B"/>
        <SolidColorBrush x:Key="TextBody" Color="#FF334155"/>
        <SolidColorBrush x:Key="Surface" Color="#FFFFFFFF"/>

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

        <LinearGradientBrush x:Key="AccentStrip" StartPoint="0,0" EndPoint="0,1">
            <GradientStop Color="#FF38BDF8" Offset="0"/>
            <GradientStop Color="#FF6366F1" Offset="1"/>
        </LinearGradientBrush>

        <Style x:Key="BaseButton" TargetType="Button">
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

        <Style x:Key="PrimaryButton" TargetType="Button" BasedOn="{StaticResource BaseButton}">
            <Setter Property="Foreground" Value="White"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Background" Value="{StaticResource PrimaryBrush}"/>
            <Style.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter Property="Background" Value="{StaticResource PrimaryHoverBrush}"/>
                </Trigger>
            </Style.Triggers>
        </Style>

        <Style x:Key="SecondaryButton" TargetType="Button" BasedOn="{StaticResource BaseButton}">
            <Setter Property="Foreground" Value="{StaticResource TextDark}"/>
            <Setter Property="Background" Value="{StaticResource BtnSecondaryBg}"/>
            <Setter Property="BorderBrush" Value="{StaticResource BtnSecondaryBorder}"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Style.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter Property="Background" Value="{StaticResource BtnSecondaryHoverBg}"/>
                </Trigger>
            </Style.Triggers>
        </Style>

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
        <Border CornerRadius="10"
                Background="{StaticResource CardBg}"
                BorderBrush="{StaticResource Border}"
                BorderThickness="2">
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
                                       FontSize="20" FontWeight="SemiBold"
                                       Foreground="#FFFFFFFF"
                                       Text="$Txt_HeaderTitle"/>
                            <TextBlock Name="TxtSubHeadline"
                                       FontSize="13"
                                       Foreground="#FFE2E8F0"
                                       Margin="0,4,0,0"
                                       Text="$Txt_HeaderSubTitle"/>
                        </StackPanel>

                        <Button Name="BtnMin" Grid.Column="3" Style="{StaticResource IconButton}">
                            <TextBlock Text="&#xE921;" FontFamily="Segoe Fluent Icons"
                                       FontSize="16" Foreground="#FF0F172A"/>
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
                            <TextBlock Text="&#xE8BB;" FontFamily="Segoe Fluent Icons"
                                       FontSize="16" Foreground="#FF0F172A"/>
                        </Button>
                    </Grid>
                </Border>

                <Grid Grid.Row="1" Margin="22,18,22,0">
                    <Border CornerRadius="10"
                            Background="{StaticResource Surface}"
                            BorderBrush="#FFD7E6FA"
                            BorderThickness="1"
                            Padding="14">
                        <StackPanel>
                            <TextBlock Name="TxtMessageTitle"
                                       FontSize="16"
                                       FontWeight="SemiBold"
                                       Foreground="{StaticResource TextDark}"
                                       Margin="0,0,0,6"
                                       TextAlignment="left"
                                       Text="$Txt_MessageTitle"/>
                            <TextBlock Name="TxtMessageBody"
                                       xml:space="preserve"
                                       TextWrapping="Wrap"
                                       TextAlignment="left"
                                       LineHeight="22"
                                       LineStackingStrategy="BlockLineHeight"
                                       FontSize="14"
                                       Foreground="{StaticResource TextBody}"
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

                        <TextBlock Grid.Column="0" VerticalAlignment="Center"
                                   FontSize="13" Foreground="{StaticResource TextMuted}"
                                   Text="$Txt_Footer"/>

                        <Border Grid.Column="1" Padding="10,6" CornerRadius="10"
                                Background="{StaticResource BadgeBg}"
                                BorderBrush="{StaticResource BadgeBorder}" BorderThickness="1">
                            <TextBlock Name="TxtDeployedBy"
                                       FontSize="12"
                                       Foreground="{StaticResource TextMuted}"
                                       Text="$Txt_DeployedBy"/>
                        </Border>
                    </Grid>

                    <StackPanel Grid.Row="2"
                                Orientation="Horizontal"
                                HorizontalAlignment="left"
                                FlowDirection="RightToLeft">

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

                <Border Width="7" HorizontalAlignment="Left" CornerRadius="10,0,0,0"
                        Background="{StaticResource AccentStrip}"/>

            </Grid>
        </Border>
    </Grid>
</Window>
"@
#endregion =====================================================================

#region ============================ BUILD WINDOW ==============================
try {
    $Reader = New-Object System.Xml.XmlNodeReader $Xaml
    $Window = [Windows.Markup.XamlReader]::Load($Reader)
} catch {
    Write-Log "Failed to load XAML: $($_.Exception.Message)" 'FAIL'
    # If UI creation fails, still honor enforcement mode when applicable.
    if ($PendingReboot -and $needForce) {
        $scheduled = Schedule-Restart -Seconds 900
        Write-Log "Fallback restart scheduling attempted for 900 second(s). Scheduled=$scheduled" 'WARN'
        Write-Log "=== Remediation END (Exit 0) ==="
        exit 0
    }
    Write-Log "=== Remediation END (Exit 1) ==="
    exit 1
}

# Map named XAML controls to PowerShell variables.
$ImgLogo         = $Window.FindName("ImgLogo")
$TxtLogoFallback = $Window.FindName("TxtLogoFallback")
$TxtMessageTitleCtrl = $Window.FindName("TxtMessageTitle")
$TxtMessageBodyCtrl  = $Window.FindName("TxtMessageBody")

$BtnRestartNow   = $Window.FindName("BtnRestartNow")
$BtnRestart1H    = $Window.FindName("BtnRestart1H")
$BtnRestart2H    = $Window.FindName("BtnRestart2H")
$BtnClose        = $Window.FindName("BtnClose")
$BtnX            = $Window.FindName("BtnX")
$BtnMin          = $Window.FindName("BtnMin")

if ($TxtMessageTitleCtrl) { $TxtMessageTitleCtrl.Text = $Txt_MessageTitle }
if ($TxtMessageBodyCtrl)  { $TxtMessageBodyCtrl.Text  = $Txt_MessageBody }
#endregion =====================================================================

#region ============================ LOAD LOGO ================================
# Prefer embedded base64 logo, then fallback to file, then fallback text.
$LoadedBitmap = $null
if ($LogoBase64 -and ($LogoBase64.Trim().Length -gt 50)) {
    $LoadedBitmap = Get-BitmapImageFromBase64 -Base64String $LogoBase64
}
if (-not $LoadedBitmap -and (Test-Path -LiteralPath $LogoPath)) {
    $LoadedBitmap = Get-BitmapImageFromFile -Path $LogoPath
}
if ($ImgLogo -and $LoadedBitmap) {
    $ImgLogo.Source = $LoadedBitmap
    $ImgLogo.Visibility = "Visible"
    if ($TxtLogoFallback) { $TxtLogoFallback.Visibility = "Collapsed" }
} else {
    if ($ImgLogo) { $ImgLogo.Visibility = "Collapsed" }
    if ($TxtLogoFallback) { $TxtLogoFallback.Visibility = "Visible" }
}
#endregion =====================================================================

#region ============================ ENFORCEMENT ===============================
# If enforcement is enabled and update reboot is pending, schedule restart with grace period.
if ($PendingReboot -and $needForce) {
    $ok = Schedule-Restart -Seconds $GraceSeconds
    Write-Log "Pending reboot detected. Restart scheduled in $GraceSeconds second(s). Scheduled=$ok" 'WARN'
}
#endregion =====================================================================

#region ============================ UI EVENTS ================================
# Enable drag for the borderless custom window.
$Window.Add_MouseLeftButtonDown({ try { $Window.DragMove() } catch { } })

if ($BtnRestartNow) {
    $BtnRestartNow.Add_Click({
        # Cancel pending schedule first, then restart immediately.
        try { Start-Process "$env:SystemRoot\System32\shutdown.exe" -ArgumentList "/a" -WindowStyle Hidden -ErrorAction SilentlyContinue } catch { }
        $null = Try-RestartNow
        try { $Window.Close() } catch { }
    })
}

if ($BtnRestart1H) {
    $BtnRestart1H.Add_Click({
        $null = Schedule-Restart -Seconds 3600
        try { $Window.Close() } catch { }
    })
}

if ($BtnRestart2H) {
    $BtnRestart2H.Add_Click({
        $null = Schedule-Restart -Seconds 7200
        try { $Window.Close() } catch { }
    })
}

if ($BtnClose) { $BtnClose.Add_Click({ try { $Window.Close() } catch { } }) }

if ($BtnX)     { $BtnX.Add_Click({ try { $Window.Close() } catch { } }) }

if ($BtnMin) {
    $BtnMin.Add_Click({ try { $Window.WindowState = 'Minimized' } catch { } })
}
#endregion =====================================================================

#region ============================ SHOW ======================================
$null = $Window.ShowDialog()

Write-Log "Remediation finished. PendingReboot=$PendingReboot | UptimeDays=$UptimeDays" 'OK'
Write-Log "=== Remediation END (Exit 0) ==="
exit 0
#endregion =====================================================================


