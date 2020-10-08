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
          // static = 8000
          to = 8000
        }
        port "https" {
          // static = 8443
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
            proxy {
            #https://www.consul.io/docs/connect/registration/sidecar-service
            config {
              protocol = "http"
              connect_timeout_ms = 300000
              local_connect_timeout_ms = 300000
              limits {
                max_pending_requests = 10000
              }
              passive_health_check {
                interval = 60000
                max_failures = 100
              }
            }
          }
        }     
      }
    } 
    service {
      name = "kong-http"
      port = "http"
      check {
        address_mode = "driver"
        name = "http"
        path = "/dns-query?name=example.com&type=a"
        type     = "http"
        interval = "10s"
        timeout  = "2s"
        header {
          accept = ["application/dns-json"]
        }
      }
      connect {
        sidecar_service {
          proxy {
            #https://www.consul.io/docs/connect/registration/sidecar-service
            config {
              protocol = "http"
              connect_timeout_ms = 300000
              local_connect_timeout_ms = 300000
              limits {
                max_pending_requests = 10000
              }
              passive_health_check {
                interval = 60000
                max_failures = 100
              }
            }
          }
          
        }
      }
    }    
    task "kong" {
      driver = "docker"
      config {
        image = "kong:2.1.3-ubuntu"
        # Image below is for debugging only with sudo access.
        # image = "mw866/kong:latest"
        # network_mode = "bridge"
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
              destination_name = "kong-metrics"
              local_bind_port  = 8011
            }
            #https://www.consul.io/docs/connect/registration/sidecar-service
            config {
              protocol = "http"
              connect_timeout_ms = 300000
              local_connect_timeout_ms = 300000
              limits {
                max_pending_requests = 10000
              }
              passive_health_check {
                interval = 60000
                max_failures = 100
              }
            }
          }
        }
      }
    }
    task "cloudflared" {
      driver = "docker"
      config {
        image = "mw866/cloudflared:2020.9.3-6-g812244d"
        # network_mode = "bridge"
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
          "--url", "http://${NOMAD_UPSTREAM_ADDR_kong_metrics}",
          "--lb-pool", "connect",
          "--metrics", "0.0.0.0:8002", 
          "--tag", "NOMAD_ALLOC_ID=${NOMAD_ALLOC_ID}",
          "--proxy-connect-timeout", "300s",
          "--retries", "100"
        ]
      }
      resources {
        cpu    = 200 
        memory = 1024 
      }
    }
    
    // task "await-kong" {
    //   driver = "docker"
    //   config {
    //     image        = "gcr.io/kubernetes-e2e-test-images/dnsutils:1.3"
    //     command      = "sh"
    //     args         = ["-c", "echo -n 'Waiting for service'; until dig +short ANY kong-metrics.service.consul @127.0.0.1 -p 8600 2>&1 >/dev/null; do echo '.'; sleep 10; done"]
    //     network_mode = "host"
    //   }

    //   resources {
    //     cpu    = 200
    //     memory = 128
    //   }

    //   lifecycle {
    //     hook    = "prestart"
    //     sidecar = false
    //   }
    // }
  }
} 
