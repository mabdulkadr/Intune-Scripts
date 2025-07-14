<#
.SYNOPSIS
    Displays a Windows notification to inform the user that a Windows 11 upgrade is available.

.DESCRIPTION
    This script shows a Windows toast notification indicating that a Windows 11 upgrade is available. The notification supports both English and Arabic languages based on the system language settings.

.HINT
    This is a community script. There is no guarantee for this. Please check thoroughly before running.

.RUN AS
    User

.EXAMPLE
    .\Remediate_Windows11UpgradeNotification.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Date    : 2024-11-11

#>

function Display-ToastNotification() {
    $Load = [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime]
    $Load = [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime]
    # Load the notification into the required format
    $ToastXML = New-Object -TypeName Windows.Data.Xml.Dom.XmlDocument
    $ToastXML.LoadXml($Toast.OuterXml)
        
    # Display the toast notification
    try {
        [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($App).Show($ToastXml)
    }
    catch { 
        Write-Output 'Something went wrong when displaying the toast notification'
        Write-Output 'Make sure the script is running as the logged on user'    
    }
}

# Setting image variables
$LogoImageUri = "https://www.qu.edu.sa/images/favicon/512x512.png"
$HeroImageUri = "https://ekhbareeat.com/wp-content/themes/Khafagy-core/timthumb/?src=https://ekhbareeat.com/wp-content/uploads/2024/04/Screenshot_%D9%A2%D9%A0%D9%A2%D9%A4%D9%A0%D9%A4%D9%A1%D9%A5_%D9%A2%D9%A3%D9%A2%D9%A4%D9%A5%D9%A2_Chrome.jpg&w=0&h=500"
$LogoImage = "$env:TEMP\ToastLogoImage.png"
$HeroImage = "$env:TEMP\ToastHeroImage.png"
$Uptime = Get-ComputerInfo | Select-Object -ExpandProperty OSUptime 

# Fetching images from URI
Invoke-WebRequest -Uri $LogoImageUri -OutFile $LogoImage -UseBasicParsing
Invoke-WebRequest -Uri $HeroImageUri -OutFile $HeroImage -UseBasicParsing

# Defining the Toast notification settings
$Scenario = 'reminder' # Possible values are: reminder | short | long

# Detect current system language
$OSLanguage = (Get-WinSystemLocale).Name
$language = (Get-WinUserLanguageList)[0].LanguageTag

# Set text variables based on language
if ($OSLanguage -like 'ar-*' -or $language -like 'ar-*') {
    # نص باللغة العربية
    $AttributionText = "https://qu.edu.sa"
    $HeaderText = "ترقية Windows 11 متاحة الآن"
    $TitleText = "تم إطلاق ترقية Windows 11."
    $BodyText1 = "لتحسين الأداء والاستقرار، ننصحك بالترقية إلى Windows 11."
    $BodyText2 = "نرجو حفظ عملك وترقية جهازك في أقرب وقت ممكن. نشكرك على تعاونك."
    $ActionButtonContent = "ابدأ الترقية الآن"
    $UILang = 'ar-SA' # أو يمكنك استخدام $OSLanguage
} else {
    # نص باللغة الإنجليزية
    $AttributionText = "https://qu.edu.sa"
    $HeaderText = "Windows 11 Upgrade Now Available"
    $TitleText = "The Windows 11 upgrade has been released."
    $BodyText1 = "We recommend upgrading to Windows 11 to enhance performance and stability."
    $BodyText2 = "Please save your work and upgrade your device at your earliest convenience. Thank you for your cooperation."
    $ActionButtonContent = "Start Upgrade Now"
    $UILang = 'en-US' # or you can use $OSLanguage
}

# Check for required entries in registry for when using PowerShell as application for the toast
# Register the AppID in the registry for use with the Action Center, if required
$RegPath = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Notifications\Settings'
$App =  '{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\WindowsPowerShell\v1.0\powershell.exe'

# Creating registry entries if they don't exist
if (-NOT (Test-Path -Path "$RegPath\$App")) {
    New-Item -Path "$RegPath\$App" -Force | Out-Null
    New-ItemProperty -Path "$RegPath\$App" -Name 'ShowInActionCenter' -Value 1 -PropertyType 'DWORD' | Out-Null
}

# Make sure the app used with the action center is enabled
if ((Get-ItemProperty -Path "$RegPath\$App" -Name 'ShowInActionCenter' -ErrorAction SilentlyContinue).ShowInActionCenter -ne '1') {
    New-ItemProperty -Path "$RegPath\$App" -Name 'ShowInActionCenter' -Value 1 -PropertyType 'DWORD' -Force | Out-Null
}

# Formatting the toast notification XML
[xml]$Toast = @"
<toast scenario="$Scenario" lang="$UILang">
    <visual>
        <binding template="ToastGeneric">
            <image placement="hero" src="$HeroImage" style="display: block; margin-left: auto; margin-right: auto;"/>
            <image id="1" placement="appLogoOverride" hint-crop="circle" src="$LogoImage" style="display: block; margin-left: auto; margin-right: auto;"/>
            <text placement="attribution">$AttributionText</text>
            <text>$HeaderText</text>
            <group>
                <subgroup>
                    <text hint-style="title" hint-wrap="true">$TitleText</text>
                </subgroup>
            </group>
            <group>
                <subgroup>     
                    <text hint-style="body" hint-wrap="true">$BodyText1</text>
                </subgroup>
            </group>
            <group>
                <subgroup>     
                    <text hint-style="body" hint-wrap="true">$BodyText2</text>
                </subgroup>
            </group>
        </binding>
    </visual>
    <actions>
        <action activationType="protocol" arguments="ms-settings:windowsupdate" content="$ActionButtonContent"/>
    </actions>
</toast>
"@

# Send the notification
Display-ToastNotification
Exit 0
