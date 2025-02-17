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
