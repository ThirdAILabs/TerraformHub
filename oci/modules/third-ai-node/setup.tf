resource "null_resource" "wait_for_instance" {
  depends_on = [oci_core_instance.generated_oci_core_instance]

  triggers = {
    instance_id = oci_core_instance.generated_oci_core_instance.id
  }

  provisioner "remote-exec" {
    inline = ["echo 'Instance is ready'"]

    connection {
      type        = "ssh"
      user        = "ubuntu"
      host        = oci_core_instance.generated_oci_core_instance.public_ip
      private_key = file("~/.ssh/id_rsa")
    }
  }
}

resource "time_sleep" "wait_30_seconds" {
  depends_on = [null_resource.wait_for_instance]

  create_duration = "30s"
}


resource "null_resource" "setup_instance" {
  depends_on = [time_sleep.wait_30_seconds]

  triggers = {
    instance_id = oci_core_instance.generated_oci_core_instance.id
  }

  provisioner "file" {
    source      = "${path.module}/ndb_enterprise_license.json"
    destination = "/home/ubuntu/ndb_enterprise_license.json"

    connection {
      type        = "ssh"
      user        = "ubuntu"
      host        = oci_core_instance.generated_oci_core_instance.public_ip
      private_key = file("~/.ssh/id_rsa")
    }
  }

  provisioner "file" {
    source      = local_file.private_key.filename
    destination = "/home/ubuntu/.ssh/id_rsa"

    connection {
      type        = "ssh"
      user        = "ubuntu"
      host        = oci_core_instance.generated_oci_core_instance.public_ip
      private_key = file("~/.ssh/id_rsa")
    }
  }

  provisioner "file" {
    source      = local_file.public_key.filename
    destination = "/home/ubuntu/.ssh/id_rsa.pub"

    connection {
      type        = "ssh"
      user        = "ubuntu"
      host        = oci_core_instance.generated_oci_core_instance.public_ip
      private_key = file("~/.ssh/id_rsa")
    }
  }

  provisioner "remote-exec" {
    inline = [
      "sudo DEBIAN_FRONTEND=noninteractive apt-get update && sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y && sudo DEBIAN_FRONTEND=noninteractive apt-get install -y ubuntu-server nano netcat rsync inetutils-ping",
      "wget https://thirdai-corp-public.s3.us-east-2.amazonaws.com/ThirdAI-Platform-latest-release/thirdai-platform-package-release-test-main-v0.0.77.tar.gz",
      "tar xvzf thirdai-platform-package-release-test-main-v0.0.77.tar.gz",
      "chmod +x /home/ubuntu/driver.sh",
      "chmod 600 /home/ubuntu/.ssh/id_rsa",
      "chmod 644 /home/ubuntu/.ssh/id_rsa.pub",
      "cat /home/ubuntu/.ssh/id_rsa.pub >> /home/ubuntu/.ssh/authorized_keys"
    ]

    connection {
      type        = "ssh"
      user        = "ubuntu"
      host        = oci_core_instance.generated_oci_core_instance.public_ip
      private_key = file("~/.ssh/id_rsa")
    }
  }
}