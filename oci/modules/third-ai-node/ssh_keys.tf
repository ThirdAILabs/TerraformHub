# Generate a new SSH key pair for this instance
resource "tls_private_key" "instance_ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "private_key" {
  content         = tls_private_key.instance_ssh_key.private_key_pem
  filename        = "${path.module}/id_rsa_${var.instance_name}"
  file_permission = "0600"
}

resource "local_file" "public_key" {
  content         = tls_private_key.instance_ssh_key.public_key_openssh
  filename        = "${path.module}/id_rsa_${var.instance_name}.pub"
  file_permission = "0644"
}