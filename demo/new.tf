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









#################

Below is an example showing how to **refactor** your SSM documents (which install AWS CLI and security agents) into a **dedicated “ssm-docs” module**, then **reuse** them from your root module. We’ll also discuss how to handle the **assumeRole** (i.e. `aws_iam_role.automation_role.arn`) in a simple but flexible manner.

---

## 1. Create an SSM Module

Let’s assume you place these resources in a folder like `modules/ssm-docs/`:

```
modules/
  └── ssm-docs/
      ├── main.tf
      ├── variables.tf
      └── outputs.tf
```

### 1.1 `modules/ssm-docs/main.tf`

We move your **aws_ssm_document** resources (install AWS CLI, install agents) into this file. We parameterize a few items (like the bucket name, region, the role ARN) so you can pass them in from the root module.

```hcl
////////////////////////////////////////////////////////////////////////
// modules/ssm-docs/main.tf
////////////////////////////////////////////////////////////////////////

resource "aws_ssm_document" "install_awscli_linux" {
  name          = var.awscli_doc_name
  document_type = "Automation"
  tags          = var.default_tags

  content = jsonencode({
    schemaVersion = "0.3",
    description   = "Install AWS CLI on Linux instances.",
    # For simplicity, assume no assumeRole here. If needed, add "assumeRole = var.assume_role_arn".
    parameters    = {
      InstanceIds = { type = "StringList", description = "List of EC2 Instance IDs." }
      Region      = { type = "String", default = var.aws_region }
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
  name          = var.install_agents_doc_name
  document_type = "Automation"
  tags          = var.default_tags

  # If you want a role, e.g. "assumeRole = var.assume_role_arn", put it here:
  content = jsonencode({
    schemaVersion = "0.3",
    assumeRole    = var.assume_role_arn,  # param or default to ""
    description   = "Install security agents on Linux EC2 instances.",
    parameters    = {
      InstanceIds    = { type = "StringList", description = "List of EC2 Instance IDs." }
      S3BucketName   = { type = "String", description = "S3 bucket containing the installers.", default = var.bucket_name }
      Region         = { type = "String", default = var.aws_region }
      CrowdStrikeCID = { type = "String", description = "CrowdStrike CID for sensor installation.", default = var.crowdstrike_cid }
      DuoIKEY        = { type = "String", description = "Duo integration key.", default = var.duo_ikey }
      DuoSKEY        = { type = "String", description = "Duo secret key.", default = var.duo_skey }
      DuoApiHost     = { type = "String", description = "Duo host address.", default = var.duo_api_host }
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
              "aws s3 cp s3://{{ S3BucketName }}/agents/falcon-sensor-7.16.0-16903.amzn2023.x86_64.rpm /tmp/agents/falcon-sensor.rpm",
              "if [ ! -f /tmp/agents/falcon-sensor.rpm ]; then",
              "  echo 'falcon-sensor.rpm not found. Exiting.'",
              "  exit 1",
              "fi",
              "sudo rpm -ivh /tmp/agents/falcon-sensor.rpm",
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
              "aws s3 cp s3://{{ S3BucketName }}/agents/rapid7-insight-agent-4.0.13.32-1.x86_64.rpm /tmp/agents/r7.rpm",
              # ...
              "sudo rpm -ivh /tmp/agents/r7.rpm",
              "echo 'Rapid7 installed.'"
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
              # ...
              "echo 'ikey={{ DuoIKEY }}' | sudo tee -a /etc/duo/login_duo.conf",
              "echo 'skey={{ DuoSKEY }}' | sudo tee -a /etc/duo/login_duo.conf",
              "echo 'host={{ DuoApiHost }}' | sudo tee -a /etc/duo/login_duo.conf",
              "echo 'Duo installation completed successfully.'"
            ]
          }
        }
      }
    ]
  })
}

# (Optional) Another doc for syxsense, or you can keep them separate:
resource "aws_ssm_document" "install_agents_linuxV1" {
  name          = var.install_agents_aarch64_doc_name
  document_type = "Automation"
  tags          = var.default_tags

  content = jsonencode({
    schemaVersion = "0.3",
    assumeRole    = var.assume_role_arn,
    description   = "Install security agents on aarch64 Linux EC2 instances.",
    parameters    = {
      InstanceIds           = { type = "StringList", description = "List of EC2 Instance IDs." }
      S3BucketName          = { type = "String", description = "S3 bucket containing the installers.", default = var.bucket_name }
      Region                = { type = "String", default = var.aws_region }
      SyxsenseInstanceName  = { type = "String", description = "linux instance name to be installed." }
    },
    mainSteps = [
      # ...
    ]
  })
}
```

### 1.2 `modules/ssm-docs/variables.tf`

We define variables for bucket name, region, doc names, etc. Also for the automation role ARN if needed:

```hcl
////////////////////////////////////////////////////////////////////////
// modules/ssm-docs/variables.tf
////////////////////////////////////////////////////////////////////////

variable "awscli_doc_name" {
  type        = string
  description = "Name of the AWS CLI Linux doc"
  default     = "Ngl-AwsCli-LinuxDocument"
}

variable "install_agents_doc_name" {
  type        = string
  description = "Name for the Crowdstrike-Duo-Rapid7 doc"
  default     = "Crowdstrike-Duo-Rapid7-LinuxOs-x86-64"
}

variable "install_agents_aarch64_doc_name" {
  type        = string
  description = "Name for the Rapid7-Syxsense aarch64 doc"
  default     = "Rapid7-Syxsense-LinuxOs-aarch64-install"
}

variable "bucket_name" {
  type        = string
  description = "S3 bucket containing installers"
}

variable "aws_region" {
  type        = string
  description = "AWS region for default doc param"
  default     = "us-east-1"
}

variable "default_tags" {
  type        = map(string)
  description = "Common tags to apply"
  default     = {}
}

variable "assume_role_arn" {
  type        = string
  description = "Automation role ARN if needed"
  default     = ""
}

# If you want to pass parameters from Parameter Store, do so:
variable "crowdstrike_cid" {
  type        = string
  default     = ""
}

variable "duo_ikey" {
  type        = string
  default     = ""
}

variable "duo_skey" {
  type        = string
  default     = ""
}

variable "duo_api_host" {
  type        = string
  default     = ""
}
```

### 1.3 `modules/ssm-docs/outputs.tf` (Optional)

If you want to expose SSM doc names or ARNs:

```hcl
output "awscli_doc_name_out" {
  description = "Name of the AWS CLI doc"
  value       = aws_ssm_document.install_awscli_linux.name
}

output "install_agents_doc_name_out" {
  description = "Name of the Crowdstrike-Duo-Rapid7 doc"
  value       = aws_ssm_document.install_agents_linux.name
}

# etc. ...
```

---

## 2. Reuse It in the Root Module

Now, in your **root or environment** Terraform (where you define `main.tf`), you can call:

```hcl
module "ssm_docs" {
  source = "./modules/ssm-docs"

  bucket_name      = var.bucket_name
  aws_region       = var.aws_region
  default_tags     = local.default_tags

  # If you have an automation role ARN you want to use:
  assume_role_arn = module.iam_role.automation_role_arn

  # If you fetch Duo or CrowdStrike from Parameter Store in the root:
  crowdstrike_cid = data.aws_ssm_parameter.crowdStrike_cid.value
  duo_ikey        = data.aws_ssm_parameter.duo_ikey.value
  duo_skey        = data.aws_ssm_parameter.duo_skey.value
  duo_api_host    = data.aws_ssm_parameter.duo_api_host.value
}
```

### Explanation

1. **`source = "./modules/ssm-docs"`**: Tells Terraform to look in your new module folder.  
2. **`assume_role_arn`**: We pass in the ARN. If you define your `automation_role` in an IAM module, you might do `assume_role_arn = module.iam.automation_role_arn`.  
3. **Parameter Store Data**: In the root module, you might define data resources:
   ```hcl
   data "aws_ssm_parameter" "duo_ikey" {
     name            = "/ngl/duo/ikey"
     with_decryption = true
   }
   ```
   Then pass `duo_ikey = data.aws_ssm_parameter.duo_ikey.value` to the SSM module.

---

## 3. Variables or Outputs in the SSM Module

### A. **Which Variables?**

- **`assume_role_arn`:** If you need your documents to run with a specific role, pass the ARN from outside. This is more flexible (and simpler) than creating the role *inside* the same module. That way, if different teams want different roles, they can pass whichever ARN they need.
- **`crowdstrike_cid`, `duo_ikey`, `duo_skey`, etc.:** These are best as variables, so each environment can provide unique secrets or references from Parameter Store.

### B. **Which Outputs?**

- You may want to output the **SSM doc names** or ARNs if you plan to do an SSM association or an `aws ssm start-automation-execution` from another place.
- If you’re not referencing them further, you might not need outputs at all.

---

## 4. About the `assumeRole` (Where to Create It?)

You asked: *“Should we create the role in the SSM module or in the IAM module?”*

### Option 1: Create It **Inside** the SSM Module

- **Pro:** Simplifies usage if you never want to change the role. Everything is in one place.  
- **Con:** Less flexible if other teams need a different role, or if you have multiple SSM docs requiring distinct roles.

### Option 2: Create It in an **IAM** Module, Pass the ARN to SSM

- **Pro:** More flexible, especially if you have a standard “automation_role” used for multiple SSM docs across the org.  
- **Con:** Slightly more code to wire them together, but minimal.  

**Recommendation**: Usually it’s simpler in a large org to have a **standard IAM module** that creates “SSM Automation Roles” or “EC2 Roles,” etc. Then you pass the relevant ARN to each module that needs it. This is more scalable than burying the role in every module.

---

## Putting It All Together

1. **Extract** your SSM doc resources into a module.  
2. **Parameterize** anything that can differ across environments: doc names, S3 bucket, region, DUO/CrowdStrike secrets, etc.  
3. **Pass** an existing role’s ARN if needed (instead of defining the role in the same module).  
4. **Consume** this module in your root config. Provide the needed variables (like secrets from Parameter Store).  
5. (Optional) **Export** SSM doc names or ARNs if you need them in an association or `start-automation-execution`.

This approach keeps your SSM doc definitions neatly organized in one place, but still flexible enough to handle different environment requirements.
