output "resource_group_name" {
  value = azurerm_resource_group.main.name
}

output "postgresql_server_fqdn" {
  value = azurerm_postgresql_flexible_server.main.fqdn
}

output "storage_account_name" {
  value = azurerm_storage_account.main.name
}

output "storage_share_name" {
  value = azurerm_storage_share.main.name
}

output "last_node_public_ip" {
  description = "Public IP of the last node"
  value       = azurerm_public_ip.last_node.ip_address
}

output "worker_private_ips" {
  description = "Private IPs of worker nodes"
  value       = azurerm_network_interface.worker_nics[*].private_ip_address
}

output "last_node_private_ip" {
  description = "Private IP of the last node"
  value       = azurerm_network_interface.last_node_nic.private_ip_address
}

output "vnet_name" {
  value = azurerm_virtual_network.main.name
}

output "subnet_name" {
  value = azurerm_subnet.postgresql.name
}
