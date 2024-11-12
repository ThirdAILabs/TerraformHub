data "local_file" "iptables_rules" {
  filename = "${path.module}/iptables-rules.v4"
}

resource "null_resource" "firewall_config" {
  depends_on = [oci_core_instance.generated_oci_core_instance]

  triggers = {
    instance_id = oci_core_instance.generated_oci_core_instance.id
    rules_hash  = md5(data.local_file.iptables_rules.content)
  }

  connection {
    type        = "ssh"
    user        = "ubuntu"
    host        = oci_core_instance.generated_oci_core_instance.public_ip
    private_key = file("~/.ssh/id_rsa")
  }

  provisioner "file" {
    source      = data.local_file.iptables_rules.filename
    destination = "/tmp/iptables-rules.v4"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mv /tmp/iptables-rules.v4 /etc/iptables/rules.v4",
      "sudo iptables-restore < /etc/iptables/rules.v4",
      "sudo netfilter-persistent save",
      "sudo systemctl restart netfilter-persistent"
    ]
  }
}

output "firewall_config_id" {
  description = "The ID of the firewall configuration resource"
  value       = null_resource.firewall_config.id
}

output "iptables_rules_hash" {
  description = "MD5 hash of the current iptables rules"
  value       = md5(data.local_file.iptables_rules.content)
}