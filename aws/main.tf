provider "aws" {
  region = var.aws_region
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
}

# Security Group allowing all ingress traffic from the subnet
resource "aws_security_group" "allow_all_ingress" {
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

# Create an EFS mount target in the specified subnet
resource "aws_efs_mount_target" "example_mount_target" {
  file_system_id  = aws_efs_file_system.example.id
  subnet_id       = var.subnet_id
  security_groups = [aws_security_group.allow_all_ingress.id]
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
  security_group_id = aws_security_group.allow_all_ingress.id
  cidr_blocks       = [data.aws_subnet.selected_subnet.cidr_block]
}

# Create an SSH key pair to be used for internal SSH access
resource "tls_private_key" "instance_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "aws_key_pair" "instance_key_pair" {
  key_name   = "internal-key"
  public_key = tls_private_key.instance_key.public_key_openssh
}

# Create (instance_count - 1) EC2 instances
resource "aws_instance" "ec2_instances" {
  count         = var.instance_count - 1
  ami           = var.ami_id
  instance_type = var.instance_type
  subnet_id     = var.subnet_id
  vpc_security_group_ids = [aws_security_group.allow_all_ingress.id]

  root_block_device {
    volume_size = var.disk_size
  }

  tags = {
    Name = "ec2-instance-${count.index}"
  }

  # Add SSH key pair for each instance
  key_name = aws_key_pair.instance_key_pair.key_name

  # User data to add public key to authorized keys
  user_data = <<EOF
#!/bin/bash
mkdir -p /home/ec2-user/.ssh
echo '${tls_private_key.instance_key.public_key_openssh}' >> /home/ec2-user/.ssh/authorized_keys
chown -R ec2-user:ec2-user /home/ec2-user/.ssh
chmod 700 /home/ec2-user/.ssh
chmod 600 /home/ec2-user/.ssh/authorized_keys

# Install NFS utilities and mount the EFS file system at /opt/thirdai_platform/model_bazaar
yum install -y amazon-efs-utils
mkdir -p /opt/thirdai_platform/model_bazaar
mount -t efs -o tls ${aws_efs_file_system.example.id}:/ /opt/thirdai_platform/model_bazaar
EOF
}

# User data for the last instance to configure all nodes
resource "aws_instance" "last_node" {
  ami           = var.ami_id
  instance_type = var.instance_type
  subnet_id     = var.subnet_id
  vpc_security_group_ids = [aws_security_group.allow_all_ingress.id]

  root_block_device {
    volume_size = var.disk_size
  }

  key_name = var.ssh_key_name

  tags = {
    Name = "ec2-last-node"
  }

  user_data = <<EOF
#!/bin/bash
mkdir -p /home/ec2-user/.ssh

# Add private key and public key to last node
echo '${tls_private_key.instance_key.private_key_pem}' > /home/ec2-user/.ssh/id_rsa
chmod 600 /home/ec2-user/.ssh/id_rsa
echo '${tls_private_key.instance_key.public_key_openssh}' > /home/ec2-user/.ssh/id_rsa.pub
chmod 644 /home/ec2-user/.ssh/id_rsa.pub
echo '${tls_private_key.instance_key.public_key_openssh}' >> /home/ec2-user/.ssh/authorized_keys
chown -R ec2-user:ec2-user /home/ec2-user/.ssh
chmod 700 /home/ec2-user/.ssh
chmod 600 /home/ec2-user/.ssh/authorized_keys

# Install NFS utilities and mount the EFS file system at /opt/thirdai_platform/model_bazaar
yum install -y amazon-efs-utils
mkdir -p /opt/thirdai_platform/model_bazaar
mount -t efs -o tls ${aws_efs_file_system.example.id}:/ /opt/thirdai_platform/model_bazaar

# Switch to ec2-user for the rest of the script
cat <<'SCRIPT' | sudo -u ec2-user bash
cd ~
wget https://thirdai-corp-public.s3.us-east-2.amazonaws.com/ThirdAI-Platform-latest-release/thirdai-platform-package-release-test-main-v0.0.82.tar.gz
tar -xvzf thirdai-platform-package-release-test-main-v0.0.82.tar.gz

# Create ndb_enterprise_license.json file from local text
cat <<EOL > /home/ec2-user/ndb_enterprise_license.json
${file(var.license_file_path)}
EOL

chmod +x driver.sh

# Fetch the last node's public and private IP addresses from instance metadata
last_node_private_ip=$(curl -s 'http://169.254.169.254/latest/meta-data/local-ipv4')
last_node_public_ip=$(curl -s 'http://169.254.169.254/latest/meta-data/public-ipv4')

echo $last_node_private_ip
echo $last_node_public_ip

sed -i '/- name: \"node2\"/,$d' config.yml

sed -i 's|license_path:.*|license_path: \"/home/ec2-user/ndb_enterprise_license.json\"|' config.yml
sed -i 's|admin_mail:.*|admin_mail: \"${var.admin_mail}\"|' config.yml
sed -i 's|admin_username:.*|admin_username: \"${var.admin_username}\"|' config.yml
sed -i 's|admin_password:.*|admin_password: \"${var.admin_password}\"|' config.yml
sed -i 's|thirdai_platform_version:.*|thirdai_platform_version: \"${var.thirdai_platform_version}\"|' config.yml
sed -i 's|login_method:.*|login_method: \"${var.login_method}\"|' config.yml
sed -i 's|genai_key:.*|genai_key: \"${var.genai_key}\"|' config.yml

sed -i "s|public_ip:.*|public_ip: \"$${last_node_public_ip}\"|" config.yml
sed -i "s|private_ip:.*|private_ip: \"$${last_node_private_ip}\"|" config.yml
sed -i 's|ssh_username:.*|ssh_username: \"ec2-user\"|' config.yml

sed -i '/connection_type:/,/# in which case Ansible will install all libraries directly on the local host without using SSH/{d}' config.yml
sed -i '/ssh_username:/a \    connection_type: \"local\"' config.yml

nodes_private_ips="${join(",", aws_instance.ec2_instances[*].private_ip)}"
IFS=',' read -r -a private_ips <<< "$nodes_private_ips"
for i in $(seq 0 $(($${#private_ips[@]} - 1))); do
    echo "  - name: \"node$((i + 2))\"" >> config.yml
    echo "    private_ip: \"$${private_ips[$i]}\"" >> config.yml
    echo "    ssh_username: \"ec2-user\"" >> config.yml
    echo "    connection_type: \"ssh\"" >> config.yml
    echo "    private_key: \"\"" >> config.yml
    echo "    ssh_common_args: \"\"" >> config.yml
    echo "    roles: []" >> config.yml
done

./driver.sh config.yml

SCRIPT
EOF
}