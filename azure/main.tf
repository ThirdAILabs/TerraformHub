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
  sku_name            = "B_Standard_B1ms"
  storage_mb          = var.rds_storage_size_gb * 1024
  version             = "14"
  storage_tier = "P4"

  delegated_subnet_id = azurerm_subnet.postgresql.id
  private_dns_zone_id       = azurerm_private_dns_zone.postgresql.id

  lifecycle {
      ignore_changes = [
        zone,
        high_availability.0.standby_availability_zone
      ]
  }

}

resource "azurerm_postgresql_flexible_server_database" "modelbazaar" {
  name                = "modelbazaar"
  server_id         = azurerm_postgresql_flexible_server.main.id
  collation = "en_US.utf8"
  charset   = "utf8"

}

resource "azurerm_postgresql_flexible_server_database" "grafana" {
  name                = "grafana"
  server_id         = azurerm_postgresql_flexible_server.main.id
  collation = "en_US.utf8"
  charset   = "utf8"

}

resource "azurerm_postgresql_flexible_server_database" "keycloak" {
  name                = "keycloak"
  server_id         = azurerm_postgresql_flexible_server.main.id
  collation = "en_US.utf8"
  charset   = "utf8"

}

resource "azurerm_storage_account" "main" {
  name                     = "thirdaiplatformsa${random_string.unique_suffix.result}"
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_share" "main" {
  name                 = "thirdai-platform-share"
  storage_account_name = azurerm_storage_account.main.name
  quota                = 100 # Size in GB
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
#cloud-config
packages:
  - cifs-utils

runcmd:
  - |
    bash -c '
    mkdir -p /home/${var.default_ssh_user}/.ssh
    echo "${base64encode(tls_private_key.instance_key.private_key_pem)}" | base64 -d > /home/${var.default_ssh_user}/.ssh/id_rsa
    chmod 600 /home/${var.default_ssh_user}/.ssh/id_rsa
    echo "${base64encode(tls_private_key.instance_key.public_key_openssh)}" | base64 -d > /home/${var.default_ssh_user}/.ssh/id_rsa.pub
    chmod 644 /home/${var.default_ssh_user}/.ssh/id_rsa.pub
    echo "${base64encode(tls_private_key.instance_key.public_key_openssh)}" | base64 -d >> /home/${var.default_ssh_user}/.ssh/authorized_keys
    chown -R ${var.default_ssh_user}:${var.default_ssh_user} /home/${var.default_ssh_user}/.ssh
    chmod 700 /home/${var.default_ssh_user}/.ssh
    chmod 600 /home/${var.default_ssh_user}/.ssh/authorized_keys
    '
  - mkdir -p /opt/thirdai_platform/model_bazaar
  - echo "Waiting for network to initialize..." >> /var/log/cloud-init-debug.log
  - sleep 10  # Wait for 10 seconds to ensure network is ready
  - echo "Attempting to mount CIFS share..." >> /var/log/cloud-init-debug.log
  - |
    bash -c '
    MOUNT_COMMAND="mount -t cifs //${replace(azurerm_storage_account.main.primary_file_endpoint, "https://", "")}${azurerm_storage_share.main.name} \
      /opt/thirdai_platform/model_bazaar \
      -o vers=3.0,username=${azurerm_storage_account.main.name},password=${azurerm_storage_account.main.primary_access_key},dir_mode=0777,file_mode=0777,serverino"

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
    '
  - echo "//${replace(azurerm_storage_account.main.primary_file_endpoint, "https://", "")}${azurerm_storage_share.main.name} /opt/thirdai_platform/model_bazaar cifs vers=3.0,username=${azurerm_storage_account.main.name},password=${azurerm_storage_account.main.primary_access_key},dir_mode=0777,file_mode=0777,serverino" >> /etc/fstab
EOF
  )
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
#cloud-config
packages:
  - cifs-utils

runcmd:
  - |
    bash -c '
    mkdir -p /home/${var.default_ssh_user}/.ssh
    echo "${base64encode(tls_private_key.instance_key.public_key_openssh)}" | base64 -d >> /home/${var.default_ssh_user}/.ssh/authorized_keys
    chown -R ${var.default_ssh_user}:${var.default_ssh_user} /home/${var.default_ssh_user}/.ssh
    chmod 700 /home/${var.default_ssh_user}/.ssh
    chmod 600 /home/${var.default_ssh_user}/.ssh/authorized_keys
    '
  - mkdir -p /opt/thirdai_platform/model_bazaar
  - echo "Waiting for network to initialize..." >> /var/log/cloud-init-debug.log
  - sleep 10  # Wait for 10 seconds to ensure network is ready
  - echo "Attempting to mount CIFS share..." >> /var/log/cloud-init-debug.log
  - |
    bash -c '
    MOUNT_COMMAND="mount -t cifs //${replace(azurerm_storage_account.main.primary_file_endpoint, "https://", "")}${azurerm_storage_share.main.name} \
      /opt/thirdai_platform/model_bazaar \
      -o vers=3.0,username=${azurerm_storage_account.main.name},password=${azurerm_storage_account.main.primary_access_key},dir_mode=0777,file_mode=0777,serverino"

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
    '
  - echo "//${replace(azurerm_storage_account.main.primary_file_endpoint, "https://", "")}${azurerm_storage_share.main.name} /opt/thirdai_platform/model_bazaar cifs vers=3.0,username=${azurerm_storage_account.main.name},password=${azurerm_storage_account.main.primary_access_key},dir_mode=0777,file_mode=0777,serverino" >> /etc/fstab
EOF
  )
}
