output "server_ip_addr" {
  value = aws_instance.nomad-server[*].public_ip
}

output "server_fqdn" {
  value = aws_route53_record.fqdn.name
}

output "host_ip" {
  value = azurerm_windows_virtual_machine.nomad-demo.public_ip_address
}

output "efs_volume" {
  value = <<EOM
  # volume registration
  type = "csi"
  id = "efs-volume"
  name = "efs-volume"
  external_id = "${aws_efs_file_system.nomad_efs.id}"
  access_mode = "multi-node-multi-writer"
  attachment_mode = "file-system"
  plugin_id = "aws-efs"
  EOM
}