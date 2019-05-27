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
#       CREATED: 2019-05-16 17:05:26
#       LICENSE: GNU General Public License.
#     COPYRIGHT: © IVAN DU 2019
#      REVISION: v1.0
#===============================================================================

. kube_config.sh
[ -z "$(free -h|grep '^Swap')" ] && echo "The swap of your system swap is satisfactory."
[ -n "$(free -h|grep '^Swap')" ] && echo "The swap of your system swap is not satisfactory. Please check. " && exit 1
[ "$(getenforce)" == "Disabled" ] && echo "Your SElinux is not disabled. Please check. "
[ "$(getenforce)" != "Disabled" ] && echo "Your SElinux is not disabled. Please check. " && exit 2
sysctl net.ipv4.ip_forward && sysctl net.bridge.bridge-nf-call-ip6tables && sysctl net.bridge.bridge-nf-call-iptables
while true;
   do
   getenforce
