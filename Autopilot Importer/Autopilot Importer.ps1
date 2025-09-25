<#! 
.SYNOPSIS
    Autopilot Importer — Dual-mode (CLI + GUI) tool for collecting and enrolling Windows devices into Intune Autopilot.

.DESCRIPTION
    This script provides both a PowerShell CLI and WPF-based GUI to streamline the Windows Autopilot enrollment process. 
    It enables IT admins to:
      • Collect hardware hash (HWID) into a compliant CSV file
      • Connect to Microsoft Graph (interactive or app-only authentication)
      • Enroll (upload) devices to Intune Autopilot from CSV/JSON
        - If no file is selected, the tool automatically creates a CSV for the current device
      • Search existing Autopilot devices by serial number
      • Display local device information (model, serial, manufacturer, TPM version, disk space, internet status)
    
    All working files (HWID exports, logs, settings) are stored under:
        C:\AutopilotGUI\{HWID, Logs, Settings}

    A packaged EXE version is also provided for GUI-only use.

.EXAMPLE
    # Run as script (CLI + GUI)
    .\Autopilot Importer.ps1

    # Collect HWID directly via CLI
    .\Autopilot Importer.ps1 -CollectHWID -OutPath "C:\HWID"

    # Enroll devices from CSV
    .\Autopilot Importer.ps1 -Enroll -Path "C:\HWID\AutopilotHWID.csv" -GroupTag "IT-Std"

    # Search for a device by serial number
    .\Autopilot Importer.ps1 -Find -Serial "PF12345"

.NOTES
    Author  : M. Omar (momar.tech)
    Version : 1.0
    License : MIT
    Date    : 2025-09-25
    Modules : Microsoft.Graph.Authentication (required for Graph operations)
#>


# -----------------------------
# region [Bootstrapping / .NET]
# -----------------------------
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase | Out-Null
Add-Type -AssemblyName System.Windows.Forms | Out-Null
# endregion

# ---------------------------------------------
# region [Constants / Brand / App file system]
# ---------------------------------------------
$BrandName     = 'momar.tech'

# App/branding (used in footer)
$AppName     = 'Autopilot Importer'
$AppVersion  = 'v1.0'
$OrgName     = 'IT Operations'
$CopyrightBy = 'M.Omar (momar.tech)'


# Delegated scopes for interactive Graph auth (sufficient for Autopilot R/W)
$DefaultScopes = @(
  'User.Read',
  'Device.Read.All',
  'DeviceManagementServiceConfig.ReadWrite.All'
)

# Root working area on system drive
$BasePath = Join-Path $env:SystemDrive 'AutopilotGUI'
$Paths = @{
  Root     = $BasePath
  HwId     = Join-Path $BasePath 'HWID'
  Logs     = Join-Path $BasePath 'Logs'
  Settings = Join-Path $BasePath 'Settings'
}
$Paths.GetEnumerator() | ForEach-Object {
  if (-not (Test-Path -LiteralPath $_.Value)) {
    New-Item -ItemType Directory -Path $_.Value -Force | Out-Null
  }
}

# Daily log file
$LogFile = Join-Path $Paths.Logs ("app_{0}.log" -f (Get-Date -Format 'yyyyMMdd') + ".log")
# endregion

# ------------------------------------
# region [Utility helpers (UI/Logging)]
# ------------------------------------
function New-Brush([string]$color) {
  $bc = New-Object Windows.Media.BrushConverter
  return $bc.ConvertFromString($color)
}

function Add-Log([string]$text, [string]$level='INFO') {
  $color = '#1F2937'
  if ($level -eq 'SUCCESS') { $color = '#0A8A0A' }
  elseif ($level -eq 'WARN') { $color = '#B58900' }
  elseif ($level -eq 'ERROR') { $color = '#D13438' }

  if ($Window -and $TxtLog) {
    $Window.Dispatcher.Invoke([action]{
      $run = New-Object Windows.Documents.Run ("[$level] $text")
      $run.Foreground = New-Brush $color
      $p = New-Object Windows.Documents.Paragraph
      $p.Margin = '0,0,0,4'
      [void]$p.Inlines.Add($run)
      $TxtLog.Document.Blocks.Add($p)
      $TxtLog.ScrollToEnd()
    })
  }

  try { Add-Content -LiteralPath $LogFile -Value ("[{0}] {1}" -f $level, $text) } catch { }
}
# endregion

# ------------------------------------
# region [Device / Environment checks]
# ------------------------------------
function Test-Internet {
  try {
    $tcp = New-Object System.Net.Sockets.TcpClient
    $ar  = $tcp.BeginConnect('www.microsoft.com', 443, $null, $null)
    if (-not $ar.AsyncWaitHandle.WaitOne(2000, $false)) { $tcp.Close(); return $false }
    $tcp.EndConnect($ar); $tcp.Close(); return $true
  } catch { return $false }
}

function Refresh-DeviceInfo {
  $LblDevModel.Text = '-'
  $LblDevName.Text  = '-'
  $LblManufacturer.Text = '-'
  $LblSerial.Text   = '-'
  $LblFreeGb.Text   = '-'
  $LblTpm.Text      = 'Unknown'; $LblTpm.Foreground = New-Brush '#444'
  $LblNet.Text      = 'Not connected'; $LblNet.Foreground = New-Brush '#D13438'

  try {
    $cs   = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop
    $bios = Get-CimInstance Win32_BIOS          -ErrorAction SilentlyContinue
    if ($cs -and $cs.Model)        { $LblDevModel.Text = $cs.Model }
    if ($cs -and $cs.Name)         { $LblDevName.Text  = $cs.Name }
    if ($cs -and $cs.Manufacturer) { $LblManufacturer.Text = $cs.Manufacturer }
    if ($bios -and $bios.SerialNumber) { $LblSerial.Text = $bios.SerialNumber }
  } catch { }

  try {
    $disks = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" -ErrorAction SilentlyContinue
    $free = 0
    if ($disks) { foreach ($d in $disks) { if ($d.FreeSpace) { $free += [int64]$d.FreeSpace } } }
    $LblFreeGb.Text = [string]([math]::Round($free/1GB, 0))
  } catch { }

  try {
    $tpm = Get-CimInstance -Namespace root\cimv2\security\microsofttpm -Class Win32_Tpm -ErrorAction Stop
    $spec = $null
    if ($tpm -and $tpm.SpecVersion)          { $spec = [string]$tpm.SpecVersion }
    elseif ($tpm -and $tpm.ManufacturerVersion) { $spec = [string]$tpm.ManufacturerVersion }
    if ($spec) {
      $LblTpm.Text = $spec
      if ($spec -match '2\.0') { $LblTpm.Foreground = New-Brush '#0A8A0A' }
      elseif ($spec -match '1\.2') { $LblTpm.Foreground = New-Brush '#D13438' }
      else { $LblTpm.Foreground = New-Brush '#444' }
    } else {
      $LblTpm.Text = 'Not present'
      $LblTpm.Foreground = New-Brush '#D13438'
    }
  } catch {
    $LblTpm.Text = 'Unknown'
    $LblTpm.Foreground = New-Brush '#444'
  }

  if (Test-Internet) { $LblNet.Text = 'Connected'; $LblNet.Foreground = New-Brush '#0A8A0A' }
}
# endregion

# ---------------------------------------
# region [Graph connection state + UI]
# ---------------------------------------
$script:GraphConnected = $false
$script:GraphAccount   = $null
$script:GraphTenantId  = $null

function Update-MainGraphUI {
  if ($script:GraphConnected) {
    $LblStatus.Text = 'Status: Connected'
    $LblStatus.Foreground = New-Brush '#0A8A0A'
    if ($script:GraphAccount)  { $LblUser.Text   = 'User: '     + $script:GraphAccount } else { $LblUser.Text = 'User: -' }
    if ($script:GraphTenantId) { $LblTenant.Text = 'TenantId: ' + $script:GraphTenantId } else { $LblTenant.Text = 'TenantId: -' }
  } else {
    $LblStatus.Text  = 'Status: Not Connected'
    $LblStatus.Foreground = New-Brush 'Black'
    $LblUser.Text   = 'User: -'
    $LblTenant.Text = 'TenantId: -'
    
    if ($FooterCenter) { $FooterCenter.Text = "$AppName $AppVersion" }
  }
}
# endregion

# ---------------------------------------------------
# region [Background pipeline (Runspace + Timer)]
# ---------------------------------------------------
$iss  = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
$pool = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspacePool(1, 1, $iss, $Host)
$pool.ApartmentState = [System.Threading.ApartmentState]::STA
$pool.Open()

$script:PS            = $null
$script:Async         = $null
$script:CurrentAction = ''

$Timer = New-Object Windows.Threading.DispatcherTimer
$Timer.Interval = [TimeSpan]::FromMilliseconds(300)
$Timer.Add_Tick({
  try {
    if ($script:Async -and $script:Async.IsCompleted) {
      $out = $script:PS.EndInvoke($script:Async)
      try { $script:PS.Dispose() } catch { }
      $script:PS    = $null
      $script:Async = $null
      $Timer.Stop()

      switch ($script:CurrentAction) {
        'collect' { $BtnCollectHash.IsEnabled = $true }
        'enroll'  { $BtnEnroll.IsEnabled      = $true }
      }

      $txt = ($out | Out-String).Trim()
      if (-not $txt) { return }
      $obj = $null
      try { $obj = $txt | ConvertFrom-Json } catch { return }

      if ($obj.Action -eq 'collect') {
        if ($obj.Success) { Add-Log ("Hash collected: " + $obj.Path) 'SUCCESS' }
        else              { Add-Log ("Collect error: " + $obj.Error) 'ERROR' }
      }
      elseif ($obj.Action -eq 'enroll') {
        if ($obj.CsvCreated -and $obj.CsvPath) { Add-Log ("CSV created: " + $obj.CsvPath) 'INFO' }
        if ($obj.Success) { Add-Log ("Uploaded " + $obj.Uploaded + " record(s) to Autopilot.") 'SUCCESS' }
        else              { Add-Log ("Upload error: " + $obj.Error) 'ERROR' }
      }
    }
  } catch {
    Add-Log ('Async error: ' + $_.Exception.Message) 'ERROR'
    try { $script:PS.Dispose() } catch { }
    $script:PS = $null; $script:Async = $null
    $Timer.Stop()
  }
})
# endregion

# -------------------------
# region [Worker scripts]
# -------------------------
# 1) Collect HWID (CSV)
$CollectHWIDWorker = @'
param($OutFolder)
try{
  if([string]::IsNullOrWhiteSpace($OutFolder)){ throw "Please select a folder." }
  if(-not (Test-Path -LiteralPath $OutFolder)){ [void](New-Item -ItemType Directory -Path $OutFolder -Force) }

  $serial = (Get-CimInstance Win32_BIOS -ErrorAction Stop).SerialNumber
  $prodId = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name ProductId).ProductId
  $devMap = Get-CimInstance -Namespace root\cimv2\mdm\dmmap -Class MDM_DevDetail_Ext01 -ErrorAction Stop
  $hw     = $devMap.DeviceHardwareData
  if(-not $serial -or -not $hw){ throw "Could not read Serial/Hardware Hash. Run as admin and ensure device supports Autopilot hash." }

  $ts   = (Get-Date).ToString("yyyyMMdd_HHmmss")
  $file = Join-Path $OutFolder ("AutopilotHWID_{0}_{1}.csv" -f $env:COMPUTERNAME,$ts)

  Set-Content -LiteralPath $file -Value 'Device Serial Number,Windows Product ID,Hardware Hash' -Encoding Ascii
  Add-Content -LiteralPath $file -Value ('"'+$serial+'","'+$prodId+'","'+$hw+'"' ) -Encoding Ascii

  [pscustomobject]@{Action='collect';Success=$true;Path=$file;Error=$null} | ConvertTo-Json -Compress
}catch{
  [pscustomobject]@{Action='collect';Success=$false;Path=$null;Error=$_.Exception.Message} | ConvertTo-Json -Compress
}
'@

# 2) Enroll / Upload (auto-create CSV for current device if none supplied)
$EnrollWorker = @'
param($Path,$GroupTag,$AssignedUser,$AssignedName,$HwIdFolder)
Import-Module Microsoft.Graph.Authentication -ErrorAction Stop
try{
  $ctx=$null; try{$ctx=Get-MgContext}catch{}
  if(-not $ctx -or (-not $ctx.Account -and -not $ctx.ClientId)){ throw "Not connected to Graph." }

  $records=@(); $csvCreated=$false; $csvPath=$null

  if([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path -LiteralPath $Path)){
    if(-not (Test-Path -LiteralPath $HwIdFolder)){ New-Item -ItemType Directory -Path $HwIdFolder -Force | Out-Null }
    $serial = (Get-CimInstance Win32_BIOS -ErrorAction Stop).SerialNumber
    $prodId = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name ProductId).ProductId
    $devMap = Get-CimInstance -Namespace root\cimv2\mdm\dmmap -Class MDM_DevDetail_Ext01 -ErrorAction Stop
    $hw     = $devMap.DeviceHardwareData
    if(-not $serial -or -not $hw){ throw "Could not read Serial/Hardware Hash." }

    $ts      = (Get-Date).ToString("yyyyMMdd_HHmmss")
    $csvPath = Join-Path $HwIdFolder ("AutopilotHWID_{0}_{1}.csv" -f $env:COMPUTERNAME,$ts)
    Set-Content -LiteralPath $csvPath -Value 'Device Serial Number,Windows Product ID,Hardware Hash' -Encoding Ascii
    Add-Content -LiteralPath $csvPath -Value ('"'+$serial+'","'+$prodId+'","'+$hw+'"' ) -Encoding Ascii
    $csvCreated=$true

    $records += [pscustomobject]@{
      serialNumber=$serial; productKey=$prodId; hardwareIdentifier=$hw;
      groupTag=$GroupTag; assignedUserPrincipalName=$AssignedUser; assignedComputerName=$AssignedName
    }
  } else {
    if($Path.ToLower().EndsWith(".json")){
      $json=Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
      foreach($r in $json){ $records+= $r }
    } else {
      $csv=Import-Csv -LiteralPath $Path
      foreach($r in $csv){
        $records+=[pscustomobject]@{
          serialNumber=$r.'Device Serial Number'; productKey=$r.'Windows Product ID'; hardwareIdentifier=$r.'Hardware Hash';
          groupTag=$GroupTag; assignedUserPrincipalName=$AssignedUser; assignedComputerName=$AssignedName
        }
      }
    }
  }
  if($records.Count -eq 0){ throw "No records to upload." }

  $uploaded=0
  foreach($rec in $records){
    $uri='https://graph.microsoft.com/v1.0/deviceManagement/importedWindowsAutopilotDeviceIdentities'
    $body=@{
      serialNumber=$rec.serialNumber; productKey=$rec.productKey; hardwareIdentifier=$rec.hardwareIdentifier;
      groupTag=$rec.groupTag; assignedUserPrincipalName=$rec.assignedUserPrincipalName; assignedComputerName=$rec.assignedComputerName;
      state=@{deviceImportStatus='pending';deviceErrorCode=0}
    } | ConvertTo-Json -Depth 5

    Invoke-MgGraphRequest -Method POST -Uri $uri -Body $body -ContentType 'application/json' -ErrorAction Stop | Out-Null
    $uploaded++
  }

  [pscustomobject]@{Action='enroll';Success=$true;Uploaded=$uploaded;CsvCreated=$csvCreated;CsvPath=$csvPath;Error=$null} | ConvertTo-Json -Compress
}catch{
  [pscustomobject]@{Action='enroll';Success=$false;Uploaded=0;CsvCreated=$false;CsvPath=$null;Error=$_.Exception.Message} | ConvertTo-Json -Compress
}
'@
# endregion

# ------------------------------------------------
# region [Secondary windows (Graph / Lookup UI)]
# ------------------------------------------------
function Show-GraphConnectWindow {
  param([string[]]$DefaultScopes)

  $x = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Connect to Microsoft Graph"
        Width="640" SizeToContent="Height"
        WindowStartupLocation="CenterScreen" Background="#FFF5F7FB">
  <Grid Margin="14">
    <Border Padding="16" CornerRadius="12" Background="White" BorderBrush="#FFDDE3EA" BorderThickness="1">
      <StackPanel>
        <StackPanel Orientation="Horizontal" Margin="0,0,0,10">
          <RadioButton x:Name="RdoInteractive" Content="Interactive Auth" IsChecked="True" Margin="0,0,18,0"/>
          <RadioButton x:Name="RdoApp"         Content="App-only Auth"/>
        </StackPanel>

        <Border x:Name="AppGroup" Padding="10" CornerRadius="8" Background="#FFF9FAFB" BorderBrush="#FFE5E7EB" BorderThickness="1" Margin="0,0,0,10">
          <Grid>
            <Grid.ColumnDefinitions><ColumnDefinition Width="140"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
            <Grid.RowDefinitions>
              <RowDefinition Height="Auto"/><RowDefinition Height="6"/>
              <RowDefinition Height="Auto"/><RowDefinition Height="6"/>
              <RowDefinition Height="Auto"/><RowDefinition Height="6"/>
              <RowDefinition Height="Auto"/>
            </Grid.RowDefinitions>
            <TextBlock Grid.Row="0" Grid.Column="0" Text="Tenant ID" VerticalAlignment="Center" Margin="0,0,8,0"/>
            <TextBox   Grid.Row="0" Grid.Column="1" x:Name="TxtTenantA" Height="24" Padding="6"/>
            <TextBlock Grid.Row="2" Grid.Column="0" Text="Client ID" VerticalAlignment="Center" Margin="0,0,8,0"/>
            <TextBox   Grid.Row="2" Grid.Column="1" x:Name="TxtClientId" Height="24" Padding="6"/>
            <TextBlock Grid.Row="4" Grid.Column="0" Text="Client Secret" VerticalAlignment="Center" Margin="0,0,8,0"/>
            <PasswordBox Grid.Row="4" Grid.Column="1" x:Name="PwdSecret" Height="24" Padding="6"/>
            <TextBlock Grid.Row="6" Grid.Column="0" Text="Cert Thumbprint" VerticalAlignment="Center" Margin="0,0,8,0"/>
            <TextBox   Grid.Row="6" Grid.Column="1" x:Name="TxtThumb" Height="24" Padding="6"/>
          </Grid>
        </Border>

        <Grid>
          <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
          <Button Grid.Column="0" x:Name="BtnConnect"    Height="36" Margin="0,0,8,0"
                  Background="#FF2E6BE6" Foreground="White" BorderBrush="#FF2E6BE6" FontWeight="SemiBold"
                  Content="Connect"/>
          <Button Grid.Column="1" x:Name="BtnDisconnect" Height="36" Content="Disconnect"/>
        </Grid>

        <StackPanel Margin="0,10,0,0">
          <TextBlock x:Name="LblStatus2" Text="Status: Not Connected" FontWeight="Bold"/>
          <TextBlock x:Name="LblUser2"   Text="User: -"  Margin="0,2,0,0"/>
          <TextBlock x:Name="LblTenant2" Text="TenantId: -"/>
        </StackPanel>
      </StackPanel>
    </Border>
  </Grid>
</Window>
"@

  $w               = [Windows.Markup.XamlReader]::Parse($x)
  $RdoInteractive2 = $w.FindName('RdoInteractive')
  $RdoApp2         = $w.FindName('RdoApp')
  $AppGroup2       = $w.FindName('AppGroup')
  $TxtTenantA2     = $w.FindName('TxtTenantA')
  $TxtClientId2    = $w.FindName('TxtClientId')
  $PwdSecret2      = $w.FindName('PwdSecret')
  $TxtThumb2       = $w.FindName('TxtThumb')
  $BtnConnect2     = $w.FindName('BtnConnect')
  $BtnDisconnect2  = $w.FindName('BtnDisconnect')
  $LblStatus2      = $w.FindName('LblStatus2')
  $LblUser2        = $w.FindName('LblUser2')
  $LblTenant2      = $w.FindName('LblTenant2')

  function Update-ModeUI2 {
    if ($RdoInteractive2.IsChecked) { $AppGroup2.IsEnabled = $false; $AppGroup2.Opacity = 0.6 }
    else                            { $AppGroup2.IsEnabled = $true;  $AppGroup2.Opacity = 1.0 }
  }
  $RdoInteractive2.Add_Checked({ Update-ModeUI2 })
  $RdoApp2.Add_Checked({ Update-ModeUI2 })
  Update-ModeUI2

  $BtnConnect2.Add_Click({
    try {
      Import-Module Microsoft.Graph.Authentication -ErrorAction Stop
      $LblStatus2.Text = 'Status: Connecting...'; $LblStatus2.Foreground = New-Brush 'Black'

      if ($RdoInteractive2.IsChecked) {
        Connect-MgGraph -Scopes $DefaultScopes -NoWelcome -ErrorAction Stop
      } else {
        if ([string]::IsNullOrWhiteSpace($TxtTenantA2.Text) -or [string]::IsNullOrWhiteSpace($TxtClientId2.Text)) {
          throw 'App-only requires Tenant ID and Client ID.'
        }
        if ([string]::IsNullOrWhiteSpace($PwdSecret2.Password) -and [string]::IsNullOrWhiteSpace($TxtThumb2.Text)) {
          throw 'Provide Client Secret OR Certificate Thumbprint.'
        }

        if (-not [string]::IsNullOrWhiteSpace($TxtThumb2.Text)) {
          Connect-MgGraph -TenantId $TxtTenantA2.Text -ClientId $TxtClientId2.Text `
            -CertificateThumbprint $TxtThumb2.Text -NoWelcome -ErrorAction Stop
        } else {
          $sec = ConvertTo-SecureString $PwdSecret2.Password -AsPlainText -Force
          Connect-MgGraph -TenantId $TxtTenantA2.Text -ClientId $TxtClientId2.Text `
            -ClientSecret $sec -NoWelcome -ErrorAction Stop
        }
      }

      $ctx = $null; try { $ctx = Get-MgContext } catch {}
      $script:GraphConnected = ($ctx -and ($ctx.Account -or $ctx.ClientId))
      $script:GraphAccount   = $null; if ($ctx -and $ctx.Account)  { $script:GraphAccount = $ctx.Account }
      $script:GraphTenantId  = $null; if ($ctx -and $ctx.TenantId) { $script:GraphTenantId = $ctx.TenantId }

      if ($script:GraphConnected) {
        $LblStatus2.Text = 'Status: Connected'; $LblStatus2.Foreground = New-Brush '#0A8A0A'
        if ($script:GraphAccount)  { $LblUser2.Text   = 'User: ' + $script:GraphAccount } else { $LblUser2.Text   = 'User: -' }
        if ($script:GraphTenantId) { $LblTenant2.Text = 'TenantId: ' + $script:GraphTenantId } else { $LblTenant2.Text = 'TenantId: -' }
        Add-Log "Connected to Graph." 'SUCCESS'
      } else {
        $LblStatus2.Text = 'Status: Not Connected'; $LblStatus2.Foreground = New-Brush 'Black'
        $LblUser2.Text = 'User: -'; $LblTenant2.Text = 'TenantId: -'
        Add-Log "Graph connection did not complete." 'WARN'
      }
      Update-MainGraphUI
    } catch {
      $LblStatus2.Text = 'Status: ERROR - ' + $_.Exception.Message
      $LblStatus2.Foreground = New-Brush '#D13438'
      Add-Log ("Graph connect error: " + $_.Exception.Message) 'ERROR'
    }
  })

  $BtnDisconnect2.Add_Click({
    try {
      Import-Module Microsoft.Graph.Authentication -ErrorAction SilentlyContinue
      $LblStatus2.Text = 'Status: Disconnecting...'
      Disconnect-MgGraph -ErrorAction SilentlyContinue
      Start-Sleep -Milliseconds 150
      $script:GraphConnected = $false; $script:GraphAccount = $null; $script:GraphTenantId = $null
      $LblStatus2.Text = 'Status: Not Connected'; $LblUser2.Text = 'User: -'; $LblTenant2.Text = 'TenantId: -'
      Update-MainGraphUI
      Add-Log "Disconnected from Graph." 'INFO'
    } catch {
      $LblStatus2.Text = 'Status: ERROR - ' + $_.Exception.Message
      Add-Log ("Graph disconnect error: " + $_.Exception.Message) 'ERROR'
    }
  })

  [void]$w.ShowDialog()
}

function Show-AutopilotLookupWindow {
  param([string]$InitialSerial)

  try { Import-Module Microsoft.Graph.Authentication -ErrorAction Stop }
  catch { Add-Log "Microsoft.Graph.Authentication module missing." "ERROR"; return }

  $ctx = $null; try { $ctx = Get-MgContext } catch {}
  if (-not $ctx -or (-not $ctx.Account -and -not $ctx.ClientId)) {
    Add-Log "Connect to Graph first." "WARN"; return
  }

  $x = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Find Autopilot Devices" Width="880" Height="540" WindowStartupLocation="CenterScreen" Background="#FFF9FAFB">
  <Grid Margin="12">
    <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="8"/><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
    <Grid Grid.Row="0">
      <Grid.ColumnDefinitions><ColumnDefinition Width="170"/><ColumnDefinition Width="*"/><ColumnDefinition Width="110"/><ColumnDefinition Width="110"/></Grid.ColumnDefinitions>
      <TextBlock Grid.Column="0" VerticalAlignment="Center" Text="Serial (exact or blank):" Margin="0,0,8,0"/>
      <TextBox   Grid.Column="1" x:Name="TxtSerial" Height="25" Padding="3"/>
      <Button    Grid.Column="2" x:Name="BtnSearch"  Content="Search"  Height="24" Margin="6,0,0,0"/>
      <Button    Grid.Column="3" x:Name="BtnClose"   Content="Close"   Height="24" Margin="6,0,0,0"/>
    </Grid>
    <DataGrid Grid.Row="2" x:Name="Dg" AutoGenerateColumns="True" IsReadOnly="True" AlternationCount="2" AlternatingRowBackground="#FFF1F5FF" GridLinesVisibility="Horizontal"/>
    <TextBlock Grid.Row="3" x:Name="LblCount" Margin="0,8,0,0" Foreground="#FF6B7280"/>
  </Grid>
</Window>
"@

  $w         = [Windows.Markup.XamlReader]::Parse($x)
  $TxtSerial = $w.FindName('TxtSerial')
  $BtnSearch = $w.FindName('BtnSearch')
  $BtnClose  = $w.FindName('BtnClose')
  $Dg        = $w.FindName('Dg')
  $LblCount  = $w.FindName('LblCount')
  if ($InitialSerial) { $TxtSerial.Text = $InitialSerial }

  function Load-Results([string]$serial) {
    try {
      $base = 'https://graph.microsoft.com/v1.0/deviceManagement/windowsAutopilotDeviceIdentities'
      if ([string]::IsNullOrWhiteSpace($serial)) { $uri = "$base`?\$top=50" }
      else {
        $filter = "serialNumber eq '$serial'"
        $uri = "$base`?\$filter=$([System.Uri]::EscapeDataString($filter))"
      }
      $res  = Invoke-MgGraphRequest -Method GET -Uri $uri -ErrorAction Stop
      $list = @()
      if ($res.value) {
        foreach ($i in $res.value) {
          $list += [pscustomobject]@{
            serialNumber = $i.serialNumber
            manufacturer = $i.manufacturer
            model        = $i.model
            groupTag     = $i.groupTag
            profileStatus= $i.deploymentProfileAssignmentStatus
            managedName  = $i.managedDeviceName
            aadDeviceId  = $i.azureActiveDirectoryDeviceId
          }
        }
      }
      $Dg.ItemsSource = $null; $Dg.ItemsSource = $list
      $LblCount.Text  = "Results: " + ($(if ($list) { $list.Count } else { 0 }))
    } catch {
      $Dg.ItemsSource = $null
      $LblCount.Text  = "Error: $($_.Exception.Message)"
    }
  }

  $BtnSearch.Add_Click({ Load-Results $TxtSerial.Text })
  $BtnClose.Add_Click({ $w.Close() })
  Load-Results $TxtSerial.Text
  [void]$w.ShowDialog()
}
# endregion

# -----------------------
# region [Main window UI]
# -----------------------
$Xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Autopilot Importer - Collect / Enroll / Find"
        Width="1100" SizeToContent="Height"
        WindowStartupLocation="CenterScreen"
        Background="#FFF5F7FB">

  <Window.Resources>
    <LinearGradientBrush x:Key="HeaderGradient" StartPoint="0,0" EndPoint="1,0">
      <GradientStop Color="#2563EB" Offset="0.0"/>   <!-- blue -->
      <GradientStop Color="#7C3AED" Offset="0.55"/>  <!-- purple -->
      <GradientStop Color="#06B6D4" Offset="1.0"/>   <!-- cyan -->
    </LinearGradientBrush>
    <Style TargetType="TextBox">
      <Setter Property="Height" Value="28"/>
      <Setter Property="Padding" Value="6"/>
    </Style>
    <Style x:Key="PrimaryBtn" TargetType="Button">
      <Setter Property="Foreground" Value="White"/>
      <Setter Property="FontWeight" Value="SemiBold"/>
      <Setter Property="Height" Value="42"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="BorderBrush" Value="#2E6BE6"/>
      <Setter Property="Background">
        <Setter.Value>
          <LinearGradientBrush StartPoint="0,0" EndPoint="1,0">
            <GradientStop Color="#2E6BE6" Offset="0"/>
            <GradientStop Color="#5B8DEF" Offset="1"/>
          </LinearGradientBrush>
        </Setter.Value>
      </Setter>
      <Style.Triggers>
        <Trigger Property="IsMouseOver" Value="True">
          <Setter Property="Background">
            <Setter.Value>
              <LinearGradientBrush StartPoint="0,0" EndPoint="1,0">
                <GradientStop Color="#245BD1" Offset="0"/>
                <GradientStop Color="#3C7AF0" Offset="1"/>
              </LinearGradientBrush>
            </Setter.Value>
          </Setter>
        </Trigger>
        <Trigger Property="IsEnabled" Value="False">
          <Setter Property="Opacity" Value="0.6"/>
        </Trigger>
      </Style.Triggers>
    </Style>
    <Style x:Key="SecondaryBtn" TargetType="Button">
      <Setter Property="Height" Value="42"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="BorderBrush" Value="#CBD5E1"/>
      <Setter Property="Background">
        <Setter.Value>
          <LinearGradientBrush StartPoint="0,0" EndPoint="1,0">
            <GradientStop Color="#E5E7EB" Offset="0"/>
            <GradientStop Color="#D1D5DB" Offset="1"/>
          </LinearGradientBrush>
        </Setter.Value>
      </Setter>
      <Style.Triggers>
        <Trigger Property="IsMouseOver" Value="True">
          <Setter Property="Background">
            <Setter.Value>
              <LinearGradientBrush StartPoint="0,0" EndPoint="1,0">
                <GradientStop Color="#CFD8E3" Offset="0"/>
                <GradientStop Color="#BAC6D5" Offset="1"/>
              </LinearGradientBrush>
            </Setter.Value>
          </Setter>
        </Trigger>
      </Style.Triggers>
    </Style>
    <Style x:Key="SmallBtn" TargetType="Button" BasedOn="{StaticResource SecondaryBtn}">
      <Setter Property="Height" Value="30"/>
      <Setter Property="Padding" Value="6,0"/>
    </Style>
  </Window.Resources>

  <DockPanel LastChildFill="True">
    <Border DockPanel.Dock="Top" Padding="23" Background="{StaticResource HeaderGradient}">
      <Grid>
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width="Auto"/><ColumnDefinition Width="*"/>
        </Grid.ColumnDefinitions>
       
        <StackPanel Grid.Column="1">
          <TextBlock Text="Autopilot Importer - Collect / Enroll / Find" Foreground="White" FontSize="23" FontWeight="Bold"/>
          <TextBlock Text="Collect HWID -> Connect Graph -> Enroll or Inspect" Foreground="#FFEAF2FF" FontSize="13"/>
        </StackPanel>
      </Grid>
    </Border>

   <!-- Footer (gradient, 3 zones) -->
    <Border DockPanel.Dock="Bottom" Padding="8">
      <Border.Background>
        <LinearGradientBrush StartPoint="0,0" EndPoint="1,0">
          <GradientStop Color="#2563EB" Offset="0.0"/>  <!-- blue -->
          <GradientStop Color="#06B6D4" Offset="1.0"/>  <!-- cyan -->
        </LinearGradientBrush>
      </Border.Background>

      <Grid>
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width="*"/>
          <ColumnDefinition Width="Auto"/>
          <ColumnDefinition Width="*"/>
        </Grid.ColumnDefinitions>

        <!-- Left zone -->
        <TextBlock x:Name="FooterLeft"
                   Grid.Column="0"
                   Text="Qassim University · IT Operations"
                   Foreground="White" FontSize="12"
                   HorizontalAlignment="Left" Margin="6,0"/>

        <!-- Center zone (shows app + version; can show tenant after connect) -->
        <TextBlock x:Name="FooterCenter"
                   Grid.Column="1"
                   Text="Autopilot Importer v1.0"
                   Foreground="White" FontSize="12"
                   HorizontalAlignment="Center"/>

        <!-- Right zone -->
        <TextBlock x:Name="FooterRight"
                   Grid.Column="2"
                   Text="© 2025 M.Omar (momar.tech) — All Rights Reserved"
                   Foreground="White" FontSize="12"
                   HorizontalAlignment="Right" Margin="0,0,6,0"/>
      </Grid>
    </Border>


    <Grid Margin="14">
      <Border Padding="16" CornerRadius="14" Background="White" BorderBrush="#FFDDE3EA" BorderThickness="1">
        <Grid>
          <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
          </Grid.RowDefinitions>
          <Grid.ColumnDefinitions>
            <ColumnDefinition Width="3*"/>
            <ColumnDefinition Width="2*"/>
          </Grid.ColumnDefinitions>

          <!-- Device info -->
          <GroupBox Grid.Row="0" Grid.Column="0" Header="Device Information" Margin="0,0,8,8">
            <Border Margin="8" Padding="10" CornerRadius="5" BorderBrush="#FFE5E7EB" BorderThickness="1" Background="#FFFAFBFF">
              <Grid>
                <Grid.ColumnDefinitions>
                  <ColumnDefinition Width="Auto"/><ColumnDefinition Width="*"/>
                  <ColumnDefinition Width="36"/>
                  <ColumnDefinition Width="Auto"/><ColumnDefinition Width="*"/>
                </Grid.ColumnDefinitions>
                <Grid.RowDefinitions>
                  <RowDefinition Height="Auto"/><RowDefinition Height="9"/>
                  <RowDefinition Height="Auto"/><RowDefinition Height="9"/>
                  <RowDefinition Height="Auto"/><RowDefinition Height="9"/>
                  <RowDefinition Height="Auto"/>
                </Grid.RowDefinitions>

                <TextBlock Grid.Row="0" Grid.Column="0" Text="Device Model: " FontWeight="Bold"/>
                <TextBlock Grid.Row="0" Grid.Column="1" x:Name="LblDevModel" Text="-"/>
                <TextBlock Grid.Row="0" Grid.Column="3" Text="Free Storage in GB:" FontWeight="Bold"/>
                <TextBlock Grid.Row="0" Grid.Column="4" x:Name="LblFreeGb" Text="-"/>

                <TextBlock Grid.Row="2" Grid.Column="0" Text="Device Name: " FontWeight="Bold"/>
                <TextBlock Grid.Row="2" Grid.Column="1" x:Name="LblDevName" Text="-"/>
                <TextBlock Grid.Row="2" Grid.Column="3" Text="TPM Version:" FontWeight="Bold"/>
                <TextBlock Grid.Row="2" Grid.Column="4" x:Name="LblTpm" Text="-"/>

                <TextBlock Grid.Row="4" Grid.Column="0" Text="Manufacturer: " FontWeight="Bold"/>
                <TextBlock Grid.Row="4" Grid.Column="1" x:Name="LblManufacturer" Text="-"/>
                <TextBlock Grid.Row="4" Grid.Column="3" Text="Internet: " FontWeight="Bold"/>
                <TextBlock Grid.Row="4" Grid.Column="4" x:Name="LblNet" Text="-"/>

                <TextBlock Grid.Row="6" Grid.Column="0" Text="Serial number: " FontWeight="Bold"/>
                <TextBlock Grid.Row="6" Grid.Column="1" x:Name="LblSerial" Text="-"/>
              </Grid>
            </Border>
          </GroupBox>

          <!-- Graph -->
          <GroupBox Grid.Row="0" Grid.Column="1" Header="Microsoft Graph" Margin="8,0,0,8">
            <Border Margin="8" Padding="10" CornerRadius="8" BorderBrush="#FFE5E7EB" BorderThickness="1">
              <StackPanel>
                <Button x:Name="BtnOpenGraph" Height="42" Content="Open Graph Connect..." Style="{StaticResource PrimaryBtn}"/>
                <StackPanel Margin="0,8,0,0">
                  <TextBlock x:Name="LblStatus" Text="Status: Not Connected" FontWeight="Bold" Foreground="Black"/>
                  <TextBlock x:Name="LblUser"   Text="User: -"  Margin="0,2,0,0"/>
                  <TextBlock x:Name="LblTenant" Text="TenantId: -"/>
                </StackPanel>
              </StackPanel>
            </Border>
          </GroupBox>

          <!-- Autopilot -->
          <GroupBox Grid.Row="1" Grid.Column="0" Header="Windows Autopilot" Margin="0,8,8,0">
            <StackPanel Margin="8,6,8,8">

              <Border Padding="10" CornerRadius="8" Background="#FFF9FAFB" BorderBrush="#FFE5E7EB" BorderThickness="1" Margin="0,0,0,10">
                <Grid>
                  <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="120"/><ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="120"/><ColumnDefinition Width="120"/>
                  </Grid.ColumnDefinitions>
                  <Grid.RowDefinitions>
                    <RowDefinition Height="Auto"/><RowDefinition Height="6"/>
                    <RowDefinition Height="Auto"/>
                  </Grid.RowDefinitions>

                  <TextBlock Grid.Row="0" Grid.Column="0" Text="Save folder:" VerticalAlignment="Center" Margin="0,0,8,0"/>
                  <TextBox   Grid.Row="0" Grid.Column="1" x:Name="TxtSaveFolder"/>
                  <Button    Grid.Row="0" Grid.Column="2" x:Name="BtnDefaultPath"  Content="Default Path" Style="{StaticResource SmallBtn}" Margin="6,0,6,0"/>
                  <Button    Grid.Row="0" Grid.Column="3" x:Name="BtnBrowseFolder" Content="Browse..."     Style="{StaticResource SmallBtn}"/>

                  <Button Grid.Row="2" Grid.Column="0" Grid.ColumnSpan="4" x:Name="BtnCollectHash"
                          Style="{StaticResource PrimaryBtn}" Margin="0,4,0,0" Content="Collect Hash"/>
                </Grid>
              </Border>

              <Border Padding="10" CornerRadius="8" Background="#FFF9FAFB" BorderBrush="#FFE5E7EB" BorderThickness="1">
                <Grid>
                  <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="150"/><ColumnDefinition Width="*"/><ColumnDefinition Width="120"/>
                  </Grid.ColumnDefinitions>
                  <Grid.RowDefinitions>
                    <RowDefinition Height="Auto"/><RowDefinition Height="6"/>
                    <RowDefinition Height="Auto"/><RowDefinition Height="6"/>
                    <RowDefinition Height="Auto"/><RowDefinition Height="6"/>
                    <RowDefinition Height="Auto"/><RowDefinition Height="10"/>
                    <RowDefinition Height="Auto"/>
                  </Grid.RowDefinitions>

                  <TextBlock Grid.Row="0" Grid.Column="0" Text="CSV/JSON file:" VerticalAlignment="Center" Margin="0,0,8,0"/>
                  <TextBox   Grid.Row="0" Grid.Column="1" x:Name="TxtImportPath"/>
                  <Button    Grid.Row="0" Grid.Column="2" x:Name="BtnBrowseImport" Content="Browse..." Style="{StaticResource SmallBtn}" Margin="6,0,0,0"/>

                  <TextBlock Grid.Row="2" Grid.Column="0" Text="Group Tag:" VerticalAlignment="Center" Margin="0,0,8,0"/>
                  <TextBox   Grid.Row="2" Grid.Column="1" x:Name="TxtGroupTag" Grid.ColumnSpan="2"/>

                  <TextBlock Grid.Row="4" Grid.Column="0" Text="Assigned User:" VerticalAlignment="Center" Margin="0,0,8,0"/>
                  <TextBox   Grid.Row="4" Grid.Column="1" x:Name="TxtAssignedUser" Grid.ColumnSpan="2"/>

                  <TextBlock Grid.Row="6" Grid.Column="0" Text="Assigned Computer Name:" VerticalAlignment="Center" Margin="0,0,8,0"/>
                  <TextBox   Grid.Row="6" Grid.Column="1" x:Name="TxtAssignedName" Grid.ColumnSpan="2"/>

                  <Grid Grid.Row="8" Grid.Column="0" Grid.ColumnSpan="3">
                    <Grid.ColumnDefinitions>
                      <ColumnDefinition Width="*"/><ColumnDefinition Width="*"/>
                    </Grid.ColumnDefinitions>

                    <Button Grid.Column="0" x:Name="BtnEnroll" Style="{StaticResource PrimaryBtn}" Margin="0,0,8,0"
                            Content="Enroll / Upload to Autopilot"/>
                    <Button Grid.Column="1" x:Name="BtnFindInAutopilot" Style="{StaticResource SecondaryBtn}"
                            Content="Find in Autopilot"/>
                  </Grid>
                </Grid>
              </Border>

            </StackPanel>
          </GroupBox>

          <!-- Message Center -->
          <GroupBox Grid.Row="1" Grid.Column="1" Header="Message Center" Margin="8,8,0,0">
            <DockPanel Margin="8">
              <StackPanel Orientation="Horizontal" DockPanel.Dock="Top" HorizontalAlignment="Right" Margin="0,0,0,6">
                <Button x:Name="BtnClearLog" Style="{StaticResource SmallBtn}" Width="90" Content="Clear"/>
                <TextBlock Text="  " Width="6"/>
                <Button x:Name="BtnCopyLog"  Style="{StaticResource SmallBtn}" Width="90" Content="Copy"/>
              </StackPanel>
              <RichTextBox x:Name="TxtLog" VerticalAlignment="Stretch" Height="Auto"
                           IsReadOnly="True" BorderBrush="#FFDDE3EA" BorderThickness="1" Padding="6"
                           VerticalScrollBarVisibility="Auto"/>
            </DockPanel>
          </GroupBox>

        </Grid>
      </Border>
    </Grid>
  </DockPanel>

</Window>
"@

# Build main window and capture controls
$Window          = [Windows.Markup.XamlReader]::Parse($Xaml)

$FooterLeft      = $Window.FindName('FooterLeft')
$FooterCenter    = $Window.FindName('FooterCenter')
$FooterRight     = $Window.FindName('FooterRight')


# Device info
$LblDevModel     = $Window.FindName('LblDevModel')
$LblDevName      = $Window.FindName('LblDevName')
$LblManufacturer = $Window.FindName('LblManufacturer')
$LblSerial       = $Window.FindName('LblSerial')
$LblFreeGb       = $Window.FindName('LblFreeGb')
$LblTpm          = $Window.FindName('LblTpm')
$LblNet          = $Window.FindName('LblNet')

# Graph
$BtnOpenGraph       = $Window.FindName('BtnOpenGraph')
$BtnFindInAutopilot = $Window.FindName('BtnFindInAutopilot')
$LblStatus          = $Window.FindName('LblStatus')
$LblUser            = $Window.FindName('LblUser')
$LblTenant          = $Window.FindName('LblTenant')

# Autopilot controls
$TxtSaveFolder      = $Window.FindName('TxtSaveFolder')
$BtnDefaultPath     = $Window.FindName('BtnDefaultPath')
$BtnBrowseFolder    = $Window.FindName('BtnBrowseFolder')
$BtnCollectHash     = $Window.FindName('BtnCollectHash')

$TxtImportPath      = $Window.FindName('TxtImportPath')
$BtnBrowseImport    = $Window.FindName('BtnBrowseImport')
$TxtGroupTag        = $Window.FindName('TxtGroupTag')
$TxtAssignedUser    = $Window.FindName('TxtAssignedUser')
$TxtAssignedName    = $Window.FindName('TxtAssignedName')
$BtnEnroll          = $Window.FindName('BtnEnroll')

# Message Center
$BtnClearLog        = $Window.FindName('BtnClearLog')
$BtnCopyLog         = $Window.FindName('BtnCopyLog')
$TxtLog             = $Window.FindName('TxtLog'); $TxtLog.Document = New-Object Windows.Documents.FlowDocument

# Footer
$year = (Get-Date).Year
$FooterLeft.Text   = $OrgName
$FooterCenter.Text = "$AppName $AppVersion"
$FooterRight.Text  = "$year $CopyrightBy - All Rights Reserved"

# endregion

# ---------------------------
# region [Wire up UI events]
# ---------------------------
$Window.Add_Loaded({
  Refresh-DeviceInfo
  Update-MainGraphUI
  $TxtSaveFolder.Text = $Paths.HwId
  Add-Log "Ready." "INFO"
})

$BtnClearLog.Add_Click({ $TxtLog.Document.Blocks.Clear() })
$BtnCopyLog.Add_Click({
  $range = New-Object Windows.Documents.TextRange($TxtLog.Document.ContentStart, $TxtLog.Document.ContentEnd)
  [System.Windows.Clipboard]::SetText($range.Text)
})

$BtnDefaultPath.Add_Click({ $TxtSaveFolder.Text = $Paths.HwId })
$BtnBrowseFolder.Add_Click({
  $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
  $dlg.Description = 'Select a folder to save the Autopilot CSV'
  if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { $TxtSaveFolder.Text = $dlg.SelectedPath }
})

$BtnCollectHash.Add_Click({
  try {
    Add-Log "Collecting hardware hash..." "INFO"
    $BtnCollectHash.IsEnabled = $false
    $script:CurrentAction     = 'collect'

    $script:PS = [System.Management.Automation.PowerShell]::Create()
    $script:PS.RunspacePool = $pool
    $script:PS.AddScript($CollectHWIDWorker).AddArgument($TxtSaveFolder.Text) | Out-Null
    $script:Async = $script:PS.BeginInvoke()
    $Timer.Start()
  } catch {
    Add-Log ("Collect start error: " + $_.Exception.Message) "ERROR"
    try { $script:PS.Dispose() } catch { }
    $BtnCollectHash.IsEnabled = $true
  }
})

$BtnBrowseImport.Add_Click({
  $dlg = New-Object System.Windows.Forms.OpenFileDialog
  $dlg.Title  = 'Select Autopilot CSV or JSON'
  $dlg.Filter = 'CSV or JSON|*.csv;*.json|CSV|*.csv|JSON|*.json|All files|*.*'
  if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { $TxtImportPath.Text = $dlg.FileName }
})

$BtnEnroll.Add_Click({
  try {
    Add-Log "Uploading to Autopilot..." "INFO"
    $BtnEnroll.IsEnabled  = $false
    $script:CurrentAction = 'enroll'

    $script:PS = [System.Management.Automation.PowerShell]::Create()
    $script:PS.RunspacePool = $pool
    $script:PS.AddScript($EnrollWorker).
      AddArgument($TxtImportPath.Text).
      AddArgument($TxtGroupTag.Text).
      AddArgument($TxtAssignedUser.Text).
      AddArgument($TxtAssignedName.Text).
      AddArgument($Paths.HwId) | Out-Null

    $script:Async = $script:PS.BeginInvoke()
    $Timer.Start()
  } catch {
    Add-Log ("Upload start error: " + $_.Exception.Message) "ERROR"
    try { $script:PS.Dispose() } catch { }
    $BtnEnroll.IsEnabled = $true
  }
})

$BtnOpenGraph.Add_Click({ Show-GraphConnectWindow -DefaultScopes $DefaultScopes })
$BtnFindInAutopilot.Add_Click({ Show-AutopilotLookupWindow -InitialSerial $LblSerial.Text })
# endregion

# ---------------------
# region [Run the UI]
# ---------------------
[void]$Window.ShowDialog()
# endregion
