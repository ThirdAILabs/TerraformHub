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

variable "platform_admin_email" {
  description = "Email for the ThirdAI platform admin"
  type        = string
}

variable "platform_admin_username" {
  description = "Username for the ThirdAI platform admin"
  type        = string
}

variable "platform_admin_password" {
  description = "Password for the ThirdAI platform admin"
  type        = string
  sensitive   = true
}

variable "platform_version" {
  description = "Version of the ThirdAI Platform to deploy"
  type        = string
  default     = "2.0.0"
}

variable "user_auth_method" {
  description = "Authentication method (e.g., SSO, manual)"
  type        = string
}

variable "openai_api_key" {
  description = "API key for OpenAI integration"
  type        = string
  sensitive   = true
}

variable "license_file_path" {
  description = "Path to the ThirdAI enterprise license file"
  type        = string
}

variable "source_image_publisher" {
  description = "Publisher for the source image"
  type        = string
  default     = "Canonical"
}

variable "source_image_offer" {
  description = "Offer for the source image"
  type        = string
  default     = "0001-com-ubuntu-server-jammy"
}

variable "source_image_sku" {
  description = "SKU for the source image"
  type        = string
  default     = "22_04-lts"
}

variable "source_image_version" {
  description = "Version for the source image"
  type        = string
  default     = "latest"
}

variable "vnet_address_space" {
  description = "The address space for the virtual network"
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "postgresql_subnet_prefix" {
  description = "Address prefix for the PostgreSQL subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "vm_subnet_prefix" {
  description = "Address prefix for the VM subnet"
  type        = string
  default     = "10.0.2.0/24"
}

variable "postgresql_sku" {
  description = "SKU name for PostgreSQL Flexible Server"
  type        = string
  default     = "B_Standard_B1ms"
}

variable "postgresql_version" {
  description = "PostgreSQL version to deploy"
  type        = string
  default     = "14"
}

variable "postgresql_storage_tier" {
  description = "Storage tier for PostgreSQL Flexible Server"
  type        = string
  default     = "P4"
}

variable "nfs_share_quota" {
  description = "Quota for the NFS share (in GB)"
  type        = number
  default     = 200
}

