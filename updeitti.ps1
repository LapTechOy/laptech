
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
Install-PackageProvider -Name NuGet -Force
Import-PackageProvider -Name NuGet

# Update the PSGallery : PSRepository
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
Get-PSRepository -Name PSGallery | Format-List * -Force

# List installed modules
Write-Output "Running:  Get-InstalledModule"
Get-InstalledModule

# Install the needed modules
Write-Output "Running:  Install-Module -Name PSWindowsUpdate -Force"
Install-Module -Name PSWindowsUpdate -Force

# Import the module
Import-Module -Name PSWindowsUpdate

# List support commands from the module:
Get-Command -Module PSWindowsUpdate

# Now, check if the Microsoft Update service is available.
# Add it if it is not available.
$MicrosoftUpdateServiceId = "7971f918-a847-4430-9279-4a52d1efe18d"
If ((Get-WUServiceManager -ServiceID $MicrosoftUpdateServiceId).ServiceID -eq $MicrosoftUpdateServiceId) { Write-Output "Confirm that Microsoft Update Service is registered ...." }
Else { Add-WUServiceManager -ServiceID $MicrosoftUpdateServiceId -ErrorAction SilentlyContinue -Confirm:$false }
# Now, check again to ensure it is available.  If not -- fail the script:
If (!((Get-WUServiceManager -ServiceID $MicrosoftUpdateServiceId).ServiceID -eq $MicrosoftUpdateServiceId)) { Throw "ERROR:  Microsoft Update Service is not registered :( " }

# Force the installation of updates and reboot
Get-WUInstall -MicrosoftUpdate -AcceptAll -AutoReboot 
Get-WUInstall -MicrosoftUpdate -AcceptAll -Download -Install -AutoReboot
