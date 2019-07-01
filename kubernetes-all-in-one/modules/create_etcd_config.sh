#!/bin/bash
#===============================================================================
#          FILE: create_etcd_cluster.sh
#         USAGE: . ${YOUR_PATH}/create_etcd_config.sh 
#   DESCRIPTION: 
#        AUTHOR: IVAN DU
#        E-MAIL: mrivandu@hotmail.com
#        WECHAT: ecsboy
#      TECHBLOG: https://ivandu.blog.csdn.net
#        GITHUB: https://github.com/mrivandu
#       CREATED: 2019-06-28 15:03:41
#       LICENSE: GNU General Public License.
#     COPYRIGHT: © IVAN DU 2019
#      REVISION: v1.0
#===============================================================================

. kube_config.sh

## The etcd configuration file.
cat>${etcd_conf}/etcd.conf<<EOF
#[Member]
ETCD_NAME="etcd-master"
ETCD_DATA_DIR="/var/lib/etcd/default.etcd"
ETCD_LISTEN_PEER_URLS="https://${hosts[gysl-master]}:2380"
ETCD_LISTEN_CLIENT_URLS="https://${hosts[gysl-master]}:2379"

#[Clustering]
ETCD_INITIAL_ADVERTISE_PEER_URLS="https://${hosts[gysl-master]}:2380"
ETCD_ADVERTISE_CLIENT_URLS="https://${hosts[gysl-master]}:2379"
ETCD_INITIAL_CLUSTER="etcd-master=https://${hosts[gysl-master]}:2380,etcd-01=https://${hosts[gysl-node1]}:2380,etcd-02=https://${hosts[gysl-node2]}:2380"
ETCD_INITIAL_CLUSTER_TOKEN="etcd-cluster"
ETCD_INITIAL_CLUSTER_STATE="new"
EOF

## The etcd servcie configuration file.
cat>/usr/lib/systemd/system/etcd.service<<EOF
[Unit]
Description=Etcd Server
After=network.target
After=network-online.target
Wants=network-online.target

[Service]
Type=notify
EnvironmentFile=${etcd_conf}/etcd.conf
ExecStart=${bin}/etcd \\
--name=\${ETCD_NAME} \\
--data-dir=\${ETCD_DATA_DIR} \\
--listen-peer-urls=\${ETCD_LISTEN_PEER_URLS} \\
--listen-client-urls=\${ETCD_LISTEN_CLIENT_URLS},http://127.0.0.1:2379 \\
--advertise-client-urls=\${ETCD_ADVERTISE_CLIENT_URLS} \\
--initial-advertise-peer-urls=\${ETCD_INITIAL_ADVERTISE_PEER_URLS} \\
--initial-cluster=\${ETCD_INITIAL_CLUSTER} \\
--initial-cluster-token=\${ETCD_INITIAL_CLUSTER_TOKEN} \\
--initial-cluster-state=\${ETCD_INITIAL_CLUSTER_STATE} \\
--cert-file=${etcd_ca}/server.pem \\
--key-file=${etcd_ca}/server-key.pem \\
--peer-cert-file=${etcd_ca}/server.pem \\
--peer-key-file=${etcd_ca}/server-key.pem \\
--trusted-ca-file=${etcd_ca}/ca.pem \\
--peer-trusted-ca-file=${etcd_ca}/ca.pem
Restart=on-failure
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF
