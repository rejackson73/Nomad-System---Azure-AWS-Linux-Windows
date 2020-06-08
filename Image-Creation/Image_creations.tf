# This file setups the resources necessary for image creation and storage
# Image storage at AWS is fairly straightforward, however, Azure needs a 
# Resource Group and Storage Account for the image

provider "azurerm" {
  features {}
  version  = ">=2.0.0"
}
resource "azurerm_resource_group" "nomad" {
  name     = var.nomad_rg
  location = var.azure_location
  tags = {
    Owner = var.owner
  }
}
# Note that Storage Accounts must be Unique within all of Azure
# Creating a random number to append to the storage account
# And then the storage account
resource "random_integer" "number" {
  min     = 1
  max     = 666
}
resource "azurerm_storage_account" "nomad" {
  name                     = "${var.azure_location}${random_integer.number.result}"
  resource_group_name      = azurerm_resource_group.nomad.name
  location                 = azurerm_resource_group.nomad.location
  account_tier             = "Standard"
  account_replication_type = "GRS"
  tags = {
    Owner = var.owner
  }
}

# Packer Runners to build images - separating the resources to enable individual resource taints
# Each packer build generates a manifest file for the respective image that is used to feed System Build

resource "null_resource" "azure_packer_runner" {
  depends_on = [
    azurerm_storage_account.nomad,azurerm_resource_group.nomad
  ]
  provisioner "local-exec" {
    command     = "packer build -var owner=${var.owner} -var resource_group_name=${azurerm_resource_group.nomad.name} -var storage_account=${azurerm_storage_account.nomad.name} -var location=${var.azure_location} Azure_Windows_image.json"
  }
}
resource "null_resource" "aws_packer_runner" {
  depends_on = [
    azurerm_storage_account.nomad,azurerm_resource_group.nomad
  ]
  provisioner "local-exec" {
    command     = "packer build -var owner=${var.owner} -var aws_region=${var.aws_region} -var aws_instance_type=${var.aws_instance_type} AWS_linux_image.pkr.hcl"
  }
}

output "Azure_Resource_Group" {
  value = var.nomad_rg
}
output "Azure_Location" {
  value = var.azure_location
}
output "AWS_Region" {
  value = var.aws_region
}