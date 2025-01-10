####################
resource "aws_ssm_document" "install_duo_no_dependencies" {
  name          = "InstallDuoNoDependencies"
  document_type = "Automation"
  tags          = var.tags

  content = jsonencode({
    schemaVersion = "0.3",
    description   = "Install Duo agent from .tar.gz without system dependencies.",
    parameters    = {
      InstanceIds  = { type = "StringList", description = "List of EC2 Instance IDs." }
      S3BucketName = { type = "String", description = "S3 bucket containing the Duo agent." }
      DuoIKEY      = { type = "String", description = "Duo integration key." }
      DuoSKEY      = { type = "String", description = "Duo secret key." }
    },
    mainSteps = [
      {
        name     = "DownloadAndExtractDuoAgent",
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

              # Copy binaries directly to appropriate system directories
              "sudo cp login_duo /usr/local/sbin/",
              "sudo cp pam_duo /lib/security/",

              # Set permissions
              "sudo chmod 755 /usr/local/sbin/login_duo",
              "sudo chmod 755 /lib/security/pam_duo.so"
            ]
          }
        }
      },
      {
        name     = "ConfigureDuo",
        action   = "aws:runCommand",
        inputs   = {
          DocumentName = "AWS-RunShellScript",
          InstanceIds  = "{{ InstanceIds }}",
          Parameters   = {
            commands = [
              # Create the Duo configuration file
              "echo '[duo]' | sudo tee /etc/duo/duo.conf > /dev/null",
              "echo 'ikey={{ DuoIKEY }}' | sudo tee -a /etc/duo/duo.conf > /dev/null",
              "echo 'skey={{ DuoSKEY }}' | sudo tee -a /etc/duo/duo.conf > /dev/null",
              "echo 'host=api-550c2cbe.duosecurity.com' | sudo tee -a /etc/duo/duo.conf > /dev/null",

              # Set permissions for the configuration file
              "sudo chmod 600 /etc/duo/duo.conf",

              # Confirm Duo installation
              "echo 'Duo installation and configuration completed.'"
            ]
          }
        }
      }
    ]
  })
}

#########################

resource "aws_ssm_document" "install_and_configure_duo_unix" {
  name          = "InstallAndConfigureDuoUnix"
  document_type = "Automation"

  content = jsonencode({
    schemaVersion = "0.3"
    description   = "Installs and configures Duo UNIX with PAM support on Linux EC2 instances."
    parameters    = {
      InstanceIds = {
        type        = "StringList"
        description = "List of EC2 Instance IDs."
      }
      Region = {
        type    = "String"
        default = "${data.aws_region.current.name}"
      }
      DuoIntegrationKey = {
        type        = "String"
        description = "Duo Integration Key."
      }
      DuoSecretKey = {
        type        = "String"
        description = "Duo Secret Key."
      }
      DuoApiHost = {
        type        = "String"
        description = "Duo API Hostname."
      }
    }
    mainSteps = [
      {
        name     = "InstallAndConfigure"
        action   = "aws:runCommand"
        inputs   = {
          DocumentName = "AWS-RunShellScript"
          InstanceIds  = "{{ InstanceIds }}"
          Parameters   = {
            commands = [
              # Install dependencies
              "sudo yum install -y openssl-devel pam-devel gcc make",

              # Download and extract Duo UNIX tarball
              "mkdir -p /tmp/duo",
              "curl -o /tmp/duo/duo_unix.tar.gz https://dl.duosecurity.com/duo_unix-latest.tar.gz",
              "tar zxf /tmp/duo/duo_unix.tar.gz -C /tmp/duo/",
              "cd /tmp/duo/duo_unix-*",

              # Build and install Duo UNIX with PAM support
              "./configure --with-pam --prefix=/usr && make && sudo make install",

              # Configure pam_duo
              "sudo mkdir -p /etc/duo",
              "sudo tee /etc/duo/pam_duo.conf > /dev/null <<EOL",
              "[duo]",
              "ikey = {{ DuoIntegrationKey }}",
              "skey = {{ DuoSecretKey }}",
              "host = {{ DuoApiHost }}",
              "pushinfo = yes",
              "autopush = yes",
              "EOL"
            ]
          }
        }
      }
    ]
  })
}


#################

resource "aws_ssm_document" "install_duo_unix" {
  name          = "InstallDuoUnix"
  document_type = "Automation"

  content = jsonencode({
    schemaVersion = "0.3"
    description   = "Installs Duo UNIX with PAM support on Linux EC2 instances."
    parameters    = {
      InstanceIds = {
        type        = "StringList"
        description = "List of EC2 Instance IDs."
      }
      Region = {
        type    = "String"
        default = "${data.aws_region.current.name}"
      }
      DuoIntegrationKey = {
        type        = "String"
        description = "Duo Integration Key."
      }
      DuoSecretKey = {
        type        = "String"
        description = "Duo Secret Key."
      }
      DuoApiHost = {
        type        = "String"
        description = "Duo API Hostname."
      }
    }
    mainSteps = [
      {
        name     = "InstallDependencies"
        action   = "aws:runCommand"
        inputs   = {
          DocumentName = "AWS-RunShellScript"
          InstanceIds  = "{{ InstanceIds }}"
          Parameters   = {
            commands = [
              "sudo yum install -y openssl-devel pam-devel gcc make",
              "mkdir -p /tmp/duo",
              "curl -o /tmp/duo/duo_unix.tar.gz https://dl.duosecurity.com/duo_unix-latest.tar.gz",
              "tar zxf /tmp/duo/duo_unix.tar.gz -C /tmp/duo/",
              "cd /tmp/duo/duo_unix-*",
              "./configure --with-pam --prefix=/usr && make && sudo make install"
            ]
          }
        }
      },
      {
        name     = "ConfigureDuoUnix"
        action   = "aws:runCommand"
        inputs   = {
          DocumentName = "AWS-RunShellScript"
          InstanceIds  = "{{ InstanceIds }}"
          Parameters   = {
            commands = [
              "sudo mkdir -p /etc/duo",
              "sudo tee /etc/duo/pam_duo.conf > /dev/null <<EOL",
              "[duo]",
              "ikey = {{ DuoIntegrationKey }}",
              "skey = {{ DuoSecretKey }}",
              "host = {{ DuoApiHost }}",
              "pushinfo = yes",
              "autopush = yes",
              "EOL"
            ]
          }
        }
      }
    ]
  })
}


sudo mkdir -p /etc/duo
sudo mv duo_unix-2.0.4/pam_duo/pam_duo.conf /etc/duo/pam_duo.conf

