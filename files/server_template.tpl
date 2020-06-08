#!/usr/bin/env bash

# Server specific consul configuration grabbing local IP
cat << EOF > /etc/consul/consul.d/consul-server.hcl
server = true
log_file = "/etc/consul/logs"
bootstrap_expect = 3
retry_join = ["provider=aws tag_key=Name tag_value=${server_name_tag}"]
bind_addr = "$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)"
advertise_addr = "$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)"
client_addr = "0.0.0.0"
ui = true
EOF

# Server specific nomad configuration
cat << EOF > /etc/nomad/nomad.d/nomad-server.hcl
bind_addr = "0.0.0.0"
log_file = "/etc/nomad/logs"
server {
    enabled = true
    bootstrap_expect = 3
    server_join {
        retry_join = ["provider=aws tag_key=Name tag_value=${server_name_tag}"]
        retry_max = 3
        retry_interval = "15s"
      }
}
advertise {
  http = "$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)"
  rpc  = "$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)"
  serf = "$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)"
}
EOF

# Starting consul and nomad services
sudo systemctl start consul
sleep 10
sudo systemctl start nomad