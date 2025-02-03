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

variable "geo_redundant_backup_enabled" {
  description = "Set to true if geo redndant backup to be enabled"
  type        = bool
  default     = false
}

variable "restore_mode" {
  description = "Set to true if restoring from backup so that databases already exist."
  type        = bool
  default     = false
}

variable "restore_from_server_id" {
  description = "Optional: Provide an existing PostgreSQL Flexible Server ID to restore from. Leave empty to create a new server."
  type        = string
  default     = ""
}

variable "restore_point_in_time" {
  description = "Optional: The point in time (in RFC3339 format) to restore from if restoring from an existing server. This value is used as the value for point_in_time_restore_time_in_utc."
  type        = string
  default     = ""
}

variable "existing_recovery_point_id" {
  description = "If set, this backup recovery point ID is used to restore the file share instead of creating a new one."
  type        = string
  default     = ""
}

variable "target_file_share_name" {
  description = "The name of the target file share to restore to."
  type        = string
  default     = "restored-fileshare"
}

variable "backup_container_name" {
  description = "The backup container name in the Recovery Services vault. This is usually available from the backup item details."
  type        = string
  default     = ""
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
