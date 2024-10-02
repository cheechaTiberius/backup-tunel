<#
    .SYNOPSIS
    Pokreni Windows Server Backup job na odabranim serverima.
    .PARAMETER Computer
    Jedan ili više servera, odvojenih zarezom.
    .PARAMETER File
    File sa popisom servera, po jedan server u svakom redu.
    .PARAMETER Group
    AD Grupa sa serverima.
    .PARAMETER BackupPath
    Path za backup.
    .PARAMETER Log
    Ime log fajla. Default: BackupLog-yyyyMMdd.log
    .PARAMETER LogPath
    Path za log fajlove
    .PARAMETER LocalBackupPath
    Lokalni path za backupove, ista lokacija na kojoj je share.
    .PARAMETER LocalBackupKomprimiraniPath
    Lokalni path za komprimiranje backupova.
    .PARAMETER Credential
    Credential objekt - User/Pass sa pravima za wbadmin. Get-Credential za interaktivni upis
    .PARAMETER BezKomprimiranja
    Bez pokretanja komprimiranja
    .PARAMETER BezMaila
    Bez slanja maila
    .PARAMETER Vault
    wbadmin credentiali iz defaultnog vaulta, ignorira zadani credential objekt
    .EXAMPLE
    .\Pokreni-backup.ps1 -Computer server1,server2 -BackupPath \\bkp\system
    .EXAMPLE
    .\Pokreni-backup.ps1 -Computer Server -Credential (Get-Credential)
    .NOTES
    wbadmin parametri:
        wbadmin START BACKUP -backuptarget:$($using:BackupPath) -include:C: -exclude:c:\temp\* -allCritical -noVerify -quiet -user:$($using:User) -password:$($Using:Password)
    Potrebni podaci u Secret Vaultu:
        - Username
        - Password
        - E-MailUsername
        - E-MailPassword
        - E-MailServer
#>

[CmdletBinding()]
param (
    [Parameter(ParameterSetName="Computer", Mandatory)]
    $Computer,
    [Parameter(ParameterSetName="File", Mandatory)]
    $File,
    [Parameter(ParameterSetName="Group", Mandatory)]
    $Group,
    $BackupPath = "\\Backup\Temp$",
    $Log="BackupLog-$((Get-date).ToString("yyyyMMdd")).log",
    $LogPath = "C:\Scripts\BackupSve\BackupLogs",
    $LocalBackupPath = "E:\OS-Backup\Temp",
    $LocalBackupKomprimiraniPath = "E:\OS-Backup\Komprimirani35",
    [pscredential] $Credential,
    [switch] $BezKomprimiranja,
    [switch] $BezMaila,
    [switch] $Vault
)
function Dodaj-log {
    param (
        [Parameter(Mandatory)]
        $LogEntry,
        $Severity = "Info"
    )
    $Timestamp = "$((Get-Date).ToString("dd.MM.yyyy HH:mm:ss"))"

    switch ($Severity) {
        Warning {
            $Message = "$($Timestamp) - WARNING: $($LogEntry)"
            Write-Warning $LogEntry
        }
        Error {
            $Message = "$($Timestamp) - ERROR: $($LogEntry)"
            Write-Error $LogEntry
        }
        Default {
            $Message = "$($Timestamp) - $($LogEntry)"
            Write-Debug $LogEntry
        }
    }
    Add-Content -Path "$($LogPath)\$($Log)" $Message   
}
function Pokreni-backup {
    param(
        [Parameter(Mandatory)]
        $Server
    )
    # pokreni novi backup
    try {
        Dodaj-log "Pokrenut backup servera $($server)"
        Invoke-Command -ComputerName $server -ErrorAction Stop -ScriptBlock {
            & 'WBADMIN' @('START', 'BACKUP', "-backuptarget:$($using:BackupPath)", '-include:C:', '-exclude:c:\temp\*', '-allCritical', '-noVerify', '-quiet', "-user:$($using:User)","-password:$($Using:Password)")
        }
    } catch {
        Dodaj-log "ERROR: Pokretanje backupa nije uspjelo" -Severity Error
    }
}

Write-Debug "Log filename: $($Log)"
Write-Debug "Backup path $($BackupPath)"

# credentials
if ($Vault) {
    $User = "$(Get-Secret -Name Username -AsPlainText)"
    $Password = "$(Get-Secret -Name Password -AsPlainText)"    
} elseif ($Credential) {
    $User = $Credential.UserName
    $Password = [System.Net.NetworkCredential]::new("", $Credential.Password).Password    
} elseif (!$Credential -and !$Vault) {
    Write-Debug ("Nije naveden niti credential objekt niti vault")
    $Credential = Get-Credential
    $User = $Credential.UserName
    $Password = [System.Net.NetworkCredential]::new("", $Credential.Password).Password 
}

Dodaj-log "--------------------------------------------------------------------------------"

$serveri = @()
$OKServeri = @()
$RetryServeri = @()
$ErrorServeri = @()
$MailTable = "<tr> <th> Server </th> <th> Status </th> <th> Napomena </th> </tr>"

switch ($PSCmdlet.ParameterSetName) {
    Computer {
        Write-Debug "-Computer"
        $SviServeri = $Computer
    }
    File {
        Write-Debug "-File"
        $SviServeri = Get-Content -Path $File 
    }
    Group {
        $type = 'System.DirectoryServices.AccountManagement'
        Add-Type -AssemblyName $type -ErrorAction Stop
        $ct = [System.DirectoryServices.AccountManagement.ContextType]::Domain
        $grp = [System.DirectoryServices.AccountManagement.GroupPrincipal]::FindByIdentity($ct,$Group)
        if($grp){
            $SviServeri = $grp.GetMembers($false) | Select-Object -Property Name
        }
        else{
            Write-Warning "Could not find group '$Group'"
            break
        }
    }
}
$localName = $Env:COMPUTERNAME
$LocalServer = $null
$PopisServera="Popis servera:"
$SviServeri | ForEach-Object {
    if ("" -ne $_) {
        $PopisServera += " $($_)"
        # Provjeri je li localhost u popisu
        if ($_ -eq $localName) {
            Write-Debug "$_ je lokalni server"
            $LocalServer += $_
        } else {
            $serveri += $_
        }
    }
}
Dodaj-log $PopisServera
if ($LocalServer) {
    # obrisi stari backup
    $ServerBackupPath = "$($BackupPath)\WindowsImageBackup\$($LocalServer)"
    if (!(Get-item -Path $ServerBackupPath -ErrorAction SilentlyContinue)) {
        Dodaj-log "Stari backup ne postoji"
    } else {
        try {
            if("" -ne $LocalServer) {
                Remove-Item -Path $ServerBackupPath -Recurse -Force -ErrorAction Stop
                Dodaj-log "Obrisan $($ServerBackupPath)"
            }
        } catch {
            Dodaj-log "WARNING: Brisanje starog backupa nije uspjelo" -Severity Warning
        }
    }
    # pokreni lokalni backup
    Dodaj-log "Lokalni backup"
    try {
        & 'WBADMIN' @('START', 'BACKUP', "-backuptarget:$($BackupPath)", '-include:C:', '-exclude:c:\temp\*', '-allCritical', '-noVerify', '-quiet')
    } catch {
        Dodaj-log "WARNING: Pokretanje backupa nije uspjelo" -Severity Warning
    }
    
    Start-Sleep 10
    $result = Get-WBJob -Previous 1
    Dodaj-log "Status backupa: $($result.JobState)"
    if ($result.HResult -ne 0) {
        Dodaj-log "Backup error: $($result.ErrorDescription)" -Severity Warning
        Dodaj-log "Server $($LocalServer) dodan u retry, pricekaj 30 sekundi"
        Start-Sleep 30
        Dodaj-log "Pokreni retry lokalnog backupa"
        try {
            & 'WBADMIN' @('START', 'BACKUP', "-backuptarget:$($BackupPath)", '-include:C:', '-exclude:c:\temp\*', '-allCritical', '-noVerify', '-quiet')
        } catch {
            Dodaj-log "ERROR: Pokretanje backupa nije uspjelo" -Severity Error
        }
        Start-Sleep 10
        $result = Get-WBJob -Previous 1
        Dodaj-log "Status backupa: $($result.JobState)"
        if ($result.HResult -ne 0) {
            Dodaj-log "Backup error: $($result.ErrorDescription)" -Severity Error
            # dodaj server na error spisak
            $ErrorServeri += $LocalServer
            $MailTable += "<tr> <td> $($LocalServer) </td> <td> Error </td> <td></td></tr>" 
        } else {
            Dodaj-log "Backup zavrsen bez gresaka"
            $MailTable += "<tr> <td> $($LocalServer) </td> <td> OK </td> <td>(ponovljeno)</td></tr>"
            $OKServeri += $LocalServer
        }
    $result = Get-WBJob -Previous 1
    } else {
        Dodaj-log "Backup zavrsen bez gresaka"
        $MailTable += "<tr> <td> $($LocalServer) </td> <td> OK </td> </tr>"
        $OKServeri += $LocalServer
    }
}

$serveri | ForEach-Object {
    $server = $_
    Dodaj-log "Backup servera $($server)"

    # obrisi postojeci backup
    $ServerBackupPath = "$($BackupPath)\WindowsImageBackup\$($server)"
    if (!(Get-item -Path $ServerBackupPath -ErrorAction SilentlyContinue)) {
        Dodaj-log "Stari backup ne postoji"
    } else {
        try {
            if ("" -ne $server) {
                Remove-Item -Path $ServerBackupPath -Recurse -Force -ErrorAction Stop
                Dodaj-log "Obrisan $($ServerBackupPath)"                
            }
        } catch {
            Dodaj-log "WARNING: Brisanje starog backupa nije uspjelo" -Severity Warning
        }
    }

    # pokreni novi backup
    Pokreni-backup -Server $server

    # provjeri status nakon kraja
    # delay od 10 sekundi, wbadminu treba malo vremena da zapiše podatke o jobu. Ako bude problema produziti.
    Start-Sleep 10
    $result = Invoke-Command -ComputerName $server -ScriptBlock { Get-WBJob -Previous 1 }

    # zapisi u log
    Dodaj-log "Status backupa: $($result.JobState)"
    if ($result.HResult -ne 0) {
        Dodaj-log "Backup error: $($result.ErrorDescription)" -Severity Warning
        Dodaj-log "Server $($server) dodan u retry"
        # dodaj server na retry spisak
        $RetryServeri += $server
    } else {
        Dodaj-log "Backup zavrsen bez gresaka"
        $MailTable += "<tr> <td> $($server) </td> <td> OK </td> <td></td> </tr>"
        $OKServeri += $server
    }
}

# retry backup servera sa spiska
$RetryServeri | ForEach-Object {
    $server = $_
    Dodaj-log "`n## Ponovni pokusaj backupa servera koji nisu uspjeli iz prve ##"
    Pokreni-backup -Server $server
    Start-Sleep 10
    $result = Invoke-Command -ComputerName $server -ScriptBlock { Get-WBJob -Previous 1 }
    Dodaj-log "Status backupa: $($result.JobState)"
    if ($result.HResult -ne 0) {
        Dodaj-log "Backup error: $($result.ErrorDescription)" -Severity Error
        # dodaj server na error spisak
        $ErrorServeri += $server
        $MailTable += "<tr> <td> $($server) </td> <td> Error </td> </tr>" 
    } else {
        Dodaj-log "Backup zavrsen bez gresaka"
        $MailTable += "<tr> <td> $($server) </td> <td> OK </td> <td>(ponovljeno)</td> </tr>"
        $OKServeri += $server
    }
}
# pošalji mail izvjestaj
if (!$BezMaila) {
    $MailArgs = @{
        From = "$(Get-Secret -name E-MailUsername -AsPlainText)"
        To = 'tibor@laszlo.com.hr','dj@meridijana.hr','zeljko.medic@outlook.com'
        Subject = 'Tunel Ucka Backup'
        Body = "<HTML><BODY><TABLE> $($MailTable) </TABLE></BODY></HTML>"
        SmtpServer = "$(Get-Secret -name E-MailServer -AsPlainText)"
        Credential = New-Object System.Management.Automation.PSCredential ((Get-Secret -name E-MailUsername -AsPlainText),(Get-Secret -name E-MailPassword))
    }
    # $MailArgs
    try {
        Send-MailMessage @MailArgs -Port 587 -BodyAsHtml -ErrorAction Stop
    } catch {
        Dodaj-log "Mail obavijest nije poslana: $_" -Severity Warning
    }
}


# Pokreni arhiviranje za uspjesno backupirane servere
$MailTable = "<tr> <th> Server </th> <th> Status </th> </tr>"
if (!$BezKomprimiranja) {
    $OKServeri | ForEach-Object {
        $Server = $_
        $ArchiveRoot = "$($($LocalBackupKomprimiraniPath))\$($server)"
        $ArchiveDestination = "$($ArchiveRoot)\$((Get-date).ToString("yyyyMMdd")).zip"
        Dodaj-log "Komprimiram backup servera $($Server) u $($ArchiveDestination)"
        if (!(Get-Item -ErrorAction SilentlyContinue -Path "$($($LocalBackupKomprimiraniPath))\$($server)")) {
            New-Item -Path "$($($LocalBackupKomprimiraniPath))\$($server)" -ItemType Directory
        }
        try {
            & 'tar' @('-acf', "$($ArchiveDestination)", "-C", "$($LocalBackupPath)\WindowsImageBackup","$($Server)")
            Dodaj-log "backup komprimiran"
            $MailTable += "<tr> <td> $Server </td> <td> OK </td> </tr>"
        } catch {
            Dodaj-log "Komprimiranje backupa za $Server nije uspjelo" -Severity Warning
            $MailTable += "<tr> <td> $Server </td> <td> Error </td> </tr>"
        }

        $StareArhive = Get-ChildItem -Path $ArchiveRoot | Where-Object {$_.CreationTime -lt ((Get-Date).AddDays(-35))}
        $StareArhive | Remove-Item -Force
        
    }
    # posalji mail izvjestaj
    if (!$BezMaila) {
        $MailArgs.Subject = "Tunel Ucka komprimiranje backupa"
        $MailArgs.Body = "<HTML><BODY><TABLE> $($MailTable) </TABLE></BODY></HTML>"
        # $MailArgs
        try {
            Send-MailMessage @MailArgs -Port 587 -BodyAsHtml -ErrorAction Stop
        } catch {
            Dodaj-log "Mail obavijest nije poslana: $_" -Severity Warning
        }
    }

    # Pocisti logove starije od 40 dana
    Dodaj-log "Brisanje starih logova"
    try {
        $StariLogovi = Get-ChildItem -Path $LogPath | Where-Object {$_.CreationTime -lt ((Get-Date).AddDays(-40))}
        $StariLogovi | Remove-Item -Force -ErrorAction Stop
        Dodaj-log "Stari logovi uspjesno obrisani"
    } catch {
        Dodaj-log "ERROR: Stari logovi nisu obrisani: $($_)" -Severity Error
    }
}
