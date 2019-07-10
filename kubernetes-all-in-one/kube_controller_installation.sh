#!/bin/bash
#===============================================================================
#          FILE: kube_controller_installation.sh
#         USAGE: . ${YOUR_PATH}/kube_controller_installation.sh 
#   DESCRIPTION: 
#        AUTHOR: IVAN DU
#        E-MAIL: mrivandu@hotmail.com
#        WECHAT: ecsboy
#      TECHBLOG: https://ivandu.blog.csdn.net
#        GITHUB: https://github.com/mrivandu
#       CREATED: 2019-07-03 13:03:46
#       LICENSE: GNU General Public License.
#     COPYRIGHT: © IVAN DU 2019
#      REVISION: v1.0
#===============================================================================

. kube_config.sh

[ -f ${bin}/kube-controller-manager ] && rm -f ${bin}/kube-controller-manager
cp temp/kubernetes-v1.15.0-linux-amd64-1/kube-controller-manager ${bin}/

. modules/create_kubecontroller_config.sh
systemctl daemon-reload
systemctl enable kube-controller-manager.service --now && systemctl status kube-controller-manager.service

[ $? -eq 0 ] && sleep 10
if [ $? -eq 0 ];then
  echo "Kube-controller-manager deployed sucessfully. "
else
  echo "Kube-controller-manager has not been deployed successfully. Plaese check. "
  exit 4
fi

