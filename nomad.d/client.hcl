client {
  enabled = true
  meta {
    connect.sidecar_image = "envoyproxy/envoy-dev:b63855d710b8b800bf4100598ad8cfef4ceda15d"
    connect.log_level = "trace"
  }
}

