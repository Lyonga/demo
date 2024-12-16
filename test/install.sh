<powershell>
<# Fetch Secrets from secret manager#>
$ad_secret_id = "${secret}"
$ad_domain = "hs.mdmgr.net"
$secret_manager = Get-SECSecretValue -SecretId $ad_secret_id
$ad_secret  = $secret_manager.SecretString | ConvertFrom-Json
<# Set Credentials #>
$username   = $ad_secret.username
$password   = $ad_secret.password | ConvertTo-SecureString -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($username, $password)
<# Join AD Domain #>
Add-Computer -DomainName $ad_domain -Credential $credential -OUPath "OU=VTS,OU=Production Critical,OU=Infrastructure Engineering,DC=hs,DC=mdmgr,DC=net" -restart -force -verbos
</powershell>
