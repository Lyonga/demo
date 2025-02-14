

Below is an illustrative example of how you can structure a **“compute” module** that creates an EC2 instance (or launch template) and pulls the IAM instance profile from a **separate IAM module**. In this scenario:

1. We have one module folder called `modules/iam/` that outputs an instance profile name (or ARN).  
2. We have another folder called `modules/compute/` (or `ec2-hardened/`) that references the IAM module to retrieve the IAM instance profile, then applies it to the launch template or EC2 resource.

---

## 1. IAM Module

**Folder**: `modules/iam/`

For illustration, this module creates an IAM role and an instance profile. It **outputs** the instance profile name so other modules can use it.

### `modules/iam/main.tf`

```hcl
////////////////////////////////////////////////////////////////////////
// modules/iam/main.tf
////////////////////////////////////////////////////////////////////////

resource "aws_iam_role" "ec2_role" {
  name               = var.iam_role_name
  assume_role_policy = data.aws_iam_policy_document.assume_ec2.json
  tags               = var.tags
}

data "aws_iam_policy_document" "assume_ec2" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "attach_ssm" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = var.iam_instance_profile_name
  role = aws_iam_role.ec2_role.name
  tags = var.tags
}
```

### `modules/iam/variables.tf`

```hcl
variable "iam_role_name" {
  type        = string
  description = "Name for the IAM role"
  default     = "my-ec2-role"
}

variable "iam_instance_profile_name" {
  type        = string
  description = "Name for the IAM instance profile"
  default     = "my-ec2-instance-profile"
}

variable "tags" {
  type    = map(string)
  default = {}
}
```

### `modules/iam/outputs.tf`

```hcl
output "instance_profile_name" {
  description = "The IAM instance profile name for the EC2"
  value       = aws_iam_instance_profile.ec2_instance_profile.name
}
```

---

## 2. Compute (EC2) Module

**Folder**: `modules/compute/` (or `ec2-hardened/`)

In this module, we **call** the IAM module internally to create or retrieve the instance profile. Then we apply that instance profile to the launch template or EC2 instance.

### `modules/compute/main.tf`

```hcl
////////////////////////////////////////////////////////////////////////
// modules/compute/main.tf
////////////////////////////////////////////////////////////////////////

# 1. Call the IAM module to get or create the instance profile
module "iam_profile" {
  source = "../iam"

  iam_role_name             = var.iam_role_name
  iam_instance_profile_name = var.iam_instance_profile_name
  tags                      = var.tags
}

# 2. Create a launch template that references the instance profile
resource "aws_launch_template" "this" {
  name          = var.launch_template_name
  image_id      = var.ami_id
  instance_type = var.instance_type
  key_name      = var.key_name

  iam_instance_profile {
    name = module.iam_profile.instance_profile_name
  }

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = var.volume_size
      volume_type           = var.volume_type
      delete_on_termination = true
      encrypted             = true
      kms_key_id            = var.ebs_kms_key_id
    }
  }

  # Additional config, e.g. metadata_options, tags, etc.
  # ...
}

# 3. (Optional) Create an actual EC2 instance if you want to demonstrate usage
resource "aws_instance" "this" {
  ami           = var.ami_id
  instance_type = var.instance_type
  subnet_id     = var.subnet_id

  launch_template {
    id      = aws_launch_template.this.id
    version = "$Latest"
  }

  tags = merge(
    { Name = var.ec2_name_prefix },
    var.tags
  )
}
```

### `modules/compute/variables.tf`

```hcl
variable "launch_template_name" {
  type        = string
  default     = "my-launch-template"
}

variable "ami_id" {
  type        = string
  description = "The AMI to use for the EC2 instance."
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "key_name" {
  type    = string
  default = ""
}

variable "volume_size" {
  type    = number
  default = 8
}

variable "volume_type" {
  type    = string
  default = "gp3"
}

variable "ebs_kms_key_id" {
  type    = string
  default = ""
}

variable "subnet_id" {
  type        = string
  description = "Subnet for the instance."
  default     = ""
}

variable "ec2_name_prefix" {
  type        = string
  description = "Prefix for the EC2 instance name."
  default     = "my-ec2"
}

variable "tags" {
  type    = map(string)
  default = {}
}

# Variables passed to IAM module
variable "iam_role_name" {
  type        = string
  default     = "my-ec2-role"
}

variable "iam_instance_profile_name" {
  type        = string
  default     = "my-ec2-instance-profile"
}
```

### `modules/compute/outputs.tf`

```hcl
output "launch_template_id" {
  description = "The ID of the launch template"
  value       = aws_launch_template.this.id
}

output "ec2_id" {
  description = "The ID of the EC2 instance (if created in this module)"
  value       = aws_instance.this.id
}
```

---

## 3. Using the `modules/compute` Module in Your Environment

Finally, in your environment’s `main.tf` (for dev, QA, etc.):

```hcl
module "my_ec2" {
  source = "../modules/compute"

  launch_template_name = "dev-my-template"
  ami_id               = "ami-0abcdef1234567890"
  instance_type        = "t3.micro"
  subnet_id            = "subnet-0123456789abcdef0"
  key_name             = "my-ssh-key"

  # Pass any IAM details:
  iam_role_name             = "my-ec2-role"
  iam_instance_profile_name = "my-ec2-profile"

  tags = {
    Owner       = "DevTeam"
    Environment = "dev"
  }
}
```

**Terraform** will:

1. Enter `modules/compute/`, see you reference `module.iam_profile` from `../iam`, create the IAM role & instance profile there,  
2. Then create a launch template using that instance profile,  
3. Optionally create a direct `aws_instance` using that launch template (if your code is structured that way),  
4. Output the instance ID or launch template ID if needed.

---

## Key Takeaways

1. **One “parent” module** (`compute` or `ec2-hardened`) can **call** a **child** module (`iam/`) to create or retrieve an IAM instance profile.  
2. Within the **child** module, output the necessary attribute (such as `instance_profile_name`) and use it in the parent’s resources.  
3. In your top-level environment code, you reference **only** the “parent” module. Terraform automatically resolves the nested module calls.

This pattern keeps your code modular:
- **`modules/iam/`** is reusable for other roles or instance profiles, 
- **`modules/compute/`** is your main “compute” logic, 
- **`module "my_ec2"`** is where you pass environment‐specific variables (like AMI, subnets, tags).
