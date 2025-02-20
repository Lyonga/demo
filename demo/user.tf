###################
Below is a **complete example** demonstrating **Option 1** (embedding a PowerShell user data script inline, plus references to an external `.ps1` file) that installs **three tools**—CrowdStrike, Rapid7, and Duo—on a **Windows EC2 instance at launch**. This example:

1. Defines a **user data** block in your Windows EC2 module.  
2. Sets **environment variables** (bucket name, CrowdStrike CID, etc.) so the PowerShell script can read them.  
3. **Includes** an external `windows_userdata.ps1` that installs all three tools from S3.

---

## 1. Directory Structure

A typical repo might look like this:

```
my-terraform-repo/
├── modules/
│   └── ec2/
│       └── windows/
│           ├── main.tf
│           ├── variables.tf
│           └── outputs.tf
├── scripts/
│   └── windows_userdata.ps1
└── main.tf  (root module)
```

- **`scripts/windows_userdata.ps1`**: PowerShell script that’s injected into user data.  
- **`modules/ec2/windows/`**: Contains your Windows EC2 module code (`main.tf`, `variables.tf`).  
- **`main.tf`** (in the root): References the Windows module.

---

## 2. `windows_userdata.ps1` (PowerShell Script)

Create a file `scripts/windows_userdata.ps1` with the following contents:

```powershell
<powershell>
Write-Host "Starting Windows user data script..."

# 1. Install AWS Tools for PowerShell
Write-Host "Installing AWS Tools for PowerShell..."
Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Confirm:$False
Install-Module AWS.Tools.S3 -Force -Confirm:$False

# Pull environment variables (injected by Terraform) for bucket and credentials
$BucketName     = $env:BUCKET_NAME
$CrowdstrikeCID = $env:CROWDSTRIKE_CID
$DuoIKEY        = $env:DUO_IKEY
$DuoSKEY        = $env:DUO_SKEY
$DuoApiHost     = $env:DUO_API_HOST

# Create a scripts folder
New-Item -ItemType Directory -Path "C:\Scripts" -Force | Out-Null

#######################################
# 1. Install CrowdStrike
#######################################
Write-Host "Downloading CrowdStrike from S3..."
Read-S3Object -BucketName $BucketName -Key "agents\CROWDSTRIKE.EXE" -File "C:\Scripts\CROWDSTRIKE.EXE"

Write-Host "Installing CrowdStrike..."
Start-Process "C:\Scripts\CROWDSTRIKE.EXE" -ArgumentList "/install","/quiet","/norestart","CID=$CrowdstrikeCID" -Wait
Write-Host "CrowdStrike installation completed."

#######################################
# 2. Install Rapid7
#######################################
Write-Host "Downloading Rapid7 from S3..."
Read-S3Object -BucketName $BucketName -Key "agents\RAPID7_X86_64.MSI" -File "C:\Scripts\RAPID7_X86_64.MSI"

Write-Host "Installing Rapid7..."
Start-Process msiexec.exe -ArgumentList "/i","C:\Scripts\RAPID7_X86_64.MSI","/qn" -Wait
Write-Host "Rapid7 installation completed."

#######################################
# 3. Install Duo
#######################################
Write-Host "Downloading Duo from S3..."
Read-S3Object -BucketName $BucketName -Key "agents\DUOWINDOWSLOGON64.MSI" -File "C:\Scripts\DUOWINDOWSLOGON64.MSI"

Write-Host "Installing Duo..."
$duoArgs = "/i C:\Scripts\DUOWINDOWSLOGON64.MSI IKEY=$DuoIKEY SKEY=$DuoSKEY HOST=$DuoApiHost AUTOPUSH='#0' FAILOPEN='#0' SMARTCARD='#0' RDPONLY='#0' USERNAMEFORMAT='0' /passive"
Start-Process msiexec.exe -ArgumentList $duoArgs -Wait
Write-Host "Duo installation completed."

Write-Host "All tools installed via Windows user data script."
</powershell>
```

### Notes

- **Install AWS Tools for PowerShell** so we can do `Read-S3Object`.  
- Reads `$BucketName`, `$CrowdstrikeCID`, `$DuoIKEY`, `$DuoSKEY`, etc. from environment variables (we’ll set these in Terraform).  
- **Three Tools**: 
  - CrowdStrike -> `CROWDSTRIKE.EXE`  
  - Rapid7 -> `RAPID7_X86_64.MSI`  
  - Duo -> `DUOWINDOWSLOGON64.MSI`  

---

## 3. Windows EC2 Module

### 3.1 `variables.tf`

In `modules/ec2/windows/variables.tf`, define the variables for your instance plus the parameters needed for the user data script:

```hcl
variable "ami_id" {
  type        = string
  description = "Windows AMI ID"
}

variable "instance_type" {
  type        = string
  default     = "t3.medium"
}

variable "bucket_name" {
  type        = string
  description = "Name of the S3 bucket with installers"
}

variable "crowdstrike_cid" {
  type        = string
  description = "CrowdStrike CID"
}

variable "duo_ikey" {
  type        = string
  description = "Duo integration key"
}

variable "duo_skey" {
  type        = string
  description = "Duo secret key"
}

variable "duo_api_host" {
  type        = string
  description = "Duo host address"
}

variable "subnet_id" {
  type        = string
  description = "Subnet ID where the instance will be placed"
}

variable "security_group_ids" {
  type        = list(string)
  description = "List of security groups"
  default     = []
}

variable "key_name" {
  type        = string
  default     = ""
}
```

### 3.2 `main.tf`

In `modules/ec2/windows/main.tf`, reference the external PowerShell script (`windows_userdata.ps1`) and set environment variables **inline**:

```hcl
resource "aws_instance" "windows_ec2" {
  ami           = var.ami_id
  instance_type = var.instance_type
  subnet_id     = var.subnet_id

  # If you want multiple SGs, you can do var.security_group_ids
  vpc_security_group_ids = var.security_group_ids

  key_name      = var.key_name

  # Embed the user data using a heredoc and environment variables
  user_data = <<-EOF
    <powershell>
    # 1. Set environment variables so the script can access them
    [Environment]::SetEnvironmentVariable("BUCKET_NAME", "${var.bucket_name}", "Machine")
    [Environment]::SetEnvironmentVariable("CROWDSTRIKE_CID", "${var.crowdstrike_cid}", "Machine")
    [Environment]::SetEnvironmentVariable("DUO_IKEY", "${var.duo_ikey}", "Machine")
    [Environment]::SetEnvironmentVariable("DUO_SKEY", "${var.duo_skey}", "Machine")
    [Environment]::SetEnvironmentVariable("DUO_API_HOST", "${var.duo_api_host}", "Machine")

    # 2. Inject the external script contents
    ${file("${path.module}/../../scripts/windows_userdata.ps1")}
    </powershell>
  EOF

  tags = {
    Name = "Windows-Tools-Instance"
  }
}
```

> **Note:**  
> - We use `file("${path.module}/../../scripts/windows_userdata.ps1")` (or adjust path if it’s in a different place).  
> - `path.module` references the location of the current Terraform module. We go “up two folders” if needed. Double-check your folder structure to ensure this path is correct.

---

## 4. Root Module Usage

In your **root** Terraform code (e.g., `main.tf` at the project root):

```hcl
provider "aws" {
  region = "us-east-1"
}

module "windows_ec2" {
  source              = "./modules/ec2/windows"
  ami_id              = "ami-0abcdef1234567890"
  instance_type       = "t3.medium"
  bucket_name         = "my-agents-bucket"
  crowdstrike_cid     = "ABC123-XXXX"
  duo_ikey            = "duo-ikey-123"
  duo_skey            = "duo-skey-456"
  duo_api_host        = "api-XXXXXXXX.duosecurity.com"
  subnet_id           = "subnet-0abc123def"
  security_group_ids  = ["sg-12345678"]
  key_name            = "my-windows-key"
}
```

Then run:

```bash
terraform init
terraform plan
terraform apply
```

When the instance launches, it will:

1. Run the embedded **user data** block.  
2. Set environment variables for the PowerShell script.  
3. Download the `.ps1` script content into user data.  
4. Install CrowdStrike, Rapid7, and Duo from S3 on first boot.

---

## 5. Summary

1. **Store** your user data script in a separate `.ps1` file (`windows_userdata.ps1`).
2. **Inject** environment variables in the `user_data` block (like `BUCKET_NAME`, `CROWDSTRIKE_CID`, etc.).
3. **Use** `file("...")` to import the PowerShell file’s contents directly into the user data for the Windows EC2 instance.
4. **At boot**, Windows executes the script, installing AWS Tools for PowerShell, pulling installers from S3, and silently installing CrowdStrike, Rapid7, and Duo.

This approach keeps your Windows user data logic **clean and modular** while letting you parameterize and override specifics (like bucket name, keys, etc.) from your root module.
