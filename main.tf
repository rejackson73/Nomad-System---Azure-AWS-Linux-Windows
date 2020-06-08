# This file creates a set of resources in both Azure and AWS Cloud environments
# It utilizes images created with HashiCorp's Packer with  Consul and Nomad pre-installed
# Be sure to set your variables properly in terraform.tfvars
# In full disclosure, I'm not a programmer, but I was able to put this together with examples
# and docs found on the interwebs

#############################
# AWS Linux Instance Creation
#############################

provider "aws" {
  version = "~> 2.5"
  region  = local.aws_region
}

####################################
# Pull AMI ID from the Packer Ouptut
####################################
locals {
  aws_to_json    = jsondecode(file("Image-Creation/aws-manifest.json"))
  aws_pull_build = element(tolist(local.aws_to_json.builds), 0)
  aws_region     = element((split(":", local.aws_pull_build["artifact_id"])), 0)
  aws_ami_id     = element(reverse(split(":", local.aws_pull_build["artifact_id"])), 0)
}

####################################
# Create AWS FQDN in hashidemos zone
####################################
data "aws_route53_zone" "selected" {
  name         = "hashidemos.io."
  private_zone = false
}
resource "aws_route53_record" "fqdn" {
  zone_id = data.aws_route53_zone.selected.zone_id
  name    = "${var.owner}-nomad.${data.aws_route53_zone.selected.name}"
  type    = "A"
  ttl     = "30"
  records = ["${aws_instance.nomad-server[0].public_ip}", "${aws_instance.nomad-server[1].public_ip}", "${aws_instance.nomad-server[2].public_ip}"]
}

###############################
# Create AWS Network Components
###############################
resource aws_vpc "nomad-demo" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  tags = {
    Name = "${var.owner}-vpc"
  }
}
resource aws_subnet "nomad-demo" {
  vpc_id     = aws_vpc.nomad-demo.id
  cidr_block = var.vpc_cidr
  tags = {
    name = "${var.owner}-subnet"
  }
}
resource aws_security_group "nomad-demo" {
  name = "${var.owner}-security-group"
  vpc_id = aws_vpc.nomad-demo.id
  # Hopefully we all know what these are for
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  # Nomad specific ports
  ingress {
    from_port   = 4648
    to_port     = 4648
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 4647
    to_port     = 4647
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 4646
    to_port     = 4646
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 4567
    to_port     = 4567
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  # Required ports for Consul
  ingress {
    from_port   = 8300
    to_port     = 8302
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 8500
    to_port     = 8500
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 8600
    to_port     = 8600
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  # Anything can leave, unlike Hotel California
  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
    prefix_list_ids = []
  }
  tags = {
    Name = "${var.owner}-security-group"
  }
}

resource aws_internet_gateway "nomad-demo" {
  vpc_id = aws_vpc.nomad-demo.id

  tags = {
    Name = "${var.owner}-internet-gateway"
  }
}
resource aws_route_table "nomad-demo" {
  vpc_id = aws_vpc.nomad-demo.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.nomad-demo.id
  }
}
resource aws_route_table_association "nomad-demo" {
  subnet_id      = aws_subnet.nomad-demo.id
  route_table_id = aws_route_table.nomad-demo.id
}

#############################################################################
# AWS Server Cluster Creation
# Note, in production it is highly recommended to go with 5 or 7 server nodes
# Three nodes doesn't protect against region/zone failure
#############################################################################

resource aws_instance "nomad-server" {
  count                       = 3
  ami                         = local.aws_ami_id
  instance_type               = var.instance_type
  key_name                    = var.aws_key
  associate_public_ip_address = true
  subnet_id                   = aws_subnet.nomad-demo.id
  vpc_security_group_ids      = [aws_security_group.nomad-demo.id]
  iam_instance_profile        = aws_iam_instance_profile.instance_profile.name
  # Using user_data/template file to setup Consul and Nomad server configuration files
  user_data = templatefile("files/server_template.tpl", { server_name_tag = "${var.owner}-nomad-server-instance" })
  tags = {
    Name  = "${var.owner}-nomad-server-instance"
    Owner = var.owner_tag
  }
}

###################################################################
# AWS Linux Client Creation
# Four clients were chosen to represent Earth, Air, Fire, and Water
# Client count would be a variable in most real scenarios
###################################################################
resource aws_instance "nomad-client" {
  count                       = 4
  ami                         = local.aws_ami_id
  instance_type               = var.instance_type
  key_name                    = var.aws_key
  associate_public_ip_address = true
  subnet_id                   = aws_subnet.nomad-demo.id
  vpc_security_group_ids      = [aws_security_group.nomad-demo.id]
  iam_instance_profile = aws_iam_instance_profile.instance_profile.name
  tags = {
    Name  = "${var.owner}-nomad-client-instance-${count.index}"
    Owner = var.owner_tag
  }
}

#############################################################
# We're using remote-exec to setup the client configurations.
# user_data is preferred, but this is an option
#############################################################
resource null_resource "provisioning-clients" {
  for_each = { for client in aws_instance.nomad-client : client.tags.Name => client }
  # Nomad Client Configuration including local host volume for storage
  provisioner "remote-exec" {
    inline = [
      "sudo cat << EOF > /tmp/nomad-client.hcl",
      "log_file = \"/etc/nomad/log\"",
      "advertise {",
      "http = \"${each.value.public_ip}\"",
      "rpc  = \"${each.value.public_ip}\"",
      "serf = \"${each.value.public_ip}\"",
      "}",
      "client {",
      "    enabled = true",
      "    servers = [\"${aws_instance.nomad-server[0].public_ip}\",\"${aws_instance.nomad-server[1].public_ip}\",\"${aws_instance.nomad-server[2].public_ip}\"]",
      "    host_volume \"host_storage\" {",
      "      path      = \"/etc/nomad/storage\"",
      "      read_only = false",
      "    }",
      "}",
      "plugin \"raw_exec\" {",
      "   config {",
      "   enabled = true",
      "   }",
      "}",
      "EOF",
      "sudo mv /tmp/nomad-client.hcl /etc/nomad/nomad.d/nomad-client.hcl",
    ]
  }
  # Consul Client Configuration
  provisioner "remote-exec" {
    inline = [
      "sudo cat << EOF > /tmp/consul-client.hcl",
      "advertise_addr = \"${each.value.public_ip}\"",
      "server = false",
      "bind_addr = \"${each.value.private_ip}\"",
      "retry_join = [\"${aws_instance.nomad-server[0].public_ip}\",\"${aws_instance.nomad-server[1].public_ip}\",\"${aws_instance.nomad-server[2].public_ip}\"]",
      "EOF",
      "sudo mv /tmp/consul-client.hcl /etc/consul/consul.d/consul-client.hcl",
    ]
  }
  # Fire Up Services
  provisioner "remote-exec" {
    inline = [
      "sudo systemctl start consul",
      "sleep 10",
      "sudo systemctl start nomad",
    ]
  }
  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = file("${var.ssh_key}")
    host        = each.value.public_ip
  }
}

##################################
# Azure Windows  Instance Creation
##################################
provider "azurerm" {
  features {}
  version = ">=2.0.0"
}

##########################################
# Pull Azure Image Name from Packer Output
##########################################
locals {
  azure_to_json    = jsondecode(file("Image-Creation/azure-manifest.json"))
  azure_pull_build = element(tolist(local.azure_to_json.builds), 0)
  azure_rg = element((split("/", local.azure_pull_build["artifact_id"])), 4)
  azure_image = local.azure_pull_build["artifact_id"]
}

#################################################
#  Pull resource Group information as data source
#################################################
data "azurerm_resource_group" "main-rg" {
  name = local.azure_rg
}

###########################################
#  Setup Azure Network Services for Compute
###########################################
resource "azurerm_virtual_network" "main" {
  name                = "${var.owner}-network"
  address_space       = ["10.0.0.0/16"]
  location            = data.azurerm_resource_group.main-rg.location
  resource_group_name = data.azurerm_resource_group.main-rg.name
}
resource "azurerm_subnet" "internal" {
  name                 = "internal"
  resource_group_name  = data.azurerm_resource_group.main-rg.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.2.0/24"]
}
resource "azurerm_public_ip" "main-ip" {
  name                = "main-public_ip"
  location            = data.azurerm_resource_group.main-rg.location
  resource_group_name = data.azurerm_resource_group.main-rg.name
  allocation_method   = "Dynamic"
}
resource "azurerm_network_interface" "main" {
  name                = "${var.owner}-nic"
  location            = data.azurerm_resource_group.main-rg.location
  resource_group_name = data.azurerm_resource_group.main-rg.name
  ip_configuration {
    name                          = "${var.owner}-private_ip"
    subnet_id                     = azurerm_subnet.internal.id
    public_ip_address_id          = azurerm_public_ip.main-ip.id
    private_ip_address_allocation = "Dynamic"
  }
}

###################################################################
# Azure Windows Client Creation
# Only once client is being created because lazy
# Also note that the machine 'name' must be less than 15 characters
###################################################################
resource "azurerm_windows_virtual_machine" "nomad-demo" {
  name                = "AZWindows1"
  resource_group_name = data.azurerm_resource_group.main-rg.name
  location            = data.azurerm_resource_group.main-rg.location
  size                = "Standard_F2"
  source_image_id     = local.azure_image
  admin_username      = "adminuser"
  admin_password      = "P@$$w0rd1234!" # Obviously pulling this from Vault would be more secure
  network_interface_ids = [
    azurerm_network_interface.main.id,
  ]
  winrm_listener {
    protocol = "Http"
  }
  os_disk {
    name                 = "${var.owner}-disk"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
  tags = {
    owner = var.owner
  }
}

###############################################################
# For Windows, we are using WINRM to connect and run powershell
###############################################################
resource null_resource "winrm_provisioner" {
  provisioner "file" {
    source      = "files/setupclient.ps1"
    destination = "c:\\hashicorp\\setupclient.ps1"
  }
  # Feeding server IP addresses into Powershell script for client to reach back
  provisioner "remote-exec" {
    inline = [
      "powershell -ExecutionPolicy Unrestricted -File  c:\\hashicorp\\setupclient.ps1 ${aws_instance.nomad-server[0].public_ip} ${aws_instance.nomad-server[1].public_ip} ${aws_instance.nomad-server[2].public_ip}"
    ]
  }
# Specifying the connection details for WinRM to the Windows machine
  connection {
    host     = azurerm_windows_virtual_machine.nomad-demo.public_ip_address
    port     = "5985"
    type     = "winrm"
    user     = azurerm_windows_virtual_machine.nomad-demo.admin_username
    password = azurerm_windows_virtual_machine.nomad-demo.admin_password
    insecure = false
    https    = false
  }
}

##########################################################
# Setting up AWS IAM Profiles and Roles for Storage Access
##########################################################

resource "aws_iam_instance_profile" "instance_profile" {
  name_prefix = var.owner
  role        = aws_iam_role.instance_role.name
}
resource "aws_iam_role" "instance_role" {
  name_prefix        = var.owner
  assume_role_policy = data.aws_iam_policy_document.instance_role.json
}
data "aws_iam_policy_document" "instance_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}
resource "aws_iam_role_policy" "sharing_volumes" {
  name   = "sharing_volumes"
  role   = aws_iam_role.instance_role.id
  policy = data.aws_iam_policy_document.sharing_volumes.json
}
data "aws_iam_policy_document" "sharing_volumes" {
  statement {
    effect = "Allow"
    actions = [
      "ec2:DescribeVolume*",
      "ec2:AttachVolume",
      "ec2:DetachVolume",
      "ec2:DescribeInstances",
      "ec2:DescribeTags",
    ]
    resources = ["*"]
  }
}

# Setting up EFS on AWS for shared file system
resource "aws_efs_file_system" "nomad_efs" {
  tags = {
    Name = var.owner
  }
}
resource "aws_efs_mount_target" "nomad-mount" {
  file_system_id  = aws_efs_file_system.nomad_efs.id
  subnet_id       = aws_subnet.nomad-demo.id
  security_groups = [aws_security_group.nomad-demo.id]
}

###########################################################################
# As part of Infrastructure setup, we are including some Nomad provisioning
###########################################################################


# We are including a 'sleep' to wait for the Nomad Servers to be up and running
resource "time_sleep" "wait_for_nomad" {
  create_duration = "60s"

  triggers = {
    # This sets up a proper dependency on the RAM association
    server_cluster = "${join(",", aws_instance.nomad-server.*.public_ip)}"
  }
}

# Pointing to Server 0 for the Nomad Provisioner
provider "nomad" {
  address = "http://${aws_instance.nomad-server[0].public_ip}:4646"
  region  = var.nomad_region
}

# Setting up Nomad Jobs for EBS And EFS Storage Access for AWS Nodes
resource "nomad_job" "plugin-ebs-controller" {
  jobspec    = file("files/plugin-ebs-controller.nomad")
  depends_on = [time_sleep.wait_for_nomad]
}
resource "nomad_job" "plugin-ebs-nodes" {
  jobspec    = file("files/plugin-ebs-nodes.nomad")
  depends_on = [time_sleep.wait_for_nomad]
}

resource "nomad_job" "plugin-efs-nodes" {
  jobspec    = file("files/plugin-efs-nodes.nomad")
  depends_on = [time_sleep.wait_for_nomad]
}