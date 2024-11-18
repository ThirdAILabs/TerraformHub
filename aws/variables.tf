variable "aws_region" {
  description = "AWS region to deploy resources in"
  type        = string
}

variable "vpc_id" {
  description = "The VPC ID to launch the instances in"
  type        = string
}

variable "subnet_id_1" {
  description = "The subnet ID to launch the instances in use for all main purposes"
  type        = string
}

variable "subnet_id_2" {
  description = "The second subnet ID in a different AZ for RDS (mandatory requirement for RDS)"
  type        = string
}

variable "ami_id" {
  description = "The AMI ID to use for the instances"
  type        = string
}

variable "instance_type" {
  description = "The type of instance to use"
  type        = string
}

variable "default_username" {
  description = "Default username for SSH and directory setup based on the AMI (e.g., 'ec2-user' for Amazon Linux, 'ubuntu' for Ubuntu)"
  type        = string
}

variable "disk_size" {
  description = "The size of the root volume in GB"
  type        = number
}

variable "instance_count" {
  description = "The number of EC2 instances to launch"
  type        = number
  default     = 1
}

variable "ssh_key_name" {
  description = "The name of the SSH key pair to attach to the first instance"
  type        = string
}

variable "license_file_path" {
  description = "Path to the ndb_enterprise_license.json file on the local machine"
  type        = string
}

variable "login_method" {
  description = "Login method"
  type        = string
  default = "postgres"
}

variable "genai_key" {
  description = "OpenAI Key"
  type        = string
  default = ""
}

# Variables for config.yml
variable "admin_mail" {
  description = "Admin email address"
  type        = string
}

variable "admin_username" {
  description = "Admin username"
  type        = string
}

variable "admin_password" {
  description = "Admin password"
  type        = string
}

variable "thirdai_platform_version" {
  description = "ThirdAI Platform Version"
  type        = string
}

# RDS related Variables
variable "rds_instance_class" {
  description = "The instance type of the RDS database"
  type        = string
  default     = "db.t3.micro"
}

variable "rds_username" {
  description = "The master username for the database"
  type        = string
  default     = "admin"
}

variable "rds_password" {
  description = "The master password for the database"
  type        = string
  sensitive   = true
}

variable "rds_allocated_storage" {
  description = "The allocated storage in GBs for the RDS instance"
  type        = number
  default     = 20
}

variable "rds_backup_retention_period" {
  description = "The number of days to retain backups for the RDS instance"
  type        = number
  default     = 7
}

variable "rds_backup_window" {
  description = "Backup window for RDS in UTC (e.g., 07:00-09:00)"
  type        = string
  default     = "07:00-09:00"
}

# Enable or disable storage encryption
variable "rds_storage_encrypted" {
  description = "Enable encryption for the RDS instance storage"
  type        = bool
  default     = true
}

# Optional KMS Key ID for encryption
variable "rds_kms_key_id" {
  description = "Optional KMS Key ID for RDS encryption and performance insights"
  type        = string
  default     = "" # Leave empty if no KMS key is used
}

# Variables for EFS (Elastic File System)
variable "efs_backup_enabled" {
  description = "Enable automatic backups for the EFS file system"
  type        = bool
  default     = true
}

# Enable encryption at rest
variable "efs_encrypted" {
  description = "Enable encryption for the EFS file system"
  type        = bool
  default     = true
}

# Lifecycle policy transition to Infrequent Access
variable "efs_lifecycle_transition" {
  description = "Set lifecycle policy for transition to Infrequent Access storage"
  type        = string
  default     = "AFTER_30_DAYS" # Options: "AFTER_7_DAYS", "AFTER_14_DAYS", "AFTER_30_DAYS", "AFTER_60_DAYS", "AFTER_90_DAYS", "NONE"
}

# Performance mode for the EFS file system
variable "efs_performance_mode" {
  description = "Performance mode of the EFS file system"
  type        = string
  default     = "generalPurpose" # Options: "generalPurpose", "maxIO"
}

# Throughput mode for the EFS file system
variable "efs_throughput_mode" {
  description = "Throughput mode of the EFS file system"
  type        = string
  default     = "bursting" # Options: "bursting", "provisioned"
}

# Provisioned throughput in MiB/s (only applicable if throughput_mode is 'provisioned')
variable "efs_provisioned_throughput" {
  description = "Provisioned throughput for the EFS file system in MiB/s"
  type        = number
  default     = 10 # Only applicable if throughput_mode is "provisioned"
}

# Add variables to specify existing EFS ID and RDS endpoint
variable "existing_efs_id" {
  description = "ID of the existing EFS to use (optional). If provided, EFS creation is skipped."
  type        = string
  default     = ""
}

variable "existing_rds_endpoint" {
  description = "Endpoint of the existing RDS instance to use (optional). If provided, RDS creation is skipped."
  type        = string
  default     = ""
}

variable "existing_rds_username" {
  description = "Username of the existing RDS instance (required if using existing RDS)."
  type        = string
  default     = ""
}

variable "existing_rds_password" {
  description = "Password of the existing RDS instance (required if using existing RDS)."
  type        = string
  sensitive   = true
  default     = ""
}
