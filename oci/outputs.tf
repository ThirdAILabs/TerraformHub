
output "vcn_id" {
  value = module.networking.vcn_id
}

output "subnet_id" {
  value = module.networking.subnet_id
}

output "instance_ids" {
  value = module.third_ai_nodes[*].instance_id
}

output "instance_public_ips" {
  value = module.third_ai_nodes[*].public_ip
}

output "instance_private_ips" {
  value = module.third_ai_nodes[*].private_ip
}

output "instance_ssh_private_keys" {
  value     = module.third_ai_nodes[*].instance_ssh_private_key
  sensitive = true
}

output "instance_ssh_public_keys" {
  value = module.third_ai_nodes[*].instance_ssh_public_key
}