<#
.SYNOPSIS
	Windowssin internet ja DNS ongelmien korjaus. 
.DESCRIPTION
	Skripti käynnistää tietokoneen verkkoadapterit uudestaan sekä resetoi kaikki verkkoprotokollat mukaanlukien DNSän. Asettaa vakio DNS palvelimeksi cloudflaren. Skripti tarvitsee Admin oikeudet. 
	
#>

#Requires -RunAsAdministrator
Powershell -noprofile -executionpolicy bypass

try {
	$StopWatch = [system.diagnostics.stopwatch]::startNew()

	Get-NetAdapter | Restart-NetAdapter 

	[int]$Elapsed = $StopWatch.Elapsed.TotalSeconds
	
	ipconfig /release
	ipconfig /renew
	arp -d *
	nbtstat -R
	nbtstat -RR
	ipconfig /flushdns
	ipconfig /registerdns
	netsh winsock reset
	netsh int ip reset c:\resetlog.txt
	
	" restarted all local network adapters and resets network stack $Elapsed sec"
	exit 0 # success
} catch {
	" Error in line $($_.InvocationInfo.ScriptLineNumber): $($Error[0])"
	exit 1
}

	Get-NetAdapter
	
	Set-DnsClientServerAddress -InterfaceAlias WLAN -ServerAddresses "1.1.1.1","1.0.0.1"
