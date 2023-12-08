Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force

# Tarkista, onko NuGet jo asennettu ja asenna se tarvittaessa ilman vahvistusta
if (-not (Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue)) {
    Write-Output "Asennetaan NuGet..."
    Install-PackageProvider -Name NuGet -ForceBootstrap -Force
    Import-PackageProvider -Name NuGet
}

# Tarkista, onko PSWindowsUpdate-moduuli asennettu
$psWindowsUpdateModule = Get-Module -ListAvailable -Name PSWindowsUpdate
if (-not $psWindowsUpdateModule) {
    Write-Output "PSWindowsUpdate-moduulia ei löydy. Asennetaan moduuli..."
    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
    Get-PSRepository -Name PSGallery | Format-List * -Force
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
    Get-WUInstall -MicrosoftUpdate -AcceptAll -AutoReboot -ErrorAction Stop
    Get-WUInstall -MicrosoftUpdate -AcceptAll -Download -Install -AutoReboot -ErrorAction Stop
} catch {
    Write-Error "Windows Update -prosessissa tapahtui virhe: $_. Tarkista yhteys ja yritä uudelleen."
}
