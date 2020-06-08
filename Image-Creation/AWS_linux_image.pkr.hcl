#########################################################################
# This files creates the AWS image for Nomad and creates a manifest file
# that is to be used for the creation of the Nomad and Consul Systems
# It sure is nice to be able to add comments into this file...data
#########################################################################

# Local variables for the Packer Creation
variable "aws_region" {
  type = string
  default = ""
}

variable "aws_instance_type" {
  type = string
  default = ""
}

variable "owner" {
  type = string
  default = ""
}

# Looking for the source image on which to pack my new image
source "amazon-ebs" "ubuntu-image" {
  ami_name = "${var.owner}_{{timestamp}}"
  region = "${var.aws_region}"
  instance_type = var.aws_instance_type
  tags = {
    Name = "${var.owner}-Nomad"
  }

  source_ami_filter {
      filter {
        key = "virtualization-type"
        value = "hvm"
      }
      filter {
        key = "name"
        value = "ubuntu/images/*ubuntu-bionic-18.04-amd64-server-*"
      }
      filter {
        key = "root-device-type"
        value = "ebs"
      }
      owners = ["099720109477"]
      most_recent = true
  }
  communicator = "ssh"
  ssh_username = "ubuntu"
}

# Here we are actually building the image with the files
build {
  sources = [
    "source.amazon-ebs.ubuntu-image"
  ]

  provisioner "file" {
    source      = "../files/consul.service"
    destination = "/tmp/consul.service"
  }

  provisioner "file" {
    source      = "../files/nomad.service"
    destination = "/tmp/nomad.service"
  }

  provisioner "file" {
    source      = "../files/nomad-common.hcl"
    destination = "/tmp/nomad-common.hcl"
  }

# installing Linux items including Docker and of course Nomad and Consul images
  provisioner "shell" {
    inline = [
      "sleep 30",
      "sudo apt-get update",
      "sudo apt install unzip -y",
      "sudo apt install nfs-common -y",
      "sudo apt install default-jre -y",
      "curl -fsSL \"https://get.docker.com\" -o get-docker.sh",
      "sudo sh get-docker.sh",
      "sleep 30",
      "sudo usermod -aG docker ubuntu",
      "curl -k -O \"https://releases.hashicorp.com/nomad/0.11.1/nomad_0.11.1_linux_amd64.zip\"",
      "curl -k -O \"https://releases.hashicorp.com/consul/1.7.2/consul_1.7.2_linux_amd64.zip\"",
      "unzip consul_1.7.2_linux_amd64.zip",
      "unzip nomad_0.11.1_linux_amd64.zip",
      "sudo mv nomad /usr/local/bin",
      "sudo mv consul /usr/local/bin"
    ]
  }
# Consul installation bits
  provisioner "shell"{
    inline = [
      "sudo /usr/local/bin/consul -autocomplete-install",
      "sudo useradd --system --home /etc/consul/consul.d --shell /bin/false consul",
      "sudo mkdir /etc/consul /etc/consul/consul.d /etc/consul/logs /var/lib/consul/ /var/run/consul/",
      "sudo chown -R consul:consul /etc/consul /var/lib/consul/ /var/run/consul/",
      "sudo mv /tmp/consul.service /etc/systemd/system/consul.service"
    ]
  }
# Nomad installation bits
  provisioner "shell"{
    inline = [
      "sudo /usr/local/bin/nomad -autocomplete-install",
      "sudo useradd --system --home /etc/nomad/nomad.d --shell /bin/false nomad",
      "sudo mkdir /etc/nomad /etc/nomad/nomad.d /etc/nomad/logs /var/lib/nomad /etc/nomad/storage",
      "sudo chown -R nomad:nomad /etc/nomad /var/lib/nomad",
      "sudo mv /tmp/nomad.service /etc/systemd/system/nomad.service",
      "sudo mv /tmp/nomad-common.hcl /etc/nomad/nomad.d/nomad-common.hcl"
    ]
 }
 post-processor "manifest" {
   output = "aws-manifest.json"
   strip_path = true
 }
}
