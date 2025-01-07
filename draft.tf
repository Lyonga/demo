resource "aws_ssm_document" "install_agents" {
  name          = "NglSecurityAgentInstallationDocument"
  document_type = "Automation"
  tags          = var.tags

  content = jsonencode({
    schemaVersion = "0.3",
    assumeRole = aws_iam_role.automation_role.arn,
    description   = "Install security agents on EC2 instances.",
    parameters    = {
      InstanceIds       = { type = "StringList", description = "List of EC2 Instance IDs." }
      S3BucketName      = { type = "String", description = "S3 bucket containing the installers.", default = "${var.bucket_name}" }
      Region            = { type = "String", default = "${data.aws_region.current.name}" }
      CrowdStrikeCID    = { type = "String", description = "CrowdStrike CID for sensor installation." }
      DuoIKEY           = { type = "String", description = "Duo integration key." }
      DuoSKEY           = { type = "String", description = "Duo secret key." }
      AutomationAssumeRole = { type = "String", description = "The ARN of the role to assume when running this automation document.", default = aws_iam_role.automation_role.arn }
    },
    mainSteps = [
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

              # Set paths and arguments
              "$installer = \"C:\\Scripts\\CROWDSTRIKE.EXE\"",
              "$argumentList = \"/install /quiet /norestart CID={{ CrowdStrikeCID }}\"",

              # Check if the file exists
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
      },
      {
        name     = "InstallRapid7",
        action   = "aws:runCommand",
        inputs   = {
          DocumentName = "AWS-RunPowerShellScript",
          InstanceIds  = "{{ InstanceIds }}",
          Parameters   = {
            commands = [
              # Ensure the directory exists
              "New-Item -ItemType Directory -Force -Path C:\\Scripts | Out-Null",

              # Set paths and arguments
              "$installer = \"C:\\Scripts\\RAPID7_X86_64.MSI\"",

              # Check if the file exists
              "if (Test-Path $installer) {",
              "    Write-Host 'RAPID7_X86_64.MSI exists. Running installation step...'",
              "} else {",
              "    Write-Host 'RAPID7_X86_64.MSI does not exist. Downloading from S3...'",
              "    aws s3 cp s3://{{ S3BucketName }}/agents/RAPID7_X86_64.MSI $installer",
              "    if (!(Test-Path $installer)) {",
              "        Write-Error 'Download failed. Exiting.'",
              "        exit 1",
              "    }",
              "}",

              # Run the installation
              "Write-Host 'Starting Rapid7 installation...'",
              "try {",
              "    Start-Process msiexec -ArgumentList \"/i $installer CONFIGCHOICE=LOCAL CUSTOMCONFIGPATH='C:\\Scripts' /qn\" -Wait -PassThru | Out-Null",
              "    Write-Host 'Rapid7 installation completed successfully.'",
              "} catch {",
              "    Write-Error 'Rapid7 installation failed: $_'",
              "    exit 1",
              "}"
            ]
          }
        }
      },
      {
        name     = "InstallDuo",
        action   = "aws:runCommand",
        inputs   = {
          DocumentName = "AWS-RunPowerShellScript",
          InstanceIds  = "{{ InstanceIds }}",
          Parameters   = {
            commands = [
              # Ensure the directory exists
              "New-Item -ItemType Directory -Force -Path C:\\Scripts | Out-Null",

              # Set paths and arguments
              "$installer = \"C:\\Scripts\\DUOWINDOWSLOGON64.MSI\"",
              "$argumentList = \"/i $installer IKEY={{ DuoIKEY }} SKEY={{ DuoSKEY }} HOST='api-550c2cbe.duosecurity.com' AUTOPUSH='#0' FAILOPEN='#0' SMARTCARD='#0' RDPONLY='#0' USERNAMEFORMAT='0' /passive\"",

              # Check if the file exists
              "if (Test-Path $installer) {",
              "    Write-Host 'DUOWINDOWSLOGON64.MSI exists. Running installation step...'",
              "} else {",
              "    Write-Host 'DUOWINDOWSLOGON64.MSI does not exist. Downloading from S3...'",
              "    aws s3 cp s3://{{ S3BucketName }}/agents/DUOWINDOWSLOGON64.MSI $installer",
              "    if (!(Test-Path $installer)) {",
              "        Write-Error 'Download failed. Exiting.'",
              "        exit 1",
              "    }",
              "}",

              # Run the installation
              "Write-Host 'Starting Duo installation...'",
              "try {",
              "    Start-Process msiexec -ArgumentList $argumentList -Wait -PassThru | Out-Null",
              "    Write-Host 'Duo installation completed successfully.'",
              "} catch {",
              "    Write-Error 'Duo installation failed: $_'",
              "    exit 1",
              "}"
            ]
          }
        }
      }
    ]
  })
}
