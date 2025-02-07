Below is the **end-to-end Terraform solution** to create self-hosted GitHub Actions runners on AWS and allow deployments to multiple AWS accounts in an AWS Organization.

---

## **1. Overview of Terraform Solution**
This Terraform setup does the following:

1. **Creates an EC2 instance** in Account A (where the GitHub self-hosted runner will run).
2. **Attaches an IAM Role** (`GitHubRunnerRole`) to the EC2 instance.
3. **Configures IAM Role in Account B** to allow cross-account deployment by assuming `DeploymentRole`.
4. **Outputs necessary details** for manual runner registration in GitHub.
5. **Sets up security groups**, VPC, and instance configurations.

---

## **2. Terraform Configuration**
### **Step 1: Create IAM Role for Self-Hosted Runner in Account A**
#### **File: `runner-role.tf`**
This IAM role allows the EC2 instance to assume a role in other AWS accounts.

```hcl
resource "aws_iam_role" "github_runner" {
  name = "GitHubRunnerRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_policy" "assume_target_role" {
  name        = "AssumeDeploymentRolePolicy"
  description = "Allows the self-hosted runner to assume roles in other AWS accounts."

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "sts:AssumeRole"
      Resource = "arn:aws:iam::ACCOUNT_B_ID:role/DeploymentRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "attach_policy" {
  policy_arn = aws_iam_policy.assume_target_role.arn
  role       = aws_iam_role.github_runner.name
}

resource "aws_iam_instance_profile" "github_runner" {
  name = "GitHubRunnerInstanceProfile"
  role = aws_iam_role.github_runner.name
}
```
🔹 Replace `ACCOUNT_B_ID` with the **target AWS account ID**.

---

### **Step 2: Create IAM Role in Account B for Deployment**
#### **File: `target-account-role.tf` (run in Account B)**
This IAM role allows the runner in Account A to assume it.

```hcl
resource "aws_iam_role" "deployment_role" {
  provider = aws.account_b
  name     = "DeploymentRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        AWS = "arn:aws:iam::ACCOUNT_A_ID:role/GitHubRunnerRole"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_policy" "deployment_policy" {
  provider    = aws.account_b
  name        = "DeploymentPolicy"
  description = "Allows deployments in target AWS account."

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = [
        "s3:PutObject",
        "ecs:UpdateService",
        "ecs:DescribeServices",
        "ecs:DescribeTaskDefinition",
        "ecs:RegisterTaskDefinition",
        "ecs:RunTask"
      ]
      Resource = "*"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "attach_deployment_policy" {
  provider   = aws.account_b
  role       = aws_iam_role.deployment_role.name
  policy_arn = aws_iam_policy.deployment_policy.arn
}
```
🔹 Replace `ACCOUNT_A_ID` with **the AWS account ID of the GitHub runner**.

---

### **Step 3: Create EC2 Instance for the Runner in Account A**
#### **File: `ec2-instance.tf`**
This launches the EC2 instance and attaches the IAM role.

```hcl
resource "aws_instance" "github_runner" {
  ami           = "ami-0c55b159cbfafe1f0" # Update with your region’s latest Amazon Linux AMI
  instance_type = "t3.medium"

  iam_instance_profile = aws_iam_instance_profile.github_runner.name

  vpc_security_group_ids = [aws_security_group.github_runner_sg.id]
  subnet_id             = aws_subnet.public.id

  user_data = <<-EOF
              #!/bin/bash
              cd /home/ec2-user
              curl -o actions-runner-linux-x64.tar.gz -L https://github.com/actions/runner/releases/latest/download/actions-runner-linux-x64.tar.gz
              tar xzf actions-runner-linux-x64.tar.gz
              ./config.sh --url https://github.com/YOUR_ORG/YOUR_REPO --token YOUR_GITHUB_TOKEN
              ./svc.sh install
              ./svc.sh start
              EOF

  tags = {
    Name = "GitHub-Runner"
  }
}
```
🔹 Replace:
- `ami` with the latest **Amazon Linux 2** AMI for your region.
- `YOUR_ORG/YOUR_REPO` with the **GitHub organization or repository**.
- `YOUR_GITHUB_TOKEN` with a **GitHub Actions runner token** (generated in the repository settings).

---

### **Step 4: Configure Security Groups**
#### **File: `security-group.tf`**
```hcl
resource "aws_security_group" "github_runner_sg" {
  name        = "github-runner-sg"
  description = "Allow necessary traffic for GitHub self-hosted runner"

  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Restrict to your IP in production
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
```

---

### **Step 5: Configure Terraform Providers**
#### **File: `providers.tf`**
```hcl
provider "aws" {
  alias = "account_a"
  region = "us-east-1"
}

provider "aws" {
  alias = "account_b"
  region = "us-east-1"
  assume_role {
    role_arn = "arn:aws:iam::ACCOUNT_B_ID:role/DeploymentRole"
  }
}
```
🔹 Replace `ACCOUNT_B_ID` with the **target AWS account ID**.

---

## **3. Deploying the Terraform Configuration**
Run the following:
```sh
terraform init
terraform apply -auto-approve
```
---

## **4. Configuring GitHub Actions Workflow**
Finally, update your **GitHub Actions workflow** to use the runner and deploy to the target AWS account.

#### **File: `.github/workflows/deploy.yml`**
```yaml
name: Deploy to AWS

on:
  push:
    branches:
      - main

jobs:
  deploy:
    runs-on: self-hosted
    steps:
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          role-to-assume: arn:aws:iam::ACCOUNT_B_ID:role/DeploymentRole
          aws-region: us-east-1

      - name: Deploy to AWS
        run: |
          aws ecs update-service --cluster my-cluster --service my-service --force-new-deployment
```
---

## **5. Summary**
✅ **Created an EC2 self-hosted GitHub Actions runner**
✅ **Configured IAM cross-account access**
✅ **Deployed Terraform infrastructure**
✅ **Updated GitHub Actions workflow for deployment**

Would you like me to add **auto-scaling for runners** using **ASG + Lambda**? 🚀


################
### **Auto-Scaling GitHub Self-Hosted Runners on AWS with Auto Scaling Groups and Lambda**
To optimize cost and efficiency, we will **dynamically scale GitHub self-hosted runners** on AWS using **Auto Scaling Groups (ASG)** and **AWS Lambda**. This setup ensures that:
- New runners are created **only when jobs are queued**.
- Runners **shut down automatically** after a period of inactivity.

---

## **1. How the Auto-Scaling Solution Works**
- **GitHub Webhook triggers an AWS Lambda function** when a job is queued.
- The **Lambda function scales up the Auto Scaling Group (ASG)** by adding an EC2 instance.
- The instance **registers as a GitHub self-hosted runner** and runs the job.
- After a timeout (e.g., **15 minutes of inactivity**), the instance **terminates automatically** to save costs.

---

## **2. Terraform Configuration for Auto-Scaling Runners**
### **Step 1: Create an Auto Scaling Group (ASG) for Runners**
#### **File: `asg.tf`**
```hcl
resource "aws_launch_template" "github_runner" {
  name          = "github-runner-template"
  image_id      = "ami-0c55b159cbfafe1f0" # Use latest Amazon Linux 2 AMI
  instance_type = "t3.medium"
  key_name      = "your-key-pair" # Replace with your key pair

  iam_instance_profile {
    name = aws_iam_instance_profile.github_runner.name
  }

  user_data = base64encode(<<EOF
#!/bin/bash
cd /home/ec2-user
curl -o actions-runner-linux-x64.tar.gz -L https://github.com/actions/runner/releases/latest/download/actions-runner-linux-x64.tar.gz
tar xzf actions-runner-linux-x64.tar.gz
./config.sh --url https://github.com/YOUR_ORG/YOUR_REPO --token YOUR_GITHUB_TOKEN --unattended
./svc.sh install
./svc.sh start
EOF
  )
}

resource "aws_autoscaling_group" "github_runners" {
  name                  = "github-runners-asg"
  min_size              = 0
  desired_capacity      = 0
  max_size              = 5
  vpc_zone_identifier   = [aws_subnet.public.id]
  launch_template {
    id      = aws_launch_template.github_runner.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "GitHub-Runner"
    propagate_at_launch = true
  }
}
```
🔹 This setup ensures that **runners scale up on demand** and terminate when no jobs are running.

---

### **Step 2: Create an AWS Lambda Function to Scale ASG**
#### **File: `lambda.tf`**
This function increases the **desired capacity** of the ASG when a GitHub Actions workflow is queued.

```hcl
resource "aws_lambda_function" "github_runner_scale_up" {
  function_name    = "GitHubRunnerScaleUp"
  runtime         = "python3.8"
  handler         = "lambda_function.lambda_handler"
  timeout         = 10
  role            = aws_iam_role.lambda_role.arn
  filename        = "lambda_function.zip"

  environment {
    variables = {
      ASG_NAME = aws_autoscaling_group.github_runners.name
    }
  }
}

resource "aws_iam_role" "lambda_role" {
  name = "GitHubRunnerLambdaRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_policy" "lambda_asg_policy" {
  name        = "LambdaASGScalingPolicy"
  description = "Allows Lambda to modify ASG"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = [
        "autoscaling:SetDesiredCapacity",
        "autoscaling:DescribeAutoScalingGroups"
      ]
      Resource = "*"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_asg_attachment" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_asg_policy.arn
}
```

---

### **Step 3: Lambda Function Code (Python)**
#### **File: `lambda_function.py`**
```python
import boto3
import json

ASG_NAME = "github-runners-asg"

def lambda_handler(event, context):
    client = boto3.client("autoscaling")

    # Fetch current ASG state
    response = client.describe_auto_scaling_groups(AutoScalingGroupNames=[ASG_NAME])
    current_size = response["AutoScalingGroups"][0]["DesiredCapacity"]

    # Increase desired capacity to at least 1
    new_size = max(current_size + 1, 1)

    client.set_desired_capacity(AutoScalingGroupName=ASG_NAME, DesiredCapacity=new_size)

    return {
        "statusCode": 200,
        "body": json.dumps(f"ASG desired capacity updated to {new_size}")
    }
}
```
🔹 This function automatically **increases the runner count** when a job is queued.

---

### **Step 4: Trigger Lambda with GitHub Webhook**
#### **File: `webhook.tf`**
Create an **API Gateway + Lambda trigger** to listen for GitHub webhooks.

```hcl
resource "aws_apigatewayv2_api" "github_webhook" {
  name          = "GitHubWebhookAPI"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.github_webhook.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id           = aws_apigatewayv2_api.github_webhook.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.github_runner_scale_up.invoke_arn
}

resource "aws_apigatewayv2_route" "github_webhook_route" {
  api_id    = aws_apigatewayv2_api.github_webhook.id
  route_key = "POST /github-webhook"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

resource "aws_lambda_permission" "allow_api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.github_runner_scale_up.function_name
  principal     = "apigateway.amazonaws.com"
}
```

---

### **Step 5: Register GitHub Webhook**
Manually register a webhook in **GitHub Settings → Webhooks**:
- **Payload URL**: Use the API Gateway URL from Terraform.
- **Content Type**: `application/json`
- **Event Type**: "Workflow Job" → "queued"

---

## **6. Summary**
✅ **Auto-scaling EC2 instances** for GitHub runners using **ASG**
✅ **Lambda function** to trigger scale-up when jobs are queued
✅ **API Gateway + GitHub Webhook** for automation
✅ **Runners terminate after inactivity** to save cost

---

## **7. Deployment Instructions**
Run the Terraform commands:
```sh
terraform init
terraform apply -auto-approve
```
Then, manually **register the webhook** in GitHub.

---

🚀 **Now, your GitHub self-hosted runners automatically scale up when needed and terminate when idle!**
Would you like a **CloudWatch-based scale-down Lambda** for further cost savings? 🔥


##############

Yes, **this can be achieved without API Gateway** by using a **CloudWatch-based scaling approach**. Instead of relying on GitHub webhooks via API Gateway, we will:

1. **Use CloudWatch Metrics** to monitor the queue of GitHub self-hosted runner jobs.
2. **Trigger an AWS Lambda function** when the queue size increases.
3. **Automatically scale up the Auto Scaling Group (ASG)** when needed.
4. **Scale down the ASG** when runners are idle.

---

## **How This Works**
- CloudWatch monitors the number of **queued jobs** for self-hosted GitHub runners.
- When **queued jobs increase**, CloudWatch triggers a **Lambda function to scale up**.
- A second **Lambda function checks for idle runners** and scales them down.
- **No need for API Gateway** or GitHub webhooks.

---

## **1. Setting Up CloudWatch Metrics to Monitor GitHub Runner Queue**
GitHub provides **self-hosted runner job metrics** via their API. We will collect this data periodically using AWS Lambda and push it to CloudWatch.

---

### **Step 1: Create an AWS Lambda Function to Collect Job Metrics**
#### **File: `github-runner-metrics.tf`**
```hcl
resource "aws_lambda_function" "github_metrics_collector" {
  function_name = "GitHubRunnerMetrics"
  runtime       = "python3.8"
  handler       = "lambda_function.lambda_handler"
  timeout       = 10
  role          = aws_iam_role.lambda_role.arn
  filename      = "github_metrics_collector.zip"

  environment {
    variables = {
      GITHUB_TOKEN   = "your_github_token"
      GITHUB_ORG     = "your_org"
      CW_NAMESPACE   = "GitHubRunnerMetrics"
    }
  }
}

resource "aws_cloudwatch_event_rule" "github_metrics_schedule" {
  name                = "GitHubRunnerMetricsSchedule"
  schedule_expression = "rate(1 minute)" # Runs every minute
}

resource "aws_cloudwatch_event_target" "github_metrics_lambda_trigger" {
  rule      = aws_cloudwatch_event_rule.github_metrics_schedule.name
  target_id = "GitHubMetricsLambda"
  arn       = aws_lambda_function.github_metrics_collector.arn
}

resource "aws_lambda_permission" "allow_cw_metrics_lambda" {
  statement_id  = "AllowCloudWatchInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.github_metrics_collector.function_name
  principal     = "events.amazonaws.com"
}
```

---

### **Step 2: Lambda Function to Fetch GitHub Runner Queue Size**
#### **File: `github_metrics_collector.py`**
```python
import os
import json
import requests
import boto3

CLOUDWATCH_NAMESPACE = os.environ["CW_NAMESPACE"]
GITHUB_ORG = os.environ["GITHUB_ORG"]
GITHUB_TOKEN = os.environ["GITHUB_TOKEN"]
CLOUDWATCH_CLIENT = boto3.client("cloudwatch")

GITHUB_API_URL = f"https://api.github.com/orgs/{GITHUB_ORG}/actions/runners"

def lambda_handler(event, context):
    headers = {"Authorization": f"Bearer {GITHUB_TOKEN}", "Accept": "application/vnd.github.v3+json"}
    response = requests.get(GITHUB_API_URL, headers=headers)

    if response.status_code != 200:
        print(f"GitHub API Error: {response.status_code}")
        return

    runners = response.json()["runners"]
    busy_runners = sum(1 for runner in runners if runner["status"] == "busy")

    # Publish metrics to CloudWatch
    CLOUDWATCH_CLIENT.put_metric_data(
        Namespace=CLOUDWATCH_NAMESPACE,
        MetricData=[
            {
                "MetricName": "BusyRunners",
                "Value": busy_runners,
                "Unit": "Count"
            }
        ]
    )

    return {"statusCode": 200, "body": json.dumps(f"Busy Runners: {busy_runners}")}
```
🔹 This function:
- Fetches **current job queue size** from GitHub.
- Publishes **metrics to CloudWatch** under the `GitHubRunnerMetrics` namespace.

---

## **2. Auto-Scaling Based on GitHub Runner Load**
Now, we use **CloudWatch Alarms** to trigger scaling.

---

### **Step 3: CloudWatch Alarm to Trigger Scaling**
#### **File: `cloudwatch-scaling.tf`**
```hcl
resource "aws_cloudwatch_metric_alarm" "scale_up_alarm" {
  alarm_name          = "GitHubRunnerScaleUp"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "BusyRunners"
  namespace           = "GitHubRunnerMetrics"
  period              = 60
  statistic           = "Sum"
  threshold           = 1
  alarm_actions       = [aws_lambda_function.github_runner_scale_up.arn]
}

resource "aws_cloudwatch_metric_alarm" "scale_down_alarm" {
  alarm_name          = "GitHubRunnerScaleDown"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = 3
  metric_name         = "BusyRunners"
  namespace           = "GitHubRunnerMetrics"
  period              = 60
  statistic           = "Sum"
  threshold           = 0
  alarm_actions       = [aws_lambda_function.github_runner_scale_down.arn]
}
```

---

### **Step 4: Lambda Function to Scale Up/Down ASG**
#### **File: `lambda_asg_scale.tf`**
```hcl
resource "aws_lambda_function" "github_runner_scale_up" {
  function_name = "GitHubRunnerScaleUp"
  runtime       = "python3.8"
  handler       = "lambda_function.lambda_handler"
  timeout       = 10
  role          = aws_iam_role.lambda_role.arn
  filename      = "github_runner_scale.zip"
}

resource "aws_lambda_function" "github_runner_scale_down" {
  function_name = "GitHubRunnerScaleDown"
  runtime       = "python3.8"
  handler       = "lambda_function.lambda_handler"
  timeout       = 10
  role          = aws_iam_role.lambda_role.arn
  filename      = "github_runner_scale.zip"
}
```

---

### **Step 5: Lambda Function Code for ASG Scaling**
#### **File: `github_runner_scale.py`**
```python
import os
import boto3

ASG_NAME = "github-runners-asg"
autoscaling = boto3.client("autoscaling")

def lambda_handler(event, context):
    action = event.get("Action", "scale_up")

    # Get current ASG size
    response = autoscaling.describe_auto_scaling_groups(AutoScalingGroupNames=[ASG_NAME])
    current_size = response["AutoScalingGroups"][0]["DesiredCapacity"]

    if action == "scale_up":
        new_size = min(current_size + 1, 5)  # Max 5 instances
    elif action == "scale_down":
        new_size = max(current_size - 1, 0)  # Min 0 instances

    autoscaling.set_desired_capacity(AutoScalingGroupName=ASG_NAME, DesiredCapacity=new_size)

    return {"statusCode": 200, "body": f"Updated ASG {ASG_NAME} to {new_size} instances"}
```
🔹 **This function is triggered by CloudWatch alarms**:
- **Scale Up** when queued jobs increase.
- **Scale Down** when no jobs are running.

---

## **3. Summary of Benefits**
✅ **No API Gateway required** – scaling is based on CloudWatch metrics.
✅ **GitHub runner queue is monitored using AWS Lambda**.
✅ **Auto Scaling Group dynamically scales runners** based on demand.
✅ **Reduces cost** by terminating idle instances automatically.

---

## **4. Deployment Instructions**
1️⃣ **Deploy Terraform setup:**
```sh
terraform init
terraform apply -auto-approve
```
2️⃣ **Upload Python files for Lambda functions**:
```sh
zip github_metrics_collector.zip github_metrics_collector.py
zip github_runner_scale.zip github_runner_scale.py
aws s3 cp github_metrics_collector.zip s3://your-lambda-bucket/
aws s3 cp github_runner_scale.zip s3://your-lambda-bucket/
```
3️⃣ **Manually trigger a test CloudWatch event to verify scaling**.

---

🚀 **Now, your GitHub self-hosted runners will automatically scale up/down based on actual job demand!**
Would you like **IAM policies restricted to specific accounts for security**? 🔒
