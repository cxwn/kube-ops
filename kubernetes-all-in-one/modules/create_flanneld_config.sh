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
#       CREATED: 2019-06-28 15:02:55
#       LICENSE: GNU General Public License.
#     COPYRIGHT: © IVAN DU 2019
#      REVISION: v1.0
#===============================================================================

. kube_config.sh

## Configuration the flannel service.
cat>temp/flanneld.conf<<EOF
FLANNEL_OPTIONS="--etcd-endpoints=https://${hosts[gysl-master]}:2379,\
https://${hosts[gysl-node1]}:2379,https://${hosts[gysl-node2]}:2379,\
-etcd-cafile=${etcd_ca}/ca.pem -etcd-certfile=${etcd_ca}/server.pem -etcd-keyfile=${etcd_ca}/server-key.pem"
EOF

## Create the flanneld service.
cat>temp/flanneld.service<<EOF
[Unit]
Description=Flanneld overlay address etcd agent
After=network-online.target network.target
Before=docker.service

[Service]
Type=notify
EnvironmentFile=${flanneld_conf}/flanneld.conf
ExecStart=${bin}/flanneld --ip-masq \$FLANNEL_OPTIONS
ExecStartPost=${bin}/mk-docker-opts.sh -k DOCKER_NETWORK_OPTIONS -d /run/flannel/subnet.env
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
