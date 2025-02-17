
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
  # alarm_actions             = [
  #   aws_sns_topic.critical_sns.arn,
  #   "arn:aws:automate:${var.region}:ec2:recover", ###if we need application restarted by linked ssm doc
  #   aws_ssm_document.redeploy_application.arn
  # ]
  dimensions = {
    InstanceId = aws_instance.linux_ec2.id
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
    InstanceId = aws_instance.linux_ec2.id
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
    InstanceId = aws_instance.linux_ec2.id
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
    InstanceId = aws_instance.linux_ec2.id
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
    InstanceId = aws_instance.linux_ec2.id
    device     = var.volume
    path       = var.path
    fstype     = var.fstype
  }
  tags          = local.default_tags
}
