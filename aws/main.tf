provider "aws" {
  region = var.aws_region
}

# Attempt to fetch the existing Security Group by name
data "aws_security_group" "existing_allow_all_ingress" {
  filter {
    name   = "group-name"
    values = ["allow_all_ingress_sg"]
  }
  vpc_id = var.vpc_id
}

# Conditionally create Security Group if it doesn't exist
resource "aws_security_group" "allow_all_ingress" {
  count       = try(data.aws_security_group.existing_allow_all_ingress.id, null) == null ? 1 : 0
  name        = "allow_all_ingress_sg"
  description = "Security group that allows all ingress traffic from the subnet"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [data.aws_subnet.selected_subnet.cidr_block]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Security Group for RDS
resource "aws_security_group" "rds_sg" {
  name        = "rds_security_group"
  description = "Allow ingress for RDS instance"
  vpc_id      = var.vpc_id

  # Allow incoming traffic from EC2 instances
  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [aws_security_group.allow_all_ingress.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# RDS instance
resource "aws_db_instance" "main" {
  allocated_storage    = var.rds_allocated_storage
  engine               = var.rds_engine
  engine_version       = var.rds_engine_version
  instance_class       = var.rds_instance_class
  name                 = var.rds_name
  username             = var.rds_username
  password             = var.rds_password
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  db_subnet_group_name = aws_db_subnet_group.rds_subnet.name

  # Ensures the RDS instance is accessible from within the VPC only
  publicly_accessible = false

  tags = {
    Name = "RDS-${var.rds_name}"
  }
}

# Subnet group for RDS
resource "aws_db_subnet_group" "rds_subnet" {
  name       = "rds_subnet_group"
  subnet_ids = [var.subnet_id]
  tags = {
    Name = "RDS subnet group"
  }
}

# Create an EFS file system
resource "aws_efs_file_system" "example" {
  encrypted = var.efs_encrypted

  # Configure lifecycle policy - OPTIONAL
  lifecycle_policy {
    transition_to_ia = var.efs_lifecycle_transition
  }

  # Performance mode - OPTIONAL
  performance_mode = var.efs_performance_mode

  # Throughput mode - OPTIONAL
  throughput_mode = var.efs_throughput_mode
  
  # Provisioned throughput - Only if throughput_mode is "provisioned"
  provisioned_throughput_in_mibps = var.efs_provisioned_throughput

  # Tags
  tags = {
    Name = "my-efs"
  }

  # Ignore changes to throughput settings to avoid unnecessary updates
  lifecycle {
    ignore_changes = [
      throughput_mode,
      provisioned_throughput_in_mibps
    ]
  }
}

# Create an EFS mount target in the specified subnet
resource "aws_efs_mount_target" "example_mount_target" {
  file_system_id  = aws_efs_file_system.example.id
  subnet_id       = var.subnet_id
  security_groups = [try(data.aws_security_group.existing_allow_all_ingress.id, aws_security_group.allow_all_ingress[0].id)]
}

# Get the subnet information
data "aws_subnet" "selected_subnet" {
  id = var.subnet_id
}

# Add an ingress rule for EFS access on NFS port 2049
resource "aws_security_group_rule" "allow_efs_access" {
  type              = "ingress"
  from_port         = 2049
  to_port           = 2049
  protocol          = "tcp"
  security_group_id = try(data.aws_security_group.existing_allow_all_ingress.id, aws_security_group.allow_all_ingress[0].id)
  cidr_blocks       = [data.aws_subnet.selected_subnet.cidr_block]
}

# Attempt to fetch existing Key Pair
data "aws_key_pair" "existing_key_pair" {
  key_name = "internal-key"
}

resource "tls_private_key" "instance_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

# Conditionally create Key Pair if it doesn't exist
resource "aws_key_pair" "instance_key_pair" {
  count       = try(data.aws_key_pair.existing_key_pair.id, null) == null ? 1 : 0
  key_name    = "internal-key"
  public_key  = tls_private_key.instance_key.public_key_openssh
}

# Create (instance_count - 1) EC2 instances
resource "aws_instance" "ec2_instances" {
  count         = var.instance_count - 1
  ami           = var.ami_id
  instance_type = var.instance_type
  subnet_id     = var.subnet_id
  vpc_security_group_ids = [try(data.aws_security_group.existing_allow_all_ingress.id, aws_security_group.allow_all_ingress[0].id)]

  root_block_device {
    volume_size = var.disk_size
  }

  tags = {
    Name = "ec2-instance-${count.index}"
  }

  # Add SSH key pair for each instance
  key_name = try(data.aws_key_pair.existing_key_pair.key_name, aws_key_pair.instance_key_pair[0].key_name)

  # User data to add public key to authorized keys
  user_data = <<EOF
#!/bin/bash
mkdir -p /home/${var.default_username}/.ssh
echo '${tls_private_key.instance_key.public_key_openssh}' >> /home/${var.default_username}/.ssh/authorized_keys
chown -R ${var.default_username}:${var.default_username} /home/${var.default_username}/.ssh
chmod 700 /home/${var.default_username}/.ssh
chmod 600 /home/${var.default_username}/.ssh/authorized_keys

# Install NFS utilities and mount the EFS file system at /opt/thirdai_platform/model_bazaar

# Determine package manager and install necessary NFS utilities
if [ "${var.default_username}" == "ubuntu" ]; then
  apt install -y nfs-common
else
  yum install -y amazon-efs-utils nfs-utils
fi

mkdir -p /opt/thirdai_platform/model_bazaar

# Wait for EFS DNS resolution
mount_dns="${aws_efs_file_system.example.id}.efs.${var.aws_region}.amazonaws.com"
mount_ip=$(dig +short $mount_dns)

# Loop until DNS resolution is successful
while [ "$mount_ip" = "" ]
do
  echo "DNS for EFS mount unresolved, retrying in 10 seconds..."
  sleep 10
  mount_ip=$(dig +short $mount_dns)
done

# Use NFS mount for EFS on Ubuntu if amazon-efs-utils is not available
if [ "${var.default_username}" == "ubuntu" ]; then
  mount -t nfs4 -o nfsvers=4.1 ${aws_efs_file_system.example.id}.efs.${var.aws_region}.amazonaws.com:/ /opt/thirdai_platform/model_bazaar
else
  mount -t efs -o tls ${aws_efs_file_system.example.id}:/ /opt/thirdai_platform/model_bazaar
fi

# Add to /etc/fstab to auto-mount EFS after reboot
echo "${aws_efs_file_system.example.id}:/ /opt/thirdai_platform/model_bazaar efs _netdev,tls 0 0" >> /etc/fstab
EOF
}

# User data for the last instance to configure all nodes
resource "aws_instance" "last_node" {
  ami           = var.ami_id
  instance_type = var.instance_type
  subnet_id     = var.subnet_id
  vpc_security_group_ids = [try(data.aws_security_group.existing_allow_all_ingress.id, aws_security_group.allow_all_ingress[0].id)]

  root_block_device {
    volume_size = var.disk_size
  }

  key_name = var.ssh_key_name

  tags = {
    Name = "ec2-last-node"
  }

  user_data = <<EOF
#!/bin/bash
mkdir -p /home/${var.default_username}/.ssh

# Add private key and public key to last node
echo '${tls_private_key.instance_key.private_key_pem}' > /home/${var.default_username}/.ssh/id_rsa
chmod 600 /home/${var.default_username}/.ssh/id_rsa
echo '${tls_private_key.instance_key.public_key_openssh}' > /home/${var.default_username}/.ssh/id_rsa.pub
chmod 644 /home/${var.default_username}/.ssh/id_rsa.pub
echo '${tls_private_key.instance_key.public_key_openssh}' >> /home/${var.default_username}/.ssh/authorized_keys
chown -R ${var.default_username}:${var.default_username} /home/${var.default_username}/.ssh
chmod 700 /home/${var.default_username}/.ssh
chmod 600 /home/${var.default_username}/.ssh/authorized_keys

# Install NFS utilities and mount the EFS file system at /opt/thirdai_platform/model_bazaar

# Determine package manager and install necessary NFS utilities
if [ "${var.default_username}" == "ubuntu" ]; then
  apt install -y nfs-common
else
  yum install -y amazon-efs-utils nfs-utils
fi

mkdir -p /opt/thirdai_platform/model_bazaar

# Wait for EFS DNS resolution
mount_dns="${aws_efs_file_system.example.id}.efs.${var.aws_region}.amazonaws.com"
mount_ip=$(dig +short $mount_dns)

# Loop until DNS resolution is successful
while [ "$mount_ip" = "" ]
do
  echo "DNS for EFS mount unresolved, retrying in 10 seconds..."
  sleep 10
  mount_ip=$(dig +short $mount_dns)
done

# Use NFS mount for EFS on Ubuntu if amazon-efs-utils is not available
if [ "${var.default_username}" == "ubuntu" ]; then
  mount -t nfs4 -o nfsvers=4.1 ${aws_efs_file_system.example.id}.efs.${var.aws_region}.amazonaws.com:/ /opt/thirdai_platform/model_bazaar
else
  mount -t efs -o tls ${aws_efs_file_system.example.id}:/ /opt/thirdai_platform/model_bazaar
fi

# Add to /etc/fstab to auto-mount EFS after reboot
echo "${aws_efs_file_system.example.id}:/ /opt/thirdai_platform/model_bazaar efs _netdev,tls 0 0" >> /etc/fstab

# Switch to ${var.default_username} for the rest of the script
cat <<'SCRIPT' | sudo -u ${var.default_username} bash
cd ~
wget https://thirdai-corp-public.s3.us-east-2.amazonaws.com/ThirdAI-Platform-latest-release/thirdai-platform-package-release-test-main-v0.0.82.tar.gz
tar -xvzf thirdai-platform-package-release-test-main-v0.0.82.tar.gz

# Create ndb_enterprise_license.json file from local text
cat <<EOL > /home/${var.default_username}/ndb_enterprise_license.json
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

sed -i 's|license_path:.*|license_path: \"/home/${var.default_username}/ndb_enterprise_license.json\"|' config.yml
sed -i 's|admin_mail:.*|admin_mail: \"${var.admin_mail}\"|' config.yml
sed -i 's|admin_username:.*|admin_username: \"${var.admin_username}\"|' config.yml
sed -i 's|admin_password:.*|admin_password: \"${var.admin_password}\"|' config.yml
sed -i 's|thirdai_platform_version:.*|thirdai_platform_version: \"${var.thirdai_platform_version}\"|' config.yml
sed -i 's|login_method:.*|login_method: \"${var.login_method}\"|' config.yml
sed -i 's|genai_key:.*|genai_key: \"${var.genai_key}\"|' config.yml
sed -i 's|create_nfs_server:.*|create_nfs_server: false|' config.yml

sed -i "s|public_ip:.*|public_ip: \"$${last_node_public_ip}\"|" config.yml
sed -i "s|private_ip:.*|private_ip: \"$${last_node_private_ip}\"|" config.yml
sed -i 's|ssh_username:.*|ssh_username: \"${var.default_username}\"|' config.yml

sed -i '/connection_type:/,/# in which case Ansible will install all libraries directly on the local host without using SSH/{d}' config.yml
sed -i '/ssh_username:/a \    connection_type: \"local\"' config.yml

nodes_private_ips="${join(",", aws_instance.ec2_instances[*].private_ip)}"
IFS=',' read -r -a private_ips <<< "$nodes_private_ips"
for i in $(seq 0 $(($${#private_ips[@]} - 1))); do
    echo "  - name: \"node$((i + 2))\"" >> config.yml
    echo "    private_ip: \"$${private_ips[$i]}\"" >> config.yml
    echo "    ssh_username: \"${var.default_username}\"" >> config.yml
    echo "    connection_type: \"ssh\"" >> config.yml
    echo "    private_key: \"\"" >> config.yml
    echo "    ssh_common_args: \"\"" >> config.yml
    echo "    roles: []" >> config.yml
done

./driver.sh config.yml

SCRIPT
EOF
}