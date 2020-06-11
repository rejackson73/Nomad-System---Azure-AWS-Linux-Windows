client {
    options {
      docker.privileged.enabled = "true"
    }
  }
consul {
  address = "127.0.0.1:8500"
}
telemetry {
  publish_allocation_metrics = true
  publish_node_metrics       = true
  datadog_address = "localhost:8125"
  disable_hostname = true
  collection_interval = "10s"
}