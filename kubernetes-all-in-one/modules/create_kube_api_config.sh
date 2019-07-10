#!/bin/bash
#===============================================================================
#          FILE: create_kube_api_config.sh
#         USAGE: . ${YOUR_PATH}/create_kube_api_config.sh 
#   DESCRIPTION: 
#        AUTHOR: IVAN DU
#        E-MAIL: mrivandu@hotmail.com
#        WECHAT: ecsboy
#      TECHBLOG: https://ivandu.blog.csdn.net
#        GITHUB: https://github.com/mrivandu
#       CREATED: 2019-07-02 15:03:12
#       LICENSE: GNU General Public License.
#     COPYRIGHT: © IVAN DU 2019
#      REVISION: v1.0
#===============================================================================

. kube_config.sh

# Create a token file.
cat>${kube_ca}/token.csv<<EOF
$(head -c 16 /dev/urandom | od -An -t x | tr -d ' '),kubelet-bootstrap,10001,"system:kubelet-bootstrap"
EOF

# Create a kube-apiserver configuration file.
cat >${kube_conf}/api-server.conf<<EOF
KUBE_APISERVER_OPTS="--logtostderr=true \
--v=4 \
--etcd-servers=https://${hosts[gysl-master]}:2379,https://${hosts[gysl-node1]}:2379,https://${hosts[gysl-node2]}:2379 \
--bind-address=${hosts[gysl-master]} \
--secure-port=6443 \
--advertise-address=${hosts[gysl-master]} \
--allow-privileged=true \
--service-cluster-ip-range=10.0.0.0/24 \
--enable-admission-plugins=NamespaceLifecycle,LimitRanger,SecurityContextDeny,ServiceAccount,ResourceQuota,NodeRestriction \
--authorization-mode=RBAC,Node \
--enable-bootstrap-token-auth \
--token-auth-file=${kube_ca}/token.csv \
--service-node-port-range=30000-50000 \
--tls-cert-file=${etcd_ca}/server.pem  \
--tls-private-key-file=${etcd_ca}/server-key.pem \
--client-ca-file=${etcd_ca}/ca.pem \
--service-account-key-file=${etcd_ca}/ca-key.pem \
--etcd-cafile=${kube_ca}/ca.pem \
--etcd-certfile=${kube_ca}/server.pem \
--etcd-keyfile=${kube_ca}/server-key.pem"
EOF

# Create the kube-apiserver service.
cat>/usr/lib/systemd/system/kube-apiserver.service<<EOF
[Unit]
Description=Kubernetes API Server
Documentation=https://github.com/kubernetes/kubernetes
After=etcd.service
Wants=etcd.service

[Service]
EnvironmentFile=-${kube_conf}/api-server.conf
ExecStart=${bin}/kube-apiserver \$KUBE_APISERVER_OPTS
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

