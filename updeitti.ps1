Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force

# Asenna NuGet suoraan ilman tarkistusta
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Scope AllUsers -ForceBootstrap -Confirm:$False
Import-PackageProvider -Name NuGet

# Aseta PSGallery luotetuksi
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted

# Tarkista, onko PSWindowsUpdate-moduuli asennettu
$psWindowsUpdateModule = Get-Module -ListAvailable -Name PSWindowsUpdate
if (-not $psWindowsUpdateModule) {
    Write-Output "PSWindowsUpdate-moduulia ei löydy. Asennetaan moduuli..."
    Install-Module -Name PSWindowsUpdate -Force -Confirm:$false
}

# Tuo PSWindowsUpdate-moduuli
Import-Module -Name PSWindowsUpdate

# Tarkista onko Microsoft Update palvelu saatavilla ja lisää se tarvittaessa
$MicrosoftUpdateServiceId = "7971f918-a847-4430-9279-4a52d1efe18d"
if ((Get-WUServiceManager -ServiceID $MicrosoftUpdateServiceId).ServiceID -ne $MicrosoftUpdateServiceId) {
    Write-Output "Microsoft Update Service ei ole rekisteröity. Lisätään palvelu..."
    Add-WUServiceManager -ServiceID $MicrosoftUpdateServiceId -ErrorAction SilentlyContinue -Confirm:$false
}

# Varmista, että Microsoft Update Service on rekisteröity
if (!((Get-WUServiceManager -ServiceID $MicrosoftUpdateServiceId).ServiceID -eq $MicrosoftUpdateServiceId)) {
    Throw "Virhe: Microsoft Update Service ei ole rekisteröity. Päivitystä ei voida suorittaa."
}

try {
    Write-Output "Aloitetaan Windows Update..."
    Get-WUInstall -MicrosoftUpdate -Category "Drivers" -AcceptAll -AutoReboot -ErrorAction Stop
    Get-WUInstall -MicrosoftUpdate -Category "Drivers" -AcceptAll -Download -Install -AutoReboot -ErrorAction Stop
} catch {
    Write-Error "Windows Update -prosessissa tapahtui virhe: $_. Tarkista yhteys ja yritä uudelleen."
}
