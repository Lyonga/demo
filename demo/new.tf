resource "aws_ssm_document" "install_awscli_linux" {
  name          = "Ngl-AwsCli-LinuxDocument"
  document_type = "Automation"
  tags          = local.default_tags

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
  name          = "Crowdstrike-Duo-Rapid7-LinuxOs-x86-64"
  document_type = "Automation"
  tags          = local.default_tags

  content = jsonencode({
    schemaVersion = "0.3",
    assumeRole    = aws_iam_role.automation_role.arn,
    description   = "Install security agents on Linux EC2 instances.",
    parameters    = {
      InstanceIds    = { type = "StringList", description = "List of EC2 Instance IDs." }
      S3BucketName   = { type = "String", description = "S3 bucket containing the installers.", default = "${var.bucket_name}" }
      Region         = { type = "String", default = "${data.aws_region.current.name}" }
      CrowdStrikeCID = { type = "String", description = "CrowdStrike CID for sensor installation.", default=data.aws_ssm_parameter.crowdStrike_cid.value }
      DuoIKEY        = { type = "String", description = "Duo integration key.", default=data.aws_ssm_parameter.duo_ikey.value }
      DuoSKEY        = { type = "String", description = "Duo secret key.", default=data.aws_ssm_parameter.duo_skey.value}
      DuoApiHost     = { type = "String", description = "Duo host address.", default=data.aws_ssm_parameter.duo_api_host.value }
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
              "aws s3 cp s3://{{ S3BucketName }}/agents/falcon-sensor-7.16.0-16903.amzn2023.x86_64.rpm /tmp/agents/falcon-sensor-7.16.0-16903.amzn2023.x86_64.rpm",
              "if [ ! -f /tmp/agents/falcon-sensor-7.16.0-16903.amzn2023.x86_64.rpm ]; then",
              "  echo 'falcon-sensor-7.16.0-16903.amzn2023.x86_64.rpm not found. Exiting.'",
              "  exit 1",
              "fi",
              "sudo rpm -ivh /tmp/agents/falcon-sensor-7.16.0-16903.amzn2023.x86_64.rpm",
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
              "aws s3 cp s3://{{ S3BucketName }}/agents/rapid7-insight-agent-4.0.13.32-1.x86_64.rpm /tmp/agents/rapid7-insight-agent-4.0.13.32-1.x86_64.rpm",
              "if [ ! -f /tmp/agents/rapid7-insight-agent-4.0.13.32-1.x86_64.rpm ]; then",
              "  echo 'rapid7-insight-agent-4.0.13.32-1.x86_64.rpm not found. Exiting.'",
              "  exit 1",
              "fi",
              "sudo rpm -ivh /tmp/agents/rapid7-insight-agent-4.0.13.32-1.x86_64.rpm",
              "echo 'Rapid7 has been installed stsrting service.'",
              "sudo systemctl enable ir_agent.service",
              "sudo systemctl start ir_agent.service",
              "systemctl status ir_agent.service",
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
              "aws s3 cp s3://{{ S3BucketName }}/agents/duo_unix-2.0.4.tar.gz /tmp/agents/duo_unix-2.0.4.tar.gz",
              "if [ ! -f /tmp/agents/duo_unix-2.0.4.tar.gz ]; then",
              "  echo 'duo_unix-2.0.4.tar.gz not found. Exiting.'",
              "  exit 1",
              "fi",

              ##Dependency installation
              "sudo yum install openssl-devel -y",
              "sudo yum install pam-devel -y",
              "sudo yum install selinux-policy-devel -y",
              "sudo yum install bzip2 -y",
              "sudo yum install gcc -y",

              # Extract the tar.gz file
              "tar -xzf /tmp/agents/duo_unix-2.0.4.tar.gz -C /tmp/agents/",

              # Change directory to the extracted folder
              "cd /tmp/agents/duo_unix-2.0.4 || exit 1",

              "./configure --prefix=/usr && make && sudo make install",

              # Configure pam_duo
              # "sudo mkdir -p /etc/duo",
              # "cd /login_duo",
              # "sudo mv pam_duo.conf login_duo.conf",
              # "sudo mv login_duo.conf /etc/duo/login_duo.conf",
              #"sudo bash -c 'cat <<EOF > /etc/login_duo.conf [duo] ikey={{ DuoIKEY }} skey={{ DuoSKEY }} host={{ DuoApiHost }}  pushinfo = 'yes' autopush = 'yes' EOF'",
              "echo '[duo]' | sudo tee /etc/duo/login_duo.conf",
              "echo 'ikey={{ DuoIKEY }}' | sudo tee -a /etc/duo/login_duo.conf",
              "echo 'skey={{ DuoSKEY }}' | sudo tee -a /etc/duo/login_duo.conf",
              "echo 'host={{ DuoApiHost }}' | sudo tee -a /etc/duo/login_duo.conf",
              "echo 'pushinfo = yes' | sudo tee -a /etc/duo/login_duo.conf",
              "echo 'autopush = yes' | sudo tee -a /etc/duo/login_duo.conf",
              "echo 'Duo installation completed successfully.'"

            ]
          }
        }
      }
    ]
  })
}

resource "aws_ssm_document" "install_agents_linuxV1" {
  name          = "Rapid7-Syxsense-LinuxOs-aarch64-install"
  document_type = "Automation"
  tags          = local.default_tags

  content = jsonencode({
    schemaVersion = "0.3",
    assumeRole    = aws_iam_role.automation_role.arn,
    description   = "Install security agents on Linux EC2 instances.",
    parameters    = {
      InstanceIds    = { type = "StringList", description = "List of EC2 Instance IDs." }
      S3BucketName   = { type = "String", description = "S3 bucket containing the installers.", default = "${var.bucket_name}" }
      Region         = { type = "String", default = "${data.aws_region.current.name}" }
      SyxsenseInstanceName = { type = "String", description = "linux instance name to be installed." }
    },
    mainSteps = [
      {
        name     = "InstallRapid7",
        action   = "aws:runCommand",
        inputs   = {
          DocumentName = "AWS-RunShellScript",
          InstanceIds  = "{{ InstanceIds }}",
          Parameters   = {
            commands = [
              "mkdir -p /tmp/agents",
              "aws s3 cp s3://{{ S3BucketName }}/agents/rapid7-insight-agent-4.0.13.32-1.aarch64.rpm /tmp/agents/rapid7-insight-agent-4.0.13.32-1.aarch64.rpm",
              "if [ ! -f /tmp/agents/rapid7-insight-agent-4.0.13.32-1.aarch64.rpm ]; then",
              "  echo 'rapid7-insight-agent-4.0.13.32-1.aarch64.rpm not found. Exiting.'",
              "  exit 1",
              "fi",
              "sudo rpm -ivh /tmp/agents/rapid7-insight-agent-4.0.13.32-1.aarch64.rpm",
              "echo 'Rapid7 has been installed stsrting service.'",
              "sudo systemctl enable ir_agent.service",
              "sudo systemctl start ir_agent.service",
              "systemctl status ir_agent.service",
              "systemctl status ir_agent.service",
              "echo 'Rapid7 installation completed.'"
            ]
          }
        }
      },
      {
        name     = "InstallSyxsense",
        action   = "aws:runCommand",
        inputs   = {
          DocumentName = "AWS-RunShellScript",
          InstanceIds  = "{{ InstanceIds }}",
          Parameters   = {
            commands = [
              "mkdir -p /tmp/agents",
              "aws s3 cp s3://{{ S3BucketName }}/agents/syxsenseresponder.latest.linux-x64.rpm /tmp/agents/syxsenseresponder.latest.linux-x64.rpm",
              "if [ ! -f /tmp/agents/syxsenseresponder.latest.linux-x64.rpm ]; then",
              "  echo 'SyxsenseResponder.rpm not found. Exiting.'",
              "  exit 1",
              "fi",
              "sudo yum install -y /tmp/syxsenseresponder.latest.linux-x64.rpm",
              "sudo /usr/local/bin/SyxsenseResponder --instanceName={{ SyxsenseInstanceName }}",
              "rm -f /tmp/syxsenseresponder.latest.linux-x64.rpm",
              "echo 'Rapid7 installation completed.'"
            ]
          }
        }
      }
    ]
  })
}

data "aws_ssm_parameter" "duo_ikey" {
  name            = "/ngl/duo/ikey"
  with_decryption = true
}

data "aws_ssm_parameter" "duo_skey" {
  name            = "/ngl/duo/skey"
  with_decryption = true
}

data "aws_ssm_parameter" "duo_api_host" {
  name            = "/ngl/duo/host"
  with_decryption = false  # or true if you stored it as SecureString
}

data "aws_ssm_parameter" "crowdStrike_cid" {
  name            = "/ngl/cs/cid"
  with_decryption = false  # or true if you stored it as SecureString
}
