# Pohjapolku verkkolevylle
$baseFolder = "\\10.27.27.3\WritableFolder"

# Käyttäjän antama alikansion nimi
$subFolder = Read-Host -Prompt "Anna alikansion nimi, johon ajurit tallennetaan"

$destinationFolder = Join-Path -Path $baseFolder -ChildPath $subFolder

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
$logFile = "\\10.27.27.3\WritableFolder\logs\Tallennus_logfile.txt"

# Luo kohdekansio, jos sitä ei ole
if (-not (Test-Path -Path $destinationFolder)) {
    New-Item -ItemType Directory -Path $destinationFolder
    Write-Log -Message "Luotiin kohdekansio: $destinationFolder" -LogFile $logFile
} else {
    Write-Log -Message "Kohdekansio on jo olemassa: $destinationFolder" -LogFile $logFile
}

# Käytä DISM-komentoa ajurien vientiin
try {
    Write-Log -Message "Viedään ajureita kansioon: $destinationFolder" -LogFile $logFile

    # Suorita DISM-komento
    & dism /online /export-driver /destination:"$destinationFolder"

    if ($?) {
        Write-Log -Message "Ajurien vienti onnistui." -LogFile $logFile
    } else {
        Write-Log -Message "DISM-komennon suoritus epäonnistui." -LogFile $logFile
        throw "DISM-komennon suoritus epäonnistui."
    }
} catch {
    Write-Log -Message "Virhe ajurien viennissä: $_" -LogFile $logFile
    Write-Host "Virhe ajurien viennissä: $_"
}
