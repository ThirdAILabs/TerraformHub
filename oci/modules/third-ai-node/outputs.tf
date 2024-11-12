output "instance_id" {
  description = "OCID of the created instance"
  value       = oci_core_instance.generated_oci_core_instance.id
}

output "public_ip" {
  description = "Public IP of the created instance"
  value       = oci_core_instance.generated_oci_core_instance.public_ip
}

output "private_ip" {
  description = "Private IP of the created instance"
  value       = oci_core_instance.generated_oci_core_instance.private_ip
}

output "instance_ssh_private_key" {
  description = "Private SSH key generated for this instance"
  value       = tls_private_key.instance_ssh_key.private_key_pem
  sensitive   = true
}

output "instance_ssh_public_key" {
  description = "Public SSH key generated for this instance"
  value       = tls_private_key.instance_ssh_key.public_key_openssh
}

output "setup_completed" {
  description = "Indicates whether the instance setup has been completed"
  value       = null_resource.setup_instance.id != "" ? "true" : "false"
}