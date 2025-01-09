resource "aws_ssm_document" "install_agents_no_cli_linux" {
  name          = "NglSecurityAgentInstallationLinuxNoCli"
  document_type = "Automation"
  tags          = var.tags

  content = jsonencode({
    schemaVersion = "0.3",
    description   = "Install security agents on Linux instances without AWS CLI.",
    parameters    = {
      InstanceIds    = { type = "StringList", description = "List of EC2 Instance IDs." }
      S3BucketName   = { type = "String", description = "S3 bucket containing the installers." }
      Region         = { type = "String", default = "${data.aws_region.current.name}" }
      CrowdStrikeCID = { type = "String", description = "CrowdStrike CID for sensor installation." }
      DuoIKEY        = { type = "String", description = "Duo integration key." }
      DuoSKEY        = { type = "String", description = "Duo secret key." }
    },
    mainSteps = [
      {
        name     = "DownloadAndInstallDuo",
        action   = "aws:runCommand",
        inputs   = {
          DocumentName = "AWS-RunShellScript",
          InstanceIds  = "{{ InstanceIds }}",
          Parameters   = {
            commands = [
              # Create a directory for the agents
              "mkdir -p /tmp/agents",

              # Download the Duo agent tar.gz from S3
              "duo_url=\"https://{{ S3BucketName }}.s3.{{ Region }}.amazonaws.com/agents/duo-agent.tar.gz\"",
              "curl -o /tmp/agents/duo-agent.tar.gz \"$duo_url\"",

              # Verify the download was successful
              "if [ ! -f /tmp/agents/duo-agent.tar.gz ]; then",
              "  echo 'Failed to download Duo agent.'",
              "  exit 1",
              "fi",

              # Extract the tar.gz file
              "tar -xzf /tmp/agents/duo-agent.tar.gz -C /tmp/agents/",

              # Change directory to the extracted folder
              "cd /tmp/agents/duo_unix-2.0.4 || exit 1",

              # Run the configure script to prepare for installation
              "./configure",

              # Build the binaries using Makefile
              "make",

              # Install the binaries
              "sudo make install",

              # Configure the Duo login binary
              "sudo /usr/local/sbin/login_duo --ikey={{ DuoIKEY }} --skey={{ DuoSKEY }} --host='api-550c2cbe.duosecurity.com'",

              # Confirm the Duo installation
              "echo 'Duo installation completed successfully.'"
            ]
          }
        }
      }
    ]
  })
}









resource "aws_ssm_document" "install_agents_cli_linux" {
  name          = "NglSecurityAgentInstallationLinuxCLI"
  document_type = "Automation"
  tags          = var.tags

  content = jsonencode({
    schemaVersion = "0.3",
    description   = "Install security agents on Linux instances using AWS CLI.",
    parameters    = {
      InstanceIds    = { type = "StringList", description = "List of EC2 Instance IDs." }
      S3BucketName   = { type = "String", description = "S3 bucket containing the installers." }
      Region         = { type = "String", default = "${data.aws_region.current.name}" }
      DuoIKEY        = { type = "String", description = "Duo integration key." }
      DuoSKEY        = { type = "String", description = "Duo secret key." }
    },
    mainSteps = [
      {
        name     = "DownloadAndInstallDuo",
        action   = "aws:runCommand",
        inputs   = {
          DocumentName = "AWS-RunShellScript",
          InstanceIds  = "{{ InstanceIds }}",
          Parameters   = {
            commands = [
              # Create a directory for the Duo agent
              "mkdir -p /tmp/agents",

              # Download the Duo agent tar.gz from S3 using AWS CLI
              "aws s3 cp s3://{{ S3BucketName }}/agents/duo-agent.tar.gz /tmp/agents/duo-agent.tar.gz",

              # Verify the download was successful
              "if [ ! -f /tmp/agents/duo-agent.tar.gz ]; then",
              "  echo 'Failed to download Duo agent.'",
              "  exit 1",
              "fi",

              # Extract the tar.gz file
              "tar -xzf /tmp/agents/duo-agent.tar.gz -C /tmp/agents/",

              # Change directory to the extracted folder
              "cd /tmp/agents/duo_unix-2.0.4 || exit 1",

              # Run the configure script to prepare for installation
              "./configure",

              # Compile the source code using Makefile
              "make",

              # Install the binaries
              "sudo make install",

              # Configure Duo login binary
              "sudo /usr/local/sbin/login_duo --ikey={{ DuoIKEY }} --skey={{ DuoSKEY }} --host='api-550c2cbe.duosecurity.com'",

              # Confirm the Duo installation
              "echo 'Duo installation completed successfully.'"
            ]
          }
        }
      }
    ]
  })
}
