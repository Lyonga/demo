#########
////////////////////////////////////////////////////////////////////////
// File: terraform/environments/dev/main.tf
////////////////////////////////////////////////////////////////////////

terraform {
  required_version = ">= 1.3.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

# Optionally define your backend here or in a backend_config/
provider "aws" {
  region = var.aws_region
}

module "linux_hardened_ec2" {
  source = "../../modules/ec2-hardened"

  name_prefix                = "${var.env_name}-linux"
  team                       = var.team
  default_tags               = var.default_tags
  launch_template_name       = "${var.env_name}-launch-template"
  instance_type              = var.instance_type
  key_name                   = var.key_name
  ami_id                     = var.ami_id
  iam_instance_profile_name  = var.ec2_instance_profile_name
  ebs_kms_key_arn            = var.ebs_kms_key_arn
  subnet_id                  = var.subnet_id
  availability_zone          = var.availability_zone
  security_group_ids         = var.security_group_ids

  enable_ad_join             = var.enable_ad_join
  ad_join_document_name      = var.ad_join_document_name
  ad_directory_id            = var.ad_directory_id
  ad_directory_name          = var.ad_directory_name
  ad_dns_ip_addresses        = var.ad_dns_ip_addresses
}


////////////////////////////////////////////////////////////////////////
// File: terraform/environments/dev/variables.tf
////////////////////////////////////////////////////////////////////////

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "env_name" {
  type    = string
  default = "dev"
}

variable "team" {
  type    = string
  default = "my-team"
}

variable "default_tags" {
  type = map(string)
  default = {
    "Owner"       = "my-team"
    "Environment" = "dev"
  }
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "key_name" {
  type = string
}

variable "ami_id" {
  type = string
  default = "ami-0123456789abcdef0"
}

variable "ec2_instance_profile_name" {
  type    = string
  default = ""
}

variable "ebs_kms_key_arn" {
  type    = string
  default = ""
}

variable "subnet_id" {
  type    = string
  default = "subnet-0abc12345def6789"
}

variable "availability_zone" {
  type    = string
  default = "us-east-1a"
}

variable "security_group_ids" {
  type    = list(string)
  default = []
}

# Domain join toggles
variable "enable_ad_join" {
  type    = bool
  default = false
}

variable "ad_join_document_name" {
  type    = string
  default = "my-ad-join-doc"
}

variable "ad_directory_id" {
  type    = string
  default = ""
}

variable "ad_directory_name" {
  type    = string
  default = ""
}

variable "ad_dns_ip_addresses" {
  type    = list(string)
  default = []
}
