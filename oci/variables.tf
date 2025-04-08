# variables.tf
variable "ssh_public_key" {
  description = "The public SSH key for accessing the instances"
  type        = string
}

variable "tenancy_ocid" {
  description = "The OCID of your tenancy"
  type        = string
}

variable "user_ocid" {
  description = "The OCID of the user calling the API"
  type        = string
}

variable "compartment_id" {
  description = "OCID of the compartment where resources will be created"
  type        = string
}

variable "region" {
  description = "The region where you want to deploy your resources"
  type        = string
  default     = "us-ashburn-1"
}

variable "availability_domain" {
  description = "The availability domain where resources will be created"
  type        = string
  default     = "uZID:US-ASHBURN-AD-1"
}

variable "fingerprint" {
  description = "The fingerprint for the user's RSA key"
  type        = string
}

variable "private_key_path" {
  description = "The path to the user's RSA private key"
  type        = string
}

variable "vcn_cidr" {
  description = "CIDR block for the VCN"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_cidr" {
  description = "CIDR block for the subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "node_count" {
  description = "Number of instances to create"
  type        = number
  default     = 2
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