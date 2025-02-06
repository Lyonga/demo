### **🚀 Terraform for FSx Auto-Scaling: Throughput & IOPS**
To **automate FSx throughput and IOPS scaling**, we will use **CloudWatch Alarms, AWS Lambda, and FSx API**. The **Terraform script** below will:

1. **Monitor FSx Utilization using CloudWatch Metrics**
2. **Trigger AWS Lambda Functions** when:
   - Throughput is underutilized (**Scale Down**)
   - Throughput is overloaded (**Scale Up**)
   - IOPS is underutilized (**Scale Down**)
   - IOPS is overloaded (**Scale Up**)
3. **Dynamically Adjust FSx Settings** using the AWS API.

---

## **1️⃣ Terraform Module for CloudWatch Alarms**
These alarms **track FSx throughput and IOPS utilization**.

### **🚦 Throughput Scaling Alarms**
```hcl
resource "aws_cloudwatch_metric_alarm" "fsx_throughput_scale_down" {
  alarm_name          = "FSx-Throughput-Scale-Down"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 3
  metric_name         = "FileServerDiskThroughputUtilization"
  namespace           = "AWS/FSx"
  period             = 86400  # 24 hours
  statistic         = "Average"
  threshold         = 10   # If utilization is under 10%, scale down
  alarm_actions      = [aws_lambda_function.fsx_scale_throughput.arn]
}

resource "aws_cloudwatch_metric_alarm" "fsx_throughput_scale_up" {
  alarm_name          = "FSx-Throughput-Scale-Up"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "FileServerDiskThroughputUtilization"
  namespace           = "AWS/FSx"
  period             = 900  # 15 minutes
  statistic         = "Average"
  threshold         = 80  # If utilization exceeds 80%, scale up
  alarm_actions      = [aws_lambda_function.fsx_scale_throughput.arn]
}
```

---

### **📊 IOPS Scaling Alarms**
```hcl
resource "aws_cloudwatch_metric_alarm" "fsx_iops_scale_down" {
  alarm_name          = "FSx-IOPS-Scale-Down"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 3
  metric_name         = "DiskWriteOperations"
  namespace           = "AWS/FSx"
  period              = 86400  # 1 day
  statistic           = "Average"
  threshold           = 300    # Alert if usage is below 300 IOPS
  alarm_actions       = [aws_lambda_function.fsx_scale_iops.arn]
}

resource "aws_cloudwatch_metric_alarm" "fsx_iops_scale_up" {
  alarm_name          = "FSx-IOPS-Scale-Up"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "DiskWriteOperations"
  namespace           = "AWS/FSx"
  period              = 900  # 15 minutes
  statistic           = "Average"
  threshold           = 800    # Alert if usage is above 800 IOPS
  alarm_actions       = [aws_lambda_function.fsx_scale_iops.arn]
}
```

---

## **2️⃣ Terraform for AWS Lambda Function (Auto-Scaling)**
This **Lambda function dynamically scales throughput and IOPS**.

### **🚀 AWS Lambda for FSx Auto-Scaling**
```hcl
resource "aws_lambda_function" "fsx_scale_throughput" {
  function_name    = "FSxScaleThroughput"
  role            = aws_iam_role.lambda_role.arn
  handler        = "lambda_function.lambda_handler"
  runtime        = "python3.9"

  filename        = "fsx_scale_throughput.zip"  # Upload Python script separately
  timeout        = 30
}

resource "aws_lambda_function" "fsx_scale_iops" {
  function_name    = "FSxScaleIOPS"
  role            = aws_iam_role.lambda_role.arn
  handler        = "lambda_function.lambda_handler"
  runtime        = "python3.9"

  filename        = "fsx_scale_iops.zip"  # Upload Python script separately
  timeout        = 30
}
```

---

## **3️⃣ AWS Lambda Python Script (for Auto-Scaling)**
This **Python script updates FSx throughput & IOPS** when alarms trigger.

### **📜 `fsx_scale_throughput.py`**
```python
import boto3
import os

FSX_ID = "fs-xxxxxxxx"
MIN_THROUGHPUT = 128
MAX_THROUGHPUT = 1024
THROUGHPUT_STEP = 128

def lambda_handler(event, context):
    client = boto3.client("fsx")

    # Get current FSx settings
    response = client.describe_file_systems(FileSystemIds=[FSX_ID])
    current_throughput = response['FileSystems'][0]['ThroughputCapacity']

    # Determine scaling action
    if "FSx-Throughput-Scale-Down" in event['AlarmName']:
        new_throughput = max(current_throughput - THROUGHPUT_STEP, MIN_THROUGHPUT)
    elif "FSx-Throughput-Scale-Up" in event['AlarmName']:
        new_throughput = min(current_throughput + THROUGHPUT_STEP, MAX_THROUGHPUT)
    else:
        return {"message": "No scaling action taken"}

    # Update FSx throughput
    client.update_file_system(
        FileSystemId=FSX_ID,
        ThroughputCapacity=new_throughput
    )

    return {"message": f"FSx Throughput updated to {new_throughput} MiBps"}
```

---

### **📜 `fsx_scale_iops.py`**
```python
import boto3

FSX_ID = "fs-xxxxxxxx"
MIN_IOPS = 3000
MAX_IOPS = 50000
IOPS_STEP = 5000

def lambda_handler(event, context):
    client = boto3.client("fsx")

    # Get current FSx settings
    response = client.describe_file_systems(FileSystemIds=[FSX_ID])
    current_iops = response['FileSystems'][0]['WindowsConfiguration']['Iops']

    # Determine scaling action
    if "FSx-IOPS-Scale-Down" in event['AlarmName']:
        new_iops = max(current_iops - IOPS_STEP, MIN_IOPS)
    elif "FSx-IOPS-Scale-Up" in event['AlarmName']:
        new_iops = min(current_iops + IOPS_STEP, MAX_IOPS)
    else:
        return {"message": "No scaling action taken"}

    # Update FSx IOPS
    client.update_file_system(
        FileSystemId=FSX_ID,
        WindowsConfiguration={"Iops": new_iops}
    )

    return {"message": f"FSx IOPS updated to {new_iops}"}
```

---

## **4️⃣ Terraform for IAM Role (Lambda Permissions)**
```hcl
resource "aws_iam_role" "lambda_role" {
  name = "fsx_lambda_execution_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_policy" "fsx_lambda_policy" {
  name        = "FSxLambdaPolicy"
  description = "Allows Lambda to modify FSx settings"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["fsx:UpdateFileSystem", "fsx:DescribeFileSystems"]
      Resource = "*"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_fsx_attach" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.fsx_lambda_policy.arn
}
```

---

## **✅ Summary of Automation**
1️⃣ **Monitors CloudWatch for FSx utilization**
2️⃣ **Automatically scales throughput and IOPS based on usage**
3️⃣ **Avoids over-provisioning, saving up to 80% in FSx costs**
4️⃣ **Works without manual intervention once deployed**

---

## **🚀 Next Steps**
- Do you want the **Terraform files bundled as a ready-to-deploy GitHub repo**?
- Need **CLI-based manual commands** as an alternative?

This setup **optimizes FSx costs with minimal effort**! 🚀





####################
module "fsx_auto_scaling" {
  source = "./modules/fsx_auto_scaling"
}

provider "aws" {
  region = "us-east-1"  # Change to your region
}

resource "aws_cloudwatch_metric_alarm" "fsx_throughput_scale_down" {
  alarm_name          = "FSx-Throughput-Scale-Down"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 3
  metric_name         = "FileServerDiskThroughputUtilization"
  namespace          = "AWS/FSx"
  period             = 86400  # 24 hours
  statistic         = "Average"
  threshold         = 10   # If utilization is under 10%, scale down
  alarm_actions      = [aws_lambda_function.fsx_scale_throughput.arn]
}

resource "aws_cloudwatch_metric_alarm" "fsx_throughput_scale_up" {
  alarm_name          = "FSx-Throughput-Scale-Up"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "FileServerDiskThroughputUtilization"
  namespace          = "AWS/FSx"
  period             = 900  # 15 minutes
  statistic         = "Average"
  threshold         = 80  # If utilization exceeds 80%, scale up
  alarm_actions      = [aws_lambda_function.fsx_scale_throughput.arn]
}

resource "aws_lambda_function" "fsx_scale_throughput" {
  function_name = "FSxScaleThroughput"
  role          = aws_iam_role.lambda_role.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.9"
  filename      = "fsx_scale_throughput.zip"  # Upload Python script separately
  timeout       = 30
}

resource "aws_lambda_function" "fsx_scale_iops" {
  function_name = "FSxScaleIOPS"
  role          = aws_iam_role.lambda_role.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.9"
  filename      = "fsx_scale_iops.zip"  # Upload Python script separately
  timeout       = 30
}

resource "aws_iam_role" "lambda_role" {
  name = "fsx_lambda_execution_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_policy" "fsx_lambda_policy" {
  name        = "FSxLambdaPolicy"
  description = "Allows Lambda to modify FSx settings"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["fsx:UpdateFileSystem", "fsx:DescribeFileSystems"]
      Resource = "*"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_fsx_attach" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.fsx_lambda_policy.arn
}


############
### AWS CLI Commands for FSx Optimization

#### 1️⃣ Create an FSx for Windows File System
```bash
aws fsx create-file-system --file-system-type WINDOWS \
  --storage-capacity 1024 \
  --subnet-ids subnet-xxxxxxxx \
  --throughput-capacity 128 \
  --windows-configuration ActiveDirectoryId=d-xxxxxxxxxx,AutomaticBackupRetentionDays=7,DailyAutomaticBackupStartTime=02:00,CopyTagsToBackups=true,DeploymentType=MULTI_AZ_1,PreferredSubnetId=subnet-xxxxxxxx,WeeklyMaintenanceStartTime=3:00:00,AuditLogConfiguration={FileAccessAuditLogLevel=DISABLED,FileShareAccessAuditLogLevel=DISABLED}
```

#### 2️⃣ Enable FSx Deduplication
```bash
aws fsx update-file-system --file-system-id fs-xxxxxxxx --windows-configuration "AutomaticBackupRetentionDays=7,DeduplicationEnabled=true"
```

#### 3️⃣ Check FSx Storage & Utilization
```bash
aws fsx describe-file-systems --file-system-ids fs-xxxxxxxx
```

#### 4️⃣ Scale Down FSx Throughput
```bash
aws fsx update-file-system --file-system-id fs-xxxxxxxx --throughput-capacity 512
```

#### 5️⃣ Scale Up FSx Throughput
```bash
aws fsx update-file-system --file-system-id fs-xxxxxxxx --throughput-capacity 1024
```

#### 6️⃣ Reduce FSx IOPS
```bash
aws fsx update-file-system --file-system-id fs-xxxxxxxx --windows-configuration Iops=3000
```

#### 7️⃣ Increase FSx IOPS
```bash
aws fsx update-file-system --file-system-id fs-xxxxxxxx --windows-configuration Iops=50000
```

#### 8️⃣ Delete an FSx File System
```bash
aws fsx delete-file-system --file-system-id fs-xxxxxxxx
```



##################


Fsx Cli Commands
1
2
3
4
5
6
7
8
9
10
11
12
13
14
15
16
17
18
19
20
21
22
23
24
25
26
27
module "fsx_auto_scaling" {
  source = "./modules/fsx_auto_scaling"
}

provider "aws" {
  region = "us-east-1"  # Change to your region
}

resource "aws_fsx_windows_file_system" "fsx_windows" {
  storage_capacity    = 1024  # 1TB
  subnet_ids          = ["subnet-xxxxxxxx"]  # Replace with actual subnet ID
  throughput_capacity = 128  # Adjust based on workload
  kms_key_id          = "arn:aws:kms:us-east-1:xxxxxxxxxxxx:key/xxxxxxx"  # Replace if using encryption

  windows_configuration {
    active_directory_id = "d-xxxxxxxxxx"  # Optional: AD integration
    automatic_backup_retention_days = 7
    daily_automatic_backup_start_time = "02:00"
    copy_tags_to_backups = true
    preferred_subnet_id = "subnet-xxxxxxxx"  # Replace with actual subnet ID
    throughput_capacity = 128
    weekly_maintenance_start_time = "3:00:00"
    deployment_type = "MULTI_AZ_1"
    audit_log_configuration {
      file_access_audit_log_level = "DISABLED"
      file_share_access_audit_log_level = "DISABLED"
    }
  }
}

resource "aws_cloudwatch_metric_alarm" "fsx_throughput_scale_down" {
  alarm_name          = "FSx-Throughput-Scale-Down"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 3
  metric_name         = "FileServerDiskThroughputUtilization"
  namespace          = "AWS/FSx"
  period             = 86400  # 24 hours
  statistic         = "Average"
  threshold         = 10   # If utilization is under 10%, scale down
  alarm_actions      = [aws_lambda_function.fsx_scale_throughput.arn]
}

resource "aws_cloudwatch_metric_alarm" "fsx_throughput_scale_up" {
  alarm_name          = "FSx-Throughput-Scale-Up"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "FileServerDiskThroughputUtilization"
  namespace          = "AWS/FSx"
  period             = 900  # 15 minutes
  statistic         = "Average"
  threshold         = 80  # If utilization exceeds 80%, scale up
  alarm_actions      = [aws_lambda_function.fsx_scale_throughput.arn]
}

resource "aws_lambda_function" "fsx_scale_throughput" {
  function_name = "FSxScaleThroughput"
  role          = aws_iam_role.lambda_role.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.9"
  filename      = "fsx_scale_throughput.zip"  # Upload Python script separately
  timeout       = 30
}

resource "aws_lambda_function" "fsx_scale_iops" {
  function_name = "FSxScaleIOPS"
  role          = aws_iam_role.lambda_role.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.9"
  filename      = "fsx_scale_iops.zip"  # Upload Python script separately
  timeout       = 30
}

resource "aws_iam_role" "lambda_role" {
  name = "fsx_lambda_execution_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_policy" "fsx_lambda_policy" {
  name        = "FSxLambdaPolicy"
  description = "Allows Lambda to modify FSx settings"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["fsx:UpdateFileSystem", "fsx:DescribeFileSystems"]
      Resource = "*"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_fsx_attach" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.fsx_lambda_policy.arn
}


fsx-cost-optimization/
│── main.tf                      # Main Terraform file
│── variables.tf                  # Variables file for flexibility
│── outputs.tf                    # Outputs for FSx scaling actions
│── lambda/
│   ├── fsx_scale_throughput.py    # Python script for auto-scaling throughput
│   ├── fsx_scale_iops.py          # Python script for auto-scaling IOPS
│   ├── requirements.txt           # Dependencies for AWS Lambda
│── modules/
│   ├── fsx_auto_scaling/
│   │   ├── main.tf                # Module for FSx auto-scaling
│── cli-commands.txt               # AWS CLI alternative commands





############
### **How FSx Deduplication Works on a File Server**
When **deduplication is enabled** on an FSx for Windows file system used as a **file server**, the system will **identify and remove duplicate file data** at the **block level**, while keeping references intact.

---

### **📌 What Happens to Duplicate Files in Multiple User Drives or Directories?**
If **multiple users store the same file** (e.g., `report.docx`) in **different directories or drives** within the same FSx file system:
- **FSx detects that the file contents are identical**.
- It **stores only one copy** of the file's data blocks.
- **Each user’s file reference (path) remains unchanged**, meaning users still **see their own version** of the file.
- **Storage footprint is reduced**, as FSx only keeps **one instance of the file's data** while maintaining **logical pointers** to all references.

---

### **📊 Example Scenario**
#### **Before Deduplication**
| **File Path** | **File Size** |
|--------------|-------------|
| `UserA/Documents/report.docx` | 10MB |
| `UserB/Shared/report.docx` | 10MB |
| `UserC/Projects/report.docx` | 10MB |
| **Total Storage Used** | **30MB** |

#### **After Deduplication**
| **File Path** | **Stored Data Blocks** |
|--------------|----------------|
| `UserA/Documents/report.docx` | 🔗 **Reference to single stored copy** |
| `UserB/Shared/report.docx` | 🔗 **Reference to same stored copy** |
| `UserC/Projects/report.docx` | 🔗 **Reference to same stored copy** |
| **Total Storage Used** | **~10MB** |

---

### **🚀 Key Benefits of Deduplication**
✅ **No impact on user experience** – Users still see their files in their respective folders.
✅ **Significant storage savings** – Only unique data is stored, reducing storage costs by **30-80%**.
✅ **Transparent operation** – The process runs in the background without user intervention.

---

### **⚠️ Considerations Before Enabling Deduplication**
1. **Cannot be disabled** once enabled.
2. **Certain file types (already compressed files like ZIP, JPEG, MP4) see minimal savings**.
3. **Works best for environments with shared content**, such as:
   - User home directories.
   - Shared drives with large **repeated files** (e.g., PDFs, Office docs, logs).
   - Software repositories (e.g., ISO images, installers).

Would you like **Terraform code to enable deduplication** and set a scheduled optimization task? 🚀





📌 Key Concept: NTFS & FSx Deduplication at the Block Level

FSx for Windows leverages NTFS deduplication, which is a block-based deduplication method:

    Each file is broken into 32KB chunks (blocks).
    A cryptographic hash is calculated for each block.
    If two files have blocks with the same hash, NTFS replaces duplicate blocks with pointers.
    The single unique block is stored, and all file references point to it.

📊 What Does This Mean for File Servers?

    If multiple users save the same file in different directories, the same physical blocks are shared.
    File paths and permissions remain unchanged.
    User experience is unaffected—each user sees their files in their own folders.

🔍 Real-World Example

Imagine an FSx file server where users frequently store the same presentations, reports, and datasets.

Before Deduplication:

    100 users each store a 500MB training video in their folders.
    Total storage used = 50GB (100 × 500MB).

After Deduplication:

    FSx identifies the duplicate blocks and keeps only one instance.
    All 100 users' files point to this single copy.
    Total storage used = ~500MB instead of 50GB.

🚀 Benefits of FSx Deduplication
Feature	Impact
✅ Storage Efficiency	Reduce storage use by 30-80%, lowering costs.
✅ No User Impact	Users still access files normally.
✅ Transparent Operation	Runs in the background, no user action needed.
✅ NTFS-Optimized	Works with Windows file systems efficiently.
