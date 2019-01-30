#!/bin/bash
KUBE_CONF=/etc/kubernetes
KUBE_SSL=$KUBE_CONF/ssl
IP=172.31.2.13
mkdir $KUBE_SSL
scp gysl-master:~/kubernetes/server/bin/{kube-proxy,kubelet} /usr/local/bin/
scp gysl-master:$KUBE_CONF/ssl/{bootstrap.kubeconfig,kube-proxy.kubeconfig} $KUBE_CONF
cat>$KUBE_CONF/kube-proxy.conf<<EOF
KUBE_PROXY_OPTS="--logtostderr=true \
--v=4 \
--hostname-override=$IP \
--cluster-cidr=10.0.0.0/24 \
--kubeconfig=$KUBE_CONF/kube-proxy.kubeconfig"
EOF
cat>/usr/lib/systemd/system/kube-proxy.service<<EOF
[Unit]
Description=Kubernetes Proxy
After=network.target

[Service]
EnvironmentFile=-$KUBE_CONF/kube-proxy.conf
ExecStart=/usr/local/bin/kube-proxy \$KUBE_PROXY_OPTS
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable kube-proxy.service --now
sleep 20
systemctl status kube-proxy.service -l
cat>$KUBE_CONF/kubelet.yaml<<EOF
kind: KubeletConfiguration
apiVersion: kubelet.config.k8s.io/v1beta1
address: $IP
port: 10250
readOnlyPort: 10255
cgroupDriver: cgroupfs
clusterDNS: ["10.0.0.2"]
clusterDomain: cluster.local.
failSwapOn: false
authentication:
  anonymous:
    enabled: true
EOF
cat>$KUBE_CONF/kubelet.conf<<EOF
KUBELET_OPTS="--logtostderr=true \
--v=4 \
--hostname-override=$IP \
--kubeconfig=$KUBE_CONF/kubelet.kubeconfig \
--bootstrap-kubeconfig=$KUBE_CONF/bootstrap.kubeconfig \
--config=$KUBE_CONF/kubelet.yaml \
--cert-dir=$KUBE_SSL \
--pod-infra-container-image=registry.cn-hangzhou.aliyuncs.com/google-containers/pause-amd64:3.0"
EOF
cat>/usr/lib/systemd/system/kubelet.service<<EOF
[Unit]
Description=Kubernetes Kubelet
After=docker.service
Requires=docker.service

[Service]
EnvironmentFile=$KUBE_CONF/kubelet.conf
ExecStart=/usr/local/bin/kubelet \$KUBELET_OPTS
Restart=on-failure
KillMode=process

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable kubelet.service --now
sleep 20
systemctl status kubelet.service -l