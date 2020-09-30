datacenter = "dc1"
data_dir = "/opt/consul"
encrypt = "GSLcrRVXZMxRJNKndVjjYPeHzfW+CA9Dky9ruYX+Jl8="
ca_file = "/home/ubuntu/doh.chriswang.tech/consul.d/consul-agent-ca.pem"
cert_file = "/home/ubuntu/doh.chriswang.tech/consul.d/dc1-server-consul-0.pem"
key_file = "/home/ubuntu/doh.chriswang.tech/consul.d/dc1-server-consul-0-key.pem"
verify_incoming = true
verify_outgoing = true
verify_server_hostname = true
acl = {
  enabled = false 
  default_policy = "allow"
  enable_token_persistence = true
}
bind_addr = "192.168.0.123"
performance {
  raft_multiplier = 1
}
enable_syslog = true
log_level= "error"
