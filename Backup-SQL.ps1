# konfiguracija
$BackupPath = "\\Backup\Temp$"
$Log="BackupLog-$((Get-date).ToString("yyyyMMdd")).log"
$LogPath = "C:\Scripts\BackupSve\BackupLogs"
$LocalBackupPath = "E:\OS-Backup\Temp"
# $LocalBackupKomprimiraniPath = "E:\OS-Backup\Komprimirani35"

$User = "$(Get-Secret -Name Username -AsPlainText)"
$Password = "$(Get-Secret -Name Password -AsPlainText)" 

# fukcija za zapisivanje logova
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
# TODO fukncija Pokreni-Backup
function Pokreni-backup {
    param(
        [Parameter(Mandatory)]
        $Server
    )
    # TODO obrisi stari backup

    # pokreni novi backup
    try {
        Dodaj-log "Pokrenut backup servera $($server)"
        Invoke-Command -ComputerName $server -ErrorAction Stop -ScriptBlock {
            & 'WBADMIN' @('START', 'BACKUP', "-backuptarget:$($using:BackupPath)", '-include:F:', '-noVerify', '-quiet', "-user:$($using:User)","-password:$($Using:Password)")
        }
    } catch {
        Dodaj-log "ERROR: Pokretanje backupa nije uspjelo" -Severity Error
    }
}

# TODO inicijalizacija reporta i retry spiska

# TODO pokreni backup za prvi server

    # TODO provjeri status

    # TODO ako backup nije uspio dodaj u retry

# TODO pokreni backup za drugi server

# TODO ...

# TODO drugi prolaz, sko je server u retry listi ponovi backup

# TODO pošalji mail report
