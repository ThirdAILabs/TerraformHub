# File: ./main.tf

terraform {
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "6.11.0"
    }
  }
}

provider "oci" {
  tenancy_ocid     = var.tenancy_ocid
  region           = var.region
  user_ocid        = var.user_ocid
  fingerprint      = var.fingerprint
  private_key_path = var.private_key_path
}

module "networking" {
  source         = "./modules/networking"
  compartment_id = var.compartment_id
  vcn_name       = "third-ai-vcn"
  vcn_cidr       = var.vcn_cidr
  subnet_cidr    = var.subnet_cidr
}

module "third_ai_nodes" {
  source = "./modules/third-ai-node"
  count  = var.node_count

  compartment_id      = var.compartment_id
  availability_domain = var.availability_domain
  subnet_id           = module.networking.subnet_id
  ssh_public_key      = var.ssh_public_key
  instance_name       = "third-ai-node-${count.index + 1}"
  vnic_name           = "third-ai-vnic-${count.index + 1}"
}