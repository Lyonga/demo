#########################


resource "aws_ssm_document" "install_agents_linux" {
  name          = local.install_agents_doc_name
  document_type = "Automation"
  tags          = local.default_tags

  content = jsonencode({
    schemaVersion = "0.3",
    assumeRole    = var.assume_role_arn,
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



####################


Below is an **example user data script for Linux** that uses **PowerShell** (on Linux) plus the **AWS Tools for PowerShell** to download and install CrowdStrike, Rapid7, and Duo from an S3 bucket—similar to the Windows approach using `Read-S3Object`. This avoids calling the traditional AWS CLI. Instead, it relies on:

1. Installing **PowerShell** on Linux.  
2. Installing **AWS.Tools.S3** PowerShell module.  
3. Using `Read-S3Object` to pull installers from S3.  

We'll place environment variables into the user data so the script knows which bucket, CID, etc. to use—just like we did for Windows. 

---

## 1. The User Data Script (e.g. `linux_userdata.sh`)

Below is a single file that you can embed in your Terraform `user_data`. It’s written as a **Bash** script that installs PowerShell, then **switches** into PowerShell inline to run `Read-S3Object` and do the installations. Feel free to adapt package install steps depending on your distro (Amazon Linux 2, RHEL, Ubuntu, etc.):

```bash
#!/bin/bash
#
# This script runs at first boot on a Linux EC2 instance:
# 1. Installs PowerShell (cross-platform)
# 2. Installs AWS.Tools.S3
# 3. Uses Read-S3Object to download & install:
#    - CrowdStrike
#    - Rapid7
#    - Duo

set -e

echo "=== [Linux User Data] Installing dependencies... ==="

# Example: Amazon Linux 2 approach to installing PowerShell
# (Adjust if you're on Ubuntu, RHEL, etc.)
rpm --import https://packages.microsoft.com/keys/microsoft.asc
yum install -y https://packages.microsoft.com/config/rhel/7/packages-microsoft-prod.rpm
yum install -y powershell

echo "=== [Linux User Data] Installing AWS Tools for PowerShell... ==="
pwsh -Command 'Install-Module -Name AWS.Tools.S3 -Force -Confirm:$False'

# Now we embed a multi-line PowerShell script in a "here-doc" to do everything else:
pwsh <<'EOF'
Write-Host "=== [PowerShell in Linux] Starting script ==="

# 1. Read environment variables
$BucketName     = [System.Environment]::GetEnvironmentVariable("S3_BUCKET")
$CrowdstrikeCID = [System.Environment]::GetEnvironmentVariable("CROWDSTRIKE_CID")
$DuoIKEY        = [System.Environment]::GetEnvironmentVariable("DUO_IKEY")
$DuoSKEY        = [System.Environment]::GetEnvironmentVariable("DUO_SKEY")
$DuoApiHost     = [System.Environment]::GetEnvironmentVariable("DUO_APIHOST")

Write-Host "Bucket: $BucketName"
Write-Host "CrowdStrike CID: $CrowdstrikeCID"
Write-Host "Duo Host: $DuoApiHost"

New-Item -ItemType Directory -Path "/tmp/agents" -Force | Out-Null

########################################################
# 2. CrowdStrike
########################################################
Write-Host "Downloading CrowdStrike .rpm from S3..."
Read-S3Object -BucketName $BucketName -Key "agents/falcon-sensor.rpm" -File "/tmp/agents/falcon-sensor.rpm"

Write-Host "Installing CrowdStrike sensor..."
# We can just call Bash from PowerShell
Start-Process "bash" -ArgumentList "-c", "yum install -y /tmp/agents/falcon-sensor.rpm" -Wait
Start-Process "bash" -ArgumentList "-c", "/opt/CrowdStrike/falconctl -s --cid=$CrowdstrikeCID" -Wait
Start-Process "bash" -ArgumentList "-c", "systemctl enable falcon-sensor && systemctl start falcon-sensor" -Wait
Write-Host "CrowdStrike installation completed."

########################################################
# 3. Rapid7
########################################################
Write-Host "Downloading Rapid7 .rpm from S3..."
Read-S3Object -BucketName $BucketName -Key "agents/rapid7-insight-agent.rpm" -File "/tmp/agents/rapid7-insight-agent.rpm"

Write-Host "Installing Rapid7 agent..."
Start-Process "bash" -ArgumentList "-c", "yum install -y /tmp/agents/rapid7-insight-agent.rpm" -Wait
Start-Process "bash" -ArgumentList "-c", "systemctl enable ir_agent.service && systemctl start ir_agent.service" -Wait
Write-Host "Rapid7 installation completed."

########################################################
# 4. Duo
########################################################
Write-Host "Downloading Duo tarball from S3..."
Read-S3Object -BucketName $BucketName -Key "agents/duo_unix-2.0.4.tar.gz" -File "/tmp/agents/duo_unix-2.0.4.tar.gz"

Write-Host "Installing Duo..."
Start-Process "bash" -ArgumentList "-c", "yum install -y openssl-devel pam-devel selinux-policy-devel bzip2 gcc" -Wait
Start-Process "bash" -ArgumentList "-c", "tar -xzf /tmp/agents/duo_unix-2.0.4.tar.gz -C /tmp/agents/" -Wait
Start-Process "bash" -ArgumentList "-c", "cd /tmp/agents/duo_unix-2.0.4 && ./configure --prefix=/usr && make && make install" -Wait

# Configure /etc/duo/login_duo.conf
Start-Process "bash" -ArgumentList "-c", "mkdir -p /etc/duo" -Wait
'echo "[duo]" > /etc/duo/login_duo.conf' | Out-Null
Add-Content -Path /etc/duo/login_duo.conf -Value "ikey=$DuoIKEY"
Add-Content -Path /etc/duo/login_duo.conf -Value "skey=$DuoSKEY"
Add-Content -Path /etc/duo/login_duo.conf -Value "host=$DuoApiHost"
Add-Content -Path /etc/duo/login_duo.conf -Value "pushinfo = yes"
Add-Content -Path /etc/duo/login_duo.conf -Value "autopush = yes"

Write-Host "Duo installation completed."

Write-Host "=== [PowerShell in Linux] Done installing everything! ==="
EOF

echo "=== [Linux User Data] Completed. ==="
```

### Key Points

1. We **install PowerShell** first, using an example approach for Amazon Linux 2. If you’re on a different distro, you’ll need to adjust.  
2. We install the **AWS Tools for PowerShell** (`AWS.Tools.S3`) so we can call `Read-S3Object`.  
3. We pass environment variables (`S3_BUCKET`, `CROWDSTRIKE_CID`, etc.) from Terraform.  
4. We use **PowerShell** to `Read-S3Object` from S3 into `/tmp/agents/...`.  
5. We run Bash commands from PowerShell via `Start-Process "bash" -ArgumentList "-c", "<bash command>"` so we can use `yum install -y` or run other Linux-specific commands.

---

## 2. Inject Environment Variables from Terraform

In your **EC2 module**:

```hcl
resource "aws_instance" "linux_ec2" {
  ami           = var.ami_id
  instance_type = var.instance_type
  subnet_id     = var.subnet_id
  vpc_security_group_ids = var.security_group_ids

  # You must ensure your instance has an IAM role that allows S3 read access
  # if you want to read from your S3 bucket.

  user_data = <<-EOF
    #!/bin/bash

    # Export environment variables for the script
    export S3_BUCKET="${var.bucket_name}"
    export CROWDSTRIKE_CID="${var.crowdstrike_cid}"
    export DUO_IKEY="${var.duo_ikey}"
    export DUO_SKEY="${var.duo_skey}"
    export DUO_APIHOST="${var.duo_api_host}"

    # Now embed the rest of the script
    $(file("${path.module}/linux_userdata.sh"))
  EOF
}
```

### Explanation

1. We **export** environment variables right before including `linux_userdata.sh`.  
2. `${file("${path.module}/linux_userdata.sh")}` loads your script from the local file system.  
3. The instance boots, runs user data, sets environment variables, installs PowerShell, uses `Read-S3Object` to download & install the agents.

---

## 3. Passing Values from the Root Module

Finally, in your **root** (or environment) Terraform:

```hcl
module "linux_ec2" {
  source = "./modules/ec2/linux"

  ami_id           = var.linux_ami
  instance_type    = "t3.micro"
  subnet_id        = var.subnet_id
  security_group_ids = [aws_security_group.default.id]

  bucket_name      = var.agent_bucket
  crowdstrike_cid  = data.aws_ssm_parameter.crowdstrike_cid.value
  duo_ikey         = data.aws_ssm_parameter.duo_ikey.value
  duo_skey         = data.aws_ssm_parameter.duo_skey.value
  duo_api_host     = data.aws_ssm_parameter.duo_api_host.value
}
```

If you define `bucket_name`, `crowdstrike_cid`, etc. as variables in your EC2 module, Terraform will pass them into the user data environment variables, and your script can read them.

---

## 4. IAM Role for S3 Access

**Important**: The instance must have **permissions** to read from your S3 bucket. That typically means:

1. An IAM role with a policy like `s3:GetObject` on the relevant bucket key.  
2. Attach the role to the instance (`iam_instance_profile = ...`).  

Otherwise, `Read-S3Object` will fail with an AccessDenied error.

---

## Summary

- **Linux approach** is similar to Windows: we install cross-platform **PowerShell** on Linux, install `AWS.Tools.S3`, and use `Read-S3Object`.  
- We embed environment variables in `user_data`.  
- The script downloads & installs CrowdStrike, Rapid7, and Duo in a single flow—**no** AWS CLI usage.  
- This replicates the “SDK approach” you used for Windows, but on Linux.  

By combining these steps, you get a user data script that runs at boot, uses the AWS Tools for PowerShell, and installs your desired security agents without having to rely on the AWS CLI.



