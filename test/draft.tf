resource "aws_ssm_document" "install_awscli_linux" {
  name          = "NglAwsCliLinuxDocument"
  document_type = "Automation"
  tags          = var.tags

  content = jsonencode({
    schemaVersion = "0.3",
    description   = "Install AWS CLI on Linux instances.",
    parameters    = {
      InstanceIds = { type = "StringList", description = "List of EC2 Instance IDs." }
      Region      = { type = "String", default = "${data.aws_region.current.name}" }
    },
    mainSteps = [
      {
        name     = "DownloadAWSCLI",
        action   = "aws:runCommand",
        inputs   = {
          DocumentName = "AWS-RunShellScript",
          InstanceIds  = "{{ InstanceIds }}",
          Parameters   = {
            commands = [
              "mkdir -p /tmp/awscli",
              "curl 'https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip' -o '/tmp/awscliv2.zip'",
              "unzip -o /tmp/awscliv2.zip -d /tmp/awscli"
            ]
          }
        }
      },
      {
        name     = "InstallAWSCLI",
        action   = "aws:runCommand",
        inputs   = {
          DocumentName = "AWS-RunShellScript",
          InstanceIds  = "{{ InstanceIds }}",
          Parameters   = {
            commands = [
              "sudo /tmp/awscli/aws/install",
              "export PATH=$PATH:/usr/local/bin",
              "aws --version"
            ]
          }
        }
      }
    ]
  })
}

resource "aws_ssm_document" "install_agents_linux" {
  name          = "NglSecurityAgentInstallationLinux"
  document_type = "Automation"
  tags          = var.tags

  content = jsonencode({
    schemaVersion = "0.3",
    assumeRole    = aws_iam_role.automation_role.arn,
    description   = "Install security agents on Linux EC2 instances.",
    parameters    = {
      InstanceIds    = { type = "StringList", description = "List of EC2 Instance IDs." }
      S3BucketName   = { type = "String", description = "S3 bucket containing the installers.", default = "${var.bucket_name}" }
      Region         = { type = "String", default = "${data.aws_region.current.name}" }
      CrowdStrikeCID = { type = "String", description = "CrowdStrike CID for sensor installation." }
      DuoIKEY        = { type = "String", description = "Duo integration key." }
      DuoSKEY        = { type = "String", description = "Duo secret key." }
    },
    mainSteps = [
      {
        name     = "InstallCrowdStrike",
        action   = "aws:runCommand",
        inputs   = {
          DocumentName = "AWS-RunShellScript",
          InstanceIds  = "{{ InstanceIds }}",
          Parameters   = {
            commands = [
              "mkdir -p /tmp/agents",
              "aws s3 cp s3://{{ S3BucketName }}/agents/CrowdStrikeSensor.rpm /tmp/agents/CrowdStrikeSensor.rpm",
              "sudo rpm -ivh /tmp/agents/CrowdStrikeSensor.rpm",
              "sudo /opt/CrowdStrike/falconctl -s --cid={{ CrowdStrikeCID }}",
              "sudo systemctl enable falcon-sensor",
              "sudo systemctl start falcon-sensor",
              "echo 'CrowdStrike installation completed.'"
            ]
          }
        }
      },
      {
        name     = "InstallRapid7",
        action   = "aws:runCommand",
        inputs   = {
          DocumentName = "AWS-RunShellScript",
          InstanceIds  = "{{ InstanceIds }}",
          Parameters   = {
            commands = [
              "mkdir -p /tmp/agents",
              "aws s3 cp s3://{{ S3BucketName }}/agents/rapid7-agent-installer.rpm /tmp/agents/rapid7-agent-installer.rpm",
              "sudo rpm -ivh /tmp/agents/rapid7-agent-installer.rpm",
              "sudo systemctl enable rapid7-agent",
              "sudo systemctl start rapid7-agent",
              "echo 'Rapid7 installation completed.'"
            ]
          }
        }
      },
      {
        name     = "InstallDuo",
        action   = "aws:runCommand",
        inputs   = {
          DocumentName = "AWS-RunShellScript",
          InstanceIds  = "{{ InstanceIds }}",
          Parameters   = {
            commands = [
              "mkdir -p /tmp/agents",
              "aws s3 cp s3://{{ S3BucketName }}/agents/duo-agent-installer.rpm /tmp/agents/duo-agent-installer.rpm",
              "sudo rpm -ivh /tmp/agents/duo-agent-installer.rpm",
              "sudo /opt/duo/duo --ikey={{ DuoIKEY }} --skey={{ DuoSKEY }} --host='api-550c2cbe.duosecurity.com'",
              "sudo systemctl enable duo-agent",
              "sudo systemctl start duo-agent",
              "echo 'Duo installation completed.'"
            ]
          }
        }
      }
    ]
  })
}


resource "aws_ssm_document" "install_agents_no_cli_linux" {
  name          = "NglSecurityAgentInstallationLinuxNoCli"
  document_type = "Automation"
  tags          = var.tags

  content = jsonencode({
    schemaVersion = "0.3",
    description   = "Install security agents on Linux instances without AWS CLI.",
    parameters    = {
      InstanceIds    = { type = "StringList", description = "List of EC2 Instance IDs." }
      S3BucketName   = { type = "String", description = "S3 bucket containing the installers.", default = "${var.bucket_name}" }
      Region         = { type = "String", default = "${data.aws_region.current.name}" }
      CrowdStrikeCID = { type = "String", description = "CrowdStrike CID for sensor installation." }
      DuoIKEY        = { type = "String", description = "Duo integration key." }
      DuoSKEY        = { type = "String", description = "Duo secret key." }
    },
    mainSteps = [
      {
        name     = "DownloadAndInstallCrowdStrike",
        action   = "aws:runCommand",
        inputs   = {
          DocumentName = "AWS-RunShellScript",
          InstanceIds  = "{{ InstanceIds }}",
          Parameters   = {
            commands = [
              "mkdir -p /tmp/agents",
              "crowdstrike_url=\"https://${S3BucketName}.s3.{{ Region }}.amazonaws.com/agents/CrowdStrikeSensor.rpm\"",
              "curl -o /tmp/agents/CrowdStrikeSensor.rpm \"$crowdstrike_url\"",
              "if [ ! -f /tmp/agents/CrowdStrikeSensor.rpm ]; then",
              "  echo 'Failed to download CrowdStrike Sensor.'",
              "  exit 1",
              "fi",
              "sudo rpm -ivh /tmp/agents/CrowdStrikeSensor.rpm",
              "sudo /opt/CrowdStrike/falconctl -s --cid={{ CrowdStrikeCID }}",
              "sudo systemctl enable falcon-sensor",
              "sudo systemctl start falcon-sensor",
              "echo 'CrowdStrike installation completed.'"
            ]
          }
        }
      },
      {
        name     = "DownloadAndInstallRapid7",
        action   = "aws:runCommand",
        inputs   = {
          DocumentName = "AWS-RunShellScript",
          InstanceIds  = "{{ InstanceIds }}",
          Parameters   = {
            commands = [
              "mkdir -p /tmp/agents",
              "rapid7_url=\"https://${S3BucketName}.s3.{{ Region }}.amazonaws.com/agents/rapid7-agent-installer.rpm\"",
              "curl -o /tmp/agents/rapid7-agent-installer.rpm \"$rapid7_url\"",
              "if [ ! -f /tmp/agents/rapid7-agent-installer.rpm ]; then",
              "  echo 'Failed to download Rapid7 Agent.'",
              "  exit 1",
              "fi",
              "sudo rpm -ivh /tmp/agents/rapid7-agent-installer.rpm",
              "sudo systemctl enable rapid7-agent",
              "sudo systemctl start rapid7-agent",
              "echo 'Rapid7 installation completed.'"
            ]
          }
        }
      },
      {
        name     = "DownloadAndInstallDuo",
        action   = "aws:runCommand",
        inputs   = {
          DocumentName = "AWS-RunShellScript",
          InstanceIds  = "{{ InstanceIds }}",
          Parameters   = {
            commands = [
              "mkdir -p /tmp/agents",
              "duo_url=\"https://${S3BucketName}.s3.{{ Region }}.amazonaws.com/agents/duo-agent-installer.rpm\"",
              "curl -o /tmp/agents/duo-agent-installer.rpm \"$duo_url\"",
              "if [ ! -f /tmp/agents/duo-agent-installer.rpm ]; then",
              "  echo 'Failed to download Duo Agent.'",
              "  exit 1",
              "fi",
              "sudo rpm -ivh /tmp/agents/duo-agent-installer.rpm",
              "sudo /opt/duo/duo --ikey={{ DuoIKEY }} --skey={{ DuoSKEY }} --host='api-550c2cbe.duosecurity.com'",
              "sudo systemctl enable duo-agent",
              "sudo systemctl start duo-agent",
              "echo 'Duo installation completed.'"
            ]resource "aws_ssm_document" "install_agents_no_cli_linux" {
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
        name     = "DownloadAndInstallCrowdStrike",
        action   = "aws:runCommand",
        inputs   = {
          DocumentName = "AWS-RunShellScript",
          InstanceIds  = "{{ InstanceIds }}",
          Parameters   = {
            commands = [
              "mkdir -p /tmp/agents",
              "crowdstrike_url=\"https://{{ S3BucketName }}.s3.{{ Region }}.amazonaws.com/agents/CrowdStrikeSensor.rpm\"",
              "curl -o /tmp/agents/CrowdStrikeSensor.rpm \"$crowdstrike_url\"",
              "if [ ! -f /tmp/agents/CrowdStrikeSensor.rpm ]; then",
              "  echo 'Failed to download CrowdStrike Sensor.'",
              "  exit 1",
              "fi",
              "sudo rpm -ivh /tmp/agents/CrowdStrikeSensor.rpm",
              "sudo /opt/CrowdStrike/falconctl -s --cid={{ CrowdStrikeCID }}",
              "sudo systemctl enable falcon-sensor",
              "sudo systemctl start falcon-sensor",
              "echo 'CrowdStrike installation completed.'"
            ]
          }
        }
      },
      {
        name     = "DownloadAndInstallRapid7",
        action   = "aws:runCommand",
        inputs   = {
          DocumentName = "AWS-RunShellScript",
          InstanceIds  = "{{ InstanceIds }}",
          Parameters   = {
            commands = [
              "mkdir -p /tmp/agents",
              "rapid7_url=\"https://{{ S3BucketName }}.s3.{{ Region }}.amazonaws.com/agents/rapid7-agent-installer.rpm\"",
              "curl -o /tmp/agents/rapid7-agent-installer.rpm \"$rapid7_url\"",
              "if [ ! -f /tmp/agents/rapid7-agent-installer.rpm ]; then",
              "  echo 'Failed to download Rapid7 Agent.'",
              "  exit 1",
              "fi",
              "sudo rpm -ivh /tmp/agents/rapid7-agent-installer.rpm",
              "sudo systemctl enable rapid7-agent",
              "sudo systemctl start rapid7-agent",
              "echo 'Rapid7 installation completed.'"
            ]
          }
        }
      },
      {
        name     = "DownloadAndInstallDuo",
        action   = "aws:runCommand",
        inputs   = {
          DocumentName = "AWS-RunShellScript",
          InstanceIds  = "{{ InstanceIds }}",
          Parameters   = {
            commands = [
              "mkdir -p /tmp/agents",
              "duo_url=\"https://{{ S3BucketName }}.s3.{{ Region }}.amazonaws.com/agents/duo-agent.tar.gz\"",
              "curl -o /tmp/agents/duo-agent.tar.gz \"$duo_url\"",
              "if [ ! -f /tmp/agents/duo-agent.tar.gz ]; then",
              "  echo 'Failed to download Duo Agent.'",
              "  exit 1",
              "fi",
              "tar -xzf /tmp/agents/duo-agent.tar.gz -C /tmp/agents/",
              "cd /tmp/agents/duo-agent || exit 1",
              "sudo ./install.sh --ikey={{ DuoIKEY }} --skey={{ DuoSKEY }} --host='api-550c2cbe.duosecurity.com'",
              "sudo systemctl enable duo-agent",
              "sudo systemctl start duo-agent",
              "echo 'Duo installation completed.'"
            ]
          }
        }
      }
    ]
  })
}

          }
        }
      }
    ]
  })
}



####################
