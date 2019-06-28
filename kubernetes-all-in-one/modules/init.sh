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
mkdir -p {${etcd},${etcd_ca},${kube_conf},${kube_ca}}

# Add the hostnames.
for hostname in ${!hosts[@]}
  do
    cat>>/etc/hosts<<EOF
${hosts[${hostname}]} ${hostname}
EOF
  if [ ${hosts['gysl-master']} != ${hosts[${hostname}]} ];then
    mkdir -p ${flanneld_conf}
  fi
  done
