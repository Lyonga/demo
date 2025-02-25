################


Below is an **example** of how to refactor your Security Group configuration into a **child module** that uses **default** and **custom** rules, following the same dynamic block approach. This allows you to keep your standard ports (80, 443, 22, 3389, DUO RADIUS, etc.) as **default ingress** in the module and let users add additional rules in the **root** config if needed.

---

## 1. Child Module Structure

Create a folder, for example, `modules/security_group`, containing:

```
modules/
  security_group/
    main.tf
    variables.tf
    outputs.tf
```

### 1.1 `variables.tf`

```hcl
////////////////////////////////////////////////////////////////////////
// modules/security_group/variables.tf
////////////////////////////////////////////////////////////////////////

variable "security_group_name" {
  type        = string
  description = "Name prefix for the security group"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID where the security group will be created"
}

variable "duo_radius_port" {
  type        = number
  description = "Port number for DUO RADIUS"
  default     = 1812
}

variable "default_ingress_rules" {
  type = list(object({
    description = string
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
  }))
  description = "Default inbound rules always applied"
  default = [
    {
      description = "Allow HTTP inbound"
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = ["10.0.0.0/8"]
    },
    {
      description = "Allow HTTPS inbound"
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["10.0.0.0/8"]
    },
    {
      description = "Allow SSH inbound"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = ["10.0.0.0/8"]
    },
    {
      description = "Allow RDP inbound"
      from_port   = 3389
      to_port     = 3389
      protocol    = "tcp"
      cidr_blocks = ["10.0.0.0/8"]
    }
    // We'll handle the DUO port dynamically inside main.tf
  ]
}

variable "default_egress_rules" {
  type = list(object({
    description = string
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
  }))
  description = "Default outbound rules always applied"
  default = [
    {
      description = "Allow all outbound"
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]
}

variable "custom_ingress_rules" {
  type = list(object({
    description = string
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
  }))
  description = "Additional inbound rules specified by the user"
  default     = []
}

variable "custom_egress_rules" {
  type = list(object({
    description = string
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
  }))
  description = "Additional outbound rules specified by the user"
  default     = []
}

variable "tags" {
  type        = map(string)
  description = "Additional tags for the security group"
  default     = {}
}
```

**Notes**:  
- We made a **default** list of ingress rules for HTTP(80), HTTPS(443), SSH(22), RDP(3389).  
- We also use a variable `duo_radius_port` for your DUO inbound rule, which we’ll handle in `main.tf`.  
- You can obviously customize or move the DUO rule into the `default_ingress_rules` array if you prefer.

### 1.2 `main.tf`

```hcl
////////////////////////////////////////////////////////////////////////
// modules/security_group/main.tf
////////////////////////////////////////////////////////////////////////

resource "aws_security_group" "this" {
  name_prefix = var.security_group_name
  description = "Allow HTTP/HTTPS, SSH, RDP, DUO inbound traffic"
  vpc_id      = var.vpc_id

  # Merge default + custom ingress rules
  dynamic "ingress" {
    for_each = concat(var.default_ingress_rules, var.custom_ingress_rules)
    content {
      description = ingress.value.description
      from_port   = ingress.value.from_port
      to_port     = ingress.value.to_port
      protocol    = ingress.value.protocol
      cidr_blocks = ingress.value.cidr_blocks
    }
  }

  # DUO RADIUS port - if you want to handle it separately
  # so the user can just set var.duo_radius_port.
  ingress {
    from_port   = var.duo_radius_port
    to_port     = var.duo_radius_port
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
    description = "DUO RADIUS inbound"
  }

  # Merge default + custom egress rules
  dynamic "egress" {
    for_each = concat(var.default_egress_rules, var.custom_egress_rules)
    content {
      description = egress.value.description
      from_port   = egress.value.from_port
      to_port     = egress.value.to_port
      protocol    = egress.value.protocol
      cidr_blocks = egress.value.cidr_blocks
    }
  }

  tags = merge(
    {
      Name = "${var.security_group_name}-sg"
    },
    var.tags
  )
}
```

**Key Points**:  
1. We do `dynamic "ingress"` for the **four** base rules (HTTP, HTTPS, SSH, RDP) **plus** any custom rules.  
2. We explicitly define an `ingress` block for the **DUO RADIUS port** using `var.duo_radius_port`. If you want to merge it into the array approach, that’s fine too—just put it in `default_ingress_rules`.  
3. Egress rules are similarly a combination of `default_egress_rules` and `custom_egress_rules`.  
4. We combine tags (the `Name` tag plus any user-supplied `var.tags`).

### 1.3 `outputs.tf`

```hcl
////////////////////////////////////////////////////////////////////////
// modules/security_group/outputs.tf
////////////////////////////////////////////////////////////////////////
output "id" {
  description = "Security group ID"
  value       = aws_security_group.this.id
}

output "arn" {
  description = "Security group ARN"
  value       = aws_security_group.this.arn
}
```

---

## 2. Using It in the Root Module

In your main Terraform (root or environment), you can do:

```hcl
module "ec2_app_sg" {
  source = "./modules/security_group"

  security_group_name = "ec2_app_sg"
  vpc_id              = var.vpc_id
  duo_radius_port     = 1812

  # If you want to override default rules or add more
  custom_ingress_rules = [
    {
      description = "Allow special admin port"
      from_port   = 8080
      to_port     = 8080
      protocol    = "tcp"
      cidr_blocks = ["10.1.2.0/24"]
    },
  ]

  custom_egress_rules = []
  
  tags = {
    Environment = var.environment_name
    Owner       = "MyTeam"
  }
}

# Then in your EC2 or other resources:
resource "aws_instance" "windows_ec2" {
  # ...
  vpc_security_group_ids = [module.ec2_app_sg.id]
  # ...
}
```

**Explanation**:
- You’re referencing the child module at `./modules/security_group`.
- You can set `duo_radius_port` if needed (the default is 1812 if you don’t override).
- You **optionally** pass `custom_ingress_rules` for additional inbound ports not covered by the defaults.

---

## 3. Result

When you `terraform apply`, the module creates **one** security group that has:

1. **Default inbound**: HTTP(80), HTTPS(443), SSH(22), RDP(3389).  
2. **DUO inbound**: Using `duo_radius_port`.  
3. **Any custom inbound** from `custom_ingress_rules`.  
4. **Default egress** of “allow all.”  
5. **Any custom egress** from `custom_egress_rules`.

Your root code can keep the child module usage minimal if you only want to rely on the default rules plus DUO, or add more inbound/outbound rules when needed.

---

## Summary

- **Child module** handles the base SG rules in `default_ingress_rules` / `default_egress_rules`, plus a separate DUO rule or merges it in if desired.  
- **Root module** references the child SG, optionally adding or overriding custom rules.  
- This approach ensures you have a consistent baseline for HTTP, HTTPS, SSH, RDP, DUO, etc., while allowing teams to add new rules without modifying the module code.
















###############


Here’s how you can refactor your **EC2 application security group** into a **modular Terraform structure**, allowing users to reference it in the root module and add custom rules.

---

## **1️⃣ Child Module (`modules/security_group/main.tf`)**
This module:
- Defines the security group.
- Allows default rules (your current rules).
- Enables users to add custom rules.

```hcl
resource "aws_security_group" "this" {
  name_prefix = var.security_group_name
  description = "Allow HTTP/HTTPS and SSH inbound traffic"
  vpc_id      = var.vpc_id

  tags = merge(
    {
      Name = "${var.environment_name}-${var.environment_name}-ec2_instance-security_group"
    },
    local.default_tags
  )
}

# Default ingress rules
resource "aws_security_group_rule" "default_ingress" {
  count = length(var.default_ingress_rules)

  type              = "ingress"
  from_port        = var.default_ingress_rules[count.index].from_port
  to_port          = var.default_ingress_rules[count.index].to_port
  protocol         = var.default_ingress_rules[count.index].protocol
  cidr_blocks      = var.default_ingress_rules[count.index].cidr_blocks
  security_group_id = aws_security_group.this.id
}

# Custom ingress rules
resource "aws_security_group_rule" "custom_ingress" {
  count = length(var.custom_ingress_rules)

  type              = "ingress"
  from_port        = var.custom_ingress_rules[count.index].from_port
  to_port          = var.custom_ingress_rules[count.index].to_port
  protocol         = var.custom_ingress_rules[count.index].protocol
  cidr_blocks      = var.custom_ingress_rules[count.index].cidr_blocks
  security_group_id = aws_security_group.this.id
}

# Egress rule
resource "aws_security_group_rule" "egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.this.id
}

output "security_group_id" {
  value = aws_security_group.this.id
}
```

---

## **2️⃣ Child Module Variables (`modules/security_group/variables.tf`)**
```hcl
variable "security_group_name" {
  description = "Security group name prefix"
  type        = string
}

variable "environment_name" {
  description = "Environment name (e.g., dev, prod)"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID for the security group"
  type        = string
}

variable "duo_radius_port" {
  description = "Duo RADIUS authentication port"
  type        = number
}

variable "default_ingress_rules" {
  description = "Default ingress rules"
  type = list(object({
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
  }))
  default = []
}

variable "custom_ingress_rules" {
  description = "Custom ingress rules"
  type = list(object({
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
  }))
  default = []
}
```

---

## **3️⃣ Root Module (`main.tf`)**
```hcl
module "security_group" {
  source = "./modules/security_group"

  security_group_name = "ec2-app-sg"
  environment_name    = "prod"
  vpc_id             = "vpc-12345678"
  duo_radius_port    = 1812

  default_ingress_rules = [
    { from_port = 80, to_port = 80, protocol = "tcp", cidr_blocks = ["10.0.0.0/8"] },
    { from_port = 443, to_port = 443, protocol = "tcp", cidr_blocks = ["10.0.0.0/8"] },
    { from_port = 22, to_port = 22, protocol = "tcp", cidr_blocks = ["10.0.0.0/8"] },
    { from_port = 3389, to_port = 3389, protocol = "tcp", cidr_blocks = ["10.0.0.0/8"] },
    { from_port = var.duo_radius_port, to_port = var.duo_radius_port, protocol = "tcp", cidr_blocks = ["10.0.0.0/8"] }
  ]

  custom_ingress_rules = var.custom_sg_rules
}
```

---

## **4️⃣ Root Module Custom Rules (`variables.tf`)**
```hcl
variable "custom_sg_rules" {
  description = "Custom security group ingress rules"
  type = list(object({
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
  }))
  default = []
}
```

---

## **5️⃣ Example Custom Rules (`terraform.tfvars`)**
```hcl
custom_sg_rules = [
  {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["10.10.0.0/16"]
  },
  {
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = ["10.20.0.0/16"]
  }
]
```

---

## **How This Works**
1. **Child Module (`modules/security_group`)**
   - Creates the security group.
   - Defines **default ingress rules**.
   - Allows **custom rules** via the `custom_ingress_rules` variable.
   - Includes a **default egress rule**.

2. **Root Module (`main.tf`)**
   - Calls the `security_group` module.
   - Passes **default security rules**.
   - Users can **add additional security rules** via `custom_sg_rules`.

---

## **Benefits**
✅ **Encapsulated logic** – Security group creation is handled in a reusable module.  
✅ **Customizable rules** – Users can override or append security rules via variables.  
✅ **Supports any environment** – Easily adaptable for different `vpc_id` and environments.  
✅ **Scalability** – Works across multiple environments without hardcoding values.  

Would you like me to add any additional features, such as using **security group references** instead of CIDR blocks? 🚀
