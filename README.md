# Multi-Cloud Multi-System Nomad Cluster

## Goals
The primary purpose of this project was to build a multi-cloud Nomad system with both Windows and Linux clients.  There are several improvements possible, that will likely be performed in forked off versions of this repo.  The original intent was to provide a sample of Nomad orchestrating a java application (minecraft) across multiple clouds and multiple OSs.

There are complications with using Minecraft for this demonstration, however, simply because Minecraft does not behave well with shared storage.  The ideal application would utilize the EFS storage that is shared across the Nomad clients.However, even with that caveat, it seemed like a worthy exercise.

As an exercise, the repository also includes several different methods of performing the same task.  Sometimes I use HCL, other times I use JSON. In an effort to collaborate, and due to my poor memory, I did try to comment as much as possible (at least in the HCL files that support commenting).

## Prerequisites
Terraform >0.12 in path
Packer accesible via path
Access to the outside world (Internet)

## System
To start, the Image-Creation folder is for, well, creating the images being used in the repo.  By running Terraform in that folder, the necessary Azure resources are created for housing the Windows image in Azure (the Azure Resource Group and Storage Account).  Terraform then calls Packer to create the Windows image in Azure, and the Linux image in AWS.  The Linux image in AWS utilizes a Ubuntu image, whilst the Windows image in Azure uses Windows Server 2019.  Both images pull down static versions of both Consul and Nomad binaries.  Luckily both binaries can operate as either a client or server, making the same image usable for both client and server applications.

The AWS image is defined using HCL, and uses the shell to perform installation/provisioning.  The Windows image is defined using JSON and uses Powershell for installation/provisioning.  Both images create a manifest json image which is used by the main Terraform build in the 'root' directory.

Part of the process also includes setting up the DataDog agents on all systems, with a DataDog KEY that is loaded as an environment variable.  The application logs for Consul and Nomad, as well as metrics, are provided to DataDog for analysis and pretty dashboards.

Variables for Image-Creation are defined in the terraform.tfvars file.
owner          = "<tag_identifying_infrastructure_owner>"
aws_region     = "<AWS_region>"
instance_type  = "<AWS_Instance_Type>"
azure_location = "<Azure_Location>"
nomad_rg       = "<Azure_Resource_Group_Name>"

Now that you have your images created, let's move into the good stuff.

##  Good Stuff
In the 'root' directory of the repository, we have the Terraform file to create all of the compute and supporting resources in both AWS and Azure.  Some items are collected from the manifest files produced by the image creation process.  That in itself was a fun exercise in using Terraform to do various sorts of parsing.  As I don't speak parseltongue, this was a bit challenging.  

The Linux server machines are provisioned using user_data along with a template file (located in the files directory), while the Linux Client machines are provisioned using the Terraform 'remote-exec' provisioner.  The provisioning tasks are primarily focused on configuring the Consul and Nomad agents, which require parameters not known until build time.  

With the Linux systems up and running in AWS, the next step was to create the Windows machine in Azure.  At this point, there is only one Windows client configured.  That machine is provisioned using Powershell and WinRM.  Currently this machines resides in its own island, as the goal was merely to create a multi-cloud and multi-OS Nomad system.  

Variables:
# Variable values to use for deployment
owner          = "<tag_identifying_infrastructure_owner>"
aws_region     = "<AWS_region>"
aws_key       = "<SSH_PEM_KEY_NAME>"
owner_tag     = "<tag_identifying_infrastructure_owner>" (should merge with 'owner')
ssh_key       = "<PATH_TO_LOCAL_PEM_KEY>"
instance_type  = "<AWS_Instance_Type>"

## Other Stuff
Now that the servers and clients defined, it was time to work on the AWS Instance Roles and Policies, and the creation of the EFS Volume.  Then, to close things out, we use the Nomad provider to setup the base Nomad services for storage.