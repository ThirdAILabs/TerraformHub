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

# After all instances are created, configure SSH keys between them
resource "null_resource" "configure_ssh_keys" {
  count = var.node_count
  
  depends_on = [module.third_ai_nodes]

  # Wait for all instances to be ready
  triggers = {
    instance_ids = join(",", [for i in module.third_ai_nodes : i.instance_id])
  }

  connection {
    type        = "ssh"
    host        = module.third_ai_nodes[count.index].public_ip
    user        = "ubuntu"  # Default user for Oracle Linux instances
    private_key = file("~/.ssh/id_rsa")  # Your SSH private key used to connect
  }

  provisioner "remote-exec" {
    inline = [
      "mkdir -p ~/.ssh",
      "chmod 700 ~/.ssh"
    ]
  }

  # Add each node's public key to this node's authorized_keys
  provisioner "remote-exec" {
    inline = concat([
      "mkdir -p ~/.ssh",
      "chmod 700 ~/.ssh",
      "chmod 600 /home/ubuntu/.ssh/id_rsa",
      "chmod 644 /home/ubuntu/.ssh/id_rsa.pub"
    ], 
    [
      for i in range(var.node_count) : 
        "echo '${file("${path.root}/modules/third-ai-node/id_rsa_third-ai-node-${i + 1}.pub")}' >> ~/.ssh/authorized_keys"
    ])
  }
}

locals {
  node_private_ips = [for instance in module.third_ai_nodes : instance.private_ip]
}

resource "null_resource" "setup_last_node" {
  provisioner "remote-exec" {

    inline = [<<-EOT
cat <<'SCRIPT' | sudo -u ubuntu bash
cd ~
wget https://thirdai-corp-public.s3.us-east-2.amazonaws.com/ThirdAI-Platform-latest-release/thirdai-platform-package-release-test-main-v2.0.1.tar.gz
tar -xvzf thirdai-platform-package-release-test-main-v2.0.1.tar.gz

chmod +x driver.sh


# Now retrieve the private and public IPs using the session token
last_node_private_ip=${module.third_ai_nodes[0].private_ip}
last_node_public_ip=${module.third_ai_nodes[0].public_ip}

# Display the results
echo "Private IP: $last_node_private_ip"
echo "Public IP: $last_node_public_ip"

sed -i '/- name: \"node2\"/,$d' config.yml

# Update config.yml with self_hosted_sql_server and sql_uri
sed -i 's|self_hosted_sql_server:.*|self_hosted_sql_server: true|' config.yml

sed -i 's|license_path:.*|license_path: \"/home/ubuntu/ndb_enterprise_license.json\"|' config.yml
sed -i 's|admin_mail:.*|admin_mail: \"${var.platform_admin_email}\"|' config.yml
sed -i 's|admin_username:.*|admin_username: \"${var.platform_admin_username}\"|' config.yml
sed -i 's|admin_password:.*|admin_password: \"${var.platform_admin_password}\"|' config.yml
sed -i 's|thirdai_platform_version:.*|thirdai_platform_version: \"${var.platform_version}\"|' config.yml
sed -i 's|login_method:.*|login_method: \"${var.user_auth_method}\"|' config.yml
sed -i 's|genai_key:.*|genai_key: \"${var.openai_api_key}\"|' config.yml
sed -i 's|create_nfs_server:.*|create_nfs_server: true|' config.yml
sed -i "s|cluster_endpoint:.*|cluster_endpoint: \"$${last_node_public_ip}\"|" config.yml

sed -i "s|private_ip:.*|private_ip: \"$${last_node_private_ip}\"|" config.yml
sed -i 's|ssh_username:.*|ssh_username: \"ubuntu\"|' config.yml

sed -i '/connection_type:/,/# in which case Ansible will install all libraries directly on the local host without using SSH/{d}' config.yml
sed -i '/ssh_username:/a \    connection_type: \"local\"' config.yml

nodes_private_ips="${join(",", slice(local.node_private_ips, 1, length(local.node_private_ips)))}"
IFS=',' read -r -a private_ips <<< "$nodes_private_ips"
for i in $(seq 0 $(($${#private_ips[@]} - 1))); do
    echo "  - name: \"node$((i + 2))\"" >> config.yml
    echo "    private_ip: \"$${private_ips[$i]}\"" >> config.yml
    echo "    ssh_username: \"ubuntu\"" >> config.yml
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
./driver.sh config.yml
SCRIPT
    EOT
    ]

    connection {
      type        = "ssh"
      user        = "ubuntu"
      host        = module.third_ai_nodes[0].public_ip
      private_key = file("~/.ssh/id_rsa")
    }
  }

  # Ensure this resource waits for the node(s) to be created.
  depends_on = [ module.third_ai_nodes ]
}
