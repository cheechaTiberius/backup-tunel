# wbadmin backup skripta

## 1. Što
Pokreće Windows Server Backup na odabranim serverima. Nakon uspješnog backupa arhivira backup u zip, i briše arhivirane zipove starije od 35 dana.

## 2. Kako
```
.\Pokreni-backup.ps1 [-Computer | -File | -Group] [-BackupPath] [-Log] [-LocalBackupPath] [-LocalBackupArchivePath] [-User] [-Password]
```
#### Parametri
    ```
    -Computer : jedan ili više servera, odvojeno zarezom
    -File : path do popisa servera u .txt fajlu, po jedan u svakom redu
    -Group : AD Grupa koja sadrži servere
    -BackupPath : path za BackupTarget. Default: \\Backup\Temp$
    -Log : Filename za log. Default: BackupLog-YYYYMMDD.log
    -LocalBackupPath : Lokalni path na kojem su backupovi. Default: E:\OS-Backup\Temp
    -LocalBackupArchivePath : lokalni path za arhive backupa. Default: E:\OS-Backup
    -User : user za wbadmin. Default: Secret s imenom Username iz default vaulta
    -Password: pass za wbadmin. Default: Secret s imenom Password iz default vaulta
    ```
Sve default vrijednosti su definirane u param() bloku na početku skripte.

## 3. Detalji
Potrebno je odabrati ili File, ili Computer, ili Group.
Nakon što se kreira popis servera, koraci su:
1. Obrisati postojeći backup tog servera (ako postoji)
2. Pokrenuti novi backup job
3. Nakon što job završi, provjeriti status nakon završetka
4. Ako je backup job bio bez grešaka, pokrenuti arhiviranje
5. Obrisati arhive starije od 35 dana, ako ih ima

## 4. Username/Password
Da bi se mogao koristiti Vault za passworde, treba kreirati Vault ZA USERA POD KOJIM ČE SE VRTITI BACKUP:

1. instalirati powershell modul
    ```
    Install-Module -Name Microsoft.PowerShell.SecretManagement, Microsoft.PowerShell.SecretStore -Repository PSGallery
    ````
2. Registrirati novi Vault
    ```
    Register-SecretVault -Name your-datastore -ModuleName Microsoft.PowerShell.SecretStore -DefaultVault
    ```
3.  Kreirati master password za Vault
    ```
    Get-SecretStoreConfiguration
    ```
4. Ugasiti autentikaciju za Vault
    ```
    Set-SecretStoreConfiguration -Authentication None -Interaction None
    ```
5. dodati podatke
    ```
    Set-Secret -Name Username -Secret 'username'
    Set-Secret -Name Password -Secret 'password'
    Set-Secret -Name E-MailUsername -Secret 'password'
    Set-Secret -Name E-MailPassword -Secret 'password'
    Set-Secret -Name E-MailServer -Secret 'password'
    ```
Lista želja:
- [x] Podesiti tar da ne sprema cijelu putanju
- [x] switch za gašenje arhiviranja
- [x] Maknut mandatory za BackupPath
- [x] dodati red u log da označimo gdje počinje retry
- [x] dodat mail obavijesti za arhiviranje
- [ ] promijeniti parametre za mail
- [x] složiti posebni backup za lokalni stroj
- [x] maknuti WindowsImageBackup iz parametara
- [x] staviti zipove u podfolder
- [x] dodano brisanje starih backup logova
- [x] dodan Path za logove
- [x] dodati bilješku za retry backupa
- [x] dodati opciju izvršavanja bez slanja maila