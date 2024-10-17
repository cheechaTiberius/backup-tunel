# konfiguracija
$BackupPath = "\\Backup\Temp$"
$Log="BackupLog-$((Get-date).ToString("yyyyMMdd")).log"
$LogPath = "C:\Scripts\BackupSve\BackupLogs"
$LocalBackupPath = "E:\OS-Backup\Temp"
$LocalBackupKomprimiraniPath = "E:\OS-Backup\Komprimirani35"

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

# TODO inicijalizacija reporta

# TODO pokreni backup za prvi server

# TODO pokreni backup za drugi server

# TODO ...

# TODO pošalji mail report
