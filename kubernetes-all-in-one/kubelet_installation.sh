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
#       CREATED: 2019-07-04 10:33:46
#       LICENSE: GNU General Public License.
#     COPYRIGHT: © IVAN DU 2019
#      REVISION: v1.0
#===============================================================================

. kube_config.sh
. modules/create_kubelet_config.sh

for kube_node_ip in ${hosts[@]};
 do 
   if [ "${kube_node_ip}" != "${hosts[gysl-master]}" ] ; then
     scp temp/kubernetes-v1.15.0-linux-amd64-2/kubelet root@${kube_node_ip}:${bin}/
     scp temp/{kubelet.yaml,kubelet.conf} root@${kube_node_ip}:${kube_conf}/
     scp ${kube_ca}/bootstrap.kubeconfig root@${kube_node_ip}:${kube_conf}/
     scp temp/kubelet.service root@${kube_node_ip}:/usr/lib/systemd/system/kubelet.service
     ssh root@${kube_node_ip} "sed -i \"s/kube_node_ip/${kube_node_ip}/g\" ${kube_conf}/kubelet.yaml"
     ssh root@${kube_node_ip} "sed -i \"s/kube_node_ip/${kube_node_ip}/g\" ${kube_conf}/kubelet.conf"
     ssh root@${kube_node_ip} "pkill kubelet"
    fi
  done
[ $? -eq 0 ] && sleep 10

if [ $? -eq 0 ];then
  echo "Kubelet deployed sucessfully. "
else
  echo "Kubelet has not been deployed successfully. Plaese check. "
  exit 6
fi
