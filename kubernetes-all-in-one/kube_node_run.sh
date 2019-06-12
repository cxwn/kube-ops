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
echo "${master[${gysl-master}]} ${hostname}">>/etc/hosts
echo "Modify hosts file of node successfully. "
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
EOF
        sysctl -p /etc/sysctl.d/docker.conf>&/dev/null
# Turn off and disable the firewalld.  
        systemctl stop firewalld  
        systemctl disable firewalld  
# Disable the SELinux.  
        sed -i.bak 's/=enforcing/=disabled/' /etc/selinux/config  
# Disable the swap.  
        sed -i.bak 's/^.*swap/#&/g' /etc/fstab
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
echo "Your system will reboot. "
sleep 10
reboot
exit 0