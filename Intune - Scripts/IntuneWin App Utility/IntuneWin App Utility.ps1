<#!
.SYNOPSIS
    IntuneWin Application Utility (Enhanced) - GUI tool to create .intunewin packages from EXE/MSI installers.

.DESCRIPTION
    - Modern WPF GUI (card-based) similar to your Cisco Secure Client Assistant layout
    - Async packaging (no UI freeze) using STA runspace + DispatcherTimer polling
    - Guard against concurrent actions
    - Live Message Center with level-based coloring (INFO/SUCCESS/WARNING/ERROR)
    - Validations: source folder, setup file must exist and be inside source, output path
    - Computes source folder size and shows package name
    - Default working root: %SystemDrive%\IntuneWinUtility\Source and \Output

.NOTES
    Author  : Mohammad Abdelkader
    Website : https://momar.tech
    Date    : 2026-02-10
    Version : 2.0
#>

[CmdletBinding()]
param()

#region -------------------- Paths / constants --------------------
$SystemDrive = if ($env:SystemDrive) { $env:SystemDrive } else { 'C:' }
$ToolRoot = Join-Path $SystemDrive 'IntuneWinUtility'
$DefaultSourcePath = Join-Path $ToolRoot 'Source'
$DefaultOutputPath = Join-Path $ToolRoot 'Output'

$ScriptDir = if ($PSScriptRoot) { $PSScriptRoot }
elseif ($PSCommandPath) { Split-Path -Parent $PSCommandPath }
elseif ($MyInvocation.MyCommand.Path) { Split-Path -Parent $MyInvocation.MyCommand.Path }
else { (Get-Location).Path }

# If compiled with PS2EXE, embed like:
# -embedFiles @{ '%TEMP%\IntuneWinAppUtil.exe'='.\IntuneWinAppUtil.exe'; }
$tempRoot = if ($env:TEMP) { $env:TEMP } else { [System.IO.Path]::GetTempPath() }
$embeddedIntuneWinUtil = Join-Path $tempRoot 'IntuneWinAppUtil.exe'
$localIntuneWinUtil = Join-Path $ScriptDir 'IntuneWinAppUtil.exe'
$IntuneWinUtil = if (Test-Path $embeddedIntuneWinUtil) { $embeddedIntuneWinUtil } else { $localIntuneWinUtil }

$null = New-Item -ItemType Directory -Path $DefaultSourcePath, $DefaultOutputPath -Force -ErrorAction SilentlyContinue | Out-Null
$LogDir = $ToolRoot
$null = New-Item -ItemType Directory -Path $LogDir -Force -ErrorAction SilentlyContinue | Out-Null
$LogFile = Join-Path $LogDir ("IntuneWinUtility-" + (Get-Date -Format "yyyyMMdd") + ".log")

# state
$script:IsBusy = $false
$script:ActiveRunspace = $null
$script:AsyncResult = $null
$script:AsyncPowerShell = $null
$script:LastProgress = 0
$script:SetupFilePath = $null
#endregion

#region -------------------- UI helpers / logging --------------------
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms | Out-Null

function New-Brush {
  param([string]$Hex = "#000000")
  $c = [Windows.Media.ColorConverter]::ConvertFromString($Hex)
  $b = New-Object Windows.Media.SolidColorBrush $c
  $b.Freeze(); $b
}

# UI log colors (match your Cisco style)
$BrushInfoUI    = New-Brush "#C7DAFF"
$BrushSuccessUI = New-Brush "#D7F0E3"
$BrushWarnUI    = New-Brush "#FBE6C5"
$BrushErrorUI   = New-Brush "#F7CFD2"

$BrushTextDark  = New-Brush "#1F2D3A"
$BrushTextOk    = New-Brush "#1F6A3A"
$BrushTextWarn  = New-Brush "#8A5A12"
$BrushTextBad   = New-Brush "#8A2026"

$script:LogSeen = New-Object 'System.Collections.Generic.HashSet[string]'
$script:LogWriter = $null
try { $script:LogWriter = New-Object System.IO.StreamWriter($LogFile, $true, [System.Text.Encoding]::UTF8) } catch {}

$script:LogBox = $null
$script:StatusTxt = $null
$script:MutedBrush = $null

function Write-Log {
  param(
    [string]$Message,
    [ValidateSet('INFO','SUCCESS','WARNING','ERROR')]
    [string]$Level = 'INFO'
  )

  $clean = [string]$Message
  $clean = $clean -replace '[^\u0009\u000A\u000D\u0020-\u007E]', ' '
  $clean = $clean -replace '\s{2,}', ' '
  $clean = $clean.Trim()
  if ([string]::IsNullOrWhiteSpace($clean)) { return }

  $line = "[{0}] {1}" -f $Level, $clean

  if ($script:LogSeen.Contains($line)) { return }
  $null = $script:LogSeen.Add($line)

  try {
    if ($script:LogWriter) { $script:LogWriter.WriteLine($line); $script:LogWriter.Flush() }
    else { $line | Out-File -FilePath $LogFile -Append -Encoding utf8 }
  } catch {}

  if ($script:StatusTxt) {
    $script:StatusTxt.Text = $clean
    switch ($Level) {
      'SUCCESS' { $script:StatusTxt.Foreground = $BrushTextOk }
      'WARNING' { $script:StatusTxt.Foreground = $BrushTextWarn }
      'ERROR'   { $script:StatusTxt.Foreground = $BrushTextBad }
      default   { $script:StatusTxt.Foreground = $BrushTextDark }
    }
  }

  if (-not $script:LogBox) { return }

  $brush = switch ($Level) {
    'SUCCESS' { $BrushSuccessUI }
    'WARNING' { $BrushWarnUI }
    'ERROR'   { $BrushErrorUI }
    default   { $BrushInfoUI }
  }

  $script:LogBox.Dispatcher.Invoke([action]{
    $para = New-Object Windows.Documents.Paragraph
    $para.Margin = '0,0,0,0'
    $para.LineHeight = 18
    $run = New-Object Windows.Documents.Run $line
    $run.Foreground = $brush
    $para.Inlines.Add($run)
    $script:LogBox.Document.Blocks.Add($para)
    $script:LogBox.ScrollToEnd()
  })
}

function Set-Busy {
  param([bool]$Busy)
  $script:IsBusy = $Busy
  if ($script:ProgressBar) {
    if ($Busy) {
      $script:ProgressBar.IsIndeterminate = $true
      $script:ProgressBar.Value = 0
    } else {
      $script:ProgressBar.IsIndeterminate = $false
    }
  }
}

function Guard-Action {
  param([string]$ActionName)
  if ($script:IsBusy) {
    Write-Log ("Another action is running. Please wait before starting: {0}" -f $ActionName) "WARNING"
    return $false
  }
  return $true
}

function Get-FolderSizeMB {
  param([Parameter(Mandatory)][string]$Path)
  try {
    $sum = (Get-ChildItem -LiteralPath $Path -Recurse -File -ErrorAction Stop | Measure-Object -Property Length -Sum).Sum
    if ($null -eq $sum) { $sum = 0 }
    return [math]::Round(($sum / 1MB), 2)
  } catch { return $null }
}

function Format-FileSize {
  param([long]$Bytes)
  if ($Bytes -lt 1KB) { return ("{0} B" -f $Bytes) }
  if ($Bytes -lt 1MB) { return ("{0:N2} KB" -f ($Bytes / 1KB)) }
  return ("{0:N2} MB" -f ($Bytes / 1MB))
}

function Normalize-FullPath {
  param([string]$Path)
  if ([string]::IsNullOrWhiteSpace($Path)) { return $null }
  try { return [System.IO.Path]::GetFullPath($Path.Trim()) } catch { return $null }
}

function Is-ChildPath {
  param(
    [Parameter(Mandatory)][string]$Parent,
    [Parameter(Mandatory)][string]$Child
  )
  $p = (Normalize-FullPath $Parent)
  $c = (Normalize-FullPath $Child)
  if (-not $p -or -not $c) { return $false }
  if (-not $p.EndsWith('\')) { $p += '\' }
  return $c.StartsWith($p, [System.StringComparison]::OrdinalIgnoreCase)
}

function Get-InstallerCandidates {
  param([Parameter(Mandatory)][string]$Folder)
  if (-not (Test-Path $Folder)) { return @() }
  try {
    return Get-ChildItem -LiteralPath $Folder -File -ErrorAction SilentlyContinue |
      Where-Object { $_.Extension -match '^\.(exe|msi)$' } |
      Sort-Object Name
  } catch { return @() }
}

function Auto-Detect-SourceFile {
  param(
    [Parameter(Mandatory)][string]$Folder,
    [bool]$Log = $false
  )

  if (-not $Folder -or -not (Test-Path $Folder)) {
    $script:SetupFilePath = $null
    if ($SetupFileTxt) { $SetupFileTxt.Text = "" }
    return
  }

  $candidates = @(Get-InstallerCandidates -Folder $Folder)
  if ($candidates.Count -gt 0) {
    $first = $candidates[0]
    $script:SetupFilePath = $first.FullName
    if ($SetupFileTxt) { $SetupFileTxt.Text = $first.Name }
    if ($Log) {
      if ($candidates.Count -gt 1) {
        Write-Log ("Multiple installers found ({0}); auto-selected: {1}" -f $candidates.Count, $first.Name) "SUCCESS"
      } else {
        Write-Log ("Setup file auto-selected: {0}" -f $first.Name) "SUCCESS"
      }
    }
  } else {
    $script:SetupFilePath = $null
    if ($SetupFileTxt) { $SetupFileTxt.Text = "" }
    if ($Log) { Write-Log "No installer (.exe/.msi) found in source folder." "WARNING" }
  }
}

#endregion

#region -------------------- Safe XAML loader --------------------
function ConvertTo-XamlWindow {
  param([Parameter(Mandatory)][string]$Xaml)
  $clean = $Xaml -replace '[\uFEFF\u200B\u200C\u200D\u200E\u200F\u202A-\u202E]', ''
  $clean = $clean.TrimStart()
  if ($clean.Length -eq 0 -or $clean[0] -ne '<') { throw "XAML must start with '<'." }
  try { return [Windows.Markup.XamlReader]::Parse($clean) }
  catch {
    $settings = New-Object System.Xml.XmlReaderSettings
    $settings.DtdProcessing = [System.Xml.DtdProcessing]::Ignore
    $sr = New-Object System.IO.StringReader($clean)
    $xr = [System.Xml.XmlReader]::Create($sr, $settings)
    return [Windows.Markup.XamlReader]::Load($xr)
  }
}
#endregion

#region -------------------- XAML --------------------
$xamlText = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="IntuneWin Application Utility"
        Width="980" Height="660"
        WindowStartupLocation="CenterScreen"
        Background="#F6F8FB"
        FontFamily="Segoe UI"
        FontSize="13"
        UseLayoutRounding="True"
        SnapsToDevicePixels="True">

  <Window.Resources>
    <DropShadowEffect x:Key="ShadowPrimary" BlurRadius="10" ShadowDepth="0" Opacity="0.55" Color="#9FAEF7"/>
    <DropShadowEffect x:Key="ShadowBlue"    BlurRadius="10" ShadowDepth="0" Opacity="0.55" Color="#8FB4FF"/>
    <DropShadowEffect x:Key="ShadowGreen"   BlurRadius="10" ShadowDepth="0" Opacity="0.55" Color="#9FD7B8"/>
    <DropShadowEffect x:Key="ShadowRed"     BlurRadius="10" ShadowDepth="0" Opacity="0.55" Color="#F7C4C4"/>

    <Style x:Key="BtnBase" TargetType="Button">
      <Setter Property="BorderThickness" Value="0"/>
      <Setter Property="Padding" Value="12,0"/>
      <Setter Property="Height" Value="32"/>
      <Setter Property="MinWidth" Value="96"/>
      <Setter Property="FontWeight" Value="SemiBold"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Style.Triggers>
        <Trigger Property="IsEnabled" Value="False">
          <Setter Property="Effect" Value="{x:Null}"/>
          <Setter Property="Background" Value="#ECEFF3"/>
          <Setter Property="Foreground" Value="#9CA3AF"/>
          <Setter Property="Opacity" Value="0.75"/>
          <Setter Property="Cursor" Value="Arrow"/>
        </Trigger>
      </Style.Triggers>
    </Style>

    <Style x:Key="BtnPrimary" TargetType="Button" BasedOn="{StaticResource BtnBase}">
      <Setter Property="Background" Value="#9FAEF7"/>
      <Setter Property="Foreground" Value="#1F2D3A"/>
      <Setter Property="Effect" Value="{StaticResource ShadowPrimary}"/>
    </Style>
    <Style x:Key="BtnBlue" TargetType="Button" BasedOn="{StaticResource BtnBase}">
      <Setter Property="Background" Value="#8FB4FF"/>
      <Setter Property="Foreground" Value="#1F2D3A"/>
      <Setter Property="Effect" Value="{StaticResource ShadowBlue}"/>
    </Style>
    <Style x:Key="BtnGreen" TargetType="Button" BasedOn="{StaticResource BtnBase}">
      <Setter Property="Background" Value="#9FD7B8"/>
      <Setter Property="Foreground" Value="#1F2D3A"/>
      <Setter Property="Effect" Value="{StaticResource ShadowGreen}"/>
    </Style>
    <Style x:Key="BtnRed" TargetType="Button" BasedOn="{StaticResource BtnBase}">
      <Setter Property="Background" Value="#F7C4C4"/>
      <Setter Property="Foreground" Value="#1F2D3A"/>
      <Setter Property="Effect" Value="{StaticResource ShadowRed}"/>
    </Style>

    <SolidColorBrush x:Key="CardBg" Color="#FFFFFF"/>
    <SolidColorBrush x:Key="Line"   Color="#E6EBF4"/>
    <SolidColorBrush x:Key="Muted"  Color="#5F6B7A"/>
    <SolidColorBrush x:Key="Title"  Color="#1F2D3A"/>
  </Window.Resources>

  <Grid>
    <Grid.ColumnDefinitions>
      <ColumnDefinition Width="270"/>
      <ColumnDefinition Width="*"/>
    </Grid.ColumnDefinitions>

    <!-- ================= Sidebar ================= -->
    <Border Grid.Column="0" Background="{StaticResource CardBg}" BorderBrush="{StaticResource Line}" BorderThickness="0,0,1,0">
      <DockPanel LastChildFill="True">

        <!-- App Header -->
        <StackPanel DockPanel.Dock="Top" Margin="18,18,18,12">
          <StackPanel Orientation="Horizontal">
            <Border Width="36" Height="36" Background="#9AB8FF" CornerRadius="6">
              <TextBlock Text="W" Foreground="#1F2D3A" FontSize="18" FontWeight="Bold"
                         VerticalAlignment="Center" HorizontalAlignment="Center"/>
            </Border>
            <StackPanel Margin="10,0,0,0">
              <TextBlock Text="IntuneWin Utility" FontSize="16" FontWeight="SemiBold" Foreground="{StaticResource Title}"/>
              <TextBlock Text="Win32 Packaging Tool" FontSize="11" Foreground="{StaticResource Muted}"/>
            </StackPanel>
          </StackPanel>
        </StackPanel>

        <!-- Footer -->
        <Border DockPanel.Dock="Bottom" BorderBrush="{StaticResource Line}" BorderThickness="0,1,0,0" Padding="14" Background="{StaticResource CardBg}">
          <StackPanel>
            <TextBlock Text="IntuneWin App Utility" FontSize="13" FontWeight="Bold" Foreground="#1F2D3A"/>
            <TextBlock Text="Version 1.0" FontSize="11" Foreground="#5F6B7A" Margin="0,4,0,0"/>
            <TextBlock FontSize="11" Foreground="#7C8BA1" Margin="0,8,0,0">
              <Run Text="© 2025 "/>
              <Hyperlink x:Name="FooterLink" NavigateUri="https://www.linkedin.com/in/mabdulkadr/">Mohammad Omar</Hyperlink>
            </TextBlock>
          </StackPanel>
        </Border>

        <!-- Nav -->
        <StackPanel DockPanel.Dock="Top" Margin="8,8">
          <TextBlock Text="TOOLS" Margin="14,10,0,6" FontSize="11" FontWeight="SemiBold" Foreground="#7C8BA1"/>
          <Button Content="Packages" Height="38" Margin="6" Padding="12,0"
                  HorizontalContentAlignment="Left"
                  Background="#D8E2F4" Foreground="#1F2D3A" BorderThickness="0"/>
        </StackPanel>

        <!-- Session + About -->
        <Grid>
          <StackPanel VerticalAlignment="Bottom">

            <Border Margin="12,0,12,8" Background="#F9FBFF" BorderBrush="{StaticResource Line}" BorderThickness="1" CornerRadius="6" Padding="12">
              <StackPanel>
                <TextBlock Text="Session" FontSize="12" FontWeight="SemiBold" Foreground="#0F172A" Margin="0,0,0,8"/>
                <Grid>
                  <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="*"/>
                  </Grid.ColumnDefinitions>
                  <Grid.RowDefinitions>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="Auto"/>
                  </Grid.RowDefinitions>

                  <TextBlock Grid.Row="0" Grid.Column="0" Text="Machine:" Foreground="#111827" FontWeight="SemiBold" Margin="0,0,8,6"/>
                  <Border Grid.Row="0" Grid.Column="1" Background="#EEF2FF" Padding="6,2" CornerRadius="4" Margin="0,0,0,6">
                    <TextBlock x:Name="SessionMachineTxt" Text="..." Foreground="#1D4ED8"/>
                  </Border>

                  <TextBlock Grid.Row="1" Grid.Column="0" Text="User:" Foreground="#111827" FontWeight="SemiBold" Margin="0,0,8,6"/>
                  <Border Grid.Row="1" Grid.Column="1" Background="#ECFDF3" Padding="6,2" CornerRadius="4" Margin="0,0,0,6">
                    <TextBlock x:Name="SessionUserTxt" Text="..." Foreground="#166534"/>
                  </Border>

                  <TextBlock Grid.Row="2" Grid.Column="0" Text="Elevation:" Foreground="#111827" FontWeight="SemiBold" Margin="0,0,8,0"/>
                  <Border BorderBrush="#E5E7EB" BorderThickness="0" Grid.Row="2" Grid.Column="1" x:Name="SessionElevationPill" Background="#FEF2F2" Padding="6,2" CornerRadius="4">
                    <TextBlock x:Name="SessionElevationTxt" Text="..." Foreground="#991B1B"/>
                  </Border>
                </Grid>
              </StackPanel>
            </Border>

            <Border Margin="12,0,12,14" Background="#F9FBFF" BorderBrush="{StaticResource Line}" BorderThickness="1" CornerRadius="6" Padding="12">
              <StackPanel>
                <TextBlock Text="About this tool" FontSize="12" FontWeight="SemiBold" Foreground="{StaticResource Title}" Margin="0,0,0,6"/>
                <TextBlock TextWrapping="Wrap" Foreground="#475467" FontSize="12"
                           Text="Create Intune Win32 packages (.intunewin) from EXE/MSI with validations and live logs."/>
              </StackPanel>
            </Border>
          </StackPanel>
        </Grid>

      </DockPanel>
    </Border>

    <!-- ================= Main Content ================= -->
    <Grid Grid.Column="1">
      <Grid.RowDefinitions>
        <RowDefinition Height="Auto"/>
        <RowDefinition Height="*"/>
        <RowDefinition Height="Auto"/>
      </Grid.RowDefinitions>

      <!-- Header -->
      <Border Grid.Row="0" Padding="18,14,18,10" Background="#F6F8FB">
        <Grid>
          <Grid.ColumnDefinitions>
            <ColumnDefinition Width="*"/>
          </Grid.ColumnDefinitions>
          <StackPanel Grid.Column="0">
            <TextBlock Text="Welcome" FontSize="20" FontWeight="Bold" Foreground="{StaticResource Title}"/>
            <TextBlock Text="Package EXE/MSI into IntuneWin with a few clicks"
                       FontSize="14" Foreground="{StaticResource Muted}" Margin="0,6,0,0"/>
          </StackPanel>
        </Grid>
      </Border>

      <!-- Body -->
      <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto">
        <Grid Margin="16,0,16,14">
          <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
          </Grid.RowDefinitions>

          <!-- Package Details -->
          <Border Grid.Row="0" Background="{StaticResource CardBg}" CornerRadius="6" BorderBrush="{StaticResource Line}" BorderThickness="1" Padding="12" Margin="0,0,0,10">
            <StackPanel>
              <TextBlock Text="Package Details" FontSize="13" FontWeight="SemiBold" Foreground="#0F172A" Margin="0,0,0,10"/>

              <Grid>
                <Grid.RowDefinitions>
                  <RowDefinition Height="Auto"/>
                  <RowDefinition Height="6"/>
                  <RowDefinition Height="Auto"/>
                  <RowDefinition Height="6"/>
                  <RowDefinition Height="Auto"/>
                  <RowDefinition Height="6"/>
                  <RowDefinition Height="Auto"/>
                  <RowDefinition Height="10"/>
                  <RowDefinition Height="Auto"/>
                </Grid.RowDefinitions>

                <Grid.ColumnDefinitions>
                  <ColumnDefinition Width="150"/>
                  <ColumnDefinition Width="*"/>
                  <ColumnDefinition Width="95"/>
                </Grid.ColumnDefinitions>

                <TextBlock Grid.Row="0" Grid.Column="0" Text="Source Folder:" Foreground="{StaticResource Title}" VerticalAlignment="Center"/>
                <TextBox x:Name="SrcFolderTxt" Grid.Row="0" Grid.Column="1" Height="28" Margin="0,0,8,0"
                         Background="#F1F5F9" BorderBrush="{StaticResource Line}" BorderThickness="1"/>
                <Button x:Name="SrcFolderBtn" Grid.Row="0" Grid.Column="2" Content="Browse" Style="{StaticResource BtnBlue}" Height="28"/>

                <TextBlock Grid.Row="2" Grid.Column="0" Text="Source File:" Foreground="{StaticResource Title}" VerticalAlignment="Center"/>
                <TextBox x:Name="SetupFileTxt" Grid.Row="2" Grid.Column="1" Height="28" Margin="0,0,8,0"
                         Background="#F1F5F9" BorderBrush="{StaticResource Line}" BorderThickness="1" IsReadOnly="True"/>
                <Button x:Name="SetupFileBtn" Grid.Row="2" Grid.Column="2" Content="Browse" Style="{StaticResource BtnBlue}" Height="28"/>

                <TextBlock Grid.Row="4" Grid.Column="0" Text="Output Folder:" Foreground="{StaticResource Title}" VerticalAlignment="Center"/>
                <StackPanel Grid.Row="4" Grid.Column="1" Grid.ColumnSpan="2" Orientation="Horizontal">
                  <RadioButton x:Name="OutSameRadio" Content="Same as source" GroupName="OutMode" Margin="0,0,16,0"/>
                  <RadioButton x:Name="OutCustomRadio" Content="Custom folder" GroupName="OutMode" IsChecked="True"/>
                </StackPanel>

                <TextBlock Grid.Row="6" Grid.Column="0" Text="Output Path:" Foreground="{StaticResource Title}" VerticalAlignment="Center"/>
                <TextBox x:Name="OutFolderTxt" Grid.Row="6" Grid.Column="1" Height="28" Margin="0,0,8,0"
                         Background="#F1F5F9" BorderBrush="{StaticResource Line}" BorderThickness="1"/>
                <Button x:Name="OutFolderBtn" Grid.Row="6" Grid.Column="2" Content="Browse" Style="{StaticResource BtnBlue}" Height="28"/>

                <StackPanel Grid.Row="8" Grid.Column="0" Grid.ColumnSpan="3" Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,6,0,0">
                  <Button x:Name="CreateBtn" Content="Create Package" Style="{StaticResource BtnPrimary}" Margin="0,0,8,0"/>
                  <Button x:Name="OpenOutBtn" Content="Open Output" Style="{StaticResource BtnGreen}" Margin="0,0,8,0"/>
                  <Button x:Name="ClearBtn" Content="Clear" Style="{StaticResource BtnBlue}" Margin="0,0,8,0"/>
                </StackPanel>

              </Grid>

              <Border Background="#F9FBFF" BorderBrush="{StaticResource Line}" BorderThickness="1" CornerRadius="6" Padding="10" Margin="0,10,0,0">
                <Grid>
                  <Grid.RowDefinitions>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="Auto"/>
                  </Grid.RowDefinitions>
                  <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="100"/>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="90"/>
                    <ColumnDefinition Width="70"/>
                  </Grid.ColumnDefinitions>

                  <TextBlock Text="Source Package:" Grid.Row="0" Grid.Column="0" Foreground="{StaticResource Title}" Margin="0,0,8,0" VerticalAlignment="Center"/>
                  <TextBlock x:Name="PkgNameTxt" Grid.Row="0" Grid.Column="1" Foreground="{StaticResource Muted}" VerticalAlignment="Center" TextTrimming="CharacterEllipsis"/>

                  <TextBlock Text="Source Size:" Grid.Row="0" Grid.Column="2" Foreground="{StaticResource Title}" Margin="8,0,8,0" VerticalAlignment="Center"/>
                  <TextBlock x:Name="SrcSizeTxt" Grid.Row="0" Grid.Column="3" Foreground="{StaticResource Muted}" Text="--" VerticalAlignment="Center" HorizontalAlignment="Left"/>

                  <TextBlock Text="Output Package:" Grid.Row="1" Grid.Column="0" Foreground="{StaticResource Title}" Margin="0,8,8,0" VerticalAlignment="Center"/>
                  <TextBlock x:Name="OutPathInfoTxt" Grid.Row="1" Grid.Column="1" Foreground="{StaticResource Muted}" Margin="0,8,8,0" Text="" TextTrimming="CharacterEllipsis" VerticalAlignment="Center"/>

                  <TextBlock Text="Output Size:" Grid.Row="1" Grid.Column="2" Foreground="{StaticResource Title}" Margin="8,5,8,0" VerticalAlignment="Center"/>
                  <TextBlock x:Name="OutFileInfoTxt" Grid.Row="1" Grid.Column="3" Foreground="{StaticResource Muted}" Margin="0,5,8,0" Text="" TextTrimming="CharacterEllipsis" VerticalAlignment="Center" HorizontalAlignment="Left"/>
                </Grid>
              </Border>

            </StackPanel>
          </Border>

          <!-- Message Center -->
          <Border Grid.Row="1" Background="{StaticResource CardBg}" CornerRadius="6" BorderBrush="{StaticResource Line}" BorderThickness="1" Padding="12" Margin="0,0,0,10">
            <StackPanel>
              <TextBlock Text="MESSAGE CENTER" FontSize="13" FontWeight="SemiBold" Foreground="#0F172A" Margin="0,0,0,8"/>
              <RichTextBox x:Name="LogBox" Height="120" IsReadOnly="True"
                           Background="#1F2D3A" Foreground="#E4E9F0"
                           BorderBrush="#1F2937" BorderThickness="1"
                           FontFamily="Consolas" FontSize="13"
                           VerticalScrollBarVisibility="Auto"
                           Padding="10"/>
            </StackPanel>
          </Border>

          <!-- Status Bar -->
          <Border Grid.Row="2" Background="{StaticResource CardBg}" CornerRadius="6" BorderBrush="{StaticResource Line}" BorderThickness="1" Padding="10">
            <Grid>
          <Grid.ColumnDefinitions>
            <ColumnDefinition Width="170"/>
            <ColumnDefinition Width="*"/>
          </Grid.ColumnDefinitions>

          <TextBlock x:Name="ClockTxt" Text="--" Foreground="{StaticResource Muted}" Grid.Column="0"/>
          <ProgressBar x:Name="ProgressBar" Value="0" Maximum="100" Height="12" Grid.Column="1" VerticalAlignment="Center"/>
        </Grid>
      </Border>

        </Grid>
      </ScrollViewer>

    </Grid>
  </Grid>
</Window>
'@
#endregion

#region -------------------- Create Window & refs --------------------
$w = ConvertTo-XamlWindow -Xaml $xamlText

try { $script:MutedBrush = $w.Resources['Muted'] } catch { $script:MutedBrush = $BrushTextDark }

# refs
$SessionMachineTxt = $w.FindName('SessionMachineTxt')
$SessionUserTxt = $w.FindName('SessionUserTxt')
$SessionElevationTxt = $w.FindName('SessionElevationTxt')
$SessionElevationPill = $w.FindName('SessionElevationPill')

$SrcFolderTxt = $w.FindName('SrcFolderTxt')
$SrcFolderBtn = $w.FindName('SrcFolderBtn')
$SetupFileTxt = $w.FindName('SetupFileTxt')
$SetupFileBtn = $w.FindName('SetupFileBtn')
$OutSameRadio = $w.FindName('OutSameRadio')
$OutCustomRadio = $w.FindName('OutCustomRadio')
$OutFolderTxt = $w.FindName('OutFolderTxt')
$OutFolderBtn = $w.FindName('OutFolderBtn')

$CreateBtn = $w.FindName('CreateBtn')
$OpenOutBtn = $w.FindName('OpenOutBtn')
$ClearBtn = $w.FindName('ClearBtn')

$PkgNameTxt = $w.FindName('PkgNameTxt')
$SrcSizeTxt = $w.FindName('SrcSizeTxt')
$OutPathInfoTxt = $w.FindName('OutPathInfoTxt')
$OutFileInfoTxt = $w.FindName('OutFileInfoTxt')

$ClockTxt = $w.FindName('ClockTxt')
$ProgressBar = $w.FindName('ProgressBar')
$script:ProgressBar = $ProgressBar
$script:LogBox = $w.FindName('LogBox')
$script:StatusTxt = $null

# session
$sessionMachine = $env:COMPUTERNAME
$sessionUser = if ($env:USERDOMAIN -and $env:USERNAME) { "{0}\{1}" -f $env:USERDOMAIN, $env:USERNAME } else { $env:USERNAME }
$isAdmin = (New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$sessionElevation = if ($isAdmin) { 'Administrator' } else { 'Standard' }

$SessionMachineTxt.Text = $sessionMachine
$SessionUserTxt.Text = $sessionUser
$SessionElevationTxt.Text = $sessionElevation
if ($isAdmin) {
  $SessionElevationPill.Background = New-Brush "#ECFDF3"
  $SessionElevationTxt.Foreground = New-Brush "#166534"
} else {
  $SessionElevationPill.Background = New-Brush "#FEF2F2"
  $SessionElevationTxt.Foreground = New-Brush "#991B1B"
}

# defaults
$SrcFolderTxt.Text = $DefaultSourcePath
$OutFolderTxt.Text = $DefaultOutputPath
$OpenOutBtn.IsEnabled = $true
Auto-Detect-SourceFile -Folder $DefaultSourcePath -Log $true
#endregion

#region -------------------- UI logic --------------------
function Refresh-UI {
  # IntuneWinAppUtil presence
  if (-not (Test-Path $IntuneWinUtil)) {
    Write-Log ("IntuneWinAppUtil.exe not found in script folder: {0}" -f $IntuneWinUtil) "WARNING"
  }

  $src = Normalize-FullPath $SrcFolderTxt.Text
  if ($SrcSizeTxt) { $SrcSizeTxt.Text = "--" }

  if (-not $script:SetupFilePath -and $src -and (Test-Path $src)) {
    Auto-Detect-SourceFile -Folder $src -Log $false
  }

  $setupPath = if ($script:SetupFilePath) { $script:SetupFilePath } else { $SetupFileTxt.Text }
  $setup = Normalize-FullPath $setupPath
  $setupName = $null
  if ($setup) {
    $setupName = [System.IO.Path]::GetFileName($setup)
    $PkgNameTxt.Text = $setupName
    if ($SrcSizeTxt -and (Test-Path $setup)) {
      try {
        $fi = Get-Item -LiteralPath $setup -ErrorAction SilentlyContinue
        if ($fi) { $SrcSizeTxt.Text = (Format-FileSize -Bytes $fi.Length) }
      } catch {}
    }
  } else {
    $PkgNameTxt.Text = ""
  }

  # output mode
  if ($OutSameRadio.IsChecked -eq $true) {
    $OutFolderTxt.IsEnabled = $false
    if ($src) { $OutFolderTxt.Text = $src }
  } else {
    $OutFolderTxt.IsEnabled = $true
    if (-not $OutFolderTxt.Text) { $OutFolderTxt.Text = $DefaultOutputPath }
    if ($src -and (Normalize-FullPath $OutFolderTxt.Text) -eq $src) { $OutFolderTxt.Text = $DefaultOutputPath }
  }

  $outInfo = Normalize-FullPath $OutFolderTxt.Text
  $outPkgName = ""
  $outPkgSize = ""
  $hasOutput = $false
  if ($outInfo -and (Test-Path $outInfo)) {
    try {
      $latest = Get-ChildItem -LiteralPath $outInfo -Filter *.intunewin -File -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
        if ($latest) {
          $hasOutput = $true
          $outPkgName = $latest.Name
          $outPkgSize = (Format-FileSize -Bytes $latest.Length)
        }
      } catch {}
    }

  if ($OutPathInfoTxt) {
    $OutPathInfoTxt.Text = $outPkgName
    $OutPathInfoTxt.Foreground = if ($hasOutput) { $BrushTextOk } else { $script:MutedBrush }
  }
  if ($OutFileInfoTxt) {
    $OutFileInfoTxt.Text = $outPkgSize
    $OutFileInfoTxt.Foreground = if ($hasOutput) { $BrushTextOk } else { $script:MutedBrush }
  }
  if ($SetupFileTxt) {
    if ($setupName) {
      if ($SetupFileTxt.Text -ne $setupName) { $SetupFileTxt.Text = $setupName }
    }
  }

  # buttons enabled/disabled
  $CreateBtn.IsEnabled = -not $script:IsBusy
  $SrcFolderBtn.IsEnabled = -not $script:IsBusy
  $SetupFileBtn.IsEnabled = -not $script:IsBusy
  $ClearBtn.IsEnabled = -not $script:IsBusy
  $OutSameRadio.IsEnabled = -not $script:IsBusy
  $OutCustomRadio.IsEnabled = -not $script:IsBusy
  $OutFolderBtn.IsEnabled = -not $script:IsBusy
  $OutFolderTxt.IsEnabled = (-not $script:IsBusy) -and ($OutCustomRadio.IsChecked -eq $true)
}

function Validate-Inputs {
  $src = Normalize-FullPath $SrcFolderTxt.Text
  if (-not $src -or -not (Test-Path $src)) { Write-Log "Source folder is invalid or not found." "ERROR"; return $null }

  $setupPath = if ($script:SetupFilePath) { $script:SetupFilePath } else { $SetupFileTxt.Text }
  $setup = Normalize-FullPath $setupPath
  if (-not $setup -or -not (Test-Path $setup)) { Write-Log "Setup file is invalid or not found." "ERROR"; return $null }

  $ext = [System.IO.Path]::GetExtension($setup).ToLower()
  if ($ext -ne '.exe' -and $ext -ne '.msi') { Write-Log "Setup file must be .exe or .msi" "ERROR"; return $null }

  if (-not (Is-ChildPath -Parent $src -Child $setup)) {
    Write-Log "Setup file must be inside the selected Source folder." "ERROR"
    return $null
  }

  $out = Normalize-FullPath $OutFolderTxt.Text
  if (-not $out) { Write-Log "Output folder is empty." "ERROR"; return $null }
  if (-not (Test-Path $out)) {
    try { $null = New-Item -ItemType Directory -Path $out -Force -ErrorAction Stop | Out-Null }
    catch { Write-Log ("Failed to create output folder: {0}" -f $_.Exception.Message) "ERROR"; return $null }
  }

  if (-not (Test-Path $IntuneWinUtil)) {
    Write-Log ("IntuneWinAppUtil.exe not found: {0}" -f $IntuneWinUtil) "ERROR"
    return $null
  }

  return [pscustomobject]@{ SourceFolder=$src; SetupFile=$setup; OutputFolder=$out; UtilPath=$IntuneWinUtil }
}

#endregion

#region -------------------- Async packaging (Runspace + polling) --------------------
function Start-PackagingAsync {
  param([Parameter(Mandatory)]$PkgInput)

  $rs = [runspacefactory]::CreateRunspace()
  $rs.ApartmentState = 'STA'
  $rs.ThreadOptions = 'ReuseThread'
  $rs.Open()

  $ps = [powershell]::Create()
  $ps.Runspace = $rs

  # Worker returns structured output (lines + exit code + output file guess)
  $null = $ps.AddScript({
    param($UtilPath, $SourceFolder, $SetupFile, $OutputFolder)

    $result = [ordered]@{
      Started     = (Get-Date).ToString("s")
      ExitCode    = $null
      StdOut      = ''
      StdErr      = ''
      OutputFiles = @()
      Args        = ''
    }

    try {
      $args = "-c `"$SourceFolder`" -s `"$SetupFile`" -o `"$OutputFolder`" -q"
      $result.Args = $args

      $psi = New-Object System.Diagnostics.ProcessStartInfo
      $psi.FileName = $UtilPath
      $psi.Arguments = $args
      $psi.UseShellExecute = $false
      $psi.RedirectStandardOutput = $true
      $psi.RedirectStandardError  = $true
      $psi.CreateNoWindow = $true

      $p = New-Object System.Diagnostics.Process
      $p.StartInfo = $psi

      if (-not $p.Start()) { throw "Failed to start IntuneWinAppUtil.exe." }
      $stdout = $p.StandardOutput.ReadToEnd()
      $stderr = $p.StandardError.ReadToEnd()
      $p.WaitForExit()

      $result.ExitCode = $p.ExitCode
      $result.StdOut = $stdout
      $result.StdErr = $stderr
    }
    catch {
      $result.ExitCode = -1
      $result.StdErr = $_.Exception.Message
    }

    try {
      $files = Get-ChildItem -LiteralPath $OutputFolder -Filter *.intunewin -ErrorAction SilentlyContinue |
               Sort-Object LastWriteTime -Descending |
               Select-Object -First 5 -ExpandProperty FullName
      if ($files) { $result.OutputFiles = @($files) }
    } catch {}

    [pscustomobject]$result
  }) | Out-Null
  $null = $ps.AddArgument($PkgInput.UtilPath)
  $null = $ps.AddArgument($PkgInput.SourceFolder)
  $null = $ps.AddArgument($PkgInput.SetupFile)
  $null = $ps.AddArgument($PkgInput.OutputFolder)

  $handle = $ps.BeginInvoke()

  $script:ActiveRunspace = $rs
  $script:AsyncPowerShell = $ps
  $script:AsyncResult = $handle
}

function Stop-AsyncIfAny {
  try {
    if ($script:AsyncPowerShell -and $script:AsyncResult -and -not $script:AsyncResult.IsCompleted) {
      try { $script:AsyncPowerShell.Stop() } catch {}
    }
  } catch {}
  try { if ($script:AsyncPowerShell) { $script:AsyncPowerShell.Dispose() } } catch {}
  try { if ($script:ActiveRunspace) { $script:ActiveRunspace.Close(); $script:ActiveRunspace.Dispose() } } catch {}
  $script:AsyncPowerShell = $null
  $script:AsyncResult = $null
  $script:ActiveRunspace = $null
}

#endregion

#region -------------------- Event Handlers --------------------
$SrcFolderBtn.Add_Click({
  if (-not (Guard-Action "Browse Source Folder")) { return }
  $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
  $dlg.Description = "Select package source folder"
  $dlg.RootFolder = "MyComputer"
  $dlg.SelectedPath = $ToolRoot
  if ($dlg.ShowDialog() -eq "OK") {
    $SrcFolderTxt.Text = $dlg.SelectedPath
    Write-Log ("Source folder set: {0}" -f $dlg.SelectedPath) "INFO"
    if ($OutSameRadio.IsChecked -eq $true) { $OutFolderTxt.Text = $dlg.SelectedPath }
    Auto-Detect-SourceFile -Folder $dlg.SelectedPath -Log $true
  }
  Refresh-UI
})

$SetupFileBtn.Add_Click({
  if (-not (Guard-Action "Browse Setup File")) { return }

  $src = Normalize-FullPath $SrcFolderTxt.Text
  if (-not $src -or -not (Test-Path $src)) {
    Write-Log "Select a valid Source folder first." "WARNING"
    return
  }

  $dlg = New-Object System.Windows.Forms.OpenFileDialog
  $dlg.InitialDirectory = $src
  $dlg.Filter = "Installer (*.exe;*.msi)|*.exe;*.msi|All files (*.*)|*.*"
  $dlg.Multiselect = $false
  if ($dlg.ShowDialog() -eq "OK") {
    $script:SetupFilePath = $dlg.FileName
    $SetupFileTxt.Text = [System.IO.Path]::GetFileName($dlg.FileName)
    Write-Log ("Setup file selected: {0}" -f ([System.IO.Path]::GetFileName($dlg.FileName))) "INFO"
  }
  Refresh-UI
})

$OutFolderBtn.Add_Click({
  if (-not (Guard-Action "Browse Output Folder")) { return }
  $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
  $dlg.Description = "Select output folder"
  $dlg.RootFolder = "MyComputer"
  $dlg.SelectedPath = $ToolRoot
  if ($dlg.ShowDialog() -eq "OK") {
    $OutFolderTxt.Text = $dlg.SelectedPath
    Write-Log ("Output folder set: {0}" -f $dlg.SelectedPath) "INFO"
  }
  Refresh-UI
})

$OutSameRadio.Add_Checked({ Refresh-UI })
$OutCustomRadio.Add_Checked({
  if (-not $script:IsBusy) {
    $src = Normalize-FullPath $SrcFolderTxt.Text
    $out = Normalize-FullPath $OutFolderTxt.Text
    if (-not $out -or ($src -and $out -eq $src)) { $OutFolderTxt.Text = $DefaultOutputPath }
  }
  Refresh-UI
})

$OpenOutBtn.Add_Click({
  $out = Normalize-FullPath $OutFolderTxt.Text
  if ($out -and (Test-Path $out)) {
    Start-Process explorer.exe -ArgumentList "`"$out`"" | Out-Null
  } else {
    Write-Log "Output folder not found." "WARNING"
  }
})

$ClearBtn.Add_Click({
  if (-not (Guard-Action "Clear")) { return }
  $SrcFolderTxt.Text = $DefaultSourcePath
  $script:SetupFilePath = $null
  $SetupFileTxt.Text = ""
  $OutFolderTxt.Text = $DefaultOutputPath
  $OutCustomRadio.IsChecked = $true
  $ProgressBar.Value = 0
  $script:LastProgress = 0
  Write-Log "Cleared inputs to defaults." "INFO"
  Refresh-UI
})

$CreateBtn.Add_Click({
  if (-not (Guard-Action "Create Package")) { return }

  $input = Validate-Inputs
  if (-not $input) { return }

  Set-Busy $true
  Refresh-UI

  $ProgressBar.Value = 10
  $script:LastProgress = 10

  Write-Log "Packaging started..." "INFO"
  Write-Log ("Command: {0} {1}" -f $input.UtilPath, ("-c `"{0}`" -s `"{1}`" -o `"{2}`" -q" -f $input.SourceFolder, $input.SetupFile, $input.OutputFolder)) "INFO"

  try {
    Start-PackagingAsync -PkgInput $input
  } catch {
    Write-Log ("Failed to start packaging: {0}" -f $_.Exception.Message) "ERROR"
    Set-Busy $false
    Refresh-UI
    return
  }
})

#endregion

#region -------------------- Timers (Clock + Polling) --------------------
# clock
$clockTimer = New-Object System.Windows.Threading.DispatcherTimer
$clockTimer.Interval = [TimeSpan]::FromSeconds(1)
$clockTimer.Add_Tick({
  $ClockTxt.Text = (Get-Date).ToString("dd-MM-yyyy HH:mm:ss")
})
$clockTimer.Start()

# polling async job
$pollTimer = New-Object System.Windows.Threading.DispatcherTimer
$pollTimer.Interval = [TimeSpan]::FromMilliseconds(350)
$pollTimer.Add_Tick({

  # progress simulation while running
  if ($script:IsBusy -and $script:AsyncResult -and -not $script:AsyncResult.IsCompleted) {
    if ($script:LastProgress -lt 85) {
      $script:LastProgress += 1
      $ProgressBar.Value = $script:LastProgress
    }
    return
  }

  # completed?
  if ($script:IsBusy -and $script:AsyncResult -and $script:AsyncResult.IsCompleted) {
    try {
      $res = $script:AsyncPowerShell.EndInvoke($script:AsyncResult)
      Stop-AsyncIfAny

      if ($res -is [System.Array]) {
        if ($res.Length -gt 0) { $res = $res[0] } else { $res = $null }
      }

      if ($res) {
        if ($res.StdOut) {
          ($res.StdOut -split "`r?`n") | Where-Object { $_.Trim() } | ForEach-Object { Write-Log $_ "INFO" }
        }
        if ($res.StdErr) {
          ($res.StdErr -split "`r?`n") | Where-Object { $_.Trim() } | ForEach-Object { Write-Log $_ "ERROR" }
        }

        $exitCode = $null
        if ($res.PSObject.Properties.Name -contains 'ExitCode') { $exitCode = $res.ExitCode }
        $successByText = ($res.StdOut -match 'has been generated successfully')
        $successByFile = ($res.OutputFiles -and $res.OutputFiles.Count -gt 0)

        if ($exitCode -eq $null -and -not ($successByText -or $successByFile)) {
          $exitCode = -1
          Write-Log "Packaging worker did not return ExitCode." "WARNING"
        }

        if ($exitCode -eq 0 -or $successByText -or $successByFile) {
          $ProgressBar.Value = 100
          $script:LastProgress = 100
          Write-Log "Packaging finished successfully." "SUCCESS"
          if ($res.OutputFiles -and $res.OutputFiles.Count -gt 0) {
            $of = $res.OutputFiles[0]
            $outMsg = $of
            try {
              $fi = Get-Item -LiteralPath $of -ErrorAction SilentlyContinue
              if ($fi) { $outMsg = ("{0} ({1})" -f $fi.Name, (Format-FileSize -Bytes $fi.Length)) }
              else { $outMsg = [System.IO.Path]::GetFileName($of) }
            } catch { $outMsg = [System.IO.Path]::GetFileName($of) }
            Write-Log ("Latest output: {0}" -f $outMsg) "SUCCESS"
            if ($OutPathInfoTxt -or $OutFileInfoTxt) {
              try {
                $fi = Get-Item -LiteralPath $of -ErrorAction SilentlyContinue
                if ($fi) {
                  if ($OutPathInfoTxt) {
                    $OutPathInfoTxt.Text = $fi.Name
                    $OutPathInfoTxt.Foreground = $BrushTextOk
                  }
                  if ($OutFileInfoTxt) {
                    $OutFileInfoTxt.Text = (Format-FileSize -Bytes $fi.Length)
                    $OutFileInfoTxt.Foreground = $BrushTextOk
                  }
                }
              } catch {}
            }
          }
        } else {
          $ProgressBar.Value = 0
          $script:LastProgress = 0
          Write-Log ("Packaging failed (ExitCode={0})." -f $exitCode) "ERROR"
        }
      } else {
        Write-Log "No result returned from packaging worker." "ERROR"
      }
    }
    catch {
      Stop-AsyncIfAny
      Write-Log ("Async completion error: {0}" -f $_.Exception.Message) "ERROR"
    }
    finally {
      Set-Busy $false
      Refresh-UI
    }
  }
})
$pollTimer.Start()
#endregion

#region -------------------- Init --------------------
Write-Log ("Log file: {0}" -f $LogFile) "INFO"
Write-Log ("ToolRoot: {0}" -f $ToolRoot) "INFO"
Refresh-UI
#endregion

#region -------------------- Run --------------------
$w.Add_Closed({
  Stop-AsyncIfAny
  try { if ($script:LogWriter) { $script:LogWriter.Flush(); $script:LogWriter.Close(); $script:LogWriter.Dispose() } } catch {}
})
$null = $w.ShowDialog()
#endregion
