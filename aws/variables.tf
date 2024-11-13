variable "aws_region" {
  description = "AWS region to deploy resources in"
  type        = string
}

variable "vpc_id" {
  description = "The VPC ID to launch the instances in"
  type        = string
}

variable "subnet_id" {
  description = "The subnet ID to launch the instances in"
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

# Variables for EFS (Elastic File System)
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
