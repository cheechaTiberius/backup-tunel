Install the modules:
$> Install-Module -Name Microsoft.PowerShell.SecretManagement, Microsoft.PowerShell.SecretStore -Repository PSGallery

Register the vault
$> Register-SecretVault -Name your-datastore -ModuleName Microsoft.PowerShell.SecretStore -DefaultVault

Check 'your-datastore' vault
$> Get-SecretVault

Create a master password to access your 'your-datastore' Vault
$> Get-SecretStoreConfiguration

Change the configuration of the store (this will disable the password prompt)
$> Set-SecretStoreConfiguration -Authentication None -Interaction None

Create a secret
$> Set-Secret -Vault your-datastore -Name your-secret -Secret "your-secret-string"

Get the secret value
$> Get-Secret -Vault your-datastore -Name your-secret -AsPlainText