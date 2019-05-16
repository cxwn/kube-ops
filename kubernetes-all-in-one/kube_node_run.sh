#!/bin/bash
#===============================================================================
#          FILE: kube_node_run.sh
#         USAGE: . ${YOUR_PATH}/kube_node_run.sh 
#   DESCRIPTION: 
#        AUTHOR: IVAN DU
#        E-MAIL: mrivandu@hotmail.com
#        WECHAT: ecsboy
#      TECHBLOG: https://ivandu.blog.csdn.net
#        GITHUB: https://github.com/mrivandu
#       CREATED: 2019-05-16 16:02:32
#       LICENSE: GNU General Public License.
#     COPYRIGHT: © IVAN DU 2019
#      REVISION: v1.0
#===============================================================================

. kube_config.sh
for hostname in ${!node[@]};
    do
        cat>>/etc/hosts<<EOF
${node[${hostname}]} ${hostname}
EOF
    done
read -p "Do you need init your system and install docker-engine?(Y/n)" affirm 
if [[ "${affirm}" == 'y' || "${affirm}" == 'Y' ]]; then
    echo "The system is initializing and installing docker-engine. Please waite a moment."
    curl http://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo -o /etc/yum.repos.d/docker-ce.repo>&/dev/null
if [ $? -eq 0 ] ;
    then
        yum remove docker \
                      docker-client \
                      docker-client-latest \
                      docker-common \
                      docker-latest \
                      docker-latest-logrotate \
                      docker-logrotate \
                      docker-selinux \
                      docker-engine-selinux \
                      docker-engine>&/dev/null
        yum list docker-ce --showduplicates|grep "^doc"|sort -r
        yum -y install docker-ce-18.09.5-3.el7
        rm -f /etc/yum.repos.d/docker-ce.repo
        systemctl enable docker --now && systemctl status docker
    else
        echo "Install failed! Please try again! ";
        exit 110
fi
# Modify related kernel parameters.
cat>/etc/sysctl.d/docker.conf<<EOF
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
sysctl -p /etc/sysctl.d/docker.conf>&/dev/null
# Turn off and disable the firewalld.  
systemctl stop firewalld  
systemctl disable firewalld  
# Disable the SELinux.  
sed -i.bak 's/=enforcing/=disabled/' /etc/selinux/config  
# Disable the swap.  
sed -i.bak 's/^.*swap/#&/g' /etc/fstab
reboot
