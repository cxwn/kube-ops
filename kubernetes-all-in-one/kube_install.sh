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

# Check swap configuration.
[ -z "$(free -h|grep '^Swap')" ] || [ $(free -h|awk 'NR==3{print $2}') == '0B' ] && echo "The swap of your system swap is satisfactory."
[ -n "$(free -h|grep '^Swap')" ] && [ $(free -h|awk 'NR==3{print $2}') != '0B' ] && echo "The swap of your system swap is not satisfactory. Please check. " && exit 1

# Check SELinux configuration.
[ "$(getenforce)" == "Disabled" ] && echo "Your SElinux is not disabled. Please check. "
[ "$(getenforce)" != "Disabled" ] && echo "Your SElinux is not disabled. Please check. " && exit 2

# Check kernel parameters.
cat>/etc/sysctl.d/temp.conf<<EOF
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
[ $? -eq 0 ] && cmp /etc/sysctl.d/docker.conf /etc/sysctl.d/temp.conf && [ $? -eq 0 ] && echo "Your system kernel parameters were configuration successfully. " && rm -f /etc/sysctl.d/temp.conf 
[ $? -ne 0 ] && echo "Your kernel parameters failed. Please check." && exit 3

# Check firewalld.
[ $(systemctl status firewalld|grep Loaded|awk -F ";" '{print $2}'|sed 's/\s//g') == 'disabled' ] && echo "Your firewalld was disabled."
[ $? -ne 0] && echo "Your firewalld was not disabled. Please check again. " && exit 4
[ $(systemctl status firewalld|grep Active|grep -o 'dead') != 'dead' ] && echo "Your firewalld was not inactive. Plaese check again. " && exit 4

# Check docker-engine.
