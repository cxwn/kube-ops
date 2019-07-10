#!/bin/bash
#===============================================================================
#          FILE: create_kube_scheduler_config.sh.sh
#         USAGE: . ${YOUR_PATH}/create_kube_scheduler_config.sh.sh 
#   DESCRIPTION: 
#        AUTHOR: IVAN DU
#        E-MAIL: mrivandu@hotmail.com
#        WECHAT: ecsboy
#      TECHBLOG: https://ivandu.blog.csdn.net
#        GITHUB: https://github.com/mrivandu
#       CREATED: 2019-07-03 15:03:46
#       LICENSE: GNU General Public License.
#     COPYRIGHT: © IVAN DU 2019
#      REVISION: v1.0
#===============================================================================

# Create the scheduler service.

cat>${kube_conf}/kube-scheduler.conf<<EOF
KUBE_SCHEDULER_OPTS="--logtostderr=true \
--v=4 \
--master=127.0.0.1:8080 \
--leader-elect"
EOF

cat>/usr/lib/systemd/system/kube-scheduler.service<<EOF
[Unit]
Description=Kubernetes Scheduler
Documentation=https://github.com/kubernetes/kubernetes

[Service]
EnvironmentFile=-${kube_conf}/kube-scheduler.conf
ExecStart=${bin}/kube-scheduler \$KUBE_SCHEDULER_OPTS
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
