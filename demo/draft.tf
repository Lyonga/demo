Below is an end-to-end example demonstrating an **industry-standard** approach to:

1. **Generate a monthly AWS cost comparison report (grouped by tags)** using an AWS Lambda function (in Python) deployed via Terraform, and
2. **Integrate a GitHub Actions CI/CD pipeline** for Terraform that includes a **manual approval** step to check estimated costs prior to `terraform apply`.

You can adapt the code and structures to match your organization’s naming conventions, IAM policies, and best practices.

---

# 1. AWS Lambda Function for Monthly Tag-Based Cost Reporting

## 1.1 Overview

- **Goal**: Retrieve monthly AWS cost data from Cost Explorer, grouped by a specific tag (e.g., `Environment`, `Team`, or `Project`), compare it to the previous month, and email a report (HTML table) to a distribution list.
- **Trigger**: Scheduled monthly (e.g., on the 1st of every month).
- **Deployment**: Via Terraform.
- **Email**: Uses Amazon SES (simple approach) or SMTP.
- **Comparison**: We’ll do a basic month-over-month comparison.

## 1.2 Terraform Configuration

Below is an example Terraform module (pseudo-structure) for deploying a Lambda function, attaching necessary IAM roles, creating an EventBridge rule for monthly triggers, and configuring permissions for SES.

<details>
<summary><strong>Terraform Example</strong></summary>

```hcl
###############
# variables.tf
###############
variable "lambda_function_name" {
  type    = string
  default = "monthly-cost-report-lambda"
}

variable "schedule_expression" {
  type    = string
  default = "cron(0 8 1 * ? *)"
  # Runs on the 1st of every month at 08:00 UTC
}

variable "email_recipients" {
  type    = list(string)
  default = ["[email protected]", "[email protected]"]
}

###############
# main.tf
###############
resource "aws_iam_role" "lambda_execution_role" {
  name = "monthly-cost-report-lambda-role"

  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

# Optional: attach AWS managed policies for CloudWatch logs, etc.
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Additional inline policy granting Lambda permissions to use Cost Explorer and SES
resource "aws_iam_role_policy" "lambda_custom_policy" {
  name   = "monthly-cost-report-lambda-policy"
  role   = aws_iam_role.lambda_execution_role.id
  policy = data.aws_iam_policy_document.lambda_custom.json
}

data "aws_iam_policy_document" "lambda_custom" {
  statement {
    actions = [
      "ce:GetCostAndUsage",
      "ses:SendEmail",
      "ses:SendRawEmail"
    ]
    resources = ["*"]
  }
}

resource "aws_lambda_function" "monthly_cost_report" {
  function_name    = var.lambda_function_name
  role             = aws_iam_role.lambda_execution_role.arn
  handler          = "main.lambda_handler"
  runtime          = "python3.9"
  publish          = true
  filename         = "${path.module}/lambda_package.zip"  # Built/packaged separately
  source_code_hash = filebase64sha256("${path.module}/lambda_package.zip")

  # (Optional) pass recipients as environment variables
  environment {
    variables = {
      EMAIL_RECIPIENTS = join(",", var.email_recipients)
    }
  }
}

# Schedule the Lambda monthly using EventBridge (CloudWatch)
resource "aws_cloudwatch_event_rule" "monthly_trigger" {
  name                = "MonthlyCostReportRule"
  schedule_expression = var.schedule_expression
}

resource "aws_cloudwatch_event_target" "monthly_target" {
  rule      = aws_cloudwatch_event_rule.monthly_trigger.name
  target_id = "MonthlyCostReportLambda"
  arn       = aws_lambda_function.monthly_cost_report.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.monthly_cost_report.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.monthly_trigger.arn
}
```
</details>

> **Note**: Ensure your Lambda zip file is built (with your `main.py` code) and uploaded to the path Terraform expects (e.g., `lambda_package.zip`).

## 1.3 Lambda Code (Python)

Below is a more **detailed, industry-standard** Lambda function that:

1. Retrieves cost data grouped by **tag** (e.g., `Environment` tag).
2. Compares the current month to the previous month.
3. Builds an HTML table.
4. Sends an email via Amazon SES to a distribution list.

<details>
<summary><strong>main.py</strong></summary>

```python
import os
import boto3
from datetime import date, timedelta
from botocore.exceptions import ClientError

def lambda_handler(event, context):
    # 1. Gather environment variables
    email_recipients = os.environ.get("EMAIL_RECIPIENTS", "")
    # e.g., "team@company.com, other@company.com"
    recipient_list = [x.strip() for x in email_recipients.split(",") if x]

    tag_key = "Environment"  # <= Adjust this to your relevant tag key

    # 2. Calculate date ranges: last month vs. the month before last
    # Example: if today is 2025-01-17, we want cost for "2025-01-01 to 2025-02-01"
    # and compare with "2024-12-01 to 2025-01-01"
    today = date.today()
    first_of_current_month = today.replace(day=1)

    first_of_last_month = (first_of_current_month.replace(day=1) - timedelta(days=1)).replace(day=1)
    first_of_2_months_ago = (first_of_last_month.replace(day=1) - timedelta(days=1)).replace(day=1)

    # For the cost explorer, the "End" date is exclusive, so we go up to the 1st of next month
    # Current monthly range (last month, e.g., 2025-01-01 to 2025-02-01)
    start_current_str = first_of_last_month.isoformat()
    end_current_str   = first_of_current_month.isoformat()

    # Previous monthly range (the month before last, e.g., 2024-12-01 to 2025-01-01)
    start_previous_str = first_of_2_months_ago.isoformat()
    end_previous_str   = first_of_last_month.isoformat()

    # 3. Retrieve cost data from Cost Explorer
    ce_client = boto3.client("ce")

    # Helper function to get cost grouped by a tag key
    def get_monthly_cost_by_tag(start_dt, end_dt, tag_key):
        try:
            response = ce_client.get_cost_and_usage(
                TimePeriod={
                    "Start": start_dt,
                    "End": end_dt
                },
                Granularity="MONTHLY",
                Metrics=["BlendedCost"],
                GroupBy=[
                    {
                        "Type": "TAG",
                        "Key": tag_key
                    }
                ]
            )
            return response
        except ClientError as e:
            print(f"Error retrieving cost data: {e}")
            return None

    current_data = get_monthly_cost_by_tag(start_current_str, end_current_str, tag_key)
    previous_data = get_monthly_cost_by_tag(start_previous_str, end_previous_str, tag_key)

    # 4. Parse the returned data
    current_tag_costs = {}
    previous_tag_costs = {}

    # Expected structure: response["ResultsByTime"][0]["Groups"]
    if current_data and current_data["ResultsByTime"]:
        for group in current_data["ResultsByTime"][0].get("Groups", []):
            tag_value = group["Keys"][0].replace(f"{tag_key}$", "")  # or just keep it raw
            amount = float(group["Metrics"]["BlendedCost"]["Amount"])
            current_tag_costs[tag_value] = amount

    if previous_data and previous_data["ResultsByTime"]:
        for group in previous_data["ResultsByTime"][0].get("Groups", []):
            tag_value = group["Keys"][0].replace(f"{tag_key}$", "")
            amount = float(group["Metrics"]["BlendedCost"]["Amount"])
            previous_tag_costs[tag_value] = amount

    # 5. Build comparison table
    html_rows = []
    all_tag_values = set(list(current_tag_costs.keys()) + list(previous_tag_costs.keys()))
    total_current = 0.0
    total_previous = 0.0

    for tv in sorted(all_tag_values):
        curr_cost = current_tag_costs.get(tv, 0.0)
        prev_cost = previous_tag_costs.get(tv, 0.0)

        total_current += curr_cost
        total_previous += prev_cost

        diff = curr_cost - prev_cost
        diff_pct = (diff / prev_cost * 100) if prev_cost > 0 else 100.0 if curr_cost > 0 else 0.0

        html_rows.append(f"""
            <tr>
              <td>{tv if tv else "Untagged/No Value"}</td>
              <td>${curr_cost:,.2f}</td>
              <td>${prev_cost:,.2f}</td>
              <td>{diff_pct:,.1f}%</td>
            </tr>
        """)

    # Add total row
    total_diff = total_current - total_previous
    total_diff_pct = (total_diff / total_previous * 100) if total_previous > 0 else 100.0 if total_current > 0 else 0.0
    html_rows.append(f"""
        <tr style="font-weight:bold;">
          <td>Total</td>
          <td>${total_current:,.2f}</td>
          <td>${total_previous:,.2f}</td>
          <td>{total_diff_pct:,.1f}%</td>
        </tr>
    """)

    html_table = f"""
    <table border="1" cellpadding="5" cellspacing="0" style="border-collapse: collapse;">
      <thead>
        <tr>
          <th>{tag_key}</th>
          <th>Last Month</th>
          <th>Previous Month</th>
          <th>% Change</th>
        </tr>
      </thead>
      <tbody>
        {''.join(html_rows)}
      </tbody>
    </table>
    """

    subject = f"Monthly AWS Cost Report by Tag ({tag_key})"
    date_range_label = f"{start_current_str} to {end_current_str}"

    email_body = f"""
    <html>
      <body>
        <h2>{subject}</h2>
        <p><strong>Date Range:</strong> {date_range_label}</p>
        {html_table}
        <br/>
        <p>This is an automated report. Please review for anomalies or unexpected cost spikes.</p>
      </body>
    </html>
    """

    # 6. Send the email via Amazon SES
    if recipient_list:
        ses_client = boto3.client("ses")
        try:
            response = ses_client.send_email(
                Source="[email protected]",  # Verified in SES
                Destination={
                    "ToAddresses": recipient_list
                },
                Message={
                    "Subject": {
                        "Data": subject
                    },
                    "Body": {
                        "Html": {
                            "Data": email_body
                        }
                    }
                }
            )
            print("Email sent successfully:", response)
        except ClientError as e:
            print(f"Failed to send email: {e}")
    else:
        print("No recipients configured in EMAIL_RECIPIENTS environment variable.")

    return "Lambda execution completed."
```
</details>

### Notes
- Adjust the tag key to match your environment (`"Environment"`, `"CostCenter"`, `"Project"`, etc.).
- The code uses “BlendedCost” for simplicity. You could also use “UnblendedCost” or “AmortizedCost” depending on your cost model.
- The code compares the last full month to the month before that. Adjust as needed.

---

# 2. CI/CD with GitHub Actions & Terraform (Manual Approval)

## 2.1 Workflow Goals

1. **Run `terraform plan`** to see proposed changes.
2. **Estimate the additional monthly cost** from these changes (optional step).
3. **Present the plan & cost** in a Pull Request comment or as output in GitHub Actions.
4. **Manual Approval** step (a gate) in the workflow.
5. **Once approved**, run `terraform apply`.

## 2.2 Sample GitHub Actions Workflow

Below is a simplified example of a GitHub Actions workflow file (`.github/workflows/infra-deploy.yml`). It demonstrates:

- **Jobs** to check out the code, configure AWS credentials, run Terraform commands, and hold for manual approval.
- **Cost checking** step that calls a Python script (similar logic to your Lambda, but designed for ephemeral usage in the pipeline).

<details>
<summary><strong>.github/workflows/infra-deploy.yml</strong></summary>

```yaml
name: Infra Deployment

on:
  pull_request:
    types: [opened, synchronize]
  workflow_dispatch:

jobs:
  terraform-plan:
    runs-on: ubuntu-latest
    steps:
      - name: Check out repository
        uses: actions/checkout@v3

      - name: Set up AWS credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: us-east-1

      - name: Terraform Init
        run: terraform init

      - name: Terraform Plan
        id: plan
        run: terraform plan -out=tfplan

      - name: Show Plan
        run: terraform show -json tfplan > plan.json

      - name: Estimate Cost (Optional)
        run: |
          pip install boto3
          python cost_estimator.py --plan plan.json
        # cost_estimator.py is a script in your repo that parses plan.json,
        # queries Pricing API, and prints an estimated monthly cost.

      - name: Upload plan.json artifact
        uses: actions/upload-artifact@v3
        with:
          name: tfplan-json
          path: plan.json

  manual-approval:
    # This job waits for manual approval before applying
    runs-on: ubuntu-latest
    needs: [terraform-plan]
    steps:
      - name: Approval Gate
        uses: dorny/paths-filter@v2
        with:
          filters: |
            Approval:
              - '*'
        # This step effectively acts as a placeholder.
        # Another approach is to use the "workflow_run" or "environment" protection rules
        # with a required approval in GitHub.
        # Or use "wait timer" or the new "Manual approval" features in GitHub Actions if available.

  terraform-apply:
    runs-on: ubuntu-latest
    needs: [manual-approval]
    steps:
      - name: Check out repository
        uses: actions/checkout@v3

      - name: Set up AWS credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: us-east-1

      - name: Download plan.json artifact
        uses: actions/download-artifact@v3
        with:
          name: tfplan-json
          path: .

      - name: Terraform Init
        run: terraform init

      - name: Terraform Apply
        run: terraform apply -auto-approve tfplan
```
</details>

### Explanation of Key Steps

- **Terraform Plan**: Generates a plan file (`tfplan`).
- **Show Plan**: Converts `tfplan` to JSON (`plan.json`) so you can parse it.
- **Estimate Cost**: Runs a Python script that reads `plan.json`, checks the resources to be created/updated, calls the Pricing API (or uses a cost table), and prints an approximate monthly cost.
- **Upload Artifact**: Saves `plan.json` for subsequent jobs.
- **Manual Approval**:
  - This example uses a placeholder approach (`paths-filter`) to pause.
  - Alternatively, you can leverage GitHub’s “Environment protection rules” with required reviewers or use the new “Manual approval” steps that GitHub introduced.
- **Terraform Apply**: After approval, downloads the same plan file and applies it.

## 2.3 Example `cost_estimator.py` (Simplified)

<details>
<summary><strong>cost_estimator.py</strong></summary>

```python
#!/usr/bin/env python3
import json
import sys
import boto3

# Very simplistic example
# In practice, you'd parse resources from plan.json, e.g.
# checking for 'aws_instance', 'aws_rds_instance', etc.
# Then call Pricing API: client.get_products(ServiceCode='AmazonEC2', ...)
# to estimate monthly cost.

def main():
    if "--plan" not in sys.argv:
        print("Usage: cost_estimator.py --plan <path_to_plan.json>")
        sys.exit(1)

    plan_index = sys.argv.index("--plan") + 1
    plan_path = sys.argv[plan_index]

    with open(plan_path, "r") as f:
        plan_data = json.load(f)

    # For brevity, just count the number of resources to be created
    create_count = 0
    for resource_change in plan_data.get("resource_changes", []):
        if resource_change.get("change", {}).get("actions") == ["create"]:
            create_count += 1

    # Fake cost: $10 per resource per month for example
    estimated_monthly_cost = create_count * 10

    print(f"Estimated monthly cost: ${estimated_monthly_cost}")
    # You could add thresholds or failure logic:
    if estimated_monthly_cost > 500:
        print("Cost threshold exceeded; consider resource optimization!")
        # Optionally exit with non-zero to fail the pipeline
        # sys.exit(1)

if __name__ == "__main__":
    main()
```
</details>

You can extend this script with deeper logic:

- Parsing instance types, EBS volumes, RDS instance sizes, etc.
- Querying the AWS Pricing API to get real numbers.
- Summing up an actual monthly estimate.

---

# 3. Putting It All Together

1. **Monthly Cost Report**
   - A Terraform-managed Lambda function triggers on a schedule, queries the Cost Explorer grouped by tag, compares last month’s costs to the previous month, and emails a summary table to your distribution list.
   - This ensures ongoing visibility into the actual usage patterns and cost trends.

2. **CI/CD Cost Checks**
   - A GitHub Actions pipeline runs on pull requests or merges.
   - After `terraform plan`, it **estimates** additional monthly costs from new/modified resources.
   - A **manual approval** step ensures a team lead or devops engineer reviews the plan and cost implications before final `terraform apply`.

3. **Industry Best Practices**
   - **Tag everything**: Resource-level tags (e.g., `Environment`, `Project`, `Owner`) let you group and filter costs effectively.
   - **Automate Approvals**: Use GitHub’s environment protection or manual gates to enforce cost review.
   - **Use granularity**: Expand from monthly to weekly or daily reports if you need faster feedback on cost anomalies.
   - **Historical Analysis**: For deeper analytics, you could store the cost data in an S3 bucket or database, but the above approach is a lightweight alternative requiring minimal infrastructure.

With these components, you’ll have:

- **Automated monthly cost visibility** (via Lambda).
- **Proactive cost gating** (via GitHub Actions + Terraform).

Both are relatively simple to maintain and align with common industry standards for AWS cost management and DevOps workflows.
