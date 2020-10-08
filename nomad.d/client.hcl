client {
  enabled = true
  meta {
    # See" https://www.nomadproject.io/docs/job-specification/sidecar_task
    connect.sidecar_image = "envoyproxy/envoy-dev:b63855d710b8b800bf4100598ad8cfef4ceda15d"
    connect.log_level = "trace" 
  }
}

