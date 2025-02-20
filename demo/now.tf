
####################non aws cli option with SDK
resource "aws_ssm_document" "install_agents_sdk" {
  name          = local.non_cli_windows_ssm
  document_type = "Automation"
  tags          = local.default_tags
  content = jsonencode({
    schemaVersion = "0.3"
    assumeRole    = var.assume_role_arn
    description   = "Install security agents on EC2 instances using AWS Tools for PowerShell."
    parameters    = {
      InstanceIds       = { type = "StringList", description = "List of EC2 Instance IDs." }
      S3BucketName      = { type = "String", description = "S3 bucket containing the installers.", default = "${var.bucket_name}" }
      Region            = { type = "String", default = "${data.aws_region.current.name}" }
      CrowdStrikeCID = { type = "String", description = "CrowdStrike CID for sensor installation.", default=data.aws_ssm_parameter.crowdStrike_cid.value }
      DuoIKEY        = { type = "String", description = "Duo integration key.", default=data.aws_ssm_parameter.duo_ikey.value }
      DuoSKEY        = { type = "String", description = "Duo secret key.", default=data.aws_ssm_parameter.duo_skey.value}
      DuoApiHost     = { type = "String", description = "Duo host address.", default=data.aws_ssm_parameter.duo_api_host.value }
    }
    mainSteps = [
      {
        name     = "DownloadAndInstallCrowdStrike"
        action   = "aws:runCommand"
        inputs   = {
          DocumentName = "AWS-RunPowerShellScript"
          InstanceIds  = "{{ InstanceIds }}"
          Parameters   = {
            commands = [
              "$s3Bucket = '{{ S3BucketName }}'",
              "$s3Key = 'agents/CROWDSTRIKE.EXE'",
              "$localPath = 'C:\\Scripts\\CROWDSTRIKE.EXE'",
              "New-Item -ItemType Directory -Path (Split-Path $localPath) -Force | Out-Null",
              "Write-Host 'Downloading CrowdStrike installer using AWS Tools for PowerShell...'",
              "Read-S3Object -BucketName $s3Bucket -Key $s3Key -File $localPath",
              "Write-Host 'Installing CrowdStrike...'",
              "Start-Process $localPath -ArgumentList '/install', '/quiet', '/norestart', 'CID={{ CrowdStrikeCID }}' -Wait",
              "Write-Host 'CrowdStrike installation completed.'"
            ]
          }
        }
      },
      {
        name     = "DownloadAndInstallRapid7"
        action   = "aws:runCommand"
        inputs   = {
          DocumentName = "AWS-RunPowerShellScript"
          InstanceIds  = "{{ InstanceIds }}"
          Parameters   = {
            commands = [
              "$s3Bucket = '{{ S3BucketName }}'",
              "$s3Key = 'agents/RAPID7_X86_64.MSI'",
              "$localPath = 'C:\\Scripts\\RAPID7_X86_64.MSI'",
              "New-Item -ItemType Directory -Path (Split-Path $localPath) -Force | Out-Null",
              "Write-Host 'Downloading Rapid7 installer using AWS Tools for PowerShell...'",
              "Read-S3Object -BucketName $s3Bucket -Key $s3Key -File $localPath",
              "Write-Host 'Installing Rapid7...'",
              "Start-Process msiexec.exe -ArgumentList \"/i $localPath CONFIGCHOICE=LOCAL CUSTOMCONFIGPATH='C:\\Scripts' /qn\" -Wait",
              #"Start-Process -FilePath "msiexec.exe" -ArgumentList \"/i $localPath /qn\" -Wait",
              "Write-Host 'Rapid7 installation completed.'"
            ]
          }
        }
      },
      {
        name     = "DownloadAndInstallDuo"
        action   = "aws:runCommand"
        inputs   = {
          DocumentName = "AWS-RunPowerShellScript"
          InstanceIds  = "{{ InstanceIds }}"
          Parameters   = {
            commands = [
              "$s3Bucket = '{{ S3BucketName }}'",
              "$s3Key = 'agents/DUOWINDOWSLOGON64.MSI'",
              "$localPath = 'C:\\Scripts\\DUOWINDOWSLOGON64.MSI'",
              "New-Item -ItemType Directory -Path (Split-Path $localPath) -Force | Out-Null",
              "Write-Host 'Downloading Duo installer using AWS Tools for PowerShell...'",
              "Read-S3Object -BucketName $s3Bucket -Key $s3Key -File $localPath",
              "Write-Host 'Installing Duo...'",
              "$argumentList = \"/i $localPath IKEY={{ DuoIKEY }} SKEY={{ DuoSKEY }} HOST='api-550c2cbe.duosecurity.com' AUTOPUSH='#0' FAILOPEN='#0' SMARTCARD='#0' RDPONLY='#0' USERNAMEFORMAT='0' /passive\"",
              "Start-Process msiexec.exe -ArgumentList $argumentList -Wait",
              "Write-Host 'Duo installation completed.'"
            ]
          }
        }
      }
    ]
  })
}
