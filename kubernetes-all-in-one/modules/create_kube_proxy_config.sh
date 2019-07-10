#!/bin/bash
#===============================================================================
#          FILE: create_kube_scheduler_config.sh
#         USAGE: . ${YOUR_PATH}/create_kube_scheduler_config.sh
#   DESCRIPTION: 
#        AUTHOR: IVAN DU
#        E-MAIL: mrivandu@hotmail.com
#        WECHAT: ecsboy
#      TECHBLOG: https://ivandu.blog.csdn.net
#        GITHUB: https://github.com/mrivandu
#       CREATED: 2019-07-04 11:03:52
#       LICENSE: GNU General Public License.
#     COPYRIGHT: © IVAN DU 2019
#      REVISION: v1.0
#===============================================================================

. kube_config.sh
cat>temp/kube-proxy.conf<<EOF
KUBE_PROXY_OPTS="--logtostderr=true \
--v=4 \
--hostname-override=kube-proxy-ip \
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




