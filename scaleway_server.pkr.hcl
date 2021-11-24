packer {
}

source "scaleway" "web_server" {
  image_name           = "webmdm1-mailly-terraform"
  image                = "ubuntu_focal"
  zone                 = "fr-par-1"
  commercial_type      = "DEV1-S"
  ssh_username         = "root"
  remove_volume        = true
}

build {
  name = "learn-packer"
  sources = [
    "source.scaleway.web_server"
  ]
  provisioner "file" {
    source      = "dockerized_app.service"
    destination = "/etc/systemd/system/dockerized_app.service"
  }
  provisioner "file" {
    source      = "docker-run.sh"
    destination = "/root/docker-run.sh"
  }
  provisioner "shell" {
    inline = [
      "chmod +x docker-run.sh",
      "sudo apt-get update -y",
      "sudo apt-get install ca-certificates curl gnupg lsb-release -y",
      "curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg",
      "echo \"deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable\" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null",
      "sudo apt-get update -y",
      "sudo apt-get install docker-ce docker-ce-cli containerd.io -y",
      "sudo systemctl enable dockerized_app.service"
    ]
  }
}
