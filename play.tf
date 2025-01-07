resource "aws_ssm_document" "install_awscli" {
  name          = "NglAwsCliDocument"
  document_type = "Automation"
  tags          = var.tags
  content = jsonencode({
    schemaVersion = "0.3"
    description   = "Install security agents on EC2 instances."
    parameters    = {
      InstanceIds    = { type = "StringList", description = "List of EC2 Instance IDs." }
      S3BucketName   = { type = "String", description = "S3 bucket containing the installers.", default = "${var.bucket_name}" }
      Region         = { type = "String", default = "${data.aws_region.current.name}" }
      CrowdStrikeCID = { type = "String", description = "CrowdStrike CID for sensor installation" }
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
              # Update the system-wide PATH
              "[Environment]::SetEnvironmentVariable('PATH', $env:PATH + ';' + $awsCliPath, [EnvironmentVariableTarget]::Machine)",
              # Refresh the current session's PATH
              "$env:PATH = [System.Environment]::GetEnvironmentVariable('PATH', [System.EnvironmentVariableTarget]::Machine)",
              # Verify AWS CLI installation
              "aws --version"
            ]
          }
        }
      }
    ]
  })
}
##############


resource "aws_ssm_document" "install_awscli" {
  name          = "NglAwsCliDocument"
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
              "[Environment]::SetEnvironmentVariable('PATH', $env:PATH + ';' + $awsCliPath, [EnvironmentVariableTarget]::Machine)",
            ]
          }
        }
       }
    ]
  })
}
