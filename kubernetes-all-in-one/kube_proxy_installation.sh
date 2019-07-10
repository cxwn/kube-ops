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
. modules/create_kube_proxy_config.sh

for kube_proxy_ip in ${hosts[@]};
 do 
   if [ "${kube_proxy_ip}" != "${hosts[gysl-master]}" ] ; then
     scp temp/kubernetes-v1.15.0-linux-amd64-2/kube-proxy root@${kube_proxy_ip}:${bin}/
     scp temp/kube-proxy.conf root@${kube_proxy_ip}:${kube_conf}/
     scp temp/kube-proxy.service root@${kube_proxy_ip}:/usr/lib/systemd/system/kube-proxy.service
     scp ${kube_ca}/kube-proxy.kubeconfig root@${kube_proxy_ip}:${kube_conf}/
     ssh root@${kube_proxy_ip} "sed -i \"s/kube_proxy_ip/${kube_proxy_ip}/g\" ${kube_conf}/kube-proxy.conf"
     ssh root@${kube_proxy_ip} "pkill kubelet"
     ssh root@${kube_proxy_ip} "systemctl daemon-reload && systemctl enable kube-proxy.service --now && systemctl status kube-proxy.service -l"
    fi
  done

[ $? -eq 0 ] && sleep 10
if [ $? -eq 0 ];then
  echo "Kube-proxy deployed sucessfully. "
else
  echo "Kube-proxy has not been deployed successfully. Plaese check. "
  exit 7
fi
