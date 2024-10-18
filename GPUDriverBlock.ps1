function Test-AdminRights {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}


# Perus Hardware ID:t ja yhteensopivat ID:t, jotta päästään edes alkuun.
function Get-DeviceHardwareIDs {
    param (
        [Parameter(Mandatory = $true)]
        [string]$DevicePath,

        [Parameter(Mandatory = $false)]
        [switch]$IncludeGenericIDs
    )

    $hardwareIDs = @()

    try {
        $device = Get-PnpDevice | Where-Object { $_.InstanceId -eq $DevicePath }

        if ($device) {
            Write-Verbose "Hae perus Hardware ID:t laitteelle: $DevicePath"
            # Perus hardware ID:t
            $hardwareIDs += $device.HardwareID
            $hardwareIDs += $device.CompatibleID

            if ($IncludeGenericIDs.IsPresent) {
                Write-Verbose "Muodostetaan geneeriset ID:t laitteelle: $DevicePath"
                $pnpId = $device.InstanceId

                # Tarkempi regex joka tukee eri PNPDeviceID-formaatteja. Koska laitteet ovat tunnetusti yhdenmukaisia ja aina helposti tunnistettavia....
                switch -Regex ($pnpId) {
                    # PCI laitteet
                    '^PCI\\VEN_([0-9A-F]{4})&DEV_([0-9A-F]{4})' {
                        $hardwareIDs += "PCI\VEN_$($matches[1])*"
                        $hardwareIDs += "PCI\VEN_$($matches[1])&DEV_$($matches[2])*"
                    }

                    # USB laitteet 
                    '^USB\\VID_([0-9A-F]{4})&PID_([0-9A-F]{4})' {
                        $hardwareIDs += "USB\VID_$($matches[1])*"
                        $hardwareIDs += "USB\VID_$($matches[1])&PID_$($matches[2])*"
                    }

                    # ACPI laitteet (legacy?)
                    '^ACPI\\([A-Za-z0-9_]+)\\([A-Za-z0-9_]+)' {
                        $hardwareIDs += "ACPI\$($matches[1])*"
                    }

                    # Muut laitteet (varmuudeksi)
                    default {
                        if ($pnpId -match '^([^\\]+)\\([^\\]+)') {
                            $hardwareIDs += "$($matches[1])\*"
                        }
                    }
                }
            }
        }
        else {
            Write-Warning "Laitetta ei löytynyt polusta: $DevicePath"
        }
    }
    catch {
        Write-Warning "Virhe hardware ID:iden haussa: $_"
        throw
    }

    return ($hardwareIDs | Where-Object { $_ } | Select-Object -Unique)
}

# Pääskripti
try {
    Write-Verbose "Tarkistetaan järjestelmänvalvojan oikeudet..."
    if (-not (Test-AdminRights)) {
        Write-Verbose "Järjestelmänvalvojan oikeuksia ei löytynyt. Keskeytetään skripti."
        throw "Tämä skripti vaatii järjestelmänvalvojan oikeudet!"
    }
    Write-Verbose "Järjestelmänvalvojan oikeudet löytyivät. Jatketaan."

    Write-Verbose "Haetaan näytönohjaimia..."
    $adapters = Get-CimInstance Win32_VideoController -ErrorAction Stop
    if (-not $adapters) {
        Write-Verbose "Näytönohjaimia ei löytynyt."
        throw "Näytönohjaimia ei löytynyt"
    }
    Write-Verbose "$($adapters.Count) näytönohjainta löytyi."

    $blockDevicesKey = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeviceInstall\Restrictions"

    Write-Verbose "Tarkistetaan, onko rekisteripolkua olemassa: $blockDevicesKey"
    if (-not (Test-Path $blockDevicesKey)) {
        Write-Verbose "Rekisteripolkua ei löytynyt. Luodaan uusi polku."
        try {
            $parentPath = Split-Path $blockDevicesKey
            if (-not (Test-Path $parentPath)) {
                Write-Verbose "Luodaan parent-polku: $parentPath"
                New-Item -Path $parentPath -Force | Out-Null
            }
            New-Item -Path $blockDevicesKey -Force | Out-Null
            Write-Verbose "Rekisteripolku luotu: $blockDevicesKey"
        }
        catch {
            Write-Verbose "Virhe rekisteripolun luonnissa: $_"
            throw "Virhe rekisteripolun luonnissa: $_"
        }
    }
    else {
        Write-Verbose "Rekisteripolku löytyy jo: $blockDevicesKey"
    }

    # Asetetaan yleiset estokäytännöt rekisterissä
    # Tarvitaan tämä if-else-hirviö, koska rajoitukset... 

    if (-not (Get-ItemProperty -Path $blockDevicesKey -Name "DenyDeviceIDs" -ErrorAction SilentlyContinue)) {
        New-ItemProperty -Path $blockDevicesKey -Name "DenyDeviceIDs" -Value 1 -PropertyType DWord -Force | Out-Null
    } else {
        Set-ItemProperty -Path $blockDevicesKey -Name "DenyDeviceIDs" -Value 1
    }

    if (-not (Get-ItemProperty -Path $blockDevicesKey -Name "DenyDeviceIDsRetroactive" -ErrorAction SilentlyContinue)) {
        New-ItemProperty -Path $blockDevicesKey -Name "DenyDeviceIDsRetroactive" -Value 1 -PropertyType DWord -Force | Out-Null
    } else {
        Set-ItemProperty -Path $blockDevicesKey -Name "DenyDeviceIDsRetroactive" -Value 1
    }

    Write-Verbose "Poistetaan vanhat laiteajurirajoitukset rekisteristä..."
    try {
        $existingRestrictions = Get-ChildItem -Path $blockDevicesKey -ErrorAction Stop |
            Where-Object { $_.PSChildName -match "DenyDeviceID_\d+" }

        if ($existingRestrictions) {
            foreach ($restriction in $existingRestrictions) {
                Write-Verbose "Poistetaan rajoitus: $($restriction.PSChildName)"
                try {
                    Remove-Item -Path $restriction.PSPath -Force -ErrorAction Stop
                    Write-Verbose "Rajoitus $($restriction.PSChildName) poistettu onnistuneesti."
                }
                catch {
                    Write-Warning "Virhe poistettaessa rajoitusta $($restriction.PSChildName): $_"
                }
            }
        }
        else {
            Write-Verbose "Ei vanhoja rajoituksia löydetty."
        }
    }
    catch {
        Write-Warning "Virhe vanhojen rajoitusten käsittelyssä: $_"
        throw
    }

    # Luo lista estetyistä ID:istä
    $allBlockedIDs = @()
    $i = 1

    foreach ($adapter in $adapters) {
        Write-Host "`nKäsitellään adapteria: $($adapter.Name)"
        Write-Verbose "Haetaan hardware ID:t laitteelle: $($adapter.PNPDeviceID)"

        $hardwareIDs = Get-DeviceHardwareIDs -DevicePath $adapter.PNPDeviceID -Verbose:$VerbosePreference

        if (-not $hardwareIDs) {
            Write-Verbose "Ei hardware ID:itä löytynyt laitteelle: $($adapter.Name)"
            continue
        }

        Write-Verbose "Löydettiin $($hardwareIDs.Count) hardware ID:tä laitteelle: $($adapter.Name)"

        foreach ($hwid in $hardwareIDs) {
            if ([string]::IsNullOrWhiteSpace($hwid)) {
                Write-Verbose "Ohitetaan tyhjä tai null hardware ID."
                continue
            }

            if ($allBlockedIDs -contains $hwid) {
                Write-Verbose "Hardware ID $hwid on jo estetty. Ohitetaan."
                continue
            }

            Write-Verbose "Lisätään hardware ID: $hwid estettyjen listalle."
            $allBlockedIDs += $hwid
            $keyName = "DenyDeviceID_$i"
            $keyPath = Join-Path $blockDevicesKey $keyName

            Write-Verbose "Lisätään rekisteriavain $keyName estämään laite ID: $hwid"
            try {
                New-Item -Path $blockDevicesKey -Name $keyName -Force | Out-Null

                New-ItemProperty -Path $keyPath -Name "DeviceID" -Value $hwid -PropertyType String -Force | Out-Null
                New-ItemProperty -Path $keyPath -Name "DenyInstall" -Value 1 -PropertyType DWord -Force | Out-Null

                Write-Verbose "Rekisteriavain $keyName lisätty onnistuneesti laitteelle $hwid"
                $i++
            }
            catch {
                # Jotain meni pieleen, koska miksi tämä menisi koskaan sujuvasti?
                Write-Warning "Virhe ID:n $hwid lisäyksessä: $_. No, tämä ei mennyt suunnitelmien mukaan."
                throw
            }
        }
    }

    # Lokitus temppi-kansioon
    Write-Verbose "Luodaan lokitiedosto, johon kirjataan estettyjen laitteiden ID:t..."
    $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm"
    $logFolder = Join-Path $env:TEMP "GPUDriverRestrictions"
    $logPath = Join-Path $logFolder "gpu_restrictions_$timestamp.log"

    if (-not (Test-Path $logFolder)) {
        Write-Verbose "Lokikansio ei löydy. Luodaan lokikansio: $logFolder"
        New-Item -ItemType Directory -Path $logFolder -Force | Out-Null
    }
    else {
        Write-Verbose "Lokikansio löytyy: $logFolder"
    }

    "GPU Ajurien estolistaus - $timestamp" | Out-File $logPath
    Write-Verbose "Lokiin kirjataan estetyt hardware ID:t..."
    foreach ($id in $allBlockedIDs) {
        "Estetty ID: $id" | Out-File $logPath -Append
        Write-Verbose "Estetty ID kirjattu: $id"
    }

    Write-Host "`nKaikki näytönohjainajurit ja niiden variantit estetty."
    Write-Host "Loki tallennettu: $logPath"
}
catch {
    Write-Error "Kriittinen virhe: $_"
    exit 1
}
