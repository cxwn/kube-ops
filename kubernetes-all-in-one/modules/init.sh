#!/bin/bash
#===============================================================================
#          FILE: init.sh
#         USAGE: . ${YOUR_PATH}/init.sh 
#   DESCRIPTION: 
#        AUTHOR: IVAN DU
#        E-MAIL: mrivandu@hotmail.com
#        WECHAT: ecsboy
#      TECHBLOG: https://ivandu.blog.csdn.net
#        GITHUB: https://github.com/mrivandu
#       CREATED: 2019-06-28 15:12:18
#       LICENSE: GNU General Public License.
#     COPYRIGHT: © IVAN DU 2019
#      REVISION: v1.0
#===============================================================================

. ../kube_config.sh

IP=$(grep -E "^IPADDR"  /etc/sysconfig/network-scripts/ifcfg-[!l][!o]*|awk -F "=" '{print $2}')

# mkdir -p {${etcd},${etcd_ca},${kube_conf},${kube_ca}}
if [ ${hosts['gysl-master']} != ${IP} ];then
   mkdir -p ${flanneld_conf}
fi

