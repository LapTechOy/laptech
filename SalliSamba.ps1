#Hyväksyy vieraskäytön, jotta sambaservuun voi yhdistää

$RegistryPath = 'HKLM:Software\Policies\Microsoft\Windows\LanmanWorkstation'
$Name = 'AllowInsecureGuestAuth'
$Value = '1'
if (-NOT (Test-Path $RegistryPath)) {
    New-Item -Path $RegistryPath -Force | Out-Null
}
 

New-ItemProperty -Path $RegistryPath -Name $Name -Value $Value -PropertyType DWORD -Force

#Hakee samba-protokollan ja asentaa sen. Hyväksyy SMB palveluiden käytön. 

Get-WindowsOptionalFeature -Online -FeatureName SMB1Protocol 

Enable-WindowsOptionalFeature -Online -FeatureName SMB1Protocol

sc.exe qc lanmanworkstation 
sc.exe config lanmanworkstation depend= bowser/mrxsmb10/mrxsmb20/nsi
sc.exe config mrxsmb10 start= auto
sc.exe config lanmanworkstation depend= bowser/mrxsmb10/mrxsmb20/nsi
sc.exe config mrxsmb20 start= auto
