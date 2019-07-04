#!/bin/bash
#===============================================================================
#          FILE: create_flanneld_config.sh
#         USAGE: . ${YOUR_PATH}/create_flanneld_config.sh 
#   DESCRIPTION: 
#        AUTHOR: IVAN DU
#        E-MAIL: mrivandu@hotmail.com
#        WECHAT: ecsboy
#      TECHBLOG: https://ivandu.blog.csdn.net
#        GITHUB: https://github.com/mrivandu
#       CREATED: 2019-06-29 15:02:55
#       LICENSE: GNU General Public License.
#     COPYRIGHT: © IVAN DU 2019
#      REVISION: v1.0
#===============================================================================

. kube_config.sh

cat>temp/flanneld.conf<<EOF
FLANNEL_OPTIONS="--etcd-endpoints=https://${etcd[etcd-master]}:2379,\
https://${etcd[etcd-01]}:2379,https://${etcd[etcd-02]}:2379,\
-etcd-cafile=${etcd_ca}/ca.pem -etcd-certfile=${etcd_ca}/server.pem -etcd-keyfile=${etcd_ca}/server-key.pem"
EOF

# Configuration the flannel service.
cat>temp/flanneld.service<<EOF
[Unit]
Description=Flanneld overlay address etcd agent
After=network-online.target network.target
Before=docker.service

[Service]
Type=notify
EnvironmentFile=${flanneld_conf}/flanneld.conf
ExecStart=${bin}/flanneld --ip-masq \$FLANNEL_OPTIONS
ExecStartPost=${bin}/mk-docker-opts.sh -k DOCKER_NETWORK_OPTIONS -d /run/flanneld/subnet.env
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
