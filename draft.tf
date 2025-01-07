resource "aws_iam_role" "automation_role" {
  name               = "MyAutomationRole"
  assume_role_policy = jsonencode({
    Version : "2012-10-17",
    Statement : [
      {
        Effect : "Allow",
        Principal : {
          Service : "ssm.amazonaws.com"
        },
        Action : "sts:AssumeRole"
      }
    ]
  })
  tags = var.tags
}

resource "aws_iam_policy" "automation_policy" {
  name        = "MyAutomationPolicy"
  description = "Policy for SSM Automation to access S3 and EC2."
  policy      = jsonencode({
    Version : "2012-10-17",
    Statement : [
      # EC2 Describe and Systems Manager Permissions
      {
        Effect   : "Allow",
        Action   : [
          "ec2:DescribeInstances",
          "ec2:DescribeTags",
          "ssm:SendCommand",
          "ssm:ListCommands",
          "ssm:GetCommandInvocation"
        ],
        Resource : "*"
      },
      # S3 Access
      {
        Effect   : "Allow",
        Action   : [
          "s3:GetObject",
          "s3:ListBucket"
        ],
        Resource : [
          "arn:aws:s3:::${var.s3_bucket_name}",
          "arn:aws:s3:::${var.s3_bucket_name}/*"
        ]
      }
    ]
  })
  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "attach_automation_policy" {
  role       = aws_iam_role.automation_role.name
  policy_arn = aws_iam_policy.automation_policy.arn
}






resource "aws_ssm_document" "install_agents" {
  name          = "MyAutomationDocument"
  document_type = "Automation"
  tags          = var.tags

  content = jsonencode({
    schemaVersion = "0.3",
    description   = "Install security agents on EC2 instances.",
    parameters    = {
      AssumeRole = {
        type        = "String",
        description = "The ARN of the role to assume when running this automation document.",
        default     = aws_iam_role.automation_role.arn
      },
      InstanceIds = {
        type        = "StringList",
        description = "List of EC2 Instance IDs to target for automation."
      },
      S3BucketName = {
        type        = "String",
        description = "The S3 bucket containing the installer files."
      }
    },
    mainSteps = [
      {
        name     = "DownloadAndInstallCrowdStrike",
        action   = "aws:runCommand",
        inputs   = {
          DocumentName = "AWS-RunPowerShellScript",
          InstanceIds  = "{{ InstanceIds }}",
          Parameters   = {
            commands = [
              "$localPath = 'C:\\Scripts\\CROWDSTRIKE.EXE'",
              "New-Item -ItemType Directory -Path (Split-Path $localPath) -Force | Out-Null",
              "Read-S3Object -BucketName '{{ S3BucketName }}' -Key 'agents/CROWDSTRIKE.EXE' -File $localPath",
              "Start-Process $localPath -ArgumentList '/install', '/quiet', '/norestart' -Wait"
            ]
          }
        }
      }
    ]
  })
}
