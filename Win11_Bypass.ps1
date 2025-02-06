<#
.SYNOPSIS
Ohittaa Windows 11:n asennuksen ja päivityksen laitteistovaatimukset (TPM, RAM, Secure Boot, CPU).

.DESCRIPTION
Tämä PowerShell-skripti muokkaa rekisteriä siten, että Windows 11 voidaan asentaa ja päivittää, vaikka laitteisto ei täyttäisi Microsoftin virallisia vaatimuksia. 
Skripti lisää rekisterimerkinnät, jotka ohittavat:
- TPM (Trusted Platform Module) -tarkistuksen
- RAM-muistin minimivaatimuksen
- Secure Boot -vaatimuksen
- Suorittimen (CPU) yhteensopivuusvaatimuksen
- Windowsin päivitysten rajoitukset (jotta päivitykset toimivat ilman TPM:ää ja tuettua CPU:ta)
- Windows Updaten käyttämät yhteensopivuustarkistukset (jotta päivitys toimii suoraan Windows Updaten kautta)

.PARAMETERS
Ei parametreja. Skripti suoritetaan sellaisenaan.

.EXAMPLE
Suorita skripti järjestelmänvalvojana PowerShellissä:
    .\Windows_TPM_SecureBoot_ohitus.ps1

.TAI suorita se suoraan verkosta (esim. Gististä):
    iwr -useb "https://raw.githubusercontent.com/LapTechOy/laptech/main/Win11_Bypass.ps1" | iex

.NOTES
- Skripti **vaatii järjestelmänvalvojan oikeudet** ja yrittää korottaa itsensä automaattisesti.
- Tämän ajaminen voi mahdollistaa Windows 11:n asennuksen tai päivityksen, mutta Microsoft ei tue tätä virallisesti.
- Käytä omalla vastuulla.

.AUTHOR
Tao Vuokko
#>

# Tarkistetaan, onko skripti käynnissä järjestelmänvalvojana
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "Skripti ei ole käynnissä järjestelmänvalvojana. Yritetään korottaa oikeuksia..." -ForegroundColor Yellow
    Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

Write-Host "`n*** Windows 11 -asennuksen ja päivityksen rajoitusten ohitus ***" -ForegroundColor Cyan
Write-Host "*** Muokataan rekisteriä, varmista että tiedät mitä olet tekemässä! ***`n" -ForegroundColor Yellow

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

# Lisätään tai päivitetään rekisterimerkinnät (asennuksen kiertäminen)
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
Write-Host "*** Lisätään uudet huijausasetukset Windows Updatelle... ***" -ForegroundColor Cyan
New-ItemProperty -Path "$appCompatFlagsPath\HwReqChk" -Name "HwReqChkVars" -PropertyType MultiString -Value @(
    "SQ_SecureBootCapable=TRUE",
    "SQ_SecureBootEnabled=TRUE",
    "SQ_TpmVersion=2",
    "SQ_RamMB=8192"
) -Force

# --- Poistetaan "system requirements not met" -vesileiman ilmoitus ---
$uhncKey = "HKCU:\Control Panel\UnsupportedHardwareNotificationCache"
if (Test-Path $uhncKey) {
    # Asetetaan SV2 arvoksi 0, mikä poistaa vesileiman ilmoituksen
    New-ItemProperty -Path $uhncKey -Name "SV2" -Value 0 -PropertyType DWord -Force
    Write-Host "Rekisteriarvo 'SV2' on asetettu arvoksi 0 kohdassa $uhncKey." -ForegroundColor Green
} else {
    Write-Host "Rekisteriavain $uhncKey ei ole olemassa. Luodaan avain ja asetetaan 'SV2' arvoksi 0." -ForegroundColor Yellow
    New-Item -Path $uhncKey -Force | Out-Null
    New-ItemProperty -Path $uhncKey -Name "SV2" -Value 0 -PropertyType DWord -Force
    Write-Host "Luotu $uhncKey ja asetettu 'SV2' arvoksi 0." -ForegroundColor Green
}

Write-Host "`n*** Valmis! ***" -ForegroundColor Green
Write-Host "*** Käynnistä tietokone uudelleen, jotta muutokset tulevat voimaan. ***`n" -ForegroundColor Yellow
