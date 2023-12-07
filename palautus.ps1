function Write-Log {
    param (
        [string]$Message,
        [string]$LogFile
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "{0}: {1}" -f $timestamp, $Message
    $logEntry | Out-File -FilePath $LogFile -Append
}


# Initialize log file
$logFile = "Z:\logs\logfile.txt"

# Pohjapolku verkkolevylle
$networkPath = "\\10.27.27.3\WritableFolder"

# Määritä verkkolevy asemaksi Z:
try {
    New-PSDrive -Name "Z" -PSProvider FileSystem -Root $networkPath -Persist
} catch {
    Write-Log -Message "Virhe yhdistettäessä asemaa Z: - $_" -LogFile $logFile
    exit
}

# Käyttäjän antama alikansion nimi
$subFolder = Read-Host -Prompt "Anna alikansion nimi, josta ajurit ladataan"

# Yhdistetään polut
$sourceFolder = Join-Path -Path "Z:\" -ChildPath $subFolder

# Paikallisen kansion polku
$localFolder = "C:\Windows\Web\Wallpaper\laptech"

# Tarkista, onko paikallinen kansio olemassa, ja luo se tarvittaessa
try {
    if (-not (Test-Path -Path $localFolder)) {
        New-Item -Path $localFolder -ItemType Directory -Force
        Write-Log -Message "Luotiin uusi kansio: $localFolder" -LogFile $logFile
    }
} catch {
    Write-Log -Message "Virhe luodessa kansiota: $_" -LogFile $logFile
    exit
}

# Kopioi ajurit paikalliseen kansioon
try {
    $allFoldersExist = $true
    $sourceFolders = Get-ChildItem -Path $sourceFolder -Directory -Recurse
    foreach ($folder in $sourceFolders) {
        $localEquivalent = Join-Path -Path $localFolder -ChildPath $folder.FullName.Substring($sourceFolder.Length)
        if (-not (Test-Path -Path $localEquivalent)) {
            $allFoldersExist = $false
            break
        }
    }

    if (-not $allFoldersExist) {
        Copy-Item -Path "$sourceFolder\*" -Destination $localFolder -Recurse -Force
        Write-Log -Message "Ajurit kopioitu paikalliseen kansioon: $localFolder" -LogFile $logFile
    } else {
        Write-Log -Message "Kaikki kansiot ovat jo paikallisessa kansiossa, kopioimista ei tarvita." -LogFile $logFile
    }
} catch {
    Write-Log -Message "Virhe kopioitaessa ajureita: $_" -LogFile $logFile
    exit
}


# Toistojen määrä
$attempts = 3

for ($i = 0; $i -lt $attempts; $i++) {
    Write-Log -Message "Asennusyritys $(($i+1))/$attempts" -LogFile $logFile

    # Hae kaikki .inf-tiedostot paikallisesta kansiosta
    $driverFiles = Get-ChildItem -Path $localFolder -Filter *.inf -Recurse

    foreach ($driver in $driverFiles) {
        try {
            # Asenna ajuri käyttäen pnputil-komentoa
            $installCommand = "pnputil /add-driver `"$($driver.FullName)`" /install"
            Invoke-Expression -Command $installCommand
            Write-Log -Message "Ajuri asennettu: $($driver.FullName)" -LogFile $logFile
        } catch {
            Write-Log -Message "Virhe asennettaessa ajuria: $($driver.FullName) - $_" -LogFile $logFile
        }
    }

    # Odota 5 sekunttia ennen seuraavaa yritystä
    if ($i -lt $attempts - 1) {
        Start-Sleep -Seconds 3
    }
}

Write-Log -Message "Ajurien asennusyritykset valmiita." -LogFile $logFile

