terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=4.0.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}

  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id
  client_id       = var.client_id
  client_secret   = var.client_secret
}

resource "random_string" "unique_suffix" {
  length  = 6
  upper   = false
  special = false
}

resource "azurerm_resource_group" "main" {
  name     = "thirdai-platform-rg-${random_string.unique_suffix.result}"
  location = var.azure_region
}

data "http" "my_ip" {
  url = "https://api4.ipify.org?format=text"
}

resource "azurerm_virtual_network" "main" {
  name                = "thirdai-platform-vnet-${random_string.unique_suffix.result}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "postgresql" {
  name                 = "thirdai-platform-postgres-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.1.0/24"]
  delegation {
    name = "postgreSQLDelegation"
    service_delegation {
      name = "Microsoft.DBforPostgreSQL/flexibleServers"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/action",
        "Microsoft.Network/virtualNetworks/subnets/join/action"
      ]
    }
  }

  lifecycle {
    ignore_changes = [delegation]
  }
}

resource "azurerm_subnet" "vm" {
  name                 = "thirdai-platform-vm-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.2.0/24"]
  service_endpoints    = ["Microsoft.Sql", "Microsoft.Storage"]
}

resource "azurerm_network_security_group" "allow_all_thirdai_platform_ingress" {
  name                = "allow_all_thirdai_platform_ingress_sg-${random_string.unique_suffix.result}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  security_rule {
    name                       = "AllowPostgres"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "*"
    destination_port_range     = "5432"
    source_port_range          = "*" # Allow all ports
  }

  security_rule {
    name                       = "AllowSubnetIngress"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "*"
    source_port_range          = "*" # Allow all ports
    destination_port_range     = "*"
  }

  security_rule {
    name                       = "AllowSSH"
    priority                   = 300
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_address_prefix      = "0.0.0.0/0"
    destination_address_prefix = "*"
    destination_port_range     = "22"
    source_port_range          = "*" # Allow all ports
  }

  security_rule {
    name                       = "AllowOutbound"
    priority                   = 400
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
    source_port_range          = "*" # Allow all ports
    destination_port_range     = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "vm" {
  subnet_id                 = azurerm_subnet.vm.id
  network_security_group_id = azurerm_network_security_group.allow_all_thirdai_platform_ingress.id
}

resource "azurerm_subnet_network_security_group_association" "postgresql" {
  subnet_id                 = azurerm_subnet.postgresql.id
  network_security_group_id = azurerm_network_security_group.allow_all_thirdai_platform_ingress.id
}

resource "tls_private_key" "instance_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "azurerm_private_dns_zone" "postgresql" {
  name                = "privatelink.postgres.database.azure.com"
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "postgresql_vnet_link" {
  name                  = "postgresql-vnet-link"
  private_dns_zone_name = azurerm_private_dns_zone.postgresql.name
  resource_group_name   = azurerm_resource_group.main.name
  virtual_network_id    = azurerm_virtual_network.main.id
}

resource "azurerm_postgresql_flexible_server" "main" {
  name                = "thirdai-platform-postgres-server"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  administrator_login = var.rds_master_username
  administrator_password = var.rds_master_password
  public_network_access_enabled = false
  sku_name            = "Standard_B1ms"
  storage_mb          = var.rds_storage_size_gb * 1024
  version             = "14"
  storage_tier = "P4"

  delegated_subnet_id = azurerm_subnet.postgresql.id
  private_dns_zone_id       = azurerm_private_dns_zone.postgresql.id

  backup_retention_days         = var.rds_backup_retention_days
  geo_redundant_backup_enabled  = false

  create_mode = var.restore_from_server_id != "" ? "PointInTimeRestore" : "Default"
  source_server_id = var.restore_from_server_id != "" ? var.restore_from_server_id : null
  point_in_time_restore_time_in_utc = var.restore_from_server_id != "" ? var.restore_point_in_time : null

  lifecycle {
      ignore_changes = [
        zone,
        high_availability.0.standby_availability_zone
      ]
  }

}

resource "azurerm_postgresql_flexible_server_database" "modelbazaar" {
  count     = var.restore_mode ? 0 : 1
  name                = "modelbazaar"
  server_id         = azurerm_postgresql_flexible_server.main.id
  collation = "en_US.utf8"
  charset   = "utf8"

}

resource "azurerm_postgresql_flexible_server_database" "grafana" {
  count     = var.restore_mode ? 0 : 1
  name                = "grafana"
  server_id         = azurerm_postgresql_flexible_server.main.id
  collation = "en_US.utf8"
  charset   = "utf8"

}

resource "azurerm_postgresql_flexible_server_database" "keycloak" {
  count     = var.restore_mode ? 0 : 1
  name                = "keycloak"
  server_id         = azurerm_postgresql_flexible_server.main.id
  collation = "en_US.utf8"
  charset   = "utf8"

}

resource "azurerm_storage_account" "main" {
  name                     = "thirdaiplatformsa${random_string.unique_suffix.result}"
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Premium"
  account_kind             = "FileStorage"
  account_replication_type = "LRS"

  https_traffic_only_enabled = false

}

resource "azurerm_storage_share" "main" {
  name                 = "thirdai-platform-share"
  storage_account_name = azurerm_storage_account.main.name
  quota                = 200 # Size in GB
  enabled_protocol     = "NFS"

  depends_on = [
    azurerm_storage_account.main,
  ]
}

resource "azurerm_storage_account_network_rules" "main" {
  storage_account_id = azurerm_storage_account.main.id
  default_action     = "Deny"

  virtual_network_subnet_ids = [
    azurerm_subnet.vm.id  # Allow access only from the VM subnet
  ]

  ip_rules = [chomp(data.http.my_ip.response_body)]

  bypass = ["AzureServices"]

  depends_on = [
    azurerm_storage_share.main,  # Ensure storage share is created first
  ]
}

resource "azurerm_recovery_services_vault" "backup_vault" {
  name                = "thirdai-backup-vault-${random_string.unique_suffix.result}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "Standard"
}

resource "azurerm_backup_policy_file_share" "backup_policy" {
  name                = "thirdai-fileshare-backup-policy"
  resource_group_name = azurerm_resource_group.main.name
  recovery_vault_name = azurerm_recovery_services_vault.backup_vault.name
  timezone            = "UTC"

  backup {
    frequency = "Daily"
    time      = "23:00"
  }

  retention_daily {
    count = 7
  }
}

resource "azurerm_backup_protected_file_share" "protected_fileshare" {
  resource_group_name = azurerm_resource_group.main.name
  recovery_vault_name = azurerm_recovery_services_vault.backup_vault.name
  backup_policy_id    = azurerm_backup_policy_file_share.backup_policy.id
  source_resource_id  = azurerm_storage_share.main.id
}

resource "null_resource" "fileshare_restore" {
  count = var.existing_recovery_point_id != "" ? 1 : 0

  provisioner "local-exec" {
    command = <<EOF
az backup restore restore-azurefileshare \\
  --resource-group "${azurerm_resource_group.main.name}" \\
  --vault-name "${azurerm_recovery_services_vault.backup_vault.name}" \\
  --container-name "${var.backup_container_name}" \\
  --item-name "${azurerm_storage_share.main.name}" \\
  --recovery-point-id "${var.existing_recovery_point_id}" \\
  --target-storage-account "$(az storage account show --ids ${azurerm_storage_account.main.id} --query id --output tsv)" \\
  --target-file-share "${var.target_file_share_name}"
EOF
  }
}

resource "azurerm_public_ip" "last_node" {
  name                = "thirdai-last-node-public-ip-${random_string.unique_suffix.result}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
}

# Last node network interface (with public IP)
resource "azurerm_network_interface" "last_node_nic" {
  name                 = "thirdai-last-node-nic-${random_string.unique_suffix.result}"
  location             = azurerm_resource_group.main.location
  resource_group_name  = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.vm.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.last_node.id
  }
}

# Worker VM network interfaces (private IP only)
resource "azurerm_network_interface" "worker_nics" {
  count                = var.vm_count - 1
  name                 = "thirdai-worker-nic-${count.index}-${random_string.unique_suffix.result}"
  location             = azurerm_resource_group.main.location
  resource_group_name  = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.vm.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "worker_vms" {
  count                  = var.vm_count - 1
  name                   = "thirdai-worker-${count.index}-${random_string.unique_suffix.result}"
  resource_group_name    = azurerm_resource_group.main.name
  location               = azurerm_resource_group.main.location
  size                   = var.instance_type
  admin_username         = var.default_ssh_user
  network_interface_ids  = [azurerm_network_interface.worker_nics[count.index].id]

  admin_ssh_key {
    username   = var.default_ssh_user
    public_key = tls_private_key.instance_key.public_key_openssh
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = var.root_volume_size_gb
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  custom_data = base64encode(<<EOF
#!/bin/bash
echo "Updating and installing NFS client..."
apt-get update -y
apt-get install -y nfs-common

# Create SSH directory
mkdir -p /home/${var.default_ssh_user}/.ssh
echo "${base64encode(tls_private_key.instance_key.public_key_openssh)}" | base64 -d >> /home/${var.default_ssh_user}/.ssh/authorized_keys
chown -R ${var.default_ssh_user}:${var.default_ssh_user} /home/${var.default_ssh_user}/.ssh
chmod 700 /home/${var.default_ssh_user}/.ssh
chmod 600 /home/${var.default_ssh_user}/.ssh/authorized_keys

# Create mount point
mkdir -p /opt/thirdai_platform/model_bazaar

# Wait for network initialization
echo "Waiting for network to initialize..." >> /var/log/cloud-init-debug.log
sleep 10

# Mount NFS Share
MOUNT_COMMAND="mount -t nfs ${azurerm_storage_account.main.name}.file.core.windows.net:/${azurerm_storage_account.main.name}/${azurerm_storage_share.main.name} /opt/thirdai_platform/model_bazaar -o vers=4,minorversion=1,sec=sys,nconnect=4"

for i in {1..5}; do
  echo "Attempt $i: Running command: $MOUNT_COMMAND" >> /var/log/cloud-init-debug.log
  eval $MOUNT_COMMAND
  if [ $? -eq 0 ]; then
    echo "Mount successful on attempt $i" >> /var/log/cloud-init-debug.log
    break
  else
    echo "Mount failed on attempt $i. Retrying in 5 seconds..." >> /var/log/cloud-init-debug.log
    sleep 5
  fi
done

if ! mountpoint -q /opt/thirdai_platform/model_bazaar; then
  echo "Mount failed after 5 attempts." >> /var/log/cloud-init-debug.log
  exit 1
fi

# Persist mount in fstab
echo "${azurerm_storage_account.main.name}.file.core.windows.net:/${azurerm_storage_account.main.name}/${azurerm_storage_share.main.name} /opt/thirdai_platform/model_bazaar nfs vers=4,minorversion=1,sec=sys,nconnect=4" >> /etc/fstab
EOF
  )
}

# Last node VM
resource "azurerm_linux_virtual_machine" "last_node" {
  name                   = "thirdai-last-node-${random_string.unique_suffix.result}"
  resource_group_name    = azurerm_resource_group.main.name
  location               = azurerm_resource_group.main.location
  size                   = var.instance_type
  admin_username         = var.default_ssh_user
  network_interface_ids  = [azurerm_network_interface.last_node_nic.id]

  admin_ssh_key {
    username   = var.default_ssh_user
    public_key = file(var.ssh_public_key_path)
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = var.root_volume_size_gb
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

custom_data = base64encode(<<EOF
#!/bin/bash

set -e  # Exit immediately if a command exits with a non-zero status.

# Install required packages
echo "Installing required packages..."
apt-get update -y
apt-get install -y nfs-common

# Set up SSH directory for the default user
mkdir -p /home/${var.default_ssh_user}/.ssh
echo "${base64encode(tls_private_key.instance_key.private_key_pem)}" | base64 -d > /home/${var.default_ssh_user}/.ssh/id_rsa
chmod 600 /home/${var.default_ssh_user}/.ssh/id_rsa
echo "${base64encode(tls_private_key.instance_key.public_key_openssh)}" | base64 -d > /home/${var.default_ssh_user}/.ssh/id_rsa.pub
chmod 644 /home/${var.default_ssh_user}/.ssh/id_rsa.pub
echo "${base64encode(tls_private_key.instance_key.public_key_openssh)}" | base64 -d >> /home/${var.default_ssh_user}/.ssh/authorized_keys
chown -R ${var.default_ssh_user}:${var.default_ssh_user} /home/${var.default_ssh_user}/.ssh
chmod 700 /home/${var.default_ssh_user}/.ssh
chmod 600 /home/${var.default_ssh_user}/.ssh/authorized_keys

# Create directory for Model Bazaar
mkdir -p /opt/thirdai_platform/model_bazaar

# Wait for network initialization
echo "Waiting for network to initialize..." >> /var/log/cloud-init-debug.log
sleep 10  # Wait for 10 seconds to ensure network is ready

# Mount CIFS Storage
echo "Attempting to mount NFS share..." >> /var/log/cloud-init-debug.log
MOUNT_COMMAND="mount -t nfs ${azurerm_storage_account.main.name}.file.core.windows.net:/${azurerm_storage_account.main.name}/${azurerm_storage_share.main.name} \
  /opt/thirdai_platform/model_bazaar -o vers=4,minorversion=1,sec=sys,nconnect=4"

for i in {1..5}; do
  echo "Attempt $i: Running command: $MOUNT_COMMAND" >> /var/log/cloud-init-debug.log
  eval $MOUNT_COMMAND
  if [ $? -eq 0 ]; then
    echo "Mount successful on attempt $i" >> /var/log/cloud-init-debug.log
    break
  else
    echo "Mount failed on attempt $i. Retrying in 5 seconds..." >> /var/log/cloud-init-debug.log
    sleep 5
  fi
done

if ! mountpoint -q /opt/thirdai_platform/model_bazaar; then
  echo "Mount failed after 5 attempts. Command: $MOUNT_COMMAND" >> /var/log/cloud-init-debug.log
  exit 1
fi

# Persist the mount in fstab
echo "${azurerm_storage_account.main.name}.file.core.windows.net:/${azurerm_storage_account.main.name}/${azurerm_storage_share.main.name} /opt/thirdai_platform/model_bazaar nfs vers=4,minorversion=1,sec=sys,nconnect=4" >> /etc/fstab

# Download and extract ThirdAI platform package
cd /home/${var.default_ssh_user}
wget https://thirdai-corp-public.s3.us-east-2.amazonaws.com/ThirdAI-Platform-latest-release/thirdai-platform-package-release-test-main-v2.0.0.tar.gz
tar -xvzf thirdai-platform-package-release-test-main-v2.0.0.tar.gz

# Create ndb_enterprise_license.json file
cat <<EOL > /home/${var.default_ssh_user}/ndb_enterprise_license.json
${file(var.license_file_path)}
EOL

chmod +x driver.sh

# Get the last node's IPs
last_node_private_ip="${azurerm_network_interface.last_node_nic.private_ip_address}"
last_node_public_ip="${azurerm_public_ip.last_node.ip_address}"

echo "Private IP: $last_node_private_ip"
echo "Public IP: $last_node_public_ip"

# Remove existing node2 configuration from config.yml
sed -i '/- name: \"node2\"/,$d' config.yml

# Construct database connection URIs
modelbazaar_db_uri="postgresql://${var.rds_master_username}:${var.rds_master_password}@${azurerm_postgresql_flexible_server.main.fqdn}/modelbazaar"
keycloak_db_uri="postgresql://${var.rds_master_username}:${var.rds_master_password}@${azurerm_postgresql_flexible_server.main.fqdn}/keycloak"
grafana_db_uri="postgres://${var.rds_master_username}:${var.rds_master_password}@${azurerm_postgresql_flexible_server.main.fqdn}/grafana?sslmode=require"

echo "MODEL BAZAAR SQL URI: $modelbazaar_db_uri"
echo "KEYCLOAK SQL URI: $keycloak_db_uri"
echo "GRAFANA SQL URI: $grafana_db_uri"

# Update config.yml with necessary values
sed -i 's|self_hosted_sql_server:.*|self_hosted_sql_server: false|' config.yml
sed -i 's|license_path:.*|license_path: \"/home/${var.default_ssh_user}/ndb_enterprise_license.json\"|' config.yml
sed -i 's|admin_mail:.*|admin_mail: \"${var.platform_admin_email}\"|' config.yml
sed -i 's|admin_username:.*|admin_username: \"${var.platform_admin_username}\"|' config.yml
sed -i 's|admin_password:.*|admin_password: \"${var.platform_admin_password}\"|' config.yml
sed -i 's|thirdai_platform_version:.*|thirdai_platform_version: \"${var.platform_version}\"|' config.yml
sed -i 's|login_method:.*|login_method: \"${var.user_auth_method}\"|' config.yml
sed -i 's|genai_key:.*|genai_key: \"${var.openai_api_key}\"|' config.yml
sed -i 's|create_nfs_server:.*|create_nfs_server: false|' config.yml
sed -i "s|cluster_endpoint:.*|cluster_endpoint: \"$last_node_public_ip\"|" config.yml
sed -i "s|external_modelbazaar_db_uri:.*|external_modelbazaar_db_uri: \"$modelbazaar_db_uri\"|" config.yml
sed -i "s|external_keycloak_db_uri:.*|external_keycloak_db_uri: \"$keycloak_db_uri\"|" config.yml
sed -i "s|external_grafana_db_uri:.*|external_grafana_db_uri: \"$grafana_db_uri\"|" config.yml
sed -i "s|private_ip:.*|private_ip: \"$last_node_private_ip\"|" config.yml
sed -i 's|ssh_username:.*|ssh_username: \"${var.default_ssh_user}\"|' config.yml

sed -i '/connection_type:/,/# in which case Ansible will install all libraries directly on the local host without using SSH/{d}' config.yml
sed -i '/ssh_username:/a \    connection_type: \"local\"' config.yml

# Process worker nodes' private IPs
nodes_private_ips="${join(",", azurerm_network_interface.worker_nics[*].private_ip_address)}"
IFS=',' read -r -a private_ips <<< "$nodes_private_ips"

for i in $(seq 0 $(($${#private_ips[@]} - 1))); do
    echo "  - name: \"node$((i + 2))\"" >> config.yml
    echo "    private_ip: \"$${private_ips[$i]}\"" >> config.yml
    echo "    ssh_username: \"${var.default_ssh_user}\"" >> config.yml
    echo "    connection_type: \"ssh\"" >> config.yml
    echo "    private_key: \"\"" >> config.yml
    echo "    ssh_common_args: \"\"" >> config.yml
    # Assign roles to nodes:
    # - If there is an even number of nodes or this is not the last node, assign 'critical_services: true'.
    # - The last node in an odd-numbered cluster will have an empty roles array.
    if [ $(($${#private_ips[@]} % 2)) -eq 0 ] || [ $i -lt $(($${#private_ips[@]} - 1)) ]; then
        echo "    roles:" >> config.yml
        echo "      critical_services:" >> config.yml
        echo "        run_jobs: True" >> config.yml
    else
        echo "    roles: {}" >> config.yml
    fi
done

sleep 50

echo "Switching to ${var.default_ssh_user} and running driver.sh..."
su - ${var.default_ssh_user} -c "cd /home/${var.default_ssh_user} && ./driver.sh config.yml"
EOF
)
}
