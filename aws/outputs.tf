output "instance_ids" {
  value = [for instance in aws_instance.ec2_instances : instance.id]
}

output "ec2_private_ips" {
  value = aws_instance.ec2_instances[*].private_ip
}

output "ec2_public_ips" {
  value = aws_instance.ec2_instances[*].public_ip
}


output "internal_ssh_private_key" {
  value     = tls_private_key.instance_key.private_key_pem
  sensitive = true
}

output "private_key" {
  value     = tls_private_key.instance_key.private_key_pem
  sensitive = true
}

output "public_key" {
  value = tls_private_key.instance_key.public_key_openssh
}

# Output the private and public IP of the last node
output "last_node_private_ip" {
  value = aws_instance.last_node.private_ip
}

output "last_node_public_ip" {
  value = aws_instance.last_node.public_ip
}

output "efs_id" {
  description = "The ID of the created EFS file system"
  value       = aws_efs_file_system.example.id
}