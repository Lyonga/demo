resource "aws_launch_template" "linux_instance_launch_template" {
  name                 = local.linux_launch_template_name
  image_id            = var.is_windows ?  var.ec2_image_id : var.linux_image_id 
  instance_type        = var.ec2_instance_type
  key_name             = var.ec2_instance_key_name
  instance_initiated_shutdown_behavior = "terminate"
  monitoring {
    enabled = true
  }
  block_device_mappings {
    device_name = var.is_windows ?  var.volume: var.linux_device_name  
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
      Name = "${var.stack_name}-${var.environment_name}-linux_ec2-launch_template"
    },
    local.default_tags
    )
  }

  tag_specifications {
    resource_type = "volume"
    tags = merge(
      {
        Name = "${var.stack_name}-${var.environment_name}-linux_ec2-ebs_volume"
      },
      local.default_tags
    )
  }
  metadata_options {
    http_tokens               = "required"
    http_endpoint             = "enabled"
    http_put_response_hop_limit = 1
  }

}

resource "aws_instance" "linux_ec2" {
  ami                         = aws_launch_template.linux_instance_launch_template.image_id
  instance_type               = aws_launch_template.linux_instance_launch_template.instance_type
  subnet_id                   = var.vpc_ec2_subnet1
  availability_zone           = var.availability_zone
  key_name                    = aws_launch_template.linux_instance_launch_template.key_name
  iam_instance_profile        = var.iam_instance_profile
  #disable_api_termination     = true
  launch_template {
    id      = aws_launch_template.linux_instance_launch_template.id
    version = aws_launch_template.linux_instance_launch_template.latest_version
  }
  lifecycle {
    ignore_changes = [
      ebs_optimized, hibernation, security_groups, monitoring, root_block_device, tags_all, root_block_device, launch_template,
      credit_specification, network_interface, iam_instance_profile
      ]
    # prevent_destroy = true
  }
  ebs_optimized = true
  vpc_security_group_ids = [var.security_group_id]
  
  tags = merge(
    {
      Name = "${var.stack_name}-${var.environment_name}-ec2_linux-instance"
      DomainJoin = "true"
    },
    local.default_tags
  )

}

################## Variables


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

 
  ec2_image_id = var.is_windows == null ? "${var.runtime_language}-${local.supported_amis[var.runtime_language][0]}" : "${var.runtime_language}-${var.runtime_version}"  #### I need help here

  # NOTE always put the latest version for each language as the first item in the list of versions
  supported_amis = {
    "windows" = [
      "ami-00cd4d5d7df22d982"
    ],
    "linux" = [
      "ami-032c672ba2c1e9bbf",
      "ami-0b4624933067d393a"
    ]
  }
}

variable "is_windows" {
  type        = bool
  description = "decide OS to use"
  default     = false
}

variable "volume" {
  description = "The volume name for windows os "
  type        = string
  default     = "/dev/sda1"
}

variable "linux_device_name" {
  description = "The volume name for linux os"
  type        = string
  default     = "/dev/xvda"
}
