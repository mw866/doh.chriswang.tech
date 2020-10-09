# README

Proof of Concept with Kong, Nomad, Consul on a Raspberry Pi.

## Getting started

### Dev on macOs
1. Install Nomad and Consul

2. Run the following Command.

Please note as of Nomad v0.12.5, Nomad's Connect integration requires Linux network namespaces. Nomad Connect will not run on macOS.

```
cd <repo>
nomad agent -dev -config=nomad.d
consul agent -dev -node=local -ui 
```


### Dev on Vagrant
1. Install Nomad, Consul and Vagrant

2. Run the following commands.

```
cd <repo>
vagrant up
vagrant ssh
```

3. Over SSH on the VM, run the following commands. 

```
nomad agent -dev -bind=0.0.0.0 -config=/vagrant/nomad.d
consul agent -dev -node=local -ui --client=0.0.0.0
```


### Production on Raspberry Pi

1. Set up Nomad by following the [officla deployment guide](https://learn.hashicorp.com/tutorials/nomad/production-deployment-guide-vm-with-consul). Make sure you install the `arm64` binary. Default URL of Nomad UI : http://HOST_IP:8500

The example `systemd` unit file is as below.

```
$ systemctl cat nomad.service

# /etc/systemd/system/nomad.service
[Unit]
Description=Nomad
Documentation=https://nomadproject.io/docs/
Wants=network-online.target
After=network-online.target

[Service]
ExecReload=/bin/kill -HUP $MAINPID
ExecStart=/usr/local/bin/nomad agent -config /home/ubuntu/doh.chriswang.tech/nomad.d
KillMode=process
KillSignal=SIGINT
LimitNOFILE=infinity
LimitNPROC=infinity
Restart=on-failure
RestartSec=2
StartLimitBurst=3
StartLimitIntervalSec=10
TasksMax=infinity

[Install]
WantedBy=multi-user.target
```


2. Set up Consul by following the [officla deployment guide](https://learn.hashicorp.com/tutorials/consul/deployment-guide). Make sure you install the `arm64` binary. Default URL of Consul UI: http://HOST_IP:4646

The example `systemd` unit file is as below.

```
$systemctl cat consul.service

# /etc/systemd/system/consul.service
[Unit]
Description="Consul"
Documentation=https://www.consul.io/
Requires=network-online.target
After=network-online.target

[Service]
# The configuration provided by this tutorial is the recommended one for a Consul datacenter running multiple server nodes. In test environemnts or environments where only one Consul server is deployed you should>
Type=exec
#User=consul
#Group=consul
ExecStart=/usr/local/bin/consul agent -config-dir=/home/ubuntu/doh.chriswang.tech/consul.d
ExecReload=/usr/local/bin/consul reload
ExecStop=/usr/local/bin/consul leave
KillMode=process
Restart=on-failure
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
```

3.  Run the nomad job.
```
nomad run <nomad_job_name>.nomad
```

## Roadmap

* Expand the Nomad Cluster from 1 node to 2 node

* Vault integratin

* Put some useful API behind Kong


## Inspiration

* [Running Hashicorp Nomad, Consul, Pihole and Gitea on Raspberry Pi 3 B+](https://medium.com/swlh/running-hashicorp-nomad-consul-pihole-and-gitea-on-raspberry-pi-3-b-f3f0d66c907)

* [mockingbirdconsulting/HashicorpAtHome](https://github.com/mockingbirdconsulting/HashicorpAtHome)