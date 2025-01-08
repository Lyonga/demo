resource "aws_ssm_document" "redeploy_application" {
  name          = "RedeployApplication"
  document_type = "Command"
  content = jsonencode({
    schemaVersion = "2.2"
    description   = "Redeploy application after EC2 recovery"
    mainSteps     = [
      {
        action = "aws:runCommand"
        name   = "RedeployApp"
        inputs = {
          DocumentName = "AWS-RunShellScript"
          Parameters = {
            commands = [
              "sudo systemctl restart my-application-service",
              "sudo systemctl status my-application-service"
            ]
          }
        }
      }
    ]
  })
}


resource "aws_ssm_association" "redeploy_on_recovery" {
  name = aws_ssm_document.redeploy_application.name
  targets {
    key    = "InstanceIds"
    values = [aws_instance.generic.id]
  }
}


resource "aws_cloudwatch_metric_alarm" "system_status_alert_critical" {
  alarm_name                = "SystemStatusCheckFailed"
  comparison_operator       = "GreaterThanThreshold"
  evaluation_periods        = 2
  metric_name               = "StatusCheckFailed_System"
  namespace                 = "AWS/EC2"
  period                    = 60
  statistic                 = "Minimum"
  threshold                 = 0
  alarm_description         = "System Status Check Failed"
  alarm_actions             = [
    aws_sns_topic.critical_sns.arn,
    "arn:aws:automate:${var.region}:ec2:recover",
    aws_ssm_document.redeploy_application.arn
  ]
  dimensions = {
    InstanceId = aws_instance.generic.id
  }
}
