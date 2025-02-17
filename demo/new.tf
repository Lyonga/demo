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
output "instance_id" {
  description = "EC2 Instance ID"
  value       = aws_instance.linux_ec2.id
}








Below is a **complete example** showing:

1. **How** to expose an EC2 instance ID via a module output (called `instance_id_output` or similar).
2. **How** to create an **SNS** module with “warning” and “critical” topics.
3. **How** to reference those outputs (both EC2 ID and SNS ARNs) from your **root** module (or environment) to pass into the CloudWatch alarms module.

You can adapt folder names and variable names as needed.

---

## 1. EC2 Module (`modules/compute`)

Assume you have a module that creates an EC2 instance (`aws_instance.linux_ec2`). In its `outputs.tf`, you expose the instance’s ID. For example:

```hcl
////////////////////////////////////////////////////////////////////////
// modules/compute/outputs.tf
////////////////////////////////////////////////////////////////////////
output "instance_id" {
  description = "EC2 Instance ID"
  value       = aws_instance.linux_ec2.id
}
```

**In the same module**, you likely have your `main.tf` that defines `aws_instance.linux_ec2`. For example:

```hcl
////////////////////////////////////////////////////////////////////////
// modules/compute/main.tf
////////////////////////////////////////////////////////////////////////
resource "aws_instance" "linux_ec2" {
  ami           = var.ami_id
  instance_type = var.instance_type
  # ... etc.
}
```

After Terraform runs, **any user** of this module can access `module.compute.instance_id`.

---

## 2. SNS Module (`modules/sns`)

Create a second module that manages your SNS topics and subscriptions. For example:

```hcl
////////////////////////////////////////////////////////////////////////
// modules/sns/main.tf
////////////////////////////////////////////////////////////////////////

resource "aws_sns_topic" "warning_sns" {
  name = var.warning_sns_name
  tags = var.default_tags
}

resource "aws_sns_topic" "critical_sns" {
  name = var.critical_sns_name
  tags = var.default_tags
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
```

### 2.1 `variables.tf` for the SNS Module

```hcl
////////////////////////////////////////////////////////////////////////
// modules/sns/variables.tf
////////////////////////////////////////////////////////////////////////
variable "warning_sns_name" {
  type        = string
  description = "Name of the warning SNS topic"
  default     = "warning-topic"
}

variable "critical_sns_name" {
  type        = string
  description = "Name of the critical SNS topic"
  default     = "critical-topic"
}

variable "email_address" {
  type        = string
  description = "Email address to subscribe"
}

variable "default_tags" {
  type        = map(string)
  default     = {}
}
```

### 2.2 `outputs.tf` in the SNS Module

```hcl
////////////////////////////////////////////////////////////////////////
// modules/sns/outputs.tf
////////////////////////////////////////////////////////////////////////
output "warning_sns_arn" {
  description = "ARN of the warning SNS topic"
  value       = aws_sns_topic.warning_sns.arn
}

output "critical_sns_arn" {
  description = "ARN of the critical SNS topic"
  value       = aws_sns_topic.critical_sns.arn
}
```

Now this SNS module can be reused to spin up the same pattern of “warning” and “critical” topics.

---

## 3. Consuming These Modules in Your Root `main.tf`

In your **root** or environment folder (often where you have your main Terraform stack), you can define something like:

```hcl
////////////////////////////////////////////////////////////////////////
// main.tf (root or environment)
////////////////////////////////////////////////////////////////////////

provider "aws" {
  region = var.aws_region
}

module "compute" {
  source = "./modules/compute"

  # pass variables (like ami_id, instance_type, etc.)
  ami_id         = var.ami_id
  instance_type  = var.instance_type
  # ...
}

module "sns" {
  source = "./modules/sns"

  warning_sns_name  = "my-warning-topic"
  critical_sns_name = "my-critical-topic"
  email_address     = "alerts@example.com"

  default_tags = {
    Environment = var.environment
  }
}

module "cw_alarms" {
  source = "./modules/cw-alarms"

  instance_id = module.compute.instance_id    # <--- referencing the EC2 module output
  region      = var.aws_region

  sns_critical_arn = module.sns.critical_sns_arn
  sns_warning_arn  = module.sns.warning_sns_arn

  default_tags = {
    Environment = var.environment
  }

  # (Optional) override any defaults for alarm names or thresholds
  # cpu_threshold    = 80
  # memory_threshold = 85
}
```

### Explanation

1. **`module "compute"`** references the `ec2-hardening/modules/compute` folder. It creates an EC2 instance and **exports** `instance_id`.  
2. **`module "sns"`** references the `ec2-hardening/modules/sns` folder. It creates your “warning” and “critical” topics, plus the email subscriptions. It then **exports** two ARNs.  
3. **`module "cw_alarms"`** references the `ec2-hardening/modules/cw-alarms` folder. It needs:
   - The **EC2 instance ID** to attach the alarms to: `module.compute.instance_id`.  
   - The **SNS ARNs** for “critical” and “warning”: `module.sns.critical_sns_arn`, `module.sns.warning_sns_arn`.  
   - Any other variables (region, tags, etc.).

---

## 4. Putting It All Together

1. **Outputs** in `modules/compute`:

   ```hcl
   output "instance_id" {
     description = "EC2 Instance ID"
     value       = aws_instance.linux_ec2.id
   }
   ```

   This is how “instance_id_output” (or simply `instance_id`) is made available.

2. **Outputs** in `modules/sns`:

   ```hcl
   output "warning_sns_arn" {
     value = aws_sns_topic.warning_sns.arn
   }

   output "critical_sns_arn" {
     value = aws_sns_topic.critical_sns.arn
   }
   ```

3. **Root** or environment code references those outputs by calling `module.<NAME>.<OUTPUT>`. For example:
   - `module.compute.instance_id`
   - `module.sns.critical_sns_arn`
   - `module.sns.warning_sns_arn`

Finally, your CloudWatch alarms module uses those values to define alarms that watch the correct EC2 instance and send notifications to the correct SNS topics.

---

### Summary

- **Your EC2 module** has an `output "instance_id"` to expose the EC2 resource’s ID.  
- **Your SNS module** provides `output "warning_sns_arn"` and `output "critical_sns_arn"`.  
- **Your CloudWatch alarms module** accepts `instance_id`, `sns_critical_arn`, and `sns_warning_arn` as inputs.  
- In the **root config**, you wire them together by referencing `module.<ec2_module>.instance_id` and `module.<sns_module>.<sns_output_arn>`.

This pattern is a clean way to **compose** multiple modules, letting each handle a different set of AWS resources while passing needed outputs around.
