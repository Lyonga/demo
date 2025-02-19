#############

Below is an overview of how you can structure your Terraform code to **cleanly separate** Linux‐specific modules from Windows‐specific modules—and still maintain a **central “hardening” repo** that other projects can reference. I’ll cover a couple of approaches for organizing both **EC2** (compute) modules and **SSM** modules, for Linux and Windows.

---

## 1. Central “Hardening” Repository Layout

In a **central** repository (let’s call it `terraform-aws-hardening`), you might have:

```
terraform-aws-hardening/
├── modules/
│   ├── ec2/
│   │   ├── linux/
│   │   │   ├── main.tf
│   │   │   ├── variables.tf
│   │   │   └── outputs.tf
│   │   ├── windows/
│   │   │   ├── main.tf
│   │   │   ├── variables.tf
│   │   │   └── outputs.tf
│   │   └── README.md
│   ├── ssm/
│   │   ├── linux/
│   │   │   ├── main.tf
│   │   │   ├── variables.tf
│   │   │   └── outputs.tf
│   │   ├── windows/
│   │   │   ├── main.tf
│   │   │   ├── variables.tf
│   │   │   └── outputs.tf
│   │   └── README.md
│   ├── cw-alarms/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── ...
├── examples/
│   ├── linux-ec2-usage/
│   ├── windows-ec2-usage/
│   └── ...
└── README.md
```

### Why Break It Down Like This?

1. **`modules/ec2/linux`**: Contains resources specifically for launching or hardening Linux EC2 instances (user data, package installs, AMI lookups, etc.).  
2. **`modules/ec2/windows`**: Same structure, but specialized for Windows EC2 (e.g., `user_data` with PowerShell, domain join using `aws:domainJoin`, Windows firewall config, etc.).  
3. **`modules/ssm/linux`**: SSM documents (Command or Automation) that reference Linux scripts (e.g., `aws:runShellScript`).  
4. **`modules/ssm/windows`**: SSM documents referencing Windows scripts (`aws:runPowerShellScript`).  
5. **`modules/cw-alarms`**: A shared module for CloudWatch alarms, independent of OS.

This **folder-based** approach keeps each OS’s logic separate, making it cleaner to evolve or patch one environment without risking the other.

---

## 2. EC2 Modules (Linux vs. Windows)

Each of the **EC2** submodules (e.g., `modules/ec2/linux` and `modules/ec2/windows`) might contain:

### 2.1 Linux EC2 Module

- **`main.tf`**: Defines resources like:
  - `aws_instance` (with user data or launch template referencing Linux user data scripts).
  - IAM roles specifically needed by Linux (like SSM or CloudWatch agent).
  - Possibly references a “base AMI” variable defaulting to a known Linux AMI.

- **`variables.tf`**:  
  - `ami_id` (with a default or required input).  
  - `instance_type`  
  - `subnet_id`, `security_group_ids`, etc.  
  - Possibly booleans or strings for things like “install CloudWatch agent for Linux,” “install additional packages,” etc.

- **`outputs.tf`**:  
  - `instance_id`, `public_ip`, etc.

### 2.2 Windows EC2 Module

- **`main.tf`**: Similar, but you might have:
  - `aws_instance` referencing Windows user data (PowerShell commands).
  - Possibly domain join logic using `aws_directory_service_*` resources or an SSM `aws:domainJoin` action.
  - A different base AMI default (e.g., a known Windows Server 2019 AMI).

- **`variables.tf`**:  
  - `windows_ami_id`, `domain_join`, `run_sysprep`, etc., as needed.

- **`outputs.tf`**: Same pattern—expose instance details.

The difference is all the OS-specific logic in the **`main.tf`** for Windows vs. Linux is separated into two submodules. This helps keep your code DRY and logically organized.

---

## 3. SSM Modules (Linux vs. Windows)

Similarly, you can put **all the SSM documents** for Linux under `modules/ssm/linux/` and all the SSM docs for Windows under `modules/ssm/windows/`.

### 3.1 Linux SSM Docs

- `main.tf` might define:
  - `aws_ssm_document.install_awscli_linux`
  - `aws_ssm_document.install_agents_linux`
  - Possibly a `aws_ssm_document.install_agents_linux_aarch64`
  - Each references `aws:runShellScript` in the doc content.

- `variables.tf` might hold:
  - `assume_role_arn` (for the SSM automation doc)
  - `s3_bucket_name`
  - `crowdstrike_cid`, etc.
  - `document_name` overrides or booleans to include/exclude certain docs.

- `outputs.tf`: Expose the doc names or ARNs if needed.

### 3.2 Windows SSM Docs

- `main.tf` might define:
  - `aws_ssm_document.install_awscli_windows` (using `aws:runPowerShellScript`).
  - `aws_ssm_document.install_agents_windows` (CrowdStrike, Rapid7, Duo, but adapted to Windows installers).
  - Possibly a doc to domain-join via `aws:domainJoin`.

- `variables.tf`:  
  - Windows-specific parameters, like `win_crowdstrike_install_exe`, `windows_ikey`, etc.

- `outputs.tf`: Expose doc names or ARNs.

---

## 4. Reference from Another Repo

Teams in other repos/projects can pick which OS modules they need. For example, in a downstream repo:

```hcl
module "hardened_ec2_linux" {
  source = "git::https://github.com/MyOrg/terraform-aws-hardening.git//modules/ec2/linux?ref=v1.0.0"

  ami_id             = "ami-0123456789abcdef0"
  subnet_id          = "subnet-0987654321"
  security_group_ids = ["sg-abcdef12"]
  # ...
}

module "ssm_docs_linux" {
  source = "git::https://github.com/MyOrg/terraform-aws-hardening.git//modules/ssm/linux?ref=v1.0.0"

  bucket_name      = "my-agents-bucket"
  assume_role_arn  = module.iam.automation_role_arn
  crowdstrike_cid  = data.aws_ssm_parameter.cs_cid.value
  # ...
}
```

And for Windows:

```hcl
module "hardened_ec2_windows" {
  source = "git::https://github.com/MyOrg/terraform-aws-hardening.git//modules/ec2/windows?ref=v1.0.0"

  windows_ami_id         = "ami-0fedcba9876543210"
  subnet_id              = "subnet-0123456789"
  security_group_ids     = ["sg-12345678"]
  domain_join            = true
  # ...
}

module "ssm_docs_windows" {
  source = "git::https://github.com/MyOrg/terraform-aws-hardening.git//modules/ssm/windows?ref=v1.0.0"

  # ...
}
```

They simply pick the OS submodules that match their environment needs.

---

## 5. Alternate Approaches

1. **Single EC2 Module with OS Switches**  
   You could have one `ec2` module that has `var.os_type = "linux" | "windows"` and toggles code accordingly via `count` or `for_each`. This can get messy if you have a lot of OS-specific logic (PowerShell vs. shell scripts, AMI lookups, domain join, etc.).

2. **Single SSM Module with OS Sub-Folders**  
   Similar to the above, you can do one module that *conditionally includes* OS-specific docs. But that can become a big file with many conditionals.

Often, **separating** them at the folder level is simpler to maintain.

---

## 6. Summarizing Best Practices

- **Separate OS-Specific Logic**:
  - Use subfolders `modules/ec2/linux` and `modules/ec2/windows`.
  - Same for `modules/ssm/linux` and `modules/ssm/windows`.
- **Parameterize** Distinctions:
  - Linux doc references `aws:runShellScript`, Windows doc references `aws:runPowerShellScript`.
  - Different AMIs or user data scripts for each OS in their respective modules.
- **Keep Common Modules OS-Agnostic**:
  - E.g., your CloudWatch alarms module, or an IAM module that just creates roles/policies, can be shared by both OS submodules.

---

## 7. Example “Root Module” In Your Hardening Repo

You might optionally keep a top-level environment directory that references both Linux and Windows modules for testing or demonstration:

```
terraform-aws-hardening/
├── environments/
│   ├── dev/
│   │   ├── main.tf
│   │   └── variables.tf
│   └── windows-demo/
│       └── main.tf
└── ...
```

In `environments/windows-demo/main.tf`, for instance:

```hcl
module "windows_ec2" {
  source = "../../modules/ec2/windows"

  windows_ami_id     = var.windows_ami_id
  instance_type      = var.instance_type
  subnet_id          = var.subnet_id
  security_group_ids = var.security_group_ids
  # ...
}

module "windows_ssm_docs" {
  source = "../../modules/ssm/windows"

  assume_role_arn = var.automation_role_arn
  bucket_name     = var.bucket_name
  # ...
}
```

You can run `terraform plan/apply` from that environment folder to create a Windows box and relevant SSM docs, purely for testing. Meanwhile, the actual downstream projects can pull the same modules from Git or a registry.

---

## Final Thoughts

1. **Structure** each OS’s logic in distinct subfolders to keep it clean.  
2. **Publish** or tag your central repo so other projects can reference the correct subfolder.  
3. **Keep shared concerns** (like IAM roles, CloudWatch alarms, or SSM parameter retrieval) in separate modules that do not depend on OS.  
4. If a consumer project is purely Windows, they just call the Windows submodules. If purely Linux, they call the Linux ones. Mixed environment? They can call both in the same Terraform config, referencing them under different module labels.

This approach scales well as your modules grow in complexity and you want to keep your code organized, DRY, and easy to maintain.
