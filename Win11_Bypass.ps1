<#
.SYNOPSIS
Ohittaa Windows 11:n asennuksen ja päivityksen rajoitukset sekä mahdollisesti suorittaa Windows Update -resetoinnin.

.DESCRIPTION
Tämä PowerShell-skripti muokkaa rekisteriä siten, että Windows 11 voidaan asentaa ja päivittää, vaikka laitteisto ei täyttäisi Microsoftin virallisia vaatimuksia. 
Skripti lisää rekisterimerkinnät, jotka ohittavat:
- TPM (Trusted Platform Module) -tarkistuksen
- RAM-muistin minimivaatimuksen
- Secure Boot -vaatimuksen
- Suorittimen (CPU) yhteensopivuusvaatimuksen
- Windows Updaten käyttämät yhteensopivuustarkistukset (jotta päivitys toimii suoraan Windows Updaten kautta)
- Estetään Windows telemetriaa, jotta yritetään varmistaa, ettei rajoituksia tule päälle tulevaisuudessa

.PARAMETERS
-r : (switch) Valinnainen parametri. Jos annettu, suoritetaan ensin Windows Update -resetointi.

.EXAMPLE
Suorita pelkät ohitukset ja telemetrian minimointi:
    .\Win11_Bypass.ps1

Suorita ensin Updaten resetointi ja sen jälkeen rekisterimuutokset:
    .\Win11_Bypass.ps1 -r

.TAI suorita se suoraan verkosta:
    iwr -useb "https://raw.githubusercontent.com/LapTechOy/laptech/main/Win11_Bypass.ps1" | iex


.NOTES
- Mahdollistaa Windows 11:n asennuksen tai päivityksen laitteilla, joita Microsoft ei virallisesti tue.
- Käytä omalla vastuulla.
- Käytä skriptiä järjestelmänvalvojana!

.AUTHOR
Tao Vuokko
#>

param(
    [switch]$r
)

# Tarkistetaan, onko skripti käynnissä järjestelmänvalvojana
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "Skripti ei ole kaynnissa jarjestelmanvalvojana. Yritetaan korottaa oikeuksia..." -ForegroundColor Yellow
    Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

if ($r) {
    Write-Host "`n*** Suoritetaan Windows Update -resetointi ja verkkoasetusten nollaus... ***" -ForegroundColor Cyan
    Write-Host "1. Pysaytetaan Windows Update -palvelut..."
    Stop-Service -Name BITS -Force -ErrorAction SilentlyContinue
    Stop-Service -Name wuauserv -Force -ErrorAction SilentlyContinue
    Stop-Service -Name appidsvc -Force -ErrorAction SilentlyContinue
    Stop-Service -Name cryptsvc -Force -ErrorAction SilentlyContinue

    Write-Host "2. Poistetaan QMGR-tiedostot..."
    Remove-Item "$env:ALLUSERSPROFILE\Application Data\Microsoft\Network\Downloader\qmgr*.dat" -ErrorAction SilentlyContinue

    Write-Host "3. Nimetaan uudelleen kansiot: SoftwareDistribution ja Catroot2..."
    Rename-Item "$env:systemroot\SoftwareDistribution" "SoftwareDistribution.bak" -ErrorAction SilentlyContinue
    Rename-Item "$env:systemroot\System32\Catroot2" "catroot2.bak" -ErrorAction SilentlyContinue

    Write-Host "4. Poistetaan WindowsUpdate.log-tiedosto..."
    Remove-Item "$env:systemroot\WindowsUpdate.log" -ErrorAction SilentlyContinue

    Set-Location $env:systemroot\system32

    Write-Host "5. Rekisteroidaan DLL tiedostoja..."
    regsvr32.exe /s atl.dll
    regsvr32.exe /s urlmon.dll
    regsvr32.exe /s mshtml.dll
    regsvr32.exe /s shdocvw.dll
    regsvr32.exe /s browseui.dll
    regsvr32.exe /s jscript.dll
    regsvr32.exe /s vbscript.dll
    regsvr32.exe /s scrrun.dll
    regsvr32.exe /s msxml.dll
    regsvr32.exe /s msxml3.dll
    regsvr32.exe /s msxml6.dll
    regsvr32.exe /s actxprxy.dll
    regsvr32.exe /s softpub.dll
    regsvr32.exe /s wintrust.dll
    regsvr32.exe /s dssenh.dll
    regsvr32.exe /s rsaenh.dll
    regsvr32.exe /s gpkcsp.dll
    regsvr32.exe /s sccbase.dll
    regsvr32.exe /s slbcsp.dll
    regsvr32.exe /s cryptdlg.dll
    regsvr32.exe /s oleaut32.dll
    regsvr32.exe /s ole32.dll
    regsvr32.exe /s shell32.dll
    regsvr32.exe /s initpki.dll
    regsvr32.exe /s wuapi.dll
    regsvr32.exe /s wuaueng.dll
    regsvr32.exe /s wuaueng1.dll
    regsvr32.exe /s wucltui.dll
    regsvr32.exe /s wups.dll
    regsvr32.exe /s wups2.dll
    regsvr32.exe /s wuweb.dll
    regsvr32.exe /s qmgr.dll
    regsvr32.exe /s qmgrprxy.dll
    regsvr32.exe /s wucltux.dll
    regsvr32.exe /s muweb.dll
    regsvr32.exe /s wuwebv.dll    

    Write-Host "6. Suoritetaan verkon reset-komennot..."
    arp -d *
    nbtstat -R
    nbtstat -RR
    ipconfig /flushdns
    ipconfig /registerdns
    netsh winsock reset
    netsh int ip reset c:\resetlog.txt

    Write-Host "7. Kaynnistetaan Windows Update -palvelut uudelleen..."
    Start-Service -Name BITS -ErrorAction SilentlyContinue
    Start-Service -Name wuauserv -ErrorAction SilentlyContinue
    Start-Service -Name appidsvc -ErrorAction SilentlyContinue
    Start-Service -Name cryptsvc -ErrorAction SilentlyContinue

    Write-Host "*** Windows Update -resetointi ja verkkoasetusten nollaus suoritettu. ***" -ForegroundColor Green
    Write-Host "On suositeltavaa kaynnistaa tietokone uudelleen ennen jatkamista." -ForegroundColor Yellow
    Read-Host "Paina Enter jatkaaksesi"
}

Write-Host "`n*** Windows 11 -asennuksen ja paivityksen rajoitusten ohitus ***" -ForegroundColor Cyan
Write-Host "*** Muokataan rekisteria, varmista etta tiedat mita olet tekemassa! ***`n" -ForegroundColor Yellow

# Määritetään rekisteripolut
$labConfigPath = "HKLM:\SYSTEM\Setup\LabConfig"
$moSetupPath = "HKLM:\SYSTEM\Setup\MoSetup"
$appCompatFlagsPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\AppCompatFlags"
$hwReqChkPath = "$appCompatFlagsPath\HwReqChk"

# Luodaan rekisteriavain, jos sitä ei ole olemassa
@($labConfigPath, $moSetupPath, $hwReqChkPath) | ForEach-Object {
    if (-not (Test-Path $_)) {
        New-Item -Path $_ -Force | Out-Null
    }
}

# Lisätään rekisterimerkinnat (ohitetaan laitteistovaatimukset)
@(
    @{ Path = $labConfigPath; Name = "BypassTPMCheck"; Value = 1 },
    @{ Path = $labConfigPath; Name = "BypassRAMCheck"; Value = 1 },
    @{ Path = $labConfigPath; Name = "BypassSecureBootCheck"; Value = 1 },
    @{ Path = $labConfigPath; Name = "BypassCPUCheck"; Value = 1 },
    @{ Path = $moSetupPath; Name = "AllowUpgradesWithUnsupportedTPMOrCPU"; Value = 1 }
) | ForEach-Object {
    New-ItemProperty -Path $_.Path -Name $_.Name -Value $_.Value -PropertyType DWord -Force
}

# Windows Update -yhteensopivuustarkistusten tyhjennys
Write-Host "`n*** Poistetaan aiemmat Windows Updaten yhteensopivuustarkistukset... ***" -ForegroundColor Cyan
@(
    "$appCompatFlagsPath\CompatMarkers",
    "$appCompatFlagsPath\Shared",
    "$appCompatFlagsPath\TargetVersionUpgradeExperienceIndicators"
) | ForEach-Object {
    Remove-Item -Path $_ -Force -Recurse -ErrorAction SilentlyContinue
}

# Lisätään Windows Updaten "huijausasetukset"
Write-Host "*** Lisataan uudet huijausasetukset Windows Updatelle... ***" -ForegroundColor Cyan
New-ItemProperty -Path "$appCompatFlagsPath\HwReqChk" -Name "HwReqChkVars" -PropertyType MultiString -Value @(
    "SQ_SecureBootCapable=TRUE",
    "SQ_SecureBootEnabled=TRUE",
    "SQ_TpmVersion=2",
    "SQ_RamMB=8192"
) -Force

# Poistetaan "System Requirements Not Met" -vesileima järjestelmätasolla (HKLM)
$systemPolicyKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
if (-not (Test-Path $systemPolicyKey)) {
    New-Item -Path $systemPolicyKey -Force | Out-Null
}
New-ItemProperty -Path $systemPolicyKey -Name "HideUnsupportedHardwareNotifications" -PropertyType DWord -Value 1 -Force | Out-Null
Write-Host "Watermark varoitus poistettu" -ForegroundColor Green

# Poistetaan "System Requirements Not Met" -vesileima käyttäjäkohtaisesti (HKCU)
$uhncKey = "HKCU:\Control Panel\UnsupportedHardwareNotificationCache"
if (-not (Test-Path $uhncKey)) {
    New-Item -Path $uhncKey -Force | Out-Null
}
New-ItemProperty -Path $uhncKey -Name "SV2" -Value 0 -PropertyType DWord -Force | Out-Null

# Määritetään Windows Update targetrelease -asetukset
Write-Host "`n*** Maaritetaan Windows Update hakemaan Windows 11 25H2 -paivitysta ***" -ForegroundColor Cyan
$WinUpdatePath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
if (!(Test-Path $WinUpdatePath)) {
    New-Item -Path $WinUpdatePath -Force | Out-Null
}
New-ItemProperty -Path $WinUpdatePath -Name "ProductVersion" -Value "Windows 11" -PropertyType String -Force
New-ItemProperty -Path $WinUpdatePath -Name "TargetReleaseVersion" -Value 1 -PropertyType DWord -Force
New-ItemProperty -Path $WinUpdatePath -Name "TargetReleaseVersionInfo" -Value "25H2" -PropertyType String -Force

# Asetetaan rekisteriavain AllowTelemetry arvoksi 0
Write-Host "Asetetaan rekisteriavain AllowTelemetry arvoksi 0..." -ForegroundColor Cyan
try {
    Set-ItemProperty -Path "HKLM:\Software\Policies\Microsoft\Windows\DataCollection" -Name "AllowTelemetry" -Value 0 -Type DWord -Force
    Write-Host "Rekisteriavain paivitetty onnistuneesti." -ForegroundColor Green
} catch {
    Write-Host "Virhe rekisteriavaimen paivittamisessa: $_" -ForegroundColor Red
}

# Poistetaan käytöstä telemetriaan liittyvät ajastetut tehtävät
$telemetryTasks = @(
    "\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser",
    "\Microsoft\Windows\Application Experience\PcaPatchDbTask",
    "\Microsoft\Windows\Application Experience\StartupAppTask"
)

foreach ($task in $telemetryTasks) {
    schtasks /query /tn "$task" 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Poistetaan kaytosta tehtava: $task..." -ForegroundColor Cyan
        schtasks /change /disable /tn "$task" | Out-Null
        Write-Host "Tehtava poistettu kaytosta: $task" -ForegroundColor Green
    } else {
        Write-Host "Tehtavaa $task ei loydy. Se on jo poistettu tai ei ole olemassa tässä Windows-versiossa." -ForegroundColor Yellow
    }
}

Write-Host "*** Windows Update kohdistettu Windows 11 25H2 -paivitykseen! ***" -ForegroundColor Green
Write-Host "`n*** Valmis! ***" -ForegroundColor Green
Write-Host "*** Kaynnista tietokone uudelleen, jotta muutokset tulevat voimaan. ***" -ForegroundColor Yellow
