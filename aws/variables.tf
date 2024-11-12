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

variable "rds_engine" {
  description = "The database engine to use"
  type        = string
  default     = "postgres"
}

variable "rds_engine_version" {
  description = "The version of the database engine"
  type        = string
  default     = "13.3"
}

variable "rds_name" {
  description = "The name of the database to create"
  type        = string
  default     = "mydatabase"
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
