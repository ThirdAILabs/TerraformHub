variable "aws_region" {
  description = "The AWS region to deploy resources"
  type        = string
}

variable "vpc_id" {
  description = "The VPC ID where resources will be deployed"
  type        = string
}

variable "primary_subnet_id" {
  description = "The primary subnet ID for general resources"
  type        = string
}

variable "secondary_subnet_id" {
  description = "The secondary subnet ID (in a different AZ) required for RDS"
  type        = string
}

variable "ami_id" {
  description = "The AMI ID for launching EC2 instances"
  type        = string
}

variable "instance_type" {
  description = "The type of EC2 instance to deploy"
  type        = string
}

variable "default_ssh_user" {
  description = "Default SSH username based on the selected AMI (e.g., 'ec2-user' for Amazon Linux)"
  type        = string
}

variable "root_volume_size_gb" {
  description = "The size of the root volume in GB for EC2 instances"
  type        = number
}

variable "ec2_instance_count" {
  description = "Number of EC2 instances to deploy"
  type        = number
  default     = 1
}

variable "ssh_key_name" {
  description = "The name of the SSH key pair to attach to EC2 instances"
  type        = string
}

variable "license_file_path" {
  description = "Path to the `ndb_enterprise_license.json` file on the local machine"
  type        = string
}

variable "user_auth_method" {
  description = "Authentication method for accessing resources"
  type        = string
  default     = "postgres"
}

variable "openai_api_key" {
  description = "API Key for OpenAI GenAI integration"
  type        = string
  default     = ""
}

# Configuration variables for platform
variable "platform_admin_email" {
  description = "Admin email for configuring the platform"
  type        = string
}

variable "platform_admin_username" {
  description = "Admin username for configuring the platform"
  type        = string
}

variable "platform_admin_password" {
  description = "Admin password for configuring the platform"
  type        = string
}

variable "platform_version" {
  description = "Version of the ThirdAI platform to deploy"
  type        = string
}

# RDS-related variables
variable "rds_instance_class" {
  description = "Instance class/type for RDS"
  type        = string
  default     = "db.t3.micro"
}

variable "rds_identifier" {
  description = "Identifier used for the final snapshot"
  type        = string
  default     = "thirdai-platform"
}

variable "rds_master_username" {
  description = "Master username for the RDS instance"
  type        = string
  default     = "admin"
}

variable "rds_master_password" {
  description = "Master password for the RDS instance"
  type        = string
  sensitive   = true
}

variable "rds_storage_size_gb" {
  description = "Allocated storage size for RDS in GB"
  type        = number
  default     = 20
}

variable "rds_backup_retention_days" {
  description = "Number of days to retain RDS backups"
  type        = number
  default     = 7
}

variable "rds_backup_window" {
  description = "The time window (UTC) for RDS backups (e.g., '07:00-09:00')"
  type        = string
  default     = "07:00-09:00"
}

variable "rds_encryption_enabled" {
  description = "Enable encryption for the RDS instance storage"
  type        = bool
  default     = true
}

variable "rds_kms_key_id" {
  description = "Optional KMS Key ID for encrypting RDS storage"
  type        = string
  default     = ""
}

# EFS-related variables
variable "efs_backup_enabled" {
  description = "Enable automatic backups for the EFS file system"
  type        = bool
  default     = true
}

variable "efs_encryption_enabled" {
  description = "Enable encryption at rest for the EFS file system"
  type        = bool
  default     = true
}

variable "efs_lifecycle_policy_transition" {
  description = "Transition lifecycle policy for EFS (e.g., 'AFTER_30_DAYS')"
  type        = string
  default     = "AFTER_30_DAYS"
}

variable "efs_performance_mode" {
  description = "Performance mode for the EFS file system ('generalPurpose' or 'maxIO')"
  type        = string
  default     = "generalPurpose"
}

variable "efs_throughput_mode" {
  description = "Throughput mode for the EFS file system ('bursting' or 'provisioned')"
  type        = string
  default     = "bursting"
}

variable "efs_provisioned_throughput_mibps" {
  description = "Provisioned throughput for EFS in MiB/s (only applies to 'provisioned' mode)"
  type        = number
  default     = 10
}

# Variables for reusing existing resources
variable "existing_efs_id" {
  description = "ID of an existing EFS to reuse (if provided, EFS creation will be skipped)"
  type        = string
  default     = ""
}

variable "existing_rds_endpoint" {
  description = "Endpoint of an existing RDS instance (if provided, RDS creation will be skipped)"
  type        = string
  default     = ""
}

variable "existing_rds_username" {
  description = "Username for an existing RDS instance (required if using an existing RDS)"
  type        = string
  default     = ""
}

variable "existing_rds_password" {
  description = "Password for an existing RDS instance (required if using an existing RDS)"
  type        = string
  sensitive   = true
  default     = ""
}
