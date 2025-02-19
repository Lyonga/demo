resource "aws_launch_template" "windows_instance_launch_template" {
  name                 = local.windows_launch_template_name
  image_id             = var.ec2_image_id
  instance_type        = var.ec2_instance_type
  key_name             = var.ec2_instance_key_name
  instance_initiated_shutdown_behavior = "terminate"
  monitoring {
    enabled = true
  }
  block_device_mappings {
    device_name = var.volume   
    ebs {
      volume_size           = var.volume_size
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
      Name = "${var.environment_name}-template-${var.team}"
    },
    local.default_tags
    )
  }

  tag_specifications {
    resource_type = "volume"
    tags = merge(
      {
        Name = "${var.environment_name}-template-volume-${var.team}"
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

resource "aws_instance" "windows_ec2" {
  ami                         = aws_launch_template.windows_instance_launch_template.image_id
  instance_type               = aws_launch_template.windows_instance_launch_template.instance_type
  subnet_id                   = var.vpc_ec2_subnet1
  availability_zone           = var.availability_zone
  key_name                    = aws_launch_template.windows_instance_launch_template.key_name
  iam_instance_profile        = var.iam_instance_profile
  launch_template {
    id      = aws_launch_template.windows_instance_launch_template.id
    version = aws_launch_template.windows_instance_launch_template.latest_version
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
      Name = "${var.stack_name}-windows-cs-instance-${var.team}"
      DomainJoin = "true"
    },
    local.default_tags
  )

}

resource "aws_ssm_document" "adjoin_domain" {
 name          = local.windows_adjoin_name
 document_type = "Command"
 tags          = local.default_tags
 content = jsonencode(
  {
    "schemaVersion" = "2.2"
    "description"   = "ssm document for Automatic Domain Join Configuration created by Terraform"
    "mainSteps" = [
      {
        "action" = "aws:domainJoin",
        "name"   = "domainJoin",
        "inputs" = {
          "directoryId": var.ad_directory_id,
          "directoryName" : var.ad_directory_name
       "dnsIpAddresses" : [
                     var.dns_ip_addresses[0],
                     var.dns_ip_addresses[1]
                  ]
          }
        }
      ]
    }
  )
}

resource "aws_ssm_association" "ad_join_domain_association" {
  depends_on = [ aws_instance.windows_ec2 ]
  name = aws_ssm_document.adjoin_domain.name
  targets {
    key    = "InstanceIds"
    values = [ aws_instance.windows_ec2.id ]
  }
}

########################alarms

resource "aws_cloudwatch_metric_alarm" "ec2_instance_auto_recovery" {
  alarm_name                = local.instance_auto_recovery_alarm-name
  alarm_description         = "Automatically recover EC2 instance on failure"
  metric_name               = "StatusCheckFailed_System"
  namespace                 = "AWS/EC2"
  statistic                 = "Minimum"
  period                    = 900
  evaluation_periods        = 2
  threshold                 = 2
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  #alarm_actions             = ["arn:aws:automate:${var.region}:ec2:recover", aws_sns_topic.critical_sns.arn]   ###FOR NON t2.MICRO instance types
  alarm_actions             = [aws_sns_topic.critical_sns.arn]
  dimensions = {
    InstanceId = aws_instance.windows_ec2.id
  }
  tags          = local.default_tags
}


# CloudWatch Alarms
resource "aws_cloudwatch_metric_alarm" "cpu_alarm_warning" {
  alarm_name                = local.cpu_alarm-name
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = 1
  metric_name               = "CPUUtilization"
  namespace                 = "AWS/EC2"
  period                    = 60
  statistic                 = "Average"
  threshold                 = 90
  alarm_description         = "High CPU Usage 70%"
  alarm_actions             = [aws_sns_topic.critical_sns.arn]
  #ok_actions                = [aws_sns_topic.warning_sns.arn]
  dimensions = {
    InstanceId = aws_instance.windows_ec2.id
  }
  tags          = local.default_tags
}

resource "aws_cloudwatch_metric_alarm" "memory_alarm_critical" {
  alarm_name                = local.memory_alarm-name
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = 2
  metric_name               = "mem_used_percent"
  namespace                 = "CWAgent"
  period                    = 300
  statistic                 = "Average"
  threshold                 = 90
  alarm_description         = "High Memory Usage 90%"
  alarm_actions             = [aws_sns_topic.critical_sns.arn]
  #ok_actions                = [aws_sns_topic.warning_sns.arn]
  dimensions = {
    InstanceId = aws_instance.windows_ec2.id
  }
  tags          = local.default_tags
}

resource "aws_cloudwatch_metric_alarm" "instance_status_alarm_critical" {
  alarm_name                = local.instance_status_check_alarm-name
  comparison_operator       = "GreaterThanThreshold"
  evaluation_periods        = 5
  metric_name               = "StatusCheckFailed_Instance"
  namespace                 = "AWS/EC2"
  period                    = 300
  statistic                 = "Minimum"
  threshold                 = 0
  alarm_description         = "Instance Status Check Failed"
  alarm_actions             = [aws_sns_topic.critical_sns.arn, "arn:aws:automate:${var.region}:ec2:reboot"]
  ok_actions                = [aws_sns_topic.warning_sns.arn]
  dimensions = {
    InstanceId = aws_instance.windows_ec2.id
  }
  tags          = local.default_tags
}

resource "aws_cloudwatch_metric_alarm" "disk_space_alarm_critical" {
  alarm_name                = local.disk_space_alarm-name
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = 2
  metric_name               = "disk_used_percent"
  namespace                 = "CWAgent"
  period                    = 300
  statistic                 = "Average"
  threshold                 = 80
  alarm_description         = "Disk Space Usage Over 95%"
  alarm_actions             = [aws_sns_topic.critical_sns.arn]
  #ok_actions                = [aws_sns_topic.warning_sns.arn]
  dimensions = {
    InstanceId = aws_instance.windows_ec2.id
    device     = var.volume
    path       = var.path
    fstype     = var.fstype
  }
  tags          = local.default_tags
}

#####SNS
resource "aws_sns_topic" "warning_sns" {
  name = local.warning_sns
  tags          = local.default_tags
}

resource "aws_sns_topic" "critical_sns" {
  name = local.critical_sns
  tags          = local.default_tags
}

resource "aws_sns_topic_subscription" "warning_email" {
  topic_arn = aws_sns_topic.warning_sns.arn
  protocol  = "email"
  endpoint  = var.email_address
}

resource "aws_sns_topic_subscription" "critical_email" {
  topic_arn = aws_sns_topic.critical_sns.arn
  protocol  = "email"
  endpoint  = var.email_address
}
