#!/bin/bash
#===============================================================================
#          FILE: flannel_installation.sh
#         USAGE: . ${YOUR_PATH}/flannel_installation.sh 
#   DESCRIPTION: 
#        AUTHOR: IVAN DU
#        E-MAIL: mrivandu@hotmail.com
#        WECHAT: ecsboy
#      TECHBLOG: https://ivandu.blog.csdn.net
#        GITHUB: https://github.com/mrivandu
#       CREATED: 2019-07-01 13:05:26
#       LICENSE: GNU General Public License.
#     COPYRIGHT: © IVAN DU 2019
#      REVISION: v1.0
#===============================================================================

# Deployment flanneld.
. kube_config.sh
. modules/create_flanneld_config.sh

# Create flanneld directory.
for flanneld_node in ${hosts[@]}
  do
   if [ ${flanneld_node} != ${hosts['gysl-master']} ];then
     ssh root@${flanneld_node} "rm -rf ${flanneld_conf} && mkdir -p ${flanneld_conf}"
   fi
  done

etcdctl \
--ca-file=${etcd_ca}/ca.pem --cert-file=${etcd_ca}/server.pem --key-file=${etcd_ca}/server-key.pem \
--endpoints="https://${etcd['etcd-master']}:2379,https://${etcd['etcd-01']}:2379,https://${etcd['etcd-02']}:2379" \
set /coreos.com/network/config  '{ "Network": "172.20.0.0/16", "Backend": {"Type": "vxlan"}}'
for node_ip in ${hosts[@]};
 do
   if [ "${node_ip}" != "${hosts[gysl-master]}" ] ; then
     scp temp/{flanneld,mk-docker-opts.sh} root@${node_ip}:${bin}/
     scp temp/flanneld.conf root@${node_ip}:${flanneld_conf}/
     scp temp/flanneld.service root@${node_ip}:/usr/lib/systemd/system/flanneld.service
     ssh root@${node_ip} "pkill flanneld"
     # Modify the docker service.
     ssh root@${node_ip} "sed -i '/EnvironmentFile/d' /usr/lib/systemd/system/docker.service"
     ssh root@${node_ip} "sed -i.bak_$(date +%d%H%M) '/ExecStart/i EnvironmentFile=\/run\/flannel\/subnet.env' /usr/lib/systemd/system/docker.service"
     ssh root@${node_ip} "sed -i 's#ExecStart=/usr/bin/dockerd -H#ExecStart=/usr/bin/dockerd \$DOCKER_NETWORK_OPTIONS -H#g' /usr/lib/systemd/system/docker.service"
     ssh root@${node_ip} "systemctl daemon-reload && systemctl enable flanneld --now && systemctl restart docker && systemctl status flanneld && systemctl status docker"
    fi
  done