# Aseta suoritusoikeudet sekä asenna nuget
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
Install-PackageProvider -Name NuGet -Force
Import-PackageProvider -Name NuGet


# Päivitä PSGallery : PSRepository
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
Get-PSRepository -Name PSGallery | Format-List * -Force

# Listaa moduulit
Write-Output "Running:  Get-InstalledModule"
Get-InstalledModule

# Asenna tarvittavat moduulit
Write-Output "Running:  Install-Module -Name PSWindowsUpdate -Force"
Install-Module -Name PSWindowsUpdate -Force

# Tuo moduulit
Import-Module -Name PSWindowsUpdate

# Listaa moduulien komennot:
Get-Command -Module PSWindowsUpdate

# Tarkista onko Microsoft Update palvelu saatavilla.
# Lisää update palvelu jollei.
$MicrosoftUpdateServiceId = "7971f918-a847-4430-9279-4a52d1efe18d"
If ((Get-WUServiceManager -ServiceID $MicrosoftUpdateServiceId).ServiceID -eq $MicrosoftUpdateServiceId) { Write-Output "Confirm that Microsoft Update Service is registered ...." }
Else { Add-WUServiceManager -ServiceID $MicrosoftUpdateServiceId -ErrorAction SilentlyContinue -Confirm:$false }
# Now, check again to ensure it is available.  If not -- fail the script:
If (!((Get-WUServiceManager -ServiceID $MicrosoftUpdateServiceId).ServiceID -eq $MicrosoftUpdateServiceId)) { Throw "ERROR:  Microsoft Update Service is not registered :( " }

# Pakota asennus ja käynnistä uudelleen
Get-WUInstall -MicrosoftUpdate -AcceptAll -AutoReboot 
Get-WUInstall -MicrosoftUpdate -AcceptAll -Download -Install -AutoReboot
