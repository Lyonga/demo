############


Below is an **illustrative example** of how you could refactor your CloudWatch alarm code into a standalone `cw-alarms` module and then **reuse** it in your top‐level (root) `main.tf`. The module will provision five alarms (auto‐recovery, CPU, memory, instance status, and disk space) for a single EC2 instance—referencing variables for instance ID, SNS topics, and so on.

You can adapt this pattern as needed (for example, by making alarms optional with `count = var.enable_auto_recovery ? 1 : 0`, or exposing more variables for thresholds, etc.).

---

## 1. Folder Structure

A typical layout might look like:

```
ec2-hardening/
├── terraform/
│   ├── modules/
│   │   └── cw-alarms/
│   │       ├── main.tf
│   │       ├── variables.tf
│   │       └── outputs.tf
│   ├── main.tf
│   ├── provider.tf
│   └── ...
└── ...
```

Where `cw-alarms/` holds your new module.

---

## 2. `cw-alarms/main.tf`

This file defines all your CloudWatch alarms (adapted from your snippet). We replace references to `aws_instance.linux_ec2.id` and `aws_sns_topic.critical_sns.arn` with module input variables (`var.instance_id`, `var.sns_critical_arn`, `var.sns_warning_arn`, etc.). We also replace any `local.*` references with variables (or simple inline strings).

```hcl
////////////////////////////////////////////////////////////////////////
// modules/cw-alarms/main.tf
////////////////////////////////////////////////////////////////////////

resource "aws_cloudwatch_metric_alarm" "auto_recovery" {
  alarm_name          = var.auto_recovery_alarm_name
  alarm_description   = "Automatically recover EC2 instance on failure"
  metric_name         = "StatusCheckFailed_System"
  namespace           = "AWS/EC2"
  statistic           = "Minimum"
  period              = 900
  evaluation_periods  = 2
  threshold           = 2
  comparison_operator = "GreaterThanOrEqualToThreshold"
  # For many instance types you could also do "arn:aws:automate:${var.region}:ec2:recover"
  # but let's keep it commented or optional:
  # alarm_actions     = [ "arn:aws:automate:${var.region}:ec2:recover", var.sns_critical_arn ]
  alarm_actions       = [ var.sns_critical_arn ]
  dimensions = {
    InstanceId = var.instance_id
  }
  tags = var.default_tags
}

resource "aws_cloudwatch_metric_alarm" "cpu_alarm_warning" {
  alarm_name                = var.cpu_alarm_name
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = 1
  metric_name               = "CPUUtilization"
  namespace                 = "AWS/EC2"
  period                    = 60
  statistic                 = "Average"
  threshold                 = var.cpu_threshold
  alarm_description         = "High CPU Usage"
  alarm_actions             = [var.sns_critical_arn]
  dimensions = {
    InstanceId = var.instance_id
  }
  tags = var.default_tags
}

resource "aws_cloudwatch_metric_alarm" "memory_alarm_critical" {
  alarm_name          = var.memory_alarm_name
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "mem_used_percent"
  namespace           = "CWAgent"
  period              = 300
  statistic           = "Average"
  threshold           = var.memory_threshold
  alarm_description   = "High Memory Usage"
  alarm_actions       = [var.sns_critical_arn]
  dimensions = {
    InstanceId = var.instance_id
  }
  tags = var.default_tags
}

resource "aws_cloudwatch_metric_alarm" "instance_status_alarm_critical" {
  alarm_name          = var.instance_status_alarm_name
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 5
  metric_name         = "StatusCheckFailed_Instance"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Minimum"
  threshold           = 0
  alarm_description   = "Instance Status Check Failed"
  alarm_actions       = [
    var.sns_critical_arn,
    "arn:aws:automate:${var.region}:ec2:reboot"
  ]
  ok_actions          = [var.sns_warning_arn]

  dimensions = {
    InstanceId = var.instance_id
  }
  tags = var.default_tags
}

resource "aws_cloudwatch_metric_alarm" "disk_space_alarm_critical" {
  alarm_name          = var.disk_alarm_name
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "disk_used_percent"
  namespace           = "CWAgent"
  period              = 300
  statistic           = "Average"
  threshold           = var.disk_threshold
  alarm_description   = "Disk Space Usage"
  alarm_actions       = [var.sns_critical_arn]
  dimensions = {
    InstanceId = var.instance_id
    device     = var.device
    path       = var.path
    fstype     = var.fstype
  }
  tags = var.default_tags
}
```

---

## 3. `cw-alarms/variables.tf`

We define all variables needed by our alarms—names, thresholds, instance ID, SNS ARNs, region, and so forth. Some are required, some have defaults.

```hcl
////////////////////////////////////////////////////////////////////////
// modules/cw-alarms/variables.tf
////////////////////////////////////////////////////////////////////////

variable "instance_id" {
  type        = string
  description = "EC2 instance ID to attach alarms to"
}

variable "region" {
  type        = string
  description = "AWS Region (used for some alarm actions)"
  default     = "us-east-1"
}

variable "sns_critical_arn" {
  type        = string
  description = "ARN of the critical SNS topic"
}

variable "sns_warning_arn" {
  type        = string
  description = "ARN of the warning SNS topic"
  default     = ""
}

variable "default_tags" {
  type        = map(string)
  description = "Common tags for all alarms"
  default     = {}
}

# Alarm Names
variable "auto_recovery_alarm_name" {
  type        = string
  description = "Name of the auto-recovery alarm"
  default     = "instance_auto_recovery"
}

variable "cpu_alarm_name" {
  type        = string
  description = "Name of the CPU alarm"
  default     = "cpu_alarm_warning"
}

variable "memory_alarm_name" {
  type        = string
  description = "Name of the memory alarm"
  default     = "memory_alarm_critical"
}

variable "instance_status_alarm_name" {
  type        = string
  description = "Name of the instance status alarm"
  default     = "instance_status_check_alarm_critical"
}

variable "disk_alarm_name" {
  type        = string
  description = "Name of the disk space alarm"
  default     = "disk_space_alarm_critical"
}

# Thresholds
variable "cpu_threshold" {
  type        = number
  description = "CPU usage threshold"
  default     = 90
}

variable "memory_threshold" {
  type        = number
  description = "Memory usage threshold"
  default     = 90
}

variable "disk_threshold" {
  type        = number
  description = "Disk usage threshold"
  default     = 80
}

# Disk alarm dimensions
variable "device" {
  type        = string
  description = "Device name for disk usage metric"
  default     = "/dev/xvda"
}

variable "path" {
  type        = string
  description = "Path name for disk usage metric"
  default     = "/"
}

variable "fstype" {
  type        = string
  description = "Filesystem type for disk usage metric"
  default     = "xfs"
}
```

---

## 4. `cw-alarms/outputs.tf` (Optional)

If you want to expose the alarm ARNs or names:

```hcl
////////////////////////////////////////////////////////////////////////
// modules/cw-alarms/outputs.tf
////////////////////////////////////////////////////////////////////////

output "auto_recovery_arn" {
  description = "ARN of the auto-recovery alarm"
  value       = aws_cloudwatch_metric_alarm.auto_recovery.arn
}

output "cpu_alarm_arn" {
  description = "ARN of the CPU alarm"
  value       = aws_cloudwatch_metric_alarm.cpu_alarm_warning.arn
}

# ...repeat for others if desired
```

---

## 5. Reusing It in the Root `main.tf`

In your top‐level or environment‐specific `main.tf` (where you have your EC2 instance and SNS topics), **call** this module. For instance:

```hcl
////////////////////////////////////////////////////////////////////////
// main.tf (root level or environment directory)
////////////////////////////////////////////////////////////////////////

module "ec2_instance" {
  source = "./modules/compute"

  # This would create your EC2, returning an instance_id output
  # ...
}

# Example: Reusing the cw-alarms module
module "cw_alarms" {
  source = "./modules/cw-alarms"

  instance_id      = module.ec2_instance.instance_id_output
  region           = var.aws_region
  sns_critical_arn = module.sns.critical_sns_arn
  sns_warning_arn  = module.sns.warning_sns_arn

  default_tags = {
    Environment = var.environment
    Owner       = var.owner
  }

  # Optionally override alarm names or thresholds
  # cpu_threshold    = 80
  # memory_threshold = 85
  # ...
}
```

Here:

- **`module.ec2_instance.instance_id_output`** references an output from your `ec2` module that returns the instance ID. If you have a direct resource (e.g., `aws_instance.linux_ec2`), you can pass `aws_instance.linux_ec2.id` directly.
- **`module.sns.critical_sns_arn`** references some separate SNS module or resource that provides the critical topic ARN.  
- You can omit any variables that have defaults if you’re happy with those defaults.

---

### Putting It All Together

1. **Move** your CloudWatch alarm definitions into a new module folder (`modules/cw-alarms`).  
2. **Parameterize** references to the instance ID, SNS topics, region, device name, etc. in `variables.tf`.  
3. **Create** resources in `main.tf`, referencing those variables.  
4. **Optionally** define outputs in `outputs.tf`.  
5. **Call** the module from your top‐level config, passing in the actual instance ID and SNS ARNs.

This approach keeps your CloudWatch alarm logic in a **self‐contained module**, letting you attach the same set of alarms to any instance by simply specifying the correct inputs (instance ID, thresholds, etc.).
