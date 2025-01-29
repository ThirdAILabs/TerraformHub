variable "azure_region" {
  description = "The Azure region to deploy resources"
  type        = string
}

variable "vm_count" {
  description = "Total number of VMs to provision (includes last node)."
  type        = number
  default     = 3
}

variable "instance_type" {
  description = "The type of virtual machine to deploy"
  type        = string
  default     = "Standard_B2s"
}

variable "default_ssh_user" {
  description = "The SSH username for the virtual machine"
  type        = string
  default     = "azureuser"
}

variable "ssh_public_key_path" {
  description = "Path to the public SSH key file"
  type        = string
}

variable "root_volume_size_gb" {
  description = "The root volume size for the VM"
  type        = number
  default     = 30
}

variable "rds_master_username" {
  description = "The master username for the PostgreSQL database"
  type        = string
}

variable "rds_master_password" {
  description = "The master password for the PostgreSQL database"
  type        = string
  sensitive   = true
}

variable "rds_storage_size_gb" {
  description = "The storage size for the PostgreSQL database"
  type        = number
  default     = 20
}

variable "rds_backup_retention_days" {
  description = "The backup retention days for PostgreSQL"
  type        = number
  default     = 7
}

variable "subscription_id" {
  description = "The Azure Subscription ID"
  type        = string
}

variable "tenant_id" {
  description = "The Azure Tenant ID"
  type        = string
}

variable "client_id" {
  description = "The Azure Client ID (Application ID)"
  type        = string
}

variable "client_secret" {
  description = "The Azure Client Secret (Application Password)"
  type        = string
  sensitive   = true
}

