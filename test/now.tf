resource "aws_ssm_document" "install_crowdstrike" {
  name          = "NglCSDUORAgentInstallationDocument"
  document_type = "Automation"
  tags =          var.tags
  content = jsonencode({
    schemaVersion = "0.3"
    description   = "Install security agents on EC2 instances."
    parameters    = {
      InstanceIds  = { type = "StringList", description = "List of EC2 Instance IDs." }
      S3BucketName = { type = "String", description = "S3 bucket containing the installers.", default = "${var.bucket_name}"}
      Region       = { type = "String", default = "${data.aws_region.current.name}" }
      CrowdStrikeCID = { type = "String", description = "CrowdStrike CID for sensor installation"}
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
              "$localPath = 'C:\\Scripts\\FalconSensor_Windows.exe'",
              "New-Item -ItemType Directory -Path (Split-Path $localPath) -Force | Out-Null",
              "Write-Host 'Downloading CrowdStrike installer...'",
              "Invoke-RestMethod -Uri \"https://$s3Bucket.s3.{{ Region }}.amazonaws.com/$s3Key\" -OutFile $localPath",
              "Write-Host 'Installing CrowdStrike...'",
              "Start-Process $localPath -Wait"
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
              "Write-Host 'Downloading Rapid7 installer...'",
              "Invoke-RestMethod -Uri \"https://$s3Bucket.s3.{{ Region }}.amazonaws.com/$s3Key\" -OutFile $localPath",
              "Write-Host 'Installing Rapid7...'",
              "Start-Process msiexec -ArgumentList \"/i $localPath /quiet /norestart\" -Wait"
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
              "$s3Key = 'agents/DUOWINDOWSLO6OG4.MSI'",
              "$localPath = 'C:\\Scripts\\DUOWINDOWSLO6OG4.MSI'",
              "New-Item -ItemType Directory -Path (Split-Path $localPath) -Force | Out-Null",
              "Write-Host 'Downloading Duo installer...'",
              "Invoke-RestMethod -Uri \"https://$s3Bucket.s3.{{ Region }}.amazonaws.com/$s3Key\" -OutFile $localPath",
              "Write-Host 'Installing Duo...'",
              "Start-Process msiexec -ArgumentList \"/i $localPath /quiet /norestart\" -Wait"
            ]
          }
        }
      }
    ]
  })
}
