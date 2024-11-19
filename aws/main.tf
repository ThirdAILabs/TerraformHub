terraform {
  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Generate a random string for unique resource names
resource "random_string" "unique_suffix" {
  length  = 6
  upper   = false
  special = false
}

# Conditionally create security group if it doesn't exist
resource "aws_security_group" "allow_all_thirdai_platform_ingress" {
  name        = "allow_all_thirdai_platform_ingress_sg-${random_string.unique_suffix.result}"
  description = "Security group that allows all ingress traffic from the subnet"
  vpc_id      = var.vpc_id

  # Allow internal communication for RDS on port 5432
  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    self        = true
  }

  # Allow all ingress traffic within the subnet
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [data.aws_subnet.selected_subnet.cidr_block]
  }

  # Allow SSH traffic
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# RDS Database Instance
resource "aws_db_instance" "thirdai-platform-main" {
  count                = var.existing_rds_endpoint != "" ? 0 : 1
  allocated_storage    = var.rds_storage_size_gb
  engine               = "postgres"
  engine_version       = "14.10"
  instance_class       = var.rds_instance_class
  db_name              = "modelbazaar"
  identifier           = "thirdai-platform-${random_string.unique_suffix.result}"
  username             = var.rds_master_username
  password             = var.rds_master_password
  vpc_security_group_ids = [aws_security_group.allow_all_thirdai_platform_ingress.id]
  db_subnet_group_name = aws_db_subnet_group.rds_subnet.name

  # Ensures the RDS instance is accessible from within the VPC only
  publicly_accessible = false

  # Configurable storage encryption
  storage_encrypted   = var.rds_encryption_enabled

  # Conditionally include KMS Key ID only if provided
  kms_key_id          = var.rds_encryption_enabled && var.rds_kms_key_id != "" ? var.rds_kms_key_id : null

  # Automated backups
  backup_retention_period = var.rds_backup_retention_days
  backup_window           = var.rds_backup_window

  tags = {
    Name = var.rds_identifier
  }

  # Skip the final snapshot
  skip_final_snapshot = false
  final_snapshot_identifier = "final-snapshot-${var.rds_identifier}-${random_string.unique_suffix.result}" # Define a final snapshot name
}

# RDS Subnet Group
resource "aws_db_subnet_group" "rds_subnet" {
  name       = "rds-subnet-group-${random_string.unique_suffix.result}"
  subnet_ids = [var.primary_subnet_id, var.secondary_subnet_id]

  tags = {
    Name = "RDS Subnet Group-${random_string.unique_suffix.result}"
  }
}

# Use existing RDS endpoint or newly created one
locals {
  rds_endpoint = var.existing_rds_endpoint != "" ? var.existing_rds_endpoint : aws_db_instance.thirdai-platform-main[0].endpoint
  rds_username = var.existing_rds_endpoint != "" ? var.existing_rds_username : var.rds_master_username
  rds_password = var.existing_rds_endpoint != "" ? var.existing_rds_password : var.rds_master_password
}

# EFS File System
resource "aws_efs_file_system" "efs" {
  count     = var.existing_efs_id != "" ? 0 : 1
  encrypted = var.efs_encryption_enabled

  lifecycle_policy {
    transition_to_ia = var.efs_lifecycle_policy_transition
  }

  performance_mode = var.efs_performance_mode
  throughput_mode  = var.efs_throughput_mode
  provisioned_throughput_in_mibps = var.efs_throughput_mode == "provisioned" ? var.efs_provisioned_throughput_mibps : null

  tags = {
    Name = "Platform EFS-${random_string.unique_suffix.result}"
  }

  # Ignore changes to throughput settings to avoid unnecessary updates
  lifecycle {
    ignore_changes = [
      throughput_mode,
      provisioned_throughput_in_mibps
    ]
  }
}

# Use existing EFS ID or newly created one
locals {
  efs_id = var.existing_efs_id != "" ? var.existing_efs_id : aws_efs_file_system.efs[0].id
}

# EFS Mount Target
resource "aws_efs_mount_target" "efs_mount" {
  file_system_id  = local.efs_id
  subnet_id       = var.primary_subnet_id
  security_groups = [aws_security_group.allow_all_thirdai_platform_ingress.id]
}

# EFS Backup Policy
resource "aws_efs_backup_policy" "efs_backup" {
  file_system_id = local.efs_id

  backup_policy {
    status = var.efs_backup_enabled ? "ENABLED" : "DISABLED"
  }
}

# Fetch Subnet Information
data "aws_subnet" "selected_subnet" {
  id = var.primary_subnet_id
}

# Ingress Rule for EFS
resource "aws_security_group_rule" "allow_efs_access" {
  type              = "ingress"
  from_port         = 2049
  to_port           = 2049
  protocol          = "tcp"
  security_group_id = aws_security_group.allow_all_thirdai_platform_ingress.id
  cidr_blocks       = [data.aws_subnet.selected_subnet.cidr_block]
}

resource "tls_private_key" "instance_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

# Conditionally Create Key Pair if it Doesn't Exist
resource "aws_key_pair" "instance_key_pair" {
  key_name   = "internal-ssh-key-${random_string.unique_suffix.result}"
  public_key = tls_private_key.instance_key.public_key_openssh
}

# Create EC2 Instances
resource "aws_instance" "ec2_instances" {
  count         = var.ec2_instance_count - 1
  ami           = var.ami_id
  instance_type = var.instance_type
  subnet_id     = var.primary_subnet_id
  vpc_security_group_ids = [aws_security_group.allow_all_thirdai_platform_ingress.id]

  root_block_device {
    volume_size = var.root_volume_size_gb
  }

  tags = {
    Name = "ec2-instance-${count.index}"
  }

  # Add SSH key pair for each instance
  key_name = aws_key_pair.instance_key_pair.key_name

  # User data to add public key to authorized keys
  user_data = <<EOF
#!/bin/bash
mkdir -p /home/${var.default_ssh_user}/.ssh
echo '${tls_private_key.instance_key.public_key_openssh}' >> /home/${var.default_ssh_user}/.ssh/authorized_keys
chown -R ${var.default_ssh_user}:${var.default_ssh_user} /home/${var.default_ssh_user}/.ssh
chmod 700 /home/${var.default_ssh_user}/.ssh
chmod 600 /home/${var.default_ssh_user}/.ssh/authorized_keys

# Install NFS utilities and mount the EFS file system at /opt/thirdai_platform/model_bazaar

# Determine package manager and install necessary NFS utilities
if [ "${var.default_ssh_user}" == "ubuntu" ]; then
  apt install -y nfs-common
else
  yum install -y amazon-efs-utils nfs-utils
fi

mkdir -p /opt/thirdai_platform/model_bazaar

# Wait for EFS DNS resolution
mount_dns="${local.efs_id}.efs.${var.aws_region}.amazonaws.com"
mount_ip=$(dig +short $mount_dns)

# Loop until DNS resolution is successful
while [ "$mount_ip" = "" ]
do
  echo "DNS for EFS mount unresolved, retrying in 10 seconds..."
  sleep 10
  mount_ip=$(dig +short $mount_dns)
done

# Use NFS mount for EFS on Ubuntu if amazon-efs-utils is not available
if [ "${var.default_ssh_user}" == "ubuntu" ]; then
  mount -t nfs4 -o nfsvers=4.1 ${local.efs_id}.efs.${var.aws_region}.amazonaws.com:/ /opt/thirdai_platform/model_bazaar
else
  mount -t efs -o tls ${local.efs_id}:/ /opt/thirdai_platform/model_bazaar
fi

# Add to /etc/fstab to auto-mount EFS after reboot
echo "${local.efs_id}:/ /opt/thirdai_platform/model_bazaar efs _netdev,tls 0 0" >> /etc/fstab
EOF
}

# User data for the last instance to configure all nodes
resource "aws_instance" "last_node" {
  ami           = var.ami_id
  instance_type = var.instance_type
  subnet_id     = var.primary_subnet_id
  vpc_security_group_ids = [aws_security_group.allow_all_thirdai_platform_ingress.id]

  root_block_device {
    volume_size = var.root_volume_size_gb
  }

  key_name = var.ssh_key_name

  tags = {
    Name = "ec2-last-node"
  }

  user_data = <<EOF
#!/bin/bash
mkdir -p /home/${var.default_ssh_user}/.ssh

# Add private key and public key to last node
echo '${tls_private_key.instance_key.private_key_pem}' > /home/${var.default_ssh_user}/.ssh/id_rsa
chmod 600 /home/${var.default_ssh_user}/.ssh/id_rsa
echo '${tls_private_key.instance_key.public_key_openssh}' > /home/${var.default_ssh_user}/.ssh/id_rsa.pub
chmod 644 /home/${var.default_ssh_user}/.ssh/id_rsa.pub
echo '${tls_private_key.instance_key.public_key_openssh}' >> /home/${var.default_ssh_user}/.ssh/authorized_keys
chown -R ${var.default_ssh_user}:${var.default_ssh_user} /home/${var.default_ssh_user}/.ssh
chmod 700 /home/${var.default_ssh_user}/.ssh
chmod 600 /home/${var.default_ssh_user}/.ssh/authorized_keys

# Install NFS utilities and mount the EFS file system at /opt/thirdai_platform/model_bazaar

# Determine package manager and install necessary NFS utilities
if [ "${var.default_ssh_user}" == "ubuntu" ]; then
  apt install -y nfs-common
else
  yum install -y amazon-efs-utils nfs-utils
fi

mkdir -p /opt/thirdai_platform/model_bazaar

# Wait for EFS DNS resolution
mount_dns="${local.efs_id}.efs.${var.aws_region}.amazonaws.com"
mount_ip=$(dig +short $mount_dns)

# Loop until DNS resolution is successful
while [ "$mount_ip" = "" ]
do
  echo "DNS for EFS mount unresolved, retrying in 10 seconds..."
  sleep 10
  mount_ip=$(dig +short $mount_dns)
done

# Use NFS mount for EFS on Ubuntu if amazon-efs-utils is not available
if [ "${var.default_ssh_user}" == "ubuntu" ]; then
  mount -t nfs4 -o nfsvers=4.1 ${local.efs_id}.efs.${var.aws_region}.amazonaws.com:/ /opt/thirdai_platform/model_bazaar
else
  mount -t efs -o tls ${local.efs_id}:/ /opt/thirdai_platform/model_bazaar
fi

# Add to /etc/fstab to auto-mount EFS after reboot
echo "${local.efs_id}:/ /opt/thirdai_platform/model_bazaar efs _netdev,tls 0 0" >> /etc/fstab

# Switch to ${var.default_ssh_user} for the rest of the script
cat <<'SCRIPT' | sudo -u ${var.default_ssh_user} bash
cd ~
wget https://thirdai-corp-public.s3.us-east-2.amazonaws.com/ThirdAI-Platform-latest-release/thirdai-platform-package-release-test-main-v0.0.82.tar.gz
tar -xvzf thirdai-platform-package-release-test-main-v0.0.82.tar.gz

# Create ndb_enterprise_license.json file from local text
cat <<EOL > /home/${var.default_ssh_user}/ndb_enterprise_license.json
${file(var.license_file_path)}
EOL

chmod +x driver.sh

# Fetch a session token from the metadata service
TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")

# Now retrieve the private and public IPs using the session token
last_node_private_ip=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" "http://169.254.169.254/latest/meta-data/local-ipv4")
last_node_public_ip=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" "http://169.254.169.254/latest/meta-data/public-ipv4")

# Display the results
echo "Private IP: $last_node_private_ip"
echo "Public IP: $last_node_public_ip"

sed -i '/- name: \"node2\"/,$d' config.yml

# Construct the sql_uri dynamically with endpoint and credentials
sql_uri="postgresql://${local.rds_username}:${local.rds_password}@${local.rds_endpoint}/modelbazaar"
echo "SQL URI: $sql_uri"

# Update config.yml with self_hosted_sql_server and sql_uri
sed -i 's|self_hosted_sql_server:.*|self_hosted_sql_server: false|' config.yml
sed -i "/^nodes:/i sql_uri: \"$${sql_uri}\"" config.yml

sed -i 's|license_path:.*|license_path: \"/home/${var.default_ssh_user}/ndb_enterprise_license.json\"|' config.yml
sed -i 's|admin_mail:.*|admin_mail: \"${var.platform_admin_email}\"|' config.yml
sed -i 's|admin_username:.*|admin_username: \"${var.platform_admin_username}\"|' config.yml
sed -i 's|admin_password:.*|admin_password: \"${var.platform_admin_password}\"|' config.yml
sed -i 's|thirdai_platform_version:.*|thirdai_platform_version: \"${var.platform_version}\"|' config.yml
sed -i 's|login_method:.*|login_method: \"${var.user_auth_method}\"|' config.yml
sed -i 's|genai_key:.*|genai_key: \"${var.openai_api_key}\"|' config.yml
sed -i 's|create_nfs_server:.*|create_nfs_server: false|' config.yml

sed -i "s|public_ip:.*|public_ip: \"$${last_node_public_ip}\"|" config.yml
sed -i "s|private_ip:.*|private_ip: \"$${last_node_private_ip}\"|" config.yml
sed -i 's|ssh_username:.*|ssh_username: \"${var.default_ssh_user}\"|' config.yml

sed -i '/connection_type:/,/# in which case Ansible will install all libraries directly on the local host without using SSH/{d}' config.yml
sed -i '/ssh_username:/a \    connection_type: \"local\"' config.yml

nodes_private_ips="${join(",", aws_instance.ec2_instances[*].private_ip)}"
IFS=',' read -r -a private_ips <<< "$nodes_private_ips"
for i in $(seq 0 $(($${#private_ips[@]} - 1))); do
    echo "  - name: \"node$((i + 2))\"" >> config.yml
    echo "    private_ip: \"$${private_ips[$i]}\"" >> config.yml
    echo "    ssh_username: \"${var.default_ssh_user}\"" >> config.yml
    echo "    connection_type: \"ssh\"" >> config.yml
    echo "    private_key: \"\"" >> config.yml
    echo "    ssh_common_args: \"\"" >> config.yml
    echo "    roles: []" >> config.yml
done

./driver.sh config.yml

SCRIPT
EOF
}