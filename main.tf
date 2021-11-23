terraform {
  required_providers {
    scaleway = {
      source = "scaleway/scaleway"
    }
  }
  required_version = ">= 0.13"
}

variable "DB_USERNAME" {
  type = string
}

variable "DB_PASSWORD" {
  type = string
}

variable "SSH_KEY" {
  type = string
}

provider "scaleway" {
  zone   = "fr-par-1"
  region = "fr-par"
}

resource "scaleway_instance_ip" "server_ip" {
  count = 2
}

resource "scaleway_lb_ip" "ip" {
}

resource "scaleway_lb" "base" {
  ip_id = scaleway_lb_ip.ip.id
  type  = "LB-S"
}

resource "scaleway_lb_backend" "backend01" {
  lb_id            = scaleway_lb.base.id
  name             = "backend01"
  forward_protocol = "http"
  forward_port     = "80"
  server_ips       = [for o in scaleway_instance_ip.server_ip : o.address]
}

resource "scaleway_lb_frontend" "frontend01" {
  lb_id        = scaleway_lb.base.id
  backend_id   = scaleway_lb_backend.backend01.id
  name         = "frontend01"
  inbound_port = "80"
}

resource "scaleway_rdb_instance" "main" {
  name          = "db_tp"
  node_type     = "db-dev-s"
  engine        = "PostgreSQL-12"
  is_ha_cluster = false
  user_name     = var.DB_USERNAME
  password      = var.DB_PASSWORD
}

resource "scaleway_instance_security_group" "www" {
  inbound_default_policy  = "drop"
  outbound_default_policy = "accept"

  inbound_rule {
    action = "accept"
    port   = "22"
  }

  inbound_rule {
    action = "accept"
    port   = "80"
    ip     = scaleway_lb.base.ip_address
  }

  inbound_rule {
    action = "accept"
    port   = "443"
    ip     = scaleway_lb.base.ip_address
  }
}

resource "scaleway_instance_placement_group" "availability_group" {
  count = 2
}

resource "scaleway_instance_server" "web" {
  count              = 2
  type               = "DEV1-S"
  image              = "ubuntu_focal"
  ip_id              = scaleway_instance_ip.server_ip[count.index].id
  security_group_id  = scaleway_instance_security_group.www.id
  placement_group_id = scaleway_instance_placement_group.availability_group[count.index].id
  user_data = {
    DATABASE_URI = "postgres://${scaleway_rdb_instance.main.user_name}:${scaleway_rdb_instance.main.password}@${scaleway_rdb_instance.main.endpoint_ip}:${scaleway_rdb_instance.main.endpoint_port}/rdb"
  }
  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "root"
      host        = scaleway_instance_ip.server_ip[count.index].address
      private_key = var.SSH_KEY
    }

    inline = [
      "sudo apt-get update -y",
      "sudo apt-get install ca-certificates curl gnupg lsb-release -y",
      "curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg",
      "echo \"deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable\" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null",
      "sudo apt-get update -y",
      "sudo apt-get install docker-ce docker-ce-cli containerd.io -y",
      "docker run -d --name app -e DATABASE_URI=\"$(scw-userdata DATABASE_URI)\" -p 80:8080 --restart=always rg.fr-par.scw.cloud/efrei-devops/app:latest"
    ]
  }
}

