#!/bin/bash
#===============================================================================
#          FILE: kube_install.sh
#         USAGE: . ${YOUR_PATH}/kube_install.sh 
#   DESCRIPTION: 
#        AUTHOR: IVAN DU
#        E-MAIL: mrivandu@hotmail.com
#        WECHAT: ecsboy
#      TECHBLOG: https://ivandu.blog.csdn.net
#        GITHUB: https://github.com/mrivandu
#       CREATED: 2019-06-26 17:05:26
#       LICENSE: GNU General Public License.
#     COPYRIGHT: © IVAN DU 2019
#      REVISION: v1.0
#===============================================================================

# cd kubernetes-all-in-one

. kube_config.sh
. modules/init.sh
. modules/no_passwd_login.sh
. modules/unzip_pkgs.sh

# Copy the binary to the master destination diretory. 
rm -rf ${bin}/*
cp temp/cfssl-tools/* ${bin}/
cp temp/kubernetes-v1.15.0-linux-amd64-1/* ${bin}/
cp temp/etcd-v3.3.13-linux-amd64/{etcd,etcdctl} ${bin}/

## Deploy the etcd cluster.
. modules/create_etcd_ca.sh
. modules/create_etcd_config.sh

pkill etcd
for node_ip in ${etcd[@]}
  do  
    if [ "${node_ip}" != "${hosts[gysl-master]}" ] ; then
      scp kube_config.sh root@${node_ip}:/tmp/
      scp modules/init.sh root@${node_ip}:/tmp/
      ssh root@${node_ip} "sed -i 's/^\./#&/g' /tmp/init.sh"
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
--endpoints="https://${etcd['etcd-master']}:2379,https://${etcd['etcd-01']}:2379,https://${etcd['etcd-02']}:2379" cluster-health
[ $? -eq 0 ] && sleep 20
if [ $? -eq 0 ];then
  echo "Etcd cluster has been successfully deployed. "
else
  echo "Etcd cluster has not been successfully deployed. Plaese check. "
  exit 1
fi
sleep 10

# Deployment flanneld.
. modules/create_flanneld_config.sh

cd ${etcd_ca}
etcdctl \
--ca-file=ca.pem --cert-file=server.pem --key-file=server-key.pem \
--endpoints="https://${etcd['etcd-master']}:2379,https://${etcd['etcd-01']}:2379,https://${etcd['etcd-02']}:2379" \
set /coreos.com/network/config  '{ "Network": "172.17.0.0/16", "Backend": {"Type": "vxlan"}}'
cd -
for node_ip in ${hosts[@]};
 do
   if [ "${node_ip}" != "${hosts[gysl-master]}" ] ; then
     scp temp/{flanneld,mk-docker-opts.sh} root@${node_ip}:${bin}/
     scp temp/flanneld.conf root@${node_ip}:${flanneld_conf}/
     scp temp/flanneld.service root@${node_ip}:/usr/lib/systemd/system/flanneld.service
     # Modify the docker service.
     ssh root@${node_ip} "sed -i '/ExecStart/d' /usr/lib/systemd/system/docker.service"
     ssh root@${node_ip} "sed -i.bak_$(date +%d%H%M) '/ExecStart/i EnvironmentFile=\/run\/flannel\/subnet.env' /usr/lib/systemd/system/docker.service"
     ssh root@${node_ip} "sed -i 's#ExecStart=/usr/bin/dockerd -H#ExecStart=/usr/bin/dockerd \$DOCKER_NETWORK_OPTIONS -H#g' /usr/lib/systemd/system/docker.service"
     ssh root@${node_ip} "systemctl daemon-reload && systemctl enable flanneld --now && systemctl restart docker && systemctl status flanneld && systemctl status docker"
    fi
  done