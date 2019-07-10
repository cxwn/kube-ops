#!/bin/bash
#===============================================================================
#          FILE: kube_scheduler_installation.sh
#         USAGE: . ${YOUR_PATH}/kube_scheduler_installation.sh 
#   DESCRIPTION: 
#        AUTHOR: IVAN DU
#        E-MAIL: mrivandu@hotmail.com
#        WECHAT: ecsboy
#      TECHBLOG: https://ivandu.blog.csdn.net
#        GITHUB: https://github.com/mrivandu
#       CREATED: 2019-07-03 15:33:46
#       LICENSE: GNU General Public License.
#     COPYRIGHT: © IVAN DU 2019
#      REVISION: v1.0
#===============================================================================

. kube_config.sh

[ -f ${bin}/kube-scheduler ] && rm -f ${bin}/kube-scheduler
cp temp/kubernetes-v1.15.0-linux-amd64-1/kube-scheduler ${bin}/

. modules/create_kube_scheduler_config.sh

systemctl daemon-reload
systemctl enable kube-scheduler.service --now && systemctl status kube-scheduler.service

[ $? -eq 0 ] && sleep 10
if [ $? -eq 0 ];then
  echo "Kube-scheduler deployed sucessfully. "
else
  echo "Kube-scheduler-manager has not been deployed successfully. Plaese check. "
  exit 5
fi
