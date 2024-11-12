provider "aws" {
  region = var.aws_region
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

# Get the subnet information
data "aws_subnet" "selected_subnet" {
  id = var.subnet_id
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