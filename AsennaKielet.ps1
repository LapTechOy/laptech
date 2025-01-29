# =========================================
# 🎨 Windows 11 - Automaattinen kieliasennus (FOD)
# 🔧 Suorita skripti ja lisää sen jälkeen tarvittavat kielet Windowsin asetuksista yksitellen valitsemalla "Lisää kieli" ja käynnistä tietokone uudelleen.
# 
#  
#  🔗 : iwr https://raw.githubusercontent.com/LapTechOy/laptech/main/AsennaKielet.ps1 | iex
# 
#=========================================

# 🎨 Värikoodit
$verde = [char]27 + "[32m"  # 🟢 Vihreä
$punainen = [char]27 + "[31m"  # 🔴 Punainen
$sininen = [char]27 + "[34m"  # 🔵 Sininen
$reset = [char]27 + "[0m"  # 🔄 Reset

# 🔹 Dynaaminen Progress Bar
function Show-Progress {
    param (
        [int]$currentStep,
        [int]$totalSteps
    )
    
    $progressWidth = 30  # Progress-barin pituus
    $percentComplete = [math]::Round(($currentStep / $totalSteps) * 100)
    $filledLength = [math]::Round($progressWidth * ($currentStep / $totalSteps))
    $bar = "█" * $filledLength + "-" * ($progressWidth - $filledLength)

    # Värikoodaus edistymisen mukaan
    if ($percentComplete -lt 30) {
        $color = [char]27 + "[31m"  # 🔴 Punainen
    } elseif ($percentComplete -lt 70) {
        $color = [char]27 + "[33m"  # 🟡 Keltainen
    } else {
        $color = [char]27 + "[32m"  # 🟢 Vihreä
    }

    Write-Host -NoNewline "`r${color}⏳ [$bar] $percentComplete% Completed${reset}"
    
    if ($currentStep -eq $totalSteps) {
        Write-Host "`n${verde}✅ Kaikki tehtävät suoritettu!${reset}`n"
    }
}

Write-Host "${verde}🚀 Aloitetaan kieliasennus ja optimointi!${reset}`n"

# 🔹 Lasketaan kokonaisvaiheet progress baria varten
$kielilista = @("fi-FI", "en-US", "en-GB", "sv-SE")
$totalSteps = 2 + ($kielilista.Count * 2) + 2  # Lisätty CBS-puhdistus
$currentStep = 0

# 🔹 1. Poistetaan automaattinen kielisiivous
$currentStep++
Show-Progress -currentStep $currentStep -totalSteps $totalSteps
Write-Host "${sininen}🧹 Poistetaan kielisiivous...${reset}"
try {
    Disable-ScheduledTask -TaskPath "\Microsoft\Windows\MUI\" -TaskName "LPRemove" -ErrorAction SilentlyContinue
    Disable-ScheduledTask -TaskPath "\Microsoft\Windows\LanguageComponentsInstaller" -TaskName "Uninstallation" -ErrorAction SilentlyContinue
    Write-Host "${verde}✅ Kielisiivous poistettu.${reset}"
} catch {
    Write-Host "${punainen}⚠️ Varoitus: Kielisiivouksen poistaminen ei onnistunut.${reset}"
}

# 🔹 2. Poistetaan turhat Appx-paketit
$currentStep++
Show-Progress -currentStep $currentStep -totalSteps $totalSteps
Write-Host "${sininen}🗑 Poistetaan tarpeettomat Appx-paketit...${reset}"
$turhatAppxPaketit = @(
    "Microsoft.OneDriveSync",
    "Microsoft.WindowsFeedbackHub",
    "Microsoft.MicrosoftSolitaireCollection",
    "Microsoft.XboxApp",
    "Microsoft.YourPhone"
)

foreach ($paketti in $turhatAppxPaketit) {
    try {
        Get-AppxPackage -AllUsers | Where-Object { $_.Name -match $paketti } | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
        Write-Host "${verde}✅ Poistettu: $paketti${reset}"
    } catch {
        Write-Host "${punainen}⚠️ Varoitus: Ei voitu poistaa $paketti.${reset}"
    }
}

# 🔹 3. Asennetaan kielet (FOD)
foreach ($kieli in $kielilista) {
    $currentStep++
    Show-Progress -currentStep $currentStep -totalSteps $totalSteps
    Write-Host "`n${sininen}🛠 Asennetaan kieli: $kieli...${reset}"
    
    try {
        Install-Language $kieli -CopyToSettings -ErrorAction Stop
        Write-Host "${verde}✅ Asennettu: $kieli${reset}"
    } catch {
        Write-Host "${punainen}⚠️ Varoitus: Ei voitu asentaa kieltä $kieli.${reset}"
    }
}

# 🔹 4. Pakotetaan Windows rekisteröimään kielet oikein OOBE:ssa
$currentStep++
Show-Progress -currentStep $currentStep -totalSteps $totalSteps
Write-Host "${sininen}🔧 Pakotetaan Windows rekisteröimään kielet...${reset}"
try {
    reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\MUI\UILanguages" /v Installed /t REG_MULTI_SZ /d "fi-FI\0en-US\0en-GB\0sv-SE" /f
    reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\OOBE" /v "SystemPreferredUILanguages" /t REG_MULTI_SZ /d "fi-FI\0en-US\0en-GB\0sv-SE" /f
    Write-Host "${verde}✅ Kielet rekisteröity!${reset}"
} catch {
    Write-Host "${punainen}⚠️ Varoitus: Kieliä ei voitu rekisteröidä.${reset}"
}

# 🔹 5. Puhdistetaan CBS Store & Windows Update
$currentStep++
Show-Progress -currentStep $currentStep -totalSteps $totalSteps
Write-Host "${sininen}🧹 Puhdistetaan Windows Update -välimuisti...${reset}"
try {
    Stop-Service wuauserv -Force -ErrorAction SilentlyContinue
    Stop-Service cryptsvc -Force -ErrorAction SilentlyContinue
    Stop-Service bits -Force -ErrorAction SilentlyContinue
    Stop-Service msiserver -Force -ErrorAction SilentlyContinue

    Remove-Item -Path "C:\Windows\SoftwareDistribution\Download\*" -Force -Recurse -ErrorAction SilentlyContinue
    Remove-Item -Path "C:\Windows\System32\catroot2\*" -Force -Recurse -ErrorAction SilentlyContinue

    Start-Service wuauserv
    Start-Service cryptsvc
    Start-Service bits
    Start-Service msiserver

    Write-Host "${verde}✅ Windows Update -välimuisti tyhjennetty!${reset}"
} catch {
    Write-Host "${punainen}⚠️ Varoitus: CBS Store & Windows Update -puhdistus epäonnistui.${reset}"
}

Write-Host "`n${verde}🎉 Kaikki valmista! Käynnistä Windows uudelleen ja testaa OOBE.${reset} 🚀`n"
