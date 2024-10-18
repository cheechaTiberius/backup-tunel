# TODO dodati HTML redove u report

# konfiguracija
$BackupPath = "\\Backup\Temp$"
$Log="SQLBackupLog-$((Get-date).ToString("yyyyMMdd")).log"
$LogPath = "C:\Scripts\BackupSQL\BackupLogs"
$LocalBackupPath = "E:\OS-Backup\Temp"

$User = "$(Get-Secret -Name Username -AsPlainText)"
$Password = "$(Get-Secret -Name Password -AsPlainText)" 

$MailTable = "<tr> <th> Server </th> <th> Status </th> <th> Napomena </th> </tr>"

$Serveri = @(
    "TestServer1"
    "TestServer2"
)

# ============================================

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
    # obrisi stari backup ako postoji i nije root
    $ServerBackupPath = "$($BackupPath)\WindowsImageBackup\$($Server)"
    if(($ServerBackupPath -ne "$($BackupPath)\WindowsImageBackup\") -and ($ServerBackupPath)) {
        Remove-Item -Path $ServerBackupPath -Recurse -Force -WhatIf
        Dodaj-log "Obrisan $($ServerBackupPath)"
    }
    # pokreni novi backup
    try {
        Dodaj-log "Pokrenut backup servera $($Server)"
        Invoke-Command -ComputerName $Server -ErrorAction Stop -ScriptBlock {
            & 'WBADMIN' @('START', 'BACKUP', "-backuptarget:$($using:BackupPath)", '-include:F:', '-noVerify', '-quiet', "-user:$($using:User)","-password:$($Using:Password)")
        }
    } catch {
        Dodaj-log "Pokretanje backupa nije uspjelo" -Severity Error
    }
}
function Provjeri-Backup {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        $Server
    )
    try {
        $output = Invoke-Command -ComputerName $Server -ErrorAction Stop -ScriptBlock {
            Get-WBJob -Previous 1
        }
        Dodaj-log -LogEntry "Status posljednjeg backupa: $($output.JobState)"
    } catch {
        Dodaj-log -LogEntry "Nije moguće provjeriti status prethodnog backupa" -Severity Error
    }
    # provjeri status nakon zavrsetka
    if ($output.HResult -ne 0) {
        # $retry += 'TestServer1'
        Dodaj-log -LogEntry "Backup $($Server) nije uspio" -Severity Warning
    } else {
        Dodaj-log -LogEntry "Backup $($Server) uspio"
    }
    return $output.HResult
}

# pokreni prvi backup
$Serveri | ForEach-Object {
    Pokreni-backup -Server $_
}

# pokreni provjeru i drugi backup ako je potrebno
$Serveri | ForEach-Object {
    $BackupResult = Provjeri-Backup -Server $_
    if ($BackupResult -eq 0) {
        Dodaj-log -LogEntry "Backup $($_) uspio"
        $MailTable += "<tr> <td> $($_) </td> <td> OK </td> <td></td> </tr>"
    } else {
        Dodaj-log -LogEntry "Backup $($_) nije uspio" -Severity Warning
        Pokreni-backup -Server $_
        Start-Sleep 15
        $BackupResult = Provjeri-Backup -Server $_
        if ($BackupResult -eq 0) {
            Dodaj-log -LogEntry "Ponovljeni backup $($_) uspio"
            $MailTable += "<tr> <td> $($_) </td> <td> OK </td> <td>(ponovljeno)</td> </tr>"
        } else {
            Dodaj-log -LogEntry "Ponovljeni backup $($_) nije uspio" -Severity Error
            $MailTable += "<tr> <td> $($_) </td> <td> Error </td> </tr>" 
        }
    }
}

# pošalji mail report
$MailArgs = @{
    From = "$(Get-Secret -name E-MailUsername -AsPlainText)"
    To = 'tibor@laszlo.com.hr','dj@meridijana.hr','zeljko.medic@outlook.com'
    Subject = 'Tunel Ucka SQL Backup'
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