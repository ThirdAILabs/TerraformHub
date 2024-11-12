resource "oci_core_instance" "generated_oci_core_instance" {
  compartment_id      = var.compartment_id
  availability_domain = var.availability_domain
  display_name        = var.instance_name
  shape               = "VM.Standard.E5.Flex"

  shape_config {
    ocpus         = 4
    memory_in_gbs = 16
  }

  create_vnic_details {
    subnet_id        = var.subnet_id
    assign_public_ip = true
    display_name     = var.vnic_name
    nsg_ids          = var.nsg_ids
  }

  source_details {
    source_type             = "image"
    source_id               = "ocid1.image.oc1.us-chicago-1.aaaaaaaaulk5wmw64opjanlveodijztcjlhrxr5zyvcbierrwhildef62pbq"
    boot_volume_size_in_gbs = 64
  }

  metadata = {
    ssh_authorized_keys = "${var.ssh_public_key}\n${tls_private_key.instance_ssh_key.public_key_openssh}"
  }

  agent_config {
    is_management_disabled = false
    is_monitoring_disabled = false
    plugins_config {
      desired_state = "ENABLED"
      name          = "Compute Instance Monitoring"
    }
  }
}