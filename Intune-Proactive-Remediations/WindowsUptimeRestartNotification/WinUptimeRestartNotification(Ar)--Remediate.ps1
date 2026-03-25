<#
.SYNOPSIS
    Displays an Arabic restart prompt and performs optional restart scheduling actions.

.DESCRIPTION
    This script is designed for Intune Proactive Remediations.
    It shows a custom Arabic WPF dialog when either condition is met:
    - A Windows update reboot is pending.
    - Device uptime is greater than or equal to the configured threshold.

    The user can restart now, postpone restart, or close the prompt.
    Forced restart is optional and controlled by settings.

    For Intune Proactive Remediations:
    - Run script using logged-on credentials = Yes
    - Save as UTF-8 with BOM for Arabic in PowerShell 5.1

.RUN AS
    User

.EXAMPLE
    .\WinUptimeRestartNotification--Remediate.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.1
#>

#region ---------- Configuration ----------

# Script metadata
$ScriptName     = 'WinUptimeRestartNotification--Remediate.ps1'
$ScriptBaseName = 'WinUptimeRestartNotification--Remediate'
$SolutionName   = 'WindowsUptimeRestartNotification'

# Keep this value aligned with the detection script
$MaxUptimeDays = 14

# Restart behavior
$ForceRestartWhenPending = $false
$GraceSeconds            = 3600
$ShutdownReason          = 'إعادة تشغيل مطلوبة لإكمال تحديثات النظام (Intune Remediation).'

# UI text
$Txt_HeaderTitle    = 'إشعار من تقنية المعلومات'
$Txt_HeaderSubTitle = 'يرجى مراجعة التنبيه واتخاذ الإجراء المناسب'
$Txt_Footer         = 'للمساعدة، يرجى التواصل مع الدعم الفني.'
$Txt_DeployedBy     = 'مرسل عبر Microsoft Intune'

$Txt_BtnRestartNow = 'إعادة تشغيل الآن'
$Txt_BtnRestart1H  = 'إعادة التشغيل بعد ساعة'
$Txt_BtnRestart2H  = 'إعادة التشغيل بعد ساعتين'
$Txt_BtnClose      = 'إغلاق'

# Branding
$Brand_LogoFile = 'logo.png'

# ضع نفس قيمة LogoBase64 الحالية هنا إذا كنت تستخدم الشعار المضمّن
$LogoBase64 = '<PASTE-YOUR-CURRENT-BASE64-HERE>'

# Window settings
$TopMost      = $true
$WinWidth     = 900
$WinHeight    = 450
$MaxWinHeight = 700

# Detect Windows system drive
$SystemDrive = if ($env:SystemDrive) {
    $env:SystemDrive.TrimEnd('\')
}
else {
    'C:'
}

# Logging path
$BasePath = Join-Path $SystemDrive "Intune\$SolutionName"
$LogFile  = Join-Path $BasePath "$ScriptBaseName.txt"

#endregion ---------- Configuration ----------


#region ---------- WPF Load ----------

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName WindowsBase

#endregion ---------- WPF Load ----------


#region ---------- Functions ----------

# Create log folder and file if needed
function Initialize-Logging {
    try {
        if (-not (Test-Path -LiteralPath $BasePath)) {
            New-Item -Path $BasePath -ItemType Directory -Force | Out-Null
        }

        if (-not (Test-Path -LiteralPath $LogFile)) {
            New-Item -Path $LogFile -ItemType File -Force | Out-Null
        }

        return $true
    }
    catch {
        return $false
    }
}

# Write log line to console and file
function Write-Log {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [ValidateSet('INFO', 'SUCCESS', 'WARNING', 'ERROR')]
        [string]$Level = 'INFO'
    )

    $TimeStamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $Line = "[$TimeStamp] [$Level] $Message"

    switch ($Level) {
        'SUCCESS' { Write-Host $Line -ForegroundColor Green }
        'WARNING' { Write-Host $Line -ForegroundColor Yellow }
        'ERROR'   { Write-Host $Line -ForegroundColor Red }
        default   { Write-Host $Line -ForegroundColor Cyan }
    }

    if ($script:LogReady) {
        try {
            Add-Content -Path $LogFile -Value $Line -Encoding UTF8
        }
        catch {}
    }
}

# Detect reboot-required state
function Get-PendingRebootInfo {
    $Reasons = @()

    if (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired') {
        $Reasons += 'تحديثات Windows'
    }

    if (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending') {
        $Reasons += 'مكوّنات النظام (CBS)'
    }

    try {
        $PendingRename = Get-ItemProperty `
            -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' `
            -Name 'PendingFileRenameOperations' `
            -ErrorAction SilentlyContinue

        if ($PendingRename -and $PendingRename.PendingFileRenameOperations) {
            $Reasons += 'ملفات معلّقة لإعادة التسمية'
        }
    }
    catch {}

    $UniqueReasons = @($Reasons | Select-Object -Unique)

    return [pscustomobject]@{
        Pending = ($UniqueReasons.Count -gt 0)
        Reasons = $UniqueReasons
    }
}

# Return uptime in full days
function Get-UptimeDays {
    try {
        $OS = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
        $BootTime = $OS.LastBootUpTime
        $Uptime = (Get-Date) - $BootTime
        return [math]::Floor($Uptime.TotalDays)
    }
    catch {
        Write-Log -Message "Failed to read uptime: $($_.Exception.Message)" -Level 'WARNING'
        return $null
    }
}

# Try immediate restart
function Try-RestartNow {
    try {
        Restart-Computer -Force -ErrorAction Stop
        return $true
    }
    catch {
        try {
            Start-Process -FilePath "$env:SystemRoot\System32\shutdown.exe" `
                -ArgumentList "/r /t 0 /f /c `"$ShutdownReason`"" `
                -WindowStyle Hidden
            return $true
        }
        catch {
            return $false
        }
    }
}

# Schedule restart after X seconds
function Schedule-Restart {
    param(
        [Parameter(Mandatory = $true)]
        [int]$Seconds
    )

    try {
        Start-Process -FilePath "$env:SystemRoot\System32\shutdown.exe" `
            -ArgumentList '/a' `
            -WindowStyle Hidden `
            -ErrorAction SilentlyContinue | Out-Null
    }
    catch {}

    try {
        Start-Process -FilePath "$env:SystemRoot\System32\shutdown.exe" `
            -ArgumentList "/r /t $Seconds /f /c `"$ShutdownReason`"" `
            -WindowStyle Hidden | Out-Null
        return $true
    }
    catch {
        return $false
    }
}

# Load image from base64
function Get-BitmapImageFromBase64 {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Base64String
    )

    try {
        $CleanBase64 = $Base64String.Trim()

        if ($CleanBase64 -match 'base64,') {
            $CleanBase64 = ($CleanBase64 -split 'base64,')[-1].Trim()
        }

        $Bytes = [Convert]::FromBase64String($CleanBase64)

        if ($Bytes.Length -ge 12) {
            $Header1 = [Text.Encoding]::ASCII.GetString($Bytes, 0, 4)
            $Header2 = [Text.Encoding]::ASCII.GetString($Bytes, 8, 4)

            if ($Header1 -eq 'RIFF' -and $Header2 -eq 'WEBP') {
                return $null
            }
        }

        $MemoryStream = New-Object System.IO.MemoryStream(,$Bytes)
        $Bitmap = New-Object System.Windows.Media.Imaging.BitmapImage
        $Bitmap.BeginInit()
        $Bitmap.CacheOption  = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
        $Bitmap.StreamSource = $MemoryStream
        $Bitmap.EndInit()
        $Bitmap.Freeze()
        $MemoryStream.Dispose()

        return $Bitmap
    }
    catch {
        return $null
    }
}

# Load image from file
function Get-BitmapImageFromFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    try {
        $Bitmap = New-Object System.Windows.Media.Imaging.BitmapImage
        $Bitmap.BeginInit()
        $Bitmap.CacheOption = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
        $Bitmap.UriSource   = New-Object System.Uri($Path)
        $Bitmap.EndInit()
        $Bitmap.Freeze()
        return $Bitmap
    }
    catch {
        return $null
    }
}

#endregion ---------- Functions ----------


#region ---------- Decision Logic ----------

# Prepare logging
$LogReady = Initialize-Logging

Write-Log -Message "Starting remediation for $ScriptName"
Write-Log -Message "Maximum uptime threshold: $MaxUptimeDays day(s)"
Write-Log -Message "Force restart when pending reboot: $ForceRestartWhenPending"
Write-Log -Message "Log file: $LogFile"

$PendingInfo   = Get-PendingRebootInfo
$PendingReboot = $PendingInfo.Pending
$UptimeDays    = Get-UptimeDays

Write-Log -Message "Pending reboot detected: $PendingReboot"
if ($PendingInfo.Reasons.Count -gt 0) {
    Write-Log -Message "Pending reboot reasons: $($PendingInfo.Reasons -join ', ')"
}

if ($null -ne $UptimeDays) {
    Write-Log -Message "Current uptime: $UptimeDays day(s)"
}
else {
    Write-Log -Message 'Current uptime could not be determined.'
}

$NeedNotice = $false
$NeedForce  = $false

if ($PendingReboot) {
    $NeedNotice = $true
    $NeedForce  = $ForceRestartWhenPending
}
elseif (($null -ne $UptimeDays) -and ($UptimeDays -ge $MaxUptimeDays)) {
    $NeedNotice = $true
}

if (-not $NeedNotice) {
    Write-Log -Message "No restart notification is required. PendingReboot=$PendingReboot | UptimeDays=$UptimeDays" -Level 'SUCCESS'
    exit 0
}

# Build Arabic message text
$Txt_MessageTitle = 'يلزم إعادة تشغيل الجهاز'
$Sections = @()

if ($PendingInfo.Reasons.Count -gt 0) {
    $ReasonText = ' (' + ($PendingInfo.Reasons -join '، ') + ')'
    $Sections += "• توجد تحديثات أو تغييرات في النظام وتتطلب إعادة تشغيل$ReasonText."
}

if (($null -ne $UptimeDays) -and ($UptimeDays -ge $MaxUptimeDays)) {
    $Sections += "• تجاوزت مدة تشغيل الجهاز $MaxUptimeDays أيام دون إعادة تشغيل."
}

if ($Sections.Count -eq 0) {
    $Sections += '• يلزم إعادة تشغيل الجهاز لإكمال المتطلبات.'
}

$MessageLines = @()
$MessageLines += $Sections
$MessageLines += ''
$MessageLines += '• يُرجى حفظ عملك قبل المتابعة.'
$MessageLines += '• يمكنك إعادة التشغيل الآن.'
$MessageLines += '• أو جدولة إعادة التشغيل بعد ساعة.'
$MessageLines += '• أو جدولة إعادة التشغيل بعد ساعتين.'

$Txt_MessageBody = $MessageLines -join "`n"

#endregion ---------- Decision Logic ----------


#region ---------- XAML ----------

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
                                       TextAlignment="Left"/>
                            <TextBlock Name="TxtMessageBody"
                                       xml:space="preserve"
                                       TextWrapping="Wrap"
                                       TextAlignment="Left"
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

                        <TextBlock Grid.Column="0"
                                   VerticalAlignment="Center"
                                   FontSize="13"
                                   Foreground="{StaticResource TextMuted}"
                                   Text="$Txt_Footer"/>

                        <Border Grid.Column="1"
                                Padding="10,6"
                                CornerRadius="10"
                                Background="{StaticResource BadgeBg}"
                                BorderBrush="{StaticResource BadgeBorder}"
                                BorderThickness="1">
                            <TextBlock Name="TxtDeployedByCtrl"
                                       FontSize="12"
                                       Foreground="{StaticResource TextMuted}"
                                       Text="$Txt_DeployedBy"/>
                        </Border>
                    </Grid>

                    <StackPanel Grid.Row="2"
                                Orientation="Horizontal"
                                HorizontalAlignment="Left"
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

                <Border Width="7"
                        HorizontalAlignment="Left"
                        CornerRadius="10,0,0,0"
                        Background="{StaticResource AccentStrip}"/>
            </Grid>
        </Border>
    </Grid>
</Window>
"@

#endregion ---------- XAML ----------


#region ---------- Build Window ----------

try {
    $Reader = New-Object System.Xml.XmlNodeReader $Xaml
    $Window = [Windows.Markup.XamlReader]::Load($Reader)
}
catch {
    Write-Log -Message "Failed to load XAML: $($_.Exception.Message)" -Level 'ERROR'

    if ($PendingReboot -and $NeedForce) {
        $Scheduled = Schedule-Restart -Seconds 900
        Write-Log -Message "Fallback restart scheduling attempted for 900 second(s). Scheduled=$Scheduled" -Level 'WARNING'
        exit 0
    }

    exit 1
}

# Map XAML controls
$ImgLogo             = $Window.FindName('ImgLogo')
$TxtLogoFallback     = $Window.FindName('TxtLogoFallback')
$TxtMessageTitleCtrl = $Window.FindName('TxtMessageTitle')
$TxtMessageBodyCtrl  = $Window.FindName('TxtMessageBody')

$BtnRestartNow = $Window.FindName('BtnRestartNow')
$BtnRestart1H  = $Window.FindName('BtnRestart1H')
$BtnRestart2H  = $Window.FindName('BtnRestart2H')
$BtnClose      = $Window.FindName('BtnClose')
$BtnX          = $Window.FindName('BtnX')
$BtnMin        = $Window.FindName('BtnMin')

if ($TxtMessageTitleCtrl) { $TxtMessageTitleCtrl.Text = $Txt_MessageTitle }
if ($TxtMessageBodyCtrl)  { $TxtMessageBodyCtrl.Text  = $Txt_MessageBody }

#endregion ---------- Build Window ----------


#region ---------- Load Logo ----------

$LoadedBitmap = $null

if ($LogoBase64 -and ($LogoBase64 -notlike '<PASTE-*') -and ($LogoBase64.Trim().Length -gt 50)) {
    $LoadedBitmap = Get-BitmapImageFromBase64 -Base64String $LogoBase64
}

if (-not $LoadedBitmap -and (Test-Path -LiteralPath $LogoPath)) {
    $LoadedBitmap = Get-BitmapImageFromFile -Path $LogoPath
}

if ($ImgLogo -and $LoadedBitmap) {
    $ImgLogo.Source = $LoadedBitmap
    $ImgLogo.Visibility = 'Visible'

    if ($TxtLogoFallback) {
        $TxtLogoFallback.Visibility = 'Collapsed'
    }
}
else {
    if ($ImgLogo) {
        $ImgLogo.Visibility = 'Collapsed'
    }

    if ($TxtLogoFallback) {
        $TxtLogoFallback.Visibility = 'Visible'
    }
}

#endregion ---------- Load Logo ----------


#region ---------- Enforcement ----------

# Schedule forced restart only when enabled for pending reboot scenario
if ($PendingReboot -and $NeedForce) {
    $Scheduled = Schedule-Restart -Seconds $GraceSeconds
    Write-Log -Message "Pending reboot detected. Restart scheduled in $GraceSeconds second(s). Scheduled=$Scheduled" -Level 'WARNING'
}

#endregion ---------- Enforcement ----------


#region ---------- UI Events ----------

# Allow dragging the borderless window
$Window.Add_MouseLeftButtonDown({
    try {
        $Window.DragMove()
    }
    catch {}
})

if ($BtnRestartNow) {
    $BtnRestartNow.Add_Click({
        try {
            Start-Process -FilePath "$env:SystemRoot\System32\shutdown.exe" `
                -ArgumentList '/a' `
                -WindowStyle Hidden `
                -ErrorAction SilentlyContinue | Out-Null
        }
        catch {}

        $Restarted = Try-RestartNow
        Write-Log -Message "Restart now clicked. RestartTriggered=$Restarted"

        try {
            $Window.Close()
        }
        catch {}
    })
}

if ($BtnRestart1H) {
    $BtnRestart1H.Add_Click({
        $Scheduled = Schedule-Restart -Seconds 3600
        Write-Log -Message "Restart after 1 hour clicked. Scheduled=$Scheduled"

        try {
            $Window.Close()
        }
        catch {}
    })
}

if ($BtnRestart2H) {
    $BtnRestart2H.Add_Click({
        $Scheduled = Schedule-Restart -Seconds 7200
        Write-Log -Message "Restart after 2 hours clicked. Scheduled=$Scheduled"

        try {
            $Window.Close()
        }
        catch {}
    })
}

if ($BtnClose) {
    $BtnClose.Add_Click({
        Write-Log -Message 'Dialog closed by user.'
        try {
            $Window.Close()
        }
        catch {}
    })
}

if ($BtnX) {
    $BtnX.Add_Click({
        Write-Log -Message 'Dialog closed from X button.'
        try {
            $Window.Close()
        }
        catch {}
    })
}

if ($BtnMin) {
    $BtnMin.Add_Click({
        Write-Log -Message 'Dialog minimized by user.'
        try {
            $Window.WindowState = 'Minimized'
        }
        catch {}
    })
}

#endregion ---------- UI Events ----------


#region ---------- Show ----------

$null = $Window.ShowDialog()

Write-Log -Message "Remediation finished. PendingReboot=$PendingReboot | UptimeDays=$UptimeDays" -Level 'SUCCESS'
exit 0

#endregion ---------- Show ----------