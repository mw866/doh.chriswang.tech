job "kong" {
  datacenters = ["dc1"]
  type = "service"
  update {
    max_parallel = 1
    min_healthy_time = "10s"
    healthy_deadline = "3m"
    progress_deadline = "10m"
    auto_revert = false
    auto_promote = true # change to false in production
    canary = 1
  }

  migrate {
    max_parallel = 1
    health_check = "checks"
    min_healthy_time = "10s"
    healthy_deadline = "5m"
  }

  group "kong" {
    count = 1
    restart {
      attempts = 2
      interval = "5m"
      delay = "15s"
      mode = "fail"
    }

    network {
        port "http" {to = 8000}
        port "https" {to = 8443}
        port "admin" {to = 8001}
    }

    service {
      tags = []
      port = "admin"
      check {
        name = "metrics"
        path = "/metrics"
        type     = "http"
        interval = "10s"
        timeout  = "2s"
      }
    }

    task "kong" {
      driver = "docker"
      config {
        image = "kong:2.1.3-ubuntu"
        network_mode = "bridge"
        ports = ["http", "admin", "https"]
        mounts = {
          type = "bind"
          # Change to the correct absolute path according to your environment. 
          source = "/home/ubuntu/doh.chriswang.tech/kong/kong.yml" 
          target = "/usr/local/kong/declarative/kong.yml"
          readonly = true
        }
      }
      env {
        KONG_DATABASE = "off"
        KONG_DECLARATIVE_CONFIG = "/usr/local/kong/declarative/kong.yml"
        KONG_ADMIN_LISTEN = "0.0.0.0:8001"
        KONG_LOG_LEVEL = "error"
      }
      resources {
        cpu    = 200 
        memory = 512 
      }
    }
  }
}
