$MetaDataHeaders = @{"Metadata"="true"} 
$client_IP = Invoke-RestMethod -Method GET -uri "http://169.254.169.254/metadata/instance/network/interface/0/ipv4/ipaddress/0/publicip?api-version=2017-03-01&format=text" -Headers $MetaDataHeaders 
$private_IP =  Invoke-RestMethod -Method GET -uri "http://169.254.169.254/metadata/instance/network/interface/0/ipv4/ipaddress/0/ipaddress?api-version=2017-03-01&format=text" -Headers $MetaDataHeaders 
$server_1 = $args[0]
$server_2 = $args[1]
$server_3 = $args[2]

# New-Item C:\hashicorp\nomad\nomad.d\nomad-client.hcl

$nomadappendage = @"

log_file  = "C:\\hashicorp\\nomad\\logs\\nomad.log"
advertise {
   http="$($client_IP)"
   rpc="$($client_IP)"
   serf="$($client_IP)"
}

client {
    enabled = true
    servers = ["$server_1","$server_2","$server_3"]
    host_volume "host_storage" {
      path      = "C:\\hashicorp\\nomad\\storage"
      read_only = false
    }
}
plugin "raw_exec" {
    config {
    enabled = true
    }
}
"@

Add-Content -path C:\hashicorp\nomad\nomad.d\nomad-common.hcl  -Value $nomadappendage

# Consul Client Configuration
# New-Item C:\hashicorp\consul\consul.d\consul-common.hcl
# $consulappendage = @"
# log_file  = "C:\\hashicorp\\consul\\logs\\consul.log"
# advertise_addr = "$($client_IP)"
# server = false
# bind_addr = "$($private_IP)"
# retry_join = ["$server_1","$server_2","$server_3"]
# "@
# Add-Content -path C:\hashicorp\consul\consul.d\consul-common.hcl -Value $consulappendage

$consulappendage = @"
{
    "log_file": "C:\\hashicorp\\consul\\logs\\consul.log",
    "advertise_addr": "$($client_IP)",
    "server": false,
    "bind_addr": "$($private_IP)",
    "retry_join": ["$server_1","$server_2","$server_3"]
}
"@

# Need to use String encoding for the Add-Content as the default isn't readable by Consul
Add-Content -path C:\hashicorp\consul\consul.d\consul-common.json -Value $consulappendage

# Adjust file due to strange things Powershell does with the HCL encoding
# ((Get-Content consul-common.hcl) -join "`n") + "`n" | Set-Content -NoNewline consul-common.hcl

# sc.exe create "Consul" binPath= "c:\hashicorp\consul\consul.exe agent -config-dir=C:\hashicorp\consul\consul.d -data-dir=C:\hashicorp\consul\consul-data" start=auto
# sc.exe start "Consul"
# sc.exe create "Nomad" binPath= "c:\hashicorp\nomad\nomad.exe agent -config=C:\hashicorp\nomad\nomad.d -data-dir=C:\hashicorp\nomad\nomad-data" start=auto
# sc.exe start "Nomad"

# Create the Consul Service
$consul_service = @{
    Name = "Consul Agent"
    BinaryPathName = "c:\hashicorp\consul\consul.exe agent -config-dir=C:\hashicorp\consul\consul.d -data-dir=C:\hashicorp\consul\consul-data"
    DisplayName = "Consul Agent"
    StartupType = "Automatic"
    Description = "HashiCorp Consul Agent"
}
New-Service @consul_service

# Create the Nomad Service
$nomad_service = @{
    Name = "Nomad Agent"
    BinaryPathName = "c:\hashicorp\nomad\nomad.exe agent -config=C:\hashicorp\nomad\nomad.d -data-dir=C:\hashicorp\nomad\nomad-data"
    DisplayName = "Nomad Agent"
    StartupType = "Automatic"
    Description = "HashiCorp Nomad Agent"
}
New-Service @nomad_service

# Fire up Consul and Nomad
Start-Service -Name "Consul Agent"
Start-Service -Name "Nomad Agent"