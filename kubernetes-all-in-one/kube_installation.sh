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
            sed "4,9s/${etcd['etcd-master']}/${node_ip}/g" ${etcd_conf}/etcd.conf>temp/etcd.conf
            scp temp/etcd.conf root@${node_ip}:${etcd_conf}/etcd.conf
            ssh ${node_ip} "rm -rf /var/lib/etcd/default.etcd/*"
            ssh root@${node_ip} "systemctl daemon-reload && systemctl enable etcd.service --now && systemctl status etcd -l"
          fi
        done
    elif [ "${node_ip}" == "${hosts[gysl-master]}" ] ; then
      rm -rf /var/lib/etcd/default.etcd/*
      systemctl daemon-reload && systemctl enable etcd.service --now && systemctl status etcd -l
    fi
  done

