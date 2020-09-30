datacenter = "dc1"
data_dir = "/opt/nomad"
plugin "docker" {
    config {
        volumes {
            enabled = true
        }
        infra_image = "gcr.io/google_containers/pause-arm64:3.0"

    }
}

enable_syslog = true
log_level= "error"
