#!/bin/bash
#===============================================================================
#          FILE: create_kube_controller_config.sh
#         USAGE: . ${YOUR_PATH}/create_kube_controller_config.sh
#   DESCRIPTION: 
#        AUTHOR: IVAN DU
#        E-MAIL: mrivandu@hotmail.com
#        WECHAT: ecsboy
#      TECHBLOG: https://ivandu.blog.csdn.net
#        GITHUB: https://github.com/mrivandu
#       CREATED: 2019-07-03 12:02:55
#       LICENSE: GNU General Public License.
#     COPYRIGHT: © IVAN DU 2019
#      REVISION: v1.0
#===============================================================================

. kube_config.sh

# Create the controller-manager service.

cat>${kube_conf}/kube-controller-manager.conf<<EOF
KUBE_CONTROLLER_MANAGER_OPTS="--logtostderr=true \
--v=4 \
--master=127.0.0.1:8080 \
--leader-elect=true \
--address=127.0.0.1 \
--service-cluster-ip-range=10.0.0.0/24 \
--cluster-name=kubernetes \
--cluster-signing-cert-file=${etcd_ca}/ca.pem \
--cluster-signing-key-file=${etcd_ca}/ca-key.pem  \
--root-ca-file=${etcd_ca}/ca.pem \
--service-account-private-key-file=${etcd_ca}/ca-key.pem"
EOF

cat>/usr/lib/systemd/system/kube-controller-manager.service<<EOF
[Unit]
Description=Kubernetes Controller Manager
Documentation=https://github.com/kubernetes/kubernetes

[Service]
EnvironmentFile=-${kube_conf}/kube-controller-manager.conf
ExecStart=${bin}/kube-controller-manager \$KUBE_CONTROLLER_MANAGER_OPTS
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
