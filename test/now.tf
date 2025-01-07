resource "aws_ssm_document" "install_agents" {
  name          = "NglSecurityAgentInstallationDocument"
  document_type = "Automation"
  tags =          var.tags
  content = jsonencode({
    schemaVersion = "0.3"
    #schemaVersion = "2.2"
    description   = "Install security agents on EC2 instances."
    parameters    = {
      InstanceIds  = { type = "StringList", description = "List of EC2 Instance IDs." }
      S3BucketName = { type = "String", description = "S3 bucket containing the installers.", default = "${var.bucket_name}"}
      Region       = { type = "String", default = "${data.aws_region.current.name}" }
      CrowdStrikeCID = { type = "String", description = "CrowdStrike CID for sensor installation"}
    }
    mainSteps = [
      {
        "name": "DownloadAWSCLI",
        "action": "aws:runCommand",
        "inputs": {
          "DocumentName": "AWS-RunPowerShellScript",
          "InstanceIds": "{{ InstanceIds }}",
          "Parameters": {
            "commands": [
              "$path = 'C:\\Temp\\AWSCLIV2.msi'",
              "$url  = 'https://awscli.amazonaws.com/AWSCLIV2.msi'",
              "New-Item -ItemType Directory -Path (Split-Path $path) -Force | Out-Null",
              "Invoke-WebRequest -Uri $url -OutFile $path"
            ]
          }
        }
      },
      {
        "name": "InstallAWSCLI",
        "action": "aws:runCommand",
        "inputs": {
          "DocumentName": "AWS-RunPowerShellScript",
          "InstanceIds": "{{ InstanceIds }}",
          "Parameters": {
            "commands": [
              "Start-Process msiexec -ArgumentList \"/i C:\\Temp\\AWSCLIV2.msi /quiet /norestart\" -Wait",
              "$awsCliPath = 'C:\\Program Files\\Amazon\\AWSCLIV2'",
              "[Environment]::SetEnvironmentVariable('PATH', $env:PATH + ';' + $awsCliPath, [EnvironmentVariableTarget]::Machine)"
            ]
          }
        }
      },
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
              "$argumentList = /install /quiet /norestart CID=$CID",
              "aws s3 cp s3://${var.bucket_name}/agents/CROWDSTRIKE.EXE $installer",
              #"Start-Process -FilePath $installer -ArgumentList '/install', '/quiet', '/norestart',  'CID={{ CrowdStrikeCID }}' -Wait" 
              "Start-Process -FilePath $installer -ArgumentList $argumentList -Wait",
              "Write-Host 'Successfully installed'"
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
              "aws s3 cp s3://${var.bucket_name}/agents/RAPID7_X86_64.MSI $installer",
              "Start-Process $installer -Wait"
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
              "$installer = \"C:\\Scripts\\DUOWINDOWSLO6OG4.MSI\"",
              #"aws s3 cp s3://${var.bucket_name}/agents/DUOWINDOWSLO6OG4.MSI $installer",
              "aws s3 cp s3://ngl-ec2-terraform-backend-workloaddev/agents/DUOWINDOWSLO6OG4.MSI $installer",
              "Start-Process msiexec -ArgumentList \"/i $installer /quiet /norestart\" -Wait"
              #"Start-Process $installer -ArgumentList \"--cid={{ CrowdStrikeCID }}\" -Wait"
            ]
          }
        }
      }
    ]
  })
}
