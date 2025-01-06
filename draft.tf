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
          "$s3Key = 'FalconSensor_Windows_F9E4A28AD0844A9382BF5114BC2ECF9E-C9.exe'",
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
          "$s3Key = 'RAPID7_X86_64.MSI'",
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
          "$s3Key = 'DUOWINDOWSLO6OG4.MSI'",
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
