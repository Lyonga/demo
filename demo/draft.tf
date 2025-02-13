########
Below is one **example** of how you could restructure your “ec2‐hardening” repository so that **other teams can reference individual modules** (such as an EC2 module, SSM documents module, SNS/CloudWatch alarms module, etc.). This helps keep your repo clean, **promotes reuse**, and still allows you to have a top‐level configuration if you want to deploy everything yourself.

---

## Proposed Folder Structure

```
ec2-hardening/
├── .github/           # CI/CD configs (if any)
├── .build_scripts/    # Scripts for building, linting, etc.
├── readme_images/
├── terraform/
│   ├── modules/
│   │   ├── ec2-hardened/
│   │   │   ├── main.tf
│   │   │   ├── variables.tf
│   │   │   └── outputs.tf
│   │   ├── ssm-documents/
│   │   │   ├── main.tf
│   │   │   ├── variables.tf
│   │   │   └── outputs.tf
│   │   ├── alarms/
│   │   │   ├── main.tf
│   │   │   ├── variables.tf
│   │   │   └── outputs.tf
│   │   └── sns/
│   │       ├── main.tf
│   │       ├── variables.tf
│   │       └── outputs.tf
│   ├── examples/
│   │   ├── basic/
│   │   │   ├── main.tf
│   │   │   └── providers.tf
│   │   └── advanced/
│   │       ├── main.tf
│   │       └── ...
│   ├── environment/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── backend_config/
│       └── ...
└── README.md
```

### Key Points

1. **`modules/`** Directory  
   - **`ec2-hardened/`**: Contains code to create a hardened EC2 instance (with SSM agent, IAM role, etc.).  
   - **`ssm-documents/`**: Contains Terraform code that creates or references SSM documents (e.g., installing agents, AWSCli).  
   - **`alarms/`**: Contains code for CloudWatch alarms (e.g., CPU usage, memory, etc.).  
   - **`sns/`**: Contains code for creating or wiring up SNS topics, subscriptions, etc.

2. **`examples/`** Directory  
   - **`basic/`**: A minimal usage example that references one or more of the modules.  
   - **`advanced/`**: A more complex example showing how to pass parameters (like instance type, custom scripts, region, etc.) and combine modules (ec2 + ssm + sns + alarms).

3. **`environment/`** Directory (Optional)  
   - If **you** want to deploy a particular environment from this repo, you can keep a “full stack” Terraform config in `environment/`. It references the modules exactly as your consumers would, but builds out the entire environment.

4. **`backend_config/`, `.github/`, `.build_scripts/`**  
   - You can retain any existing pipeline scripts, remote backend configs, or GitHub CI workflows here.  

With this structure, you have clear **boundaries** between your **reusable modules** (in `modules/`) and the **top‐level or example code** (in `environment/` or `examples/`).  

---

## Example of a Reusable EC2 Module

Below is a rough sketch of how the `ec2-hardened/main.tf` might look:

```hcl
// terraform/modules/ec2-hardened/main.tf

resource "aws_iam_role" "ec2_ssm_role" {
  # ...
}

resource "aws_iam_instance_profile" "ec2_profile" {
  # ...
}

resource "aws_instance" "hardened" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = var.security_group_ids
  iam_instance_profile        = aws_iam_instance_profile.ec2_profile.name
  associate_public_ip_address = var.associate_public_ip_address

  tags = merge(
    var.tags,
    { "Name" = var.name_prefix }
  )
}
```

Then, in `variables.tf`:

```hcl
variable "name_prefix" {
  type        = string
  description = "Prefix for naming the EC2 instance"
  default     = "hardened"
}

variable "ami_id" {
  type        = string
  description = "AMI ID for the hardened base image"
}

variable "instance_type" {
  type        = string
  description = "EC2 instance type"
  default     = "t3.micro"
}

variable "subnet_id" {
  type        = string
  description = "Subnet in which to launch the instance"
}

variable "security_group_ids" {
  type        = list(string)
  default     = []
}

variable "associate_public_ip_address" {
  type        = bool
  default     = false
}

variable "tags" {
  type        = map(string)
  default     = {}
}
```

---

## Consuming the Modules from Another Repo

If another project (in a **different repo**) wants to create a hardened EC2 instance plus an SSM document, they can do:

```hcl
// my-other-project/main.tf

module "hardened_ec2" {
  source = "git::https://github.com/YourOrg/ec2-hardening.git//terraform/modules/ec2-hardened?ref=v1.0.0"

  ami_id            = "ami-0123456789abcdef0"
  subnet_id         = "subnet-0987654321abc"
  security_group_ids = ["sg-123abc"]
  name_prefix       = "my-team-ec2"
}

module "my_ssm_docs" {
  source = "git::https://github.com/YourOrg/ec2-hardening.git//terraform/modules/ssm-documents?ref=v1.0.0"
  # pass variables relevant to the SSM docs module
}
```

Similarly, they could reference your `alarms` and `sns` modules. They only “pull in” the pieces they actually need.

---

## Why This Is Best Practice

1. **Clear Reusability**  
   Each module is self‐contained, with well‐defined inputs (`variables.tf`) and outputs. This makes it straightforward for other teams to pick and choose which pieces they want without pulling in the entire environment.

2. **Easier Maintenance**  
   - You can make changes or release new versions in each module.  
   - Teams can update references to `?ref=v1.1.0` when they’re ready to upgrade.  

3. **Consistent Hardening**  
   - Everyone calling your “ec2-hardened” module gets the same SSM agent, the same base IAM roles, etc.  
   - Security changes can roll out centrally.

4. **Organized Repository**  
   - The top‐level (like `environment/`) can remain your “example environment” or your “main deployment.”  
   - The `examples/` folder shows minimal or advanced usage for new adopters.  

---

### Summary

- **Create subfolders under `modules/`**: `ec2-hardened`, `ssm-documents`, `alarms`, `sns`.  
- **Keep each module’s logic** (i.e., `.tf` files) inside those subfolders, with a clear `variables.tf` and `outputs.tf`.  
- Provide **usage examples** in `examples/` so internal teams can quickly reference them.  
- If you also want to run everything from this repo, keep an **`environment/`** folder that references the modules, but do not mix environment code with your reusable module code.

This structure is a **tried‐and‐true best practice** for Terraform if your ultimate goal is to let external teams **reuse** your resources (EC2, SSM, SNS, alarms, etc.) in a modular and maintainable way.
