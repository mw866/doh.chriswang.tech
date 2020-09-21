job "doh" {
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
      delay = "1m"
      mode = "fail"
    }
    network {
        mode = "bridge"
        port "http" {to = 8000}
        port "https" {to = 8443}
        port "admin" {to = 8001}
    }
    service {
      name = "kong"
      tags = []
      port = "admin"
      check {
        name = "metrics"
        path = "/metrics"
        type     = "http"
        interval = "10s"
        timeout  = "2s"
      }
      // connect {
      //   sidecar_service {}
      // }
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
        KONG_ADMIN_LISTEN = "0.0.0.0:8001" # TODO need to tighen up
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
          static  = 8002
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
          timeout  = "2s"
        }

        // connect {
        //   sidecar_service {
        //     proxy {
        //       upstreams {
        //         destination_name = "kong"
        //         local_bind_port  = 8000
        //       }
        //     }
        //   }
        // }
      }

      task "cloudflared" {
        driver = "docker"
        config {
          image = "mw866/cloudflared:2020.9.1-13-gafa5e68"
          network_mode = "bridge"
          ports = ["metrics"]
          mounts = {
            type = "bind"
            # Change to the correct absolute path according to your environment. 
            source = "/home/ubuntu/.cloudflared/cert.pem" 
            target = "/etc/cloudflared/cert.pem"
            readonly = true
          }
          command = "tunnel"
          args = [
            "--hostname", "doh.chriswang.tech",
            "--origincert", "/etc/cloudflared/cert.pem",
            "--metrics", "0.0.0.0:8002", # TODO need to tighen up
            # "--url", "http://${NOMAD_UPSTREAM_ADDR_kong}",
            "--hello-world"
          ]
        }
      }
    }

}
