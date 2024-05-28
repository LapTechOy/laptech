function Write-Log {
    param (
        [string]$Message,
        [string]$LogFile
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "{0}: {1}" -f $timestamp, $Message
    $logEntry | Out-File -FilePath $LogFile -Append
    Write-Host $logEntry -ForegroundColor Cyan
}

function Initialize-LogFile {
    param (
        [string]$LogFilePath
    )
    if (-not (Test-Path -Path $LogFilePath)) {
        New-Item -Path $LogFilePath -ItemType File -Force
    }
}

function Mount-NetworkDrive {
    param (
        [string]$DriveName,
        [string]$NetworkPath,
        [string]$LogFile
    )
    $driveLetter = "${DriveName}:"
    $existingDrive = Get-PSDrive -Name $DriveName -ErrorAction SilentlyContinue

    if ($existingDrive) {
        Write-Log -Message "Verkkolevy ${DriveName} on jo liitetty" -LogFile $LogFile
    } else {
        try {
            Write-Log -Message "Liitetään verkkolevy ${DriveName}..." -LogFile $LogFile
            net use $driveLetter $NetworkPath /persistent:yes
            Start-Sleep -Seconds 2 # Odota 2 sekuntia, jotta asema ehtii liitetyksi
            if (Test-Path $driveLetter) {
                Write-Log -Message "Verkkolevy ${DriveName} yhdistetty onnistuneesti" -LogFile $LogFile
            } else {
                Write-Log -Message "Virhe: Asemaa ${DriveName} ei löydy liittämisen jälkeen." -LogFile $LogFile
                throw "Asemaa ${DriveName} ei löydy liittämisen jälkeen."
            }
        } catch {
            Write-Log -Message "Virhe yhdistettäessä asemaa ${DriveName}: $_" -LogFile $LogFile
            throw $_
        }
    }
}

function Ensure-Directory {
    param (
        [string]$DirectoryPath,
        [string]$LogFile
    )
    try {
        if (-not (Test-Path -Path $DirectoryPath)) {
            New-Item -Path $DirectoryPath -ItemType Directory -Force
            Write-Log -Message "Luotiin uusi kansio: ${DirectoryPath}" -LogFile $LogFile
        }
    } catch {
        Write-Log -Message "Virhe luodessa kansiota: $_" -LogFile $LogFile
        throw $_
    }
}

function Copy-Drivers {
    param (
        [string]$SourcePath,
        [string]$DestinationPath,
        [string]$LogFile
    )
    try {
        Copy-Item -Path "$SourcePath\*" -Destination $DestinationPath -Recurse -Force
        Write-Log -Message "Ajurit ja .cab-tiedostot kopioitu paikalliseen kansioon: ${DestinationPath}" -LogFile $LogFile
    } catch {
        Write-Log -Message "Virhe kopioitaessa tiedostoja: $_" -LogFile $LogFile
        throw $_
    }
}

function Expand-CabFiles {
    param (
        [string]$DriversPath,
        [string]$LogFile
    )
    try {
        $cabFiles = Get-ChildItem -Path $DriversPath -Filter *.cab -Recurse
        if ($cabFiles.Count -gt 0) {
            foreach ($cab in $cabFiles) {
                try {
                    & expand.exe $cab.FullName -F:* $DriversPath
                    Write-Log -Message "Purkamisyritys onnistui: $($cab.FullName)" -LogFile $LogFile
                } catch {
                    Write-Log -Message "Virhe purkaessa tiedostoa: $($cab.FullName) - $_" -LogFile $LogFile
                }
            }
        } else {
            Write-Log -Message ".cab-tiedostoja ei löytynyt" -LogFile $LogFile
        }
    } catch {
        Write-Log -Message "Virhe purettaessa .cab tiedostoja: $_" -LogFile $LogFile
        throw $_
    }
}

function Install-Drivers {
    param (
        [string]$DriversPath,
        [string]$LogFile
    )
    try {
        $infFiles = Get-ChildItem -Path $DriversPath -Filter *.inf -Recurse
        foreach ($inf in $infFiles) {
            $installed = $false
            for ($i = 1; $i -le 2; $i++) {
                if ($installed -eq $false) {
                    try {
                        Start-Process pnputil -ArgumentList "/add-driver `"$($inf.FullName)`" /install" -NoNewWindow -Wait
                        Write-Log -Message "Ajuri asennettu: $($inf.FullName)" -LogFile $LogFile
                        $installed = $true
                    } catch {
                        Write-Log -Message "Virhe asennettaessa ajuria (yritys $i): $($inf.FullName) - $_" -LogFile $LogFile
                        if ($i -eq 2) {
                            Write-Log -Message "Ajurin asennus epäonnistui kahdesti: $($inf.FullName)" -LogFile $LogFile
                        }
                    }
                }
            }
        }
    } catch {
        Write-Log -Message "Virhe ajurien asennuksessa: $_" -LogFile $LogFile
        throw $_
    }
}

# Aloita
$logFile = "C:\Windows\Web\Wallpaper\laptech\logfile.txt"
$networkPath = "\\10.27.27.3\WritableFolder"
$localFolder = "C:\Windows\Web\Wallpaper\laptech"
$driveName = "Z"

Initialize-LogFile -LogFilePath $logFile

Mount-NetworkDrive -DriveName $driveName -NetworkPath $networkPath -LogFile $logFile

Write-Host "Yhdistetään verkkolevyn kansioon: " -ForegroundColor Green

# Listaa kaikki kansiot verkkolevyltä
Write-Host "Löytyneet kansiot kohteesta:" -ForegroundColor Yellow
$sourceFolders = Get-ChildItem -Path $networkPath -Directory -ErrorAction SilentlyContinue

# Tulosta kansiot kahden per rivi
$counter = 0
foreach ($folder in $sourceFolders) {
    $folderName = $folder.Name
    if ($folderName.StartsWith('.')) {
        continue
    }
    Write-Host "$folderName" -NoNewline -ForegroundColor Magenta
    $counter++
    if ($counter -eq 2) {
        Write-Host ""
        $counter = 0
    } else {
        Write-Host " | " -NoNewline -ForegroundColor DarkGray
    }
}
if ($counter -ne 0) {
    Write-Host ""
}

# Käyttäjän antama alikansion nimi
$subFolder = Read-Host -Prompt "Anna alikansion nimi, josta ajurit ladataan"
$sourceFolder = Join-Path -Path $networkPath -ChildPath $subFolder

# Varmista, että alikansio on olemassa
if (-not (Test-Path -Path $sourceFolder)) {
    Write-Log -Message "Virhe: Alikansiota ei löydy - $subFolder" -LogFile $logFile
    throw "Alikansiota ei löydy: $subFolder"
}
Write-Log -Message "Valittu alikansion nimi: $subFolder" -LogFile $logFile

Ensure-Directory -DirectoryPath $localFolder -LogFile $logFile

Copy-Drivers -SourcePath $sourceFolder -DestinationPath $localFolder -LogFile $logFile

# Purkaa .cab tiedostot (jos löytyy) ja asenna ajurit
try {
    Expand-CabFiles -DriversPath $localFolder -LogFile $logFile
    Install-Drivers -DriversPath $localFolder -LogFile $logFile
} catch {
    Write-Log -Message "Virhe ajurien purkamisessa ja asennuksessa: $_" -LogFile $logFile
    exit
}

Write-Log -Message "Ajurien asennusyritykset valmiita." -LogFile $logFile
