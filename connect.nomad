# The job uses sperate groups for cloudflared and kong. 
# cloudflared is connected the upstream, Kong, over Consul Connect.

job "connect" {
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

  group "kong" {
    count = 1
    restart {
      attempts = 2
      interval = "5m"
      delay = "1m"
      mode = "fail"
    }
    network {
        mode = "bridge"
        port "http" {
          static = 8000
          to = 8000
        }
        port "https" {
          static = 8443
          to = 8443
        }
        port "admin" {
          static = 8001
          to = 8001
        }
    }
    service {
      name = "kong-metrics"
      port = "admin"
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
      connect {
        sidecar_service {
        }     
      }
    } 
    service {
      name = "kong-http"
      port = "http"
      check {
        address_mode = "driver"
        name = "http"
        path = "/status/200"
        type     = "http"
        interval = "10s"
        timeout  = "2s"
      }
      connect {
        sidecar_service {    
        }
      }
    }    
    task "kong" {
      driver = "docker"
      config {
        image = "kong:2.1.4-alpine"
        # Image below is for debugging only with sudo access.
        # image = "mw866/kong:latest"
        ports = ["http", "admin", "https"]
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
        KONG_ADMIN_LISTEN = "0.0.0.0:8001" # TODO need to tighen up in production
        KONG_LOG_LEVEL = "error"
      }
      resources {
        cpu    = 200 
        memory = 512 
      }
    }
  }

  group "cloudflared" {
    count = 1
    restart {
      attempts = 2
      interval = "5m"
      delay = "1m"
      mode = "fail"
    } 
    network {
      mode = "bridge"
      port "metrics" {
        to = 8002
      }
    }
    service {
      name = "cloudflared"
      tags = []
      port = "metrics"
      check {
        name = "healthcheck"
        path = "/healthcheck"
        type     = "http"
        interval = "10s"
        timeout  = "60s"
      }

      connect {
        sidecar_service {
          proxy {
            upstreams {
              destination_name = "kong-http"
              local_bind_port  = 8011
            }
          }
        }
      }
    }
    task "cloudflared" {
      driver = "docker"
      config {
        image = "mw866/cloudflared:2020.9.3-6-g812244d"
        ports = ["metrics"]
        mounts = {
          type = "bind"
          source = "/home/ubuntu/.cloudflared/cert.pem" 
          target = "/etc/cloudflared/cert.pem"
          readonly = true
        }
        command = "tunnel"
        # Not all args have corresponding environement variables
        args = [
          "--hostname", "connect.chriswang.tech",
          "--origincert", "/etc/cloudflared/cert.pem",
          "--url", "http://${NOMAD_UPSTREAM_ADDR_kong_http}",
          "--lb-pool", "connect",
          "--metrics", "0.0.0.0:8002", 
          "--tag", "NOMAD_ALLOC_ID=${NOMAD_ALLOC_ID}",
          "--proxy-connect-timeout", "300s",
          "--retries", "100"
        ]
      }
      resources {
        cpu    = 200 
        memory = 256 
      }
    }
  }
} 
