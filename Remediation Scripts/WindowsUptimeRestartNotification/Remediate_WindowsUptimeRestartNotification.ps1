<#
Script: Remediate_WindowsUptimeRestartNotification.ps1
Description: Checks the device's uptime in days. If it has been 7 days or more since the last reboot, it shows a Windows notification prompting the user to restart. The notification supports both English and Arabic languages based on the system language settings and includes "Restart Now" and "Restart Later" buttons.
Version 1.2: Added "Restart Now" and "Restart Later" buttons with language support
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

# Fetching images from URI
Invoke-WebRequest -Uri $LogoImageUri -OutFile $LogoImage -UseBasicParsing
Invoke-WebRequest -Uri $HeroImageUri -OutFile $HeroImage -UseBasicParsing

# Get the device uptime
$Uptime = (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
$DaysUptime = (New-TimeSpan -Start $Uptime -End (Get-Date)).Days

# Define the Toast notification settings
$Scenario = 'reminder' # Possible values are: reminder | default

# Detect current system language
$OSLanguage = (Get-WinSystemLocale).Name
$language = (Get-WinUserLanguageList)[0].LanguageTag

# Set text variables based on language
if ($OSLanguage -like 'ar-*' -or $language -like 'ar-*') {
    # Arabic text
    $AttributionText = "فريق عمليات تقنية المعلومات"
    $HeaderText = "يتطلب إعادة تشغيل الكمبيوتر!"
    $TitleText = "لم يتم إعادة تشغيل جهازك منذ $DaysUptime أيام"
    $BodyText1 = "لأسباب تتعلق بالأداء والاستقرار، نقترح إعادة التشغيل مرة واحدة على الأقل في الأسبوع."
    $BodyText2 = "يرجى حفظ عملك وإعادة تشغيل جهازك اليوم. شكرًا لتعاونك."
    $RestartNowButtonContent = "أعد التشغيل الآن"
    $RestartLaterButtonContent = "أعد التشغيل لاحقًا"
    $UILang = 'ar-SA'
} else {
    # English text
    $AttributionText = "IT Operation Team"
    $HeaderText = "Computer Restart is Needed!"
    $TitleText = "Your device has not been rebooted in the last $DaysUptime days"
    $BodyText1 = "For performance and stability reasons, we suggest a reboot at least once a week."
    $BodyText2 = "Please save your work and restart your device today. Thank you in advance."
    $RestartNowButtonContent = "Restart Now"
    $RestartLaterButtonContent = "Restart Later"
    $UILang = 'en-US'
}

# Check for required entries in registry for when using PowerShell as application for the toast
$RegPath = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Notifications\Settings'
$App = '{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\WindowsPowerShell\v1.0\powershell.exe'

# Creating registry entries if they don't exist
if (-NOT (Test-Path -Path "$RegPath\$App")) {
    New-Item -Path "$RegPath\$App" -Force | Out-Null
    New-ItemProperty -Path "$RegPath\$App" -Name 'ShowInActionCenter' -Value 1 -PropertyType 'DWORD' | Out-Null
}

# Ensure the app used with the action center is enabled
if ((Get-ItemProperty -Path "$RegPath\$App" -Name 'ShowInActionCenter' -ErrorAction SilentlyContinue).ShowInActionCenter -ne '1') {
    New-ItemProperty -Path "$RegPath\$App" -Name 'ShowInActionCenter' -Value 1 -PropertyType 'DWORD' -Force | Out-Null
}

# Only display the notification if uptime is 7 days or more
if ($DaysUptime -ge 7) {
    # Formatting the toast notification XML
    [xml]$Toast = @"
    <toast scenario="$Scenario" lang="$UILang">
        <visual>
            <binding template="ToastGeneric">
                <image placement="hero" src="$HeroImage" />
                <image id="1" placement="appLogoOverride" hint-crop="circle" src="$LogoImage" />
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
            <action activationType="protocol" arguments="Restart-Computer -force" content="$RestartNowButtonContent"/>
            <action activationType="system" arguments="dismiss" content="$RestartLaterButtonContent"/>
        </actions>
    </toast>
"@
    # Send the notification
    Display-ToastNotification
}

Exit 0
