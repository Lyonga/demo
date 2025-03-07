- windows_ec2 in modules/compute/windows
- windows_ssm_docs in modules/ssm-documents/windows
╷
│ Error: Argument or block definition required
│ 
│   on modules/compute/variables.tf line 85, in locals:
│   85:     ? var.override_ami
│ 
│ An argument or block definition is required here.
╵

╷
│ Error: Argument or block definition required
│ 
│   on modules/compute/windows/variables.tf line 86, in locals:
│   86:     ? var.override_ami
│ 
│ An argument or block definition is required here.
╵

Error: Process completed with exit code 1.


variable "product_name" {
  type        = string
  description = "name of the product for resources"
  default     = "spaceport"
}

variable "project_name" {
  type        = string
  description = "name of the project for resources"
  default     = "traverse" 
}

variable "service_name" {
  type        = string
  description = "name of the service for resources"
  default     = "infrastructure-tools"
}

variable "environment_name" {
  type        = string
  description = "name of the environment where resources are deployed"
  validation {
    condition     = contains(["dev", "qa", "prod"], var.environment_name)
    error_message = "Value must be one of the following: ['dev', 'qa', 'prod']"
  }
  default     = "dev"
}

locals {
  prefix = var.service_name
  instance_security_group = "${var.stack_name}-ec2-security-group"
  ec2_launch_template_name = "${var.stack_name}-ec2-launch-template"
  linux_launch_template_name = "${var.stack_name}-linux-server-launch-template"
  instance_iam_profile = "${var.stack_name}-ec2-instance-profile"
  linux_adjoin_name = "${var.stack_name}-lunux-domain-join"
  instance_auto_recovery_alarm-name = "${var.stack_name}-instance-autorecovery-alarm"
  system_status_check_alarm_name = "${var.stack_name}-system-status-check-alarm"
  disk_space_alarm-name = "${var.stack_name}-ebs-disk-space-alarm"
  warning_sns = "${var.stack_name}-warning-sns-topic"
  critical_sns = "${var.stack_name}-critical-sns-topic"
  cpu_alarm-name ="${var.stack_name}-Instance-CPUUtilization-alarm"
  memory_alarm-name = "${var.stack_name}-Instance-memory-utilization-alarm"
  instance_status_check_alarm-name = "${var.stack_name}-instance-autorecovery-alarm"


  default_tags = {
    environment_name = var.environment_name,
    product_name = var.product_name,
    project_name = var.project_name,
    service_name = var.service_name,
    created_by  = "terraform"
    Team        = "EIS"
  }

  vpc_info = {
    dev = {
      "vpc"             = "vpc-072395b5d96856310"
      "subnets"         = ["subnet-0d327ff0e2e84a195", "subnet-0934df13dc88ccb2d"]
      "security_groups" = ["xxxxxxx", "xxxxxxx"]
    }
    qa = {
      "vpc"             = ""
      "subnets"         = [""]
      "security_groups" = [""]
    }
    prod = {
      "vpc"             = "xxxxxxx"
      "subnets"         = ["xxxxxxx"]
      "security_groups" = ["xxxxxxx", "xxxxxxx"]
    }
  }
  supported_amis = {
    "windows" = [
      "ami-00cd4d5d7df22d982", 
      "ami-01b14e65cd6ad74f9"
    ],
    "linux" = [
      "ami-032c672ba2c1e9bbf", 
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

variable "override_ami" {
  type        = string
  default     = "" 
  description = "Optional user-supplied AMI. If empty, defaults to the first OS-appropriate AMI."
}


variable "stack_name" {
  description = "Name of stack, change to suit your naming style"
  type        = string
  default     = "ec2_resiliency"
}


variable "vpc_id" {
  description = "VPC ID for testing"
  type        = string
  default     = "vpc-072395b5d96856310"
}

variable "vpc_ec2_subnet1" {
  description = "EC2 subnet 1 (AZ-a)"
  type        = string
  default     = "subnet-0d327ff0e2e84a195"
}

variable "vpc_ec2_subnet2" {
  description = "EC2 subnet 2 (AZ-c)"
  type        = string
  default     = "subnet-0934df13dc88ccb2d"
}

variable "subnet_ids" {
  description = "List of EC2 subnet IDs"
  type        = list(string)
  default     = ["subnet-0d327ff0e2e84a195", "subnet-0934df13dc88ccb2d"]
}


variable "ssm_key" {
  description = "Name of parameter store which contains the json configuration of CWAgent."
  type        = string
  default     = "/ec2/resiliency/cloudwatch/agent"
}

variable "linux_image_id" {
  description = "AMI ID"
  type        = string
  default     = "ami-0b4624933067d393a"
  #default     = "ami-032c672ba2c1e9bbf"
  #default     = "ami-0db575de70f37f380" for arrch64 arch type
}

variable "ec2_instance_type" {
  description = "EC2 InstanceType"
  type        = string
  default     = "t2.micro"
}


variable "volume" {
  description = "The volume name or device "
  type        = string
  default     = "/dev/xvda"
}


variable "ec2_instance_key_name" {
  description = "EC2 SSH Key"
  type        = string
  default     = "res-wl-keypair"
}

variable "availability_zone" {
  description = "The AZ for deployment"
  type        = string
  default     = "us-east-2a"
}

variable "region" {
  description = "The AWS region for deployment"
  type        = string
  default     = "us-east-2"
}

variable "ad_directory_id" {
  description = "Active Directory ID"
  type        = string
  default     = "NGL"
}

variable "ad_directory_name" {
  description = "Active Directory Name"
  type        = string
  default     = "nglic.local"
}

variable "ad_dns_ip_address1" {
  description = "Active Directory DNS 1"
  type        = string
  default     = "10.49.2.10"
}

variable "ad_dns_ip_address2" {
  description = "Active Directory DNS 2"
  type        = string
  default     = "10.49.1.10"
}
variable "dns_ip_addresses" {
  type        = list(string)
  description = "id of aws directory service AD domain."
  default = ["10.49.2.10", "10.49.1.10"]
}


variable "bucket_name" {
  description = "S3 storage name"
  type        = string
  default     = "ngl-ec2-terraform-backend-workloaddev"
}


variable "email_address" {
  description = "Enter Your Email Address"
  type        = string
  default     = "clyonga@nglic.com"
}

variable "path" {
  description = "Provide path"
  type        = string
  default     = "/"
}



#EFS security group
variable "inbound_tcp_port" {
  default     = [2049]
}

variable "outbound_tcp_port" {
  default     = [2049]
}

# variable "Environment" {
#   default     = "dev"
# }

variable "team" {
  default     = "EIS"
}
variable "ec2-association-name" {
  default     = "ec2-instance-association"
}
variable "asg-association-name" {
  default     = "asg-instance-association"
}

variable "trusted_ip_address" {
  type        = string
  description = "The CIDR block to allow RDP access will remove this to add my ip"
  default     = "1.2.3.4/32"
}


variable "ebs_kms_key_arn" {
  type        = string
  description = "kms key for encyptyion"
  default     = "arn:aws:kms:us-east-2:384352530920:key/48e020cc-9b1b-4cea-9306-e03d9e39e991"
}

variable "iam_instance_profile" {
  type        = string
  description = "iam instance profile for the ec2 instance"
}

variable "security_group_id" {
  type        = string
  description = "instance security group"
}
variable "fstype" {
  description = "Choose fstype - ext4 or xfs"
  type        = string
  default     = "ext4"
  validation {
    condition     = contains(["ext4", "xfs", "btrfs"], var.fstype)
    error_message = "You must specify ext4, xfs, or btrfs."
  }
}


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
