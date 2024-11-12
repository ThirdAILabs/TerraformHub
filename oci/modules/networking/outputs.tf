# File: ./modules/networking/outputs.tf

output "vcn_id" {
  description = "OCID of the created VCN"
  value       = oci_core_vcn.vcn.id
}

output "subnet_id" {
  description = "OCID of the created subnet"
  value       = oci_core_subnet.subnet.id
}