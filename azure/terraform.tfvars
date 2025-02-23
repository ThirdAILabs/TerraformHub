azure_region           = "Central US"
instance_type          = "Standard_B8ms"
default_ssh_user       = "azureuser"
ssh_public_key_path = "~/.ssh/azure_vm_rsa.pub"
rds_master_username    = "adminuser"
rds_master_password    = "adminpassword"
vm_count = 3
rds_storage_size_gb    = 32
rds_backup_retention_days = 7
subscription_id = "azure-subscription-id"
tenant_id       = "azure-tenant-id"
client_id       = "azure-client-id" # Contributor role for subscription level
client_secret   = "azure-client-secret"
platform_admin_email = "admin@thirdai.com"
platform_admin_username = "admin"
platform_admin_password = "password"
platform_version = "v2.0.1"
user_auth_method = "keycloak"
openai_api_key = ""
license_file_path = "/path/to/ndb_enterprise_license.json"