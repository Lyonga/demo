resource "aws_ssm_document" "install_agents" {
  name          = "NglSecurityAgentInstallationDocument"
  document_type = "Automation"
  tags          = var.tags

  content = jsonencode({
    schemaVersion = "0.3"
    description   = "Install security agents on EC2 instances."
    parameters    = {
      InstanceIds       = { type = "StringList", description = "List of EC2 Instance IDs." }
      S3BucketName      = { type = "String", description = "S3 bucket containing the installers.", default = "${var.bucket_name}" }
      Region            = { type = "String", default = "${data.aws_region.current.name}" }
      CrowdStrikeCID    = { type = "String", description = "CrowdStrike CID for sensor installation." }
      DuoIKEY           = { type = "String", description = "Duo integration key." }
      DuoSKEY           = { type = "String", description = "Duo secret key." }
    }
    mainSteps = [
      {
        name     = "InstallCrowdStrike"
        action   = "aws:runCommand"
        inputs   = {
          DocumentName = "AWS-RunPowerShellScript"
          InstanceIds  = "{{ InstanceIds }}"
          Parameters   = {
            commands = [
              "New-Item -ItemType Directory -Force -Path C:\\Scripts",
              "$installer = \"C:\\Scripts\\CROWDSTRIKE.EXE\"",
              "$argumentList = \"/install /quiet /norestart CID={{ CrowdStrikeCID }}\"",
              "aws s3 cp s3://{{ S3BucketName }}/agents/CROWDSTRIKE.EXE $installer",
              "Start-Process -FilePath $installer -ArgumentList $argumentList -Wait",
              "Write-Host 'CrowdStrike installation completed.'"
            ]
          }
        }
      },
      {
        name     = "InstallRapid7"
        action   = "aws:runCommand"
        inputs   = {
          DocumentName = "AWS-RunPowerShellScript"
          InstanceIds  = "{{ InstanceIds }}"
          Parameters   = {
            commands = [
              "$installer = \"C:\\Scripts\\RAPID7_X86_64.MSI\"",
              "aws s3 cp s3://{{ S3BucketName }}/agents/RAPID7_X86_64.MSI $installer",
              "Start-Process msiexec -ArgumentList \"/i $installer CONFIGCHOICE=LOCAL CUSTOMCONFIGPATH='C:\\Scripts' /qn\" -Wait",
              "Write-Host 'Rapid7 installation completed.'"
            ]
          }
        }
      },
      {
        name     = "InstallDuo"
        action   = "aws:runCommand"
        inputs   = {
          DocumentName = "AWS-RunPowerShellScript"
          InstanceIds  = "{{ InstanceIds }}"
          Parameters   = {
            commands = [
              "$installer = \"C:\\Scripts\\DUOWINDOWSLOGON64.MSI\"",
              "aws s3 cp s3://{{ S3BucketName }}/agents/DUOWINDOWSLOGON64.MSI $installer",
              "$argumentList = \"/i $installer IKEY={{ DuoIKEY }} SKEY={{ DuoSKEY }} HOST='api-550c2cbe.duosecurity.com' AUTOPUSH='#0' FAILOPEN='#0' SMARTCARD='#0' RDPONLY='#0' USERNAMEFORMAT='0' /passive\"",
              "Start-Process msiexec -ArgumentList $argumentList -Wait",
              "Write-Host 'Duo installation completed.'"
            ]
          }
        }
      }
    ]
  })
}





##########################
resource "aws_ssm_document" "install_agents" {
  name          = "NglSecurityAgentInstallationDocument"
  document_type = "Automation"
  tags          = var.tags

  content = jsonencode({
    schemaVersion = "0.3"
    description   = "Install security agents on EC2 instances using AWS Tools for PowerShell."
    parameters    = {
      InstanceIds       = { type = "StringList", description = "List of EC2 Instance IDs." }
      S3BucketName      = { type = "String", description = "S3 bucket containing the installers.", default = "${var.bucket_name}" }
      Region            = { type = "String", default = "${data.aws_region.current.name}" }
      CrowdStrikeCID    = { type = "String", description = "CrowdStrike CID for sensor installation." }
      DuoIKEY           = { type = "String", description = "Duo integration key." }
      DuoSKEY           = { type = "String", description = "Duo secret key." }
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
              "Start-Process msiexec -ArgumentList \"/i $localPath CONFIGCHOICE=LOCAL CUSTOMCONFIGPATH='C:\\Scripts' /qn\" -Wait",
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
              "Start-Process msiexec -ArgumentList $argumentList -Wait",
              "Write-Host 'Duo installation completed.'"
            ]
          }
        }
      }
    ]
  })
}
