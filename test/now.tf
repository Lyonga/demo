resource "aws_iam_role" "ec2_instance_role" {
  name               = local.instance_role_name
  description        = "Instance role to attach to your EC2 instance"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "myEC2Role"
  }
}

# Managed Policies for CloudWatch and SSM
resource "aws_iam_role_policy_attachment" "cloudwatch_agent" {
  role       = aws_iam_role.ec2_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_role_policy_attachment" "ssm_managed_core" {
  role       = aws_iam_role.ec2_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "cloudwatch_admin" {
  role       = aws_iam_role.ec2_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentAdminPolicy"
}

# Custom Policy for Additional Permissions
resource "aws_iam_policy" "ec2_role_policy" {
  name        = local.instance_policy_name
  description = "Custom policy for EC2 role"
  policy      = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject*", "s3:ListBucket", "s3:GetBucketLocation", "s3:*"]
        Resource = [
          "arn:aws:s3:::${var.bucket_name}",
          "arn:aws:s3:::${var.bucket_name}/*"
        ]
      },
      {
        Effect   = "Allow"
        Action   = [
          "ec2:DescribeInstances",
          "ec2:StartInstances",
          "ec2:StopInstances",
          "ec2:RebootInstances",
          "ec2:DescribeTags"
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = [
          "ssm:SendCommand",
          "ssm:CreateAssociation",
          "ssm:DescribeAssociation",
          "ssm:GetParameters",
          "ssm:GetParameter",
          "ssm:ListDocuments",
          "ssm:DescribeDocument",
          "ssm:ListCommands",
          "ssm:ListCommandInvocations",
          "ssm:DescribeAssociation",
          "ssm:ListAssociations",
          "ssm:GetDocument",
          "ssm:ListInstanceAssociations",
          "ssm:UpdateAssociationStatus",
          "ssm:UpdateInstanceInformation",
          "ec2messages:AcknowledgeMessage",
          "ec2messages:DeleteMessage",
          "ec2messages:FailMessage",
          "ec2messages:GetEndpoint",
          "ec2messages:GetMessages",
          "ec2messages:SendReply",
          "ds:CreateComputer",
          "ds:DescribeDirectories",
          "ec2:DescribeInstanceStatus",
          "ssm:*"
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = [
          "ds:DescribeDirectories",
          "ds:CreateComputer",
          "ds:AuthorizeApplication",
          "ds:UnauthorizeApplication"
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = [
          "cloudwatch:DescribeAlarms",
          "cloudwatch:GetMetricData",
          "cloudwatch:PutMetricAlarm",
          "cloudwatch:ListMetrics"
        ]
        Resource = "*"
      }
    ]
  })
}


resource "aws_iam_role_policy_attachment" "custom_policy_attachment" {
  role       = aws_iam_role.ec2_instance_role.name
  policy_arn = aws_iam_policy.ec2_role_policy.arn
}

# IAM Instance Profile
resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "Nglec2instanceprofile"
  role = aws_iam_role.ec2_instance_role.name
}

# AD Join 
resource "aws_ssm_document" "api_ad_join_domain" {
 name          = local.instance_adjoin_name
 document_type = "Command"
 content = jsonencode(
  {
    "schemaVersion" = "2.2"
    "description"   = "aws:domainJoin"
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
  depends_on = [ aws_instance.generic ]
  name = aws_ssm_document.api_ad_join_domain.name
  targets {
    key    = "InstanceIds"
    values = [ aws_instance.generic.id ]
  }
}


resource "aws_security_group" "web_app_sg" {
  name_prefix        = local.instance_security_group
  description        = "Allow HTTP/HTTPS and SSH inbound traffic"
  vpc_id             = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
  }

  ingress {
    from_port   = 3389
    to_port     = 3389
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
  }

  ingress {
    from_port   = var.duo_radius_port
    to_port     = var.duo_radius_port
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name           = "${var.environment_name} WebAppSecurityGroup"
    Project        = "infrastructure-tools"
    Environment    = var.environment_scp_tag
    Service-Name   = "infrastructure"
  }
}

resource "aws_launch_template" "ec2_instance_launch_template" {
  name                  = local.ec2_launch_template_name
  image_id             = var.ec2_image_id
  instance_type        = var.ec2_instance_type
  key_name             = var.ec2_instance_key_name
  instance_initiated_shutdown_behavior = "terminate"
  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_instance_profile.name
  }
  # This user_data uses PowerShell to:
  # 1) Download & install AWS CLI
  # 2) Use the newly installed AWS CLI to copy .exe/.msi installers from S3
  # 3) Install CrowdStrike, Rapid7, Duo
  # user_data = base64encode(<<-POWERSHELL
  #   <powershell>

  #   # --- 1) Download & Install AWS CLI (Windows) ---
  #   Write-Host "Downloading AWS CLI .msi..."
  #   New-Item -ItemType Directory -Path C:\\Temp -Force | Out-Null
  #   Invoke-WebRequest -Uri "https://awscli.amazonaws.com/AWSCLIV2.msi" -OutFile "C:\\Temp\\AWSCLIV2.msi"
  #   Write-Host "Installing AWS CLI..."
  #   Start-Process msiexec -ArgumentList "/i C:\\Temp\\AWSCLIV2.msi /quiet /norestart" -Wait

  #   # Optionally update PATH environment so AWS CLI is immediately usable in the same session
  #   $awsCliPath = "C:\\Program Files\\Amazon\\AWSCLIV2"
  #   [Environment]::SetEnvironmentVariable('PATH', $env:PATH + ';' + $awsCliPath, [EnvironmentVariableTarget]::Machine)

  #   # --- 2) Install CrowdStrike (Example: FalconSensor.exe) ---
  #   Write-Host "Installing CrowdStrike sensor..."
  #   New-Item -ItemType Directory -Path "C:\\agents" -Force | Out-Null
  #   aws s3 cp s3://my-bucket/FalconSensor.exe C:\\agents\\FalconSensor.exe
  #   # If you need a CID token, add --cid=XYZ in the argument list:
  #   Start-Process "C:\\agents\\FalconSensor.exe" -Wait
  #   # Example with argument:
  #   # Start-Process "C:\\agents\\FalconSensor.exe" -ArgumentList "--cid=ABCD1234" -Wait

  #   # --- 3) Install Rapid7 (Example: RAPID7_X86_64.MSI) ---
  #   Write-Host "Installing Rapid7..."
  #   aws s3 cp s3://my-bucket/RAPID7_X86_64.MSI C:\\agents\\RAPID7_X86_64.MSI
  #   Start-Process msiexec -ArgumentList "/i C:\\agents\\RAPID7_X86_64.MSI /quiet /norestart" -Wait

  #   # --- 4) Install Duo (Example: DUOWINDOWSLO6OG4.MSI) ---
  #   Write-Host "Installing Duo agent..."
  #   aws s3 cp s3://my-bucket/DUOWINDOWSLO6OG4.MSI C:\\agents\\DUOWINDOWSLO6OG4.MSI
  #   Start-Process msiexec -ArgumentList "/i C:\\agents\\DUOWINDOWSLO6OG4.MSI /quiet /norestart" -Wait

  #   Write-Host "All agent installations complete!"

  #   # Add any additional setup or logging
  #   Start-Sleep -Seconds 5
  #   </powershell>
  # POWERSHELL
  # )
  # user_data = base64encode(<<EOT
  #   <script>
  #   powershell -Command "C:\'Program Files'\Amazon\AmazonCloudWatchAgent\amazon-cloudwatch-agent-ctl.ps1 -a fetch-config -m ec2 -c ssm:${var.ssm_key} -s"
  #   powershell -Command "Start-Sleep -Seconds 30"
  #   </script>
  #   EOT
  #   )



#   user_data = base64encode(<<EOT
#     <script>
#     powershell -Command "C:\'Program Files'\Amazon\AmazonCloudWatchAgent\amazon-cloudwatch-agent-ctl.ps1 -a fetch-config -m ec2 -c ssm:${var.ssm_key} -s"
#     cfn-init.exe -v --stack ${var.stack_id} --resource EC2InstanceLaunchTemplate --region ${var.region} --configsets default
#     powershell -Command "Start-Sleep -Seconds 30"
#     cfn-signal.exe -e %errorlevel% --stack ${var.stack_id} --resource AutoScalingGroup --region ${var.region}
#     </script>
#     EOT
#     )

  block_device_mappings {
    device_name = "/dev/sda1"            # or "/dev/xvda" depending on AMI
    ebs {
      volume_size           = 75
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
      Name = "${var.Environment}-template-${var.team}"
    },
    var.tags
    )
  }

  tag_specifications {
    resource_type = "volume"
    tags = merge(
      {
        Name = "${var.Environment}-template-volume-${var.team}"
      },
      var.tags
    )
  }
  metadata_options {
    http_tokens               = "required"
    http_endpoint             = "enabled"
    http_put_response_hop_limit = 1
  }
}

resource "aws_instance" "generic" {
  ami                         = aws_launch_template.ec2_instance_launch_template.image_id
  instance_type               = aws_launch_template.ec2_instance_launch_template.instance_type
  subnet_id                   = var.vpc_ec2_subnet1
  availability_zone           = var.availability_zone
  key_name                    = aws_launch_template.ec2_instance_launch_template.key_name
  iam_instance_profile        = aws_launch_template.ec2_instance_launch_template.iam_instance_profile[0].name
  launch_template {
    id      = aws_launch_template.ec2_instance_launch_template.id
    version = aws_launch_template.ec2_instance_launch_template.latest_version
  }
  ebs_optimized = true
  security_groups = [
    aws_security_group.web_app_sg.id
  ]
  
  tags = merge(
    {
      Name = "${var.stack_name}-ec2-instance-${var.team}"
      DomainJoin = "true"
    },
    var.tags
  )

}

resource "aws_ec2_tag" "tags" {
  resource_id = aws_launch_template.ec2_instance_launch_template.id
  key         = "Environment"
  value       = var.environment_scp_tag
}

resource "aws_cloudwatch_metric_alarm" "ec2_instance_auto_recovery" {
  alarm_name                = local.instance_auto_recovery_alarm-name
  alarm_description         = "Automatically recover EC2 instance on failure"
  metric_name               = "StatusCheckFailed_System"
  namespace                 = "AWS/EC2"
  statistic                 = "Minimum"
  period                    = 60
  evaluation_periods        = 1
  threshold                 = 1
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  alarm_actions             = ["arn:aws:automate:${var.region}:ec2:recover"]
  dimensions = {
    InstanceId = aws_instance.generic.id
  }
}


resource "aws_sns_topic" "warning_sns" {
  name = local.warning_sns
}

resource "aws_sns_topic" "critical_sns" {
  name = local.critical_sns
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

# CloudWatch Alarms
resource "aws_cloudwatch_metric_alarm" "cpu_alarm_warning" {
  alarm_name                = local.cpu_alarm-name
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = 1
  metric_name               = "CPUUtilization"
  namespace                 = "AWS/EC2"
  period                    = 300
  statistic                 = "Average"
  threshold                 = 90
  alarm_description         = "High CPU Usage 70%"
  alarm_actions             = [aws_sns_topic.critical_sns.arn]
  #ok_actions                = [aws_sns_topic.warning_sns.arn]
  dimensions = {
    InstanceId = aws_instance.generic.id
  }
}

resource "aws_cloudwatch_metric_alarm" "memory_alarm_critical" {
  alarm_name                = local.memory_alarm-name
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = 2
  metric_name               = "mem_used_percent"
  namespace                 = "CWAgent"
  period                    = 900
  statistic                 = "Average"
  threshold                 = 90
  alarm_description         = "High Memory Usage 90%"
  alarm_actions             = [aws_sns_topic.critical_sns.arn]
  #ok_actions                = [aws_sns_topic.warning_sns.arn]
  dimensions = {
    InstanceId = aws_instance.generic.id
  }
}

resource "aws_cloudwatch_metric_alarm" "instance_status_alarm_critical" {
  alarm_name                = local.instance_status_check_alarm-name
  comparison_operator       = "GreaterThanThreshold"
  evaluation_periods        = 2
  metric_name               = "StatusCheckFailed_Instance"
  namespace                 = "AWS/EC2"
  period                    = 120
  statistic                 = "Minimum"
  threshold                 = 0
  alarm_description         = "Instance Status Check Failed"
  alarm_actions             = [aws_sns_topic.critical_sns.arn]
  #ok_actions                = [aws_sns_topic.warning_sns.arn]
  dimensions = {
    InstanceId = aws_instance.generic.id
  }
}

resource "aws_cloudwatch_metric_alarm" "disk_space_alarm_critical" {
  alarm_name                = local.disk_space_alarm-name
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = 2
  metric_name               = "disk_used_percent"
  namespace                 = "CWAgent"
  period                    = 300
  statistic                 = "Average"
  threshold                 = 95
  alarm_description         = "Disk Space Usage Over 95%"
  alarm_actions             = [aws_sns_topic.critical_sns.arn]
  #ok_actions                = [aws_sns_topic.warning_sns.arn]
  dimensions = {
    InstanceId = aws_instance.generic.id
    device     = var.volume
    path       = var.path
    fstype     = var.fstype
  }
}

resource "aws_cloudwatch_metric_alarm" "system_status_alert_critical" {
  alarm_name                = local.system_status_check_alarm_name
  comparison_operator       = "GreaterThanThreshold"
  evaluation_periods        = 2
  metric_name               = "StatusCheckFailed_System"
  namespace                 = "AWS/EC2"
  period                    = 60
  statistic                 = "Minimum"
  threshold                 = 0
  alarm_description         = "System Status Check Failed"
  alarm_actions             = [aws_sns_topic.critical_sns.arn, "arn:aws:automate:${var.region}:ec2:recover"]
  #ok_actions                = [aws_sns_topic.warning_sns.arn]
  dimensions = {
    InstanceId = aws_instance.generic.id
  }
}

