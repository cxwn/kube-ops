#!/bin/bash
#===============================================================================
#          FILE: etcd_cluster_installation.sh
#         USAGE: . ${YOUR_PATH}/etcd_cluster_installation.sh
#   DESCRIPTION: 
#        AUTHOR: IVAN DU
#        E-MAIL: mrivandu@hotmail.com
#        WECHAT: ecsboy
#      TECHBLOG: https://ivandu.blog.csdn.net
#        GITHUB: https://github.com/mrivandu
#       CREATED: 2019-06-29 12:05:26
#       LICENSE: GNU General Public License.
#     COPYRIGHT: © IVAN DU 2019
#      REVISION: v1.0
#===============================================================================

## Deploy the etcd cluster.
. kube_config.sh
. modules/create_etcd_ca.sh
. modules/create_etcd_config.sh

pkill etcd
for node_ip in ${etcd[@]}
  do  
    if [ "${node_ip}" != "${hosts[gysl-master]}" ] ; then
      scp kube_config.sh root@${node_ip}:/tmp/
      scp modules/init.sh root@${node_ip}:/tmp/
      ssh root@${node_ip} "sed -i 's/^\./#&/g' /tmp/init.sh;pkill etcd"
      ssh root@${node_ip} ". /tmp/kube_config.sh && . /tmp/init.sh"
      scp -p ${etcd_ca}/{ca*pem,server*pem} root@${node_ip}:${etcd_ca}
      scp -p temp/etcd-v3.3.13-linux-amd64/{etcd,etcdctl} root@${node_ip}:${bin}/
      scp -p /usr/lib/systemd/system/etcd.service root@${node_ip}:/usr/lib/systemd/system/etcd.service
      for etcd_name in ${!etcd[@]}
        do
          if [ "${node_ip}" == "${etcd[${etcd_name}]}" ] ; then
            ssh ${node_ip} "[ -f ${etcd_conf}/etcd.conf ] && rm -f ${etcd_conf}/etcd.conf"
            sed "/ETCD_NAME/{s/etcd-master/${etcd_name}/g}" ${etcd_conf}/etcd.conf>temp/etcd.conf
            sed -i "4,9s/${etcd['etcd-master']}/${node_ip}/g" temp/etcd.conf
            scp temp/etcd.conf root@${node_ip}:${etcd_conf}/etcd.conf
            ssh ${node_ip} "rm -rf /var/lib/etcd/default.etcd/*"
            ssh root@${node_ip} "systemctl daemon-reload && systemctl enable etcd.service --now && systemctl restart etcd.service && systemctl status etcd -l"
          fi
        done
    elif [ "${node_ip}" == "${hosts[gysl-master]}" ] ; then
      rm -rf /var/lib/etcd/default.etcd/*
    fi
  done
sleep 10
systemctl daemon-reload && systemctl enable etcd.service --now && systemctl restart etcd.service && systemctl status etcd -l
etcdctl \
--ca-file=${etcd_ca}/ca.pem \
--cert-file=${etcd_ca}/server.pem \
--key-file=${etcd_ca}/server-key.pem \
--endpoints="https://${etcd['etcd-master']}:2379,https://${etcd['etcd-01']}:2379,https://${etcd['etcd-02']}:2379" cluster-health ## Note
[ $? -eq 0 ] && sleep 20
if [ $? -eq 0 ];then
  echo "Etcd cluster has been successfully deployed. "
else
  echo "Etcd cluster has not been successfully deployed. Plaese check. "
  exit 1
fi
sleep 10