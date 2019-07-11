#!/bin/bash
#===============================================================================
#          FILE: last_config.sh
#         USAGE: . ${YOUR_PATH}/last_config.sh 
#   DESCRIPTION: 
#        AUTHOR: IVAN DU
#        E-MAIL: mrivandu@hotmail.com
#        WECHAT: ecsboy
#      TECHBLOG: https://ivandu.blog.csdn.net
#        GITHUB: https://github.com/mrivandu
#       CREATED: 2019-07-9 12:51:27
#       LICENSE: GNU General Public License.
#     COPYRIGHT: © IVAN DU 2019
#      REVISION: v1.0
#==============================================================================

. kube_config.sh

for csr in $(kubectl get csr | awk '{if(NR>1) print $1}');
  do
    kubectl certificate approve ${csr};
  done

sleep 20

for node in ${hosts[@]}
  do  
    if [ "${node}" == "${hosts[gysl-master]}" ] ;then
      kubectl label node ${node} node-role.kubernetes.io/master='master'
    else
      kubectl label node ${node} node-role.kubernetes.io/node='node'
    fi
  done
kubectl get cs
kubectl get nodes -o wide