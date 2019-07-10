#!/bin/bash

cat>temp/kube-proxy.conf<<EOF
KUBE_PROXY_OPTS="--logtostderr=true \
--v=4 \
--hostname-override=$IP \
--cluster-cidr=10.0.0.0/24 \
--kubeconfig=${kube_conf}/kube-proxy.kubeconfig"
EOF
cat>temp/kube-proxy.service<<EOF
[Unit]
Description=Kubernetes Proxy
After=network.target

[Service]
EnvironmentFile=-${kube_conf}/kube-proxy.conf
ExecStart=${bin}/kube-proxy \$KUBE_PROXY_OPTS
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable kube-proxy.service --now
sleep 20
systemctl status kube-proxy.service -l



