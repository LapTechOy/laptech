# Reset-Windows_Update.ps1 skripti Windows Update -komponenttien nollaamiseen

Write-Host "`n=== Windows Update Resetointi ===" -ForegroundColor Cyan

# 1. Tarkista jarjestelmanvalvojan oikeudet
$ident = [Security.Principal.WindowsIdentity]::GetCurrent()
$princ = New-Object Security.Principal.WindowsPrincipal($ident)
if (-not $princ.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Tama skripti vaatii jarjestelmanvalvojan oikeudet." -ForegroundColor Red
    return
}

# 2. Maarita oikea System32-polku riippuen PowerShell-prosessin bittisyydesta
if ([Environment]::Is64BitProcess) {
    $sys32 = "$env:windir\System32"
} else {
    $sys32 = "$env:windir\Sysnative"
}

# 3. Pysaytetaan palvelut
Write-Host "Pysaytetaan Windows Update -palvelut..."
$services = @("BITS", "wuauserv", "appidsvc", "cryptsvc")
foreach ($svc in $services) {
    Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue
    Write-Host "  - $svc pysaytetty"
}

# 4. Yritetaan nimetä kansiot uudelleen
$ts = Get-Date -Format "yyyyMMdd_HHmmss"
$sd = "$env:SystemRoot\SoftwareDistribution"
$cr = "$env:SystemRoot\System32\Catroot2"

Write-Host "Nimetaan kansiot, jos mahdollista..."
try {
    if (Test-Path $sd) {
        Rename-Item $sd "$sd.bak_$ts" -Force -ErrorAction Stop
        Write-Host "  - SoftwareDistribution nimetty uudelleen"
    }
} catch {
    Write-Host "  - Ei voitu nimetä SoftwareDistribution – jatketaan" -ForegroundColor Yellow
}
try {
    if (Test-Path $cr) {
        Rename-Item $cr "$cr.bak_$ts" -Force -ErrorAction Stop
        Write-Host "  - Catroot2 nimetty uudelleen"
    }
} catch {
    Write-Host "  - Ei voitu nimetä Catroot2 – jatketaan" -ForegroundColor Yellow
}

# 5. Poistetaan WindowsUpdate.log
$log = "$env:SystemRoot\WindowsUpdate.log"
if (Test-Path $log) {
    try {
        Remove-Item $log -Force -ErrorAction Stop
        Write-Host "  - WindowsUpdate.log poistettu"
    } catch {
        Write-Host "  - Ei voitu poistaa logia – jatketaan" -ForegroundColor Yellow
    }
}

# 6. Verkkoasetusten nollaus
Write-Host "Nollataan verkkoasetukset..."
& "$sys32\arp.exe" -d * | Out-Null
& "$sys32\nbtstat.exe" -R | Out-Null
& "$sys32\nbtstat.exe" -RR | Out-Null
& "$sys32\ipconfig.exe" /flushdns | Out-Null
& "$sys32\ipconfig.exe" /registerdns | Out-Null
& "$sys32\netsh.exe" winsock reset | Out-Null
& "$sys32\netsh.exe" int ip reset | Out-Null
Write-Host "  - Verkkoasetukset nollattu"

# 7. Palveluiden uudelleenkaynnistys
Write-Host "Kaynnistetaan palvelut uudelleen..."
foreach ($svc in $services) {
    Start-Service -Name $svc -ErrorAction SilentlyContinue
    Write-Host "  - $svc kaynnistetty"
}

Write-Host "Pakotetaan paivityshaku..."
try {
    & "$sys32\UsoClient.exe" StartScan
    Write-Host "  - UsoClient kaynnistetty"
} catch {
    try {
        & "$sys32\wuauclt.exe" /resetauthorization /detectnow
        Write-Host "  - Fallback: wuauclt kaynnistetty"
    } catch {
        Write-Host "  - Ei onnistunut pakotettu haku" -ForegroundColor Yellow
    }
}

Write-Host "`nValmis! Suositellaan kaynnistamaan kone uudelleen." -ForegroundColor Green
