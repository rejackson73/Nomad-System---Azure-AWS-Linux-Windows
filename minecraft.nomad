job "minecraft" {
  datacenters = ["dc1"]
  type        = "service"
  group "minecraft" {
    volume "efs-tests" {
      type      = "csi"
      read_only = false
      source    = "efs-tests"
    }
    task "eula" {
      driver = "exec"
      volume_mount {
         volume      = "efs-tests"
         destination = "/csi-mount"
         read_only   = false
      }
      template {
        data        = "eula=true"
        destination = "local/eula.txt"
      }
      config {
        // command = "mv"
        // args    = ["${NOMAD_TASK_DIR}/eula.txt", "/var/volume/"]
        command = "mv"
        args    = ["local/eula.txt", "/csi-mount/"]
      }
    }
    task "sleep" {
      driver = "exec"
      volume_mount {
         volume      = "efs-tests"
         destination = "/csi-mount"
         read_only   = false
      }
      config {
        command = "/bin/sleep"
        args    = ["600"]
      }
    }
  }
}