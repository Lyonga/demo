Here is one straightforward way to handle picking the correct AMI **and** the correct device name by OS. The main idea is:

1. Keep a small map of your default Windows and Linux AMIs.  
2. Use your `var.is_windows` boolean to pick either the Windows AMI or the Linux AMI.  
3. Likewise use `var.is_windows` to pick the correct volume/device name.

Below is an example refactoring that uses a local variable `final_ami` to decide which AMI to use if you have not explicitly passed in an AMI override. It also shows how to pick device names conditionally.

```hcl
#######################
# locals.tf
#######################
locals {
  supported_amis = {
    "windows" = "ami-00cd4d5d7df22d982"
    "linux"   = "ami-032c672ba2c1e9bbf"
  }

  # If you allow the user to override the AMI with a variable, coalesce that with your default
  final_ami = var.is_windows 
    ? coalesce(var.windows_ami, local.supported_amis["windows"]) 
    : coalesce(var.linux_ami,   local.supported_amis["linux"])

  # Likewise pick the correct block-device name
  final_device_name = var.is_windows 
    ? var.windows_volume_name 
    : var.linux_volume_name
}

#######################
# variables.tf
#######################
variable "is_windows" {
  type        = bool
  description = "If set to true, launches a Windows EC2. Otherwise Linux."
  default     = false
}

variable "windows_ami" {
  type        = string
  description = "Optional override for the Windows AMI."
  default     = ""
}

variable "linux_ami" {
  type        = string
  description = "Optional override for the Linux AMI."
  default     = ""
}

variable "windows_volume_name" {
  type        = string
  description = "Block device name for Windows volumes."
  default     = "/dev/sda1"
}

variable "linux_volume_name" {
  type        = string
  description = "Block device name for Linux volumes."
  default     = "/dev/xvda"
}

#######################
# main.tf
#######################
resource "aws_launch_template" "os_instance_launch_template" {
  name                             = local.linux_launch_template_name
  image_id                         = local.final_ami
  instance_type                    = var.ec2_instance_type
  key_name                         = var.ec2_instance_key_name
  instance_initiated_shutdown_behavior = "terminate"

  monitoring {
    enabled = true
  }

  block_device_mappings {
    device_name = local.final_device_name
    ebs {
      volume_size           = 8
      volume_type           = "gp3"
      delete_on_termination = true
      encrypted             = true
      kms_key_id            = var.ebs_kms_key_arn
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags = merge(
      {
        Name = "${var.stack_name}-${var.environment_name}-ec2-launch_template"
      },
      local.default_tags
    )
  }

  tag_specifications {
    resource_type = "volume"
    tags = merge(
      {
        Name = "${var.stack_name}-${var.environment_name}-ec2-ebs_volume"
      },
      local.default_tags
    )
  }

  metadata_options {
    http_tokens   = "required"
    http_endpoint = "enabled"
    http_put_response_hop_limit = 1
  }
}

resource "aws_instance" "os_ec2" {
  ami               = aws_launch_template.os_instance_launch_template.image_id
  instance_type     = aws_launch_template.os_instance_launch_template.instance_type
  subnet_id         = var.vpc_ec2_subnet1
  availability_zone = var.availability_zone
  key_name          = aws_launch_template.os_instance_launch_template.key_name
  iam_instance_profile = var.iam_instance_profile
  ebs_optimized     = true
  vpc_security_group_ids = [var.security_group_id]

  launch_template {
    id      = aws_launch_template.os_instance_launch_template.id
    version = aws_launch_template.os_instance_launch_template.latest_version
  }

  lifecycle {
    ignore_changes = [
      ebs_optimized,
      hibernation,
      security_groups,
      monitoring,
      root_block_device,
      tags_all,
      launch_template,
      credit_specification,
      network_interface,
      iam_instance_profile
    ]
  }

  tags = merge(
    {
      Name      = "${var.stack_name}-${var.environment_name}-ec2-instance"
      DomainJoin = "true"
    },
    local.default_tags
  )
}
```

### Key points in the example

- **Local `supported_amis`**: A simple map containing your default Windows and Linux AMIs.  
- **Local `final_ami`**: Uses `is_windows` to decide which of the supported AMIs to use. If you also allow users to specify their own AMI, you can layer in `coalesce(var.windows_ami, local.supported_amis["windows"])` to let them override.
- **Local `final_device_name`**: Picks the correct device name for Windows vs. Linux.  
- The `aws_launch_template` and `aws_instance` resources just reference those locals so they “automatically” update for whichever OS you are launching.  

This pattern (a local `final_ami` or `final_device_name` that depends on `is_windows`) is generally the simplest way to keep your plan DRY, keep everything typed correctly, and allow for minimal updates when new AMIs become available.







#############################


If you simply want to default to the **first** AMI in each OS’s list (e.g., `supported_amis["linux"][0]` or `supported_amis["windows"][0]`) while still allowing for a full list of AMIs, you can do something like:

```hcl
locals {
  supported_amis = {
    "windows" = [
      "ami-00cd4d5d7df22d982",   # first = default
      "ami-0fffffffffffffff"
    ],
    "linux" = [
      "ami-032c672ba2c1e9bbf",   # first = default
      "ami-0b4624933067d393a"
    ]
  }

  # If you don't have a custom var override, just default to the first AMI in the OS's list.
  final_ami = var.is_windows
    ? local.supported_amis["windows"][0]
    : local.supported_amis["linux"][0]

  # Similarly pick the correct block-device name for the OS
  final_device_name = var.is_windows
    ? var.windows_volume_name
    : var.linux_volume_name
}
```

### If you still want user overrides

If you also want to let a user supply a custom AMI, keep a variable for it, then fallback to that first element:

```hcl
variable "override_ami" {
  type        = string
  default     = "" 
  description = "Optional user-supplied AMI. If empty, defaults to the first OS-appropriate AMI."
}

locals {
  supported_amis = {
    "windows" = [
      "ami-00cd4d5d7df22d982",   # first = default
      "ami-0fffffffffffffff"
    ],
    "linux" = [
      "ami-032c672ba2c1e9bbf",   # first = default
      "ami-0b4624933067d393a"
    ]
  }

  # If override_ami is provided, use it. Otherwise default to the first in the OS list.
  final_ami = length(var.override_ami) > 0
    ? var.override_ami
    : (
        var.is_windows
          ? local.supported_amis["windows"][0]
          : local.supported_amis["linux"][0]
      )

  final_device_name = var.is_windows
    ? var.windows_volume_name
    : var.linux_volume_name
}
```

Then you just reference `local.final_ami` wherever you need your AMI:

```hcl
resource "aws_launch_template" "example" {
  image_id = local.final_ami
  # ...
}
```

This approach ensures you always default to the first AMI in your list, yet still have the ability to override it if you need to.
