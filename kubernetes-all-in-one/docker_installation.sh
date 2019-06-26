#!/bin/bash
#===============================================================================
#          FILE: docker_installation.sh
#         USAGE: . ${YOUR_PATH}/docker_installation.sh 
#   DESCRIPTION: 
#        AUTHOR: IVAN DU
#        E-MAIL: mrivandu@hotmail.com
#        WECHAT: ecsboy
#      TECHBLOG: https://ivandu.blog.csdn.net
#        GITHUB: https://github.com/mrivandu
#       CREATED: 2019-06-26 16:02:00
#       LICENSE: GNU General Public License.
#     COPYRIGHT: © IVAN DU 2019
#      REVISION: v1.0
#===============================================================================

. kube_config.sh
read -p "Do you need init your system and install docker-engine?(Y/n)" affirm
while true;
do 
    if [[ "${affirm}"=='y' || "${affirm}"=='Y' ]]; 
       then

# Modify related kernel parameters.
       cat>/etc/sysctl.d/docker.conf<<EOF
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv6.conf.all.disable_ipv6 = 0
net.ipv6.conf.default.forwarding = 1
net.ipv6.conf.all.forwarding = 1
EOF
        sysctl -p /etc/sysctl.d/docker.conf>&/dev/null

# IPv6 configuration.
        [ ! -d /etc/docker ] && mkdir /etc/docker
        cat>/etc/docker/daemon.json<<EOF
{
  "ipv6": true,
  "fixed-cidr-v6": "2001:db8:1::/64"
}
EOF
        echo "The system is initializing and installing docker-engine. Please waite a moment."
        curl http://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo -o /etc/yum.repos.d/docker-ce.repo>&/dev/null
        while true;
        do
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
#        yum list docker-ce --showduplicates|grep "^doc"|sort -r
                yum -y install docker-ce-${docker_version}
                [ $? -eq 0 ] && rm -f /etc/yum.repos.d/docker-ce.repo
                systemctl enable docker --now && systemctl status docker
                if [ $? -eq 0 ]; 
                    then
                    echo "Install and start docker.servie successfully. " && break 2
                else
                    echo 'Install or start docker.service failed! Please try again! '
                    continue
                fi
        done
    elif [[  "${affirm}"=='n' || "${affirm}"=='N' ]];
    then
        echo 'Your system and docker-engine will not be modify! '
        break
    else
        echo 'Your input is wrong. Please check! '
        continue
    fi
done

# Turn off and disable the firewalld.  
systemctl stop firewalld  
systemctl disable firewalld  

# Disable the SELinux.  
sed -i.bak 's/=enforcing/=disabled/' /etc/selinux/config  

# Disable the swap.  
sed -i.bak 's/^.*swap/#&/g' /etc/fstab

# Reboot the machine.  
reboot
