{
  name     = "InstallCrowdStrike",
  action   = "aws:runCommand",
  inputs   = {
    DocumentName = "AWS-RunPowerShellScript",
    InstanceIds  = "{{ InstanceIds }}",
    Parameters   = {
      commands = [
        # Ensure the directory exists
        "New-Item -ItemType Directory -Force -Path C:\\Scripts | Out-Null",

        # Set the installer path
        "$installer = \"C:\\Scripts\\CROWDSTRIKE.EXE\"",
        "$argumentList = \"/install /quiet /norestart CID={{ CrowdStrikeCID }}\"",

        # Check if the installer exists
        "if (Test-Path $installer) {",
        "    Write-Host 'CROWDSTRIKE.EXE exists. Running installation step...'",
        "} else {",
        "    Write-Host 'CROWDSTRIKE.EXE does not exist. Downloading from S3...'",
        "    aws s3 cp s3://{{ S3BucketName }}/agents/CROWDSTRIKE.EXE $installer",
        "    if (!(Test-Path $installer)) {",
        "        Write-Error 'Download failed. Exiting.'",
        "        exit 1",
        "    }",
        "}",

        # Run the installation
        "Write-Host 'Starting CrowdStrike installation...'",
        "try {",
        "    Start-Process -FilePath $installer -ArgumentList $argumentList -Wait -PassThru | Out-Null",
        "    Write-Host 'CrowdStrike installation completed successfully.'",
        "} catch {",
        "    Write-Error 'CrowdStrike installation failed: $_'",
        "    exit 1",
        "}"
      ]
    }
  }
}
