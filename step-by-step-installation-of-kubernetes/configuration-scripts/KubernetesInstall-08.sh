#!/bin/bash
KUBE_CONF=/etc/kubernetes
FLANNEL_CONF=$KUBE_CONF/flannel.conf
mkdir $KUBE_CONF
tar -xvzf flannel-v0.11.0-linux-amd64.tar.gz
mv {flanneld,mk-docker-opts.sh} /usr/local/bin/
# Check whether etcd cluster is healthy.
etcdctl \
--ca-file=/etc/etcd/ssl/ca.pem \
--cert-file=/etc/etcd/ssl/server.pem \
--key-file=/etc/etcd/ssl/server-key.pem \
--endpoints="https://172.31.2.11:2379,\
https://172.31.2.12:2379,\
https://172.31.2.13:2379" cluster-health

# Writing into a predetermined subnetwork.
cd /etc/etcd/ssl
etcdctl \
--ca-file=ca.pem --cert-file=server.pem --key-file=server-key.pem \
--endpoints="https://172.31.2.11:2379,https://172.31.2.12:2379,https://172.31.2.13:2379" \
set /coreos.com/network/config  '{ "Network": "172.17.0.0/16", "Backend": {"Type": "vxlan"}}'
cd ~

# Configuration the flannel service.
cat>$FLANNEL_CONF<<EOF
FLANNEL_OPTIONS="--etcd-endpoints=https://172.31.2.11:2379,https://172.31.2.12:2379,https://172.31.2.13:2379 -etcd-cafile=/etc/etcd/ssl/ca.pem -etcd-certfile=/etc/etcd/ssl/server.pem -etcd-keyfile=/etc/etcd/ssl/server-key.pem" 
EOF
cat>/usr/lib/systemd/system/flanneld.service<<EOF
[Unit]
Description=Flanneld overlay address etcd agent
After=network-online.target network.target
Before=docker.service

[Service]
Type=notify
EnvironmentFile=$FLANNEL_CONF
ExecStart=/usr/local/bin/flanneld --ip-masq \$FLANNEL_OPTIONS
ExecStartPost=/usr/local/bin/mk-docker-opts.sh -k DOCKER_NETWORK_OPTIONS -d /run/flannel/subnet.env
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

# Modify the docker service.
sed -i.bak -e '/ExecStart/i EnvironmentFile=\/run\/flannel\/subnet.env' -e 's/ExecStart=\/usr\/bin\/dockerd/ExecStart=\/usr\/bin\/dockerd $DOCKER_NETWORK_OPTIONS/g' /usr/lib/systemd/system/docker.service

# Start or restart related services.
systemctl daemon-reload
systemctl enable flanneld --now
systemctl restart docker
systemctl status flanneld
systemctl status docker
ip address show