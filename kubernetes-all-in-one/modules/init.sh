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

. kube_config.sh

# mkdir some directorys.
for dir in {${etcd_conf},${etcd_ca},${kube_conf},${kube_ca},${bin}};
  do
    [ -d ${dir} ] && rm -rf ${dir}/*
  done
mkdir -p {${etcd_conf},${etcd_ca},${kube_conf},${kube_ca}}

# Add the hostnames.
for node_ip in ${hosts[@]}
  do
    sed -i "/${node_ip}/d" /etc/hosts
  done

for hostname in ${!hosts[@]}
  do
    cat>>/etc/hosts<<EOF
${hosts["${hostname}"]} ${hostname}
EOF
  done

for flanneld_node in ${hosts[@]}
  do
   if [ ${flanneld_node} != ${hosts['gysl-master']} ];then
     rm -rf ${flanneld_conf} && mkdir -p ${flanneld_conf}
   fi
  done