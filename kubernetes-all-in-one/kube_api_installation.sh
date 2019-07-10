#!/bin/bash
#===============================================================================
#          FILE: kube_api_installation.sh
#         USAGE: . ${YOUR_PATH}/kube_api_installation.sh 
#   DESCRIPTION: 
#        AUTHOR: IVAN DU
#        E-MAIL: mrivandu@hotmail.com
#        WECHAT: ecsboy
#      TECHBLOG: https://ivandu.blog.csdn.net
#        GITHUB: https://github.com/mrivandu
#       CREATED: 2019-07-03 12:05:26
#       LICENSE: GNU General Public License.
#     COPYRIGHT: © IVAN DU 2019
#      REVISION: v1.0
#===============================================================================

. kube_config.sh

[ -f ${bin}/kube-apiserver ] && rm -f ${bin}/kube-apiserver
cp temp/kubernetes-v1.15.0-linux-amd64-1/kube-apiserver ${bin}/

. modules/create_kube_ca.sh
. modules/create_kube_api_config.sh
systemctl daemon-reload
systemctl enable kube-apiserver.service --now
systemctl status kube-apiserver.service