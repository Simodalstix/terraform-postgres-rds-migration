variable "region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "ap-southeast-2"
}

variable "my_ip" {
  description = "Your IP for accessing SSH (ignored if using SSM-only)"
  type        = string
  default     = "0.0.0.0/0"
}

variable "rds_username" {
  description = "Master username for RDS"
  type        = string
}

variable "rds_password" {
  description = "Master password for RDS"
  type        = string
  sensitive   = true
}

variable "rds_dbname" {
  description = "Initial database name for RDS"
  type        = string
}

variable "bastion_ami" {
  description = "AMI ID for Bastion Host (Amazon Linux 2 or Ubuntu 20.04+)"
  type        = string
}

variable "key_name" {
  description = "EC2 key pair name (not used in SSM-only mode, but required for EC2 resource)"
  type        = string
}

