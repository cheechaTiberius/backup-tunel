$BackupPath = "E:\temp\"

$ServerBackupPath = Get-ChildItem -Path "$($BackupPath)\WindowsImageBackup\"
$ServerBackupPath | ForEach-Object {
    Remove-Item -Path $_ -Recurse -Force -WhatIf
    # Dodaj-log "Obrisan $($_)"
}