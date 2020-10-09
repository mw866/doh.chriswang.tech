# The job puts cloudflared and kong in the same task group. 
# cloudflared communicates to Kong in the same network namespace.

job "sidecar" {
  datacenters = ["dc1"]
  type = "service"
  update {
    max_parallel = 1
    min_healthy_time = "10s"
    healthy_deadline = "3m"
    progress_deadline = "10m"
    auto_revert = false
    auto_promote = false
    canary = 0
  }

  migrate {
    max_parallel = 1
    health_check = "checks"
    min_healthy_time = "10s"
    healthy_deadline = "5m"
  }

  group "sidecar" {
    count = 1
    restart {
      attempts = 2
      interval = "5m"
      delay = "1m"
      mode = "fail"
    }
    network {
        mode = "host"
        port "konghttp" {
          to = 8000
        }
        port "konghttps" {
          to = 8443
        }
        port "kongadmin" {
          to = 8001
        }
        port "cloudflaredmetrics" {
          to = 8002
        }
    }
    service {
      name = "kong-http"
      port = "konghttp"
      address_mode = "driver"
      check {
        name = "http"
        path = "/dns-query?name=example.com&type=a"
        type     = "http"
        interval = "10s"
        timeout  = "2s"
        header {
          accept = ["application/dns-json"]
        }
      }
    }
    service {
      name = "kong-metrics"
      port = "kongadmin"
      address_mode = "driver"

      check {
        address_mode = "driver"
        name = "metrics"
        path = "/metrics"
        type     = "http"
        protocol = "http"
        interval = "10s"
        timeout  = "2s"
      }
    }
    service {
      name = "cloudflared-metrics"
      tags = []
      port = "cloudflaredmetrics"
      address_mode = "driver"
      check {
        name = "healthcheck"
        path = "/healthcheck"
        type     = "http"
        interval = "10s"
        timeout  = "60s"
      }
    }   
    task "kong" {
      driver = "docker"
      config {
        image = "kong:2.1.3-ubuntu"
        ports = ["konghttp", "kongadmin", "konghttps"]
        mounts = {
          type = "bind"
          # Change to the correct absolute path according to your environment. 
          source = "/home/ubuntu/doh.chriswang.tech/kong.yml" 
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
      
      lifecycle {
        hook    = "prestart"
        sidecar = true
      }
    }

    task "cloudflared" {
      driver = "docker"
      config {
        image = "mw866/cloudflared:2020.9.3-6-g812244d"
        ports = ["cloudflaredmetrics"]
        mounts = {
          type = "bind"
          source = "/home/ubuntu/.cloudflared/cert.pem" 
          target = "/etc/cloudflared/cert.pem"
          readonly = true
        }
        command = "tunnel"
        # Not all args have corresponding environement variables
        args = [
          "--hostname", "sidecar.chriswang.tech",
          "--origincert", "/etc/cloudflared/cert.pem",
          "--url", "http://${NOMAD_ADDR_konghttp}",
          "--lb-pool", "sidecar",
          "--metrics", "0.0.0.0:8002", 
          "--tag", "NOMAD_ALLOC_ID=${NOMAD_ALLOC_ID}"
        ]
      }
      resources {
        cpu    = 200 
        memory = 1024 
      }
    }
  }
}