#!/bin/bash
#===============================================================================
#          FILE: offline_install_docker.sh
#         USAGE: . ${YOUR_PATH}/offline_install_docker.sh 
#   DESCRIPTION: 
#        AUTHOR: IVAN DU
#        E-MAIL: mrivandu@hotmail.com
#        WECHAT: ecsboy
#      TECHBLOG: https://ivandu.blog.csdn.net
#        GITHUB: https://github.com/mrivandu
#       CREATED: 2019-06-13 18:26:03
#       LICENSE: GNU General Public License.
#     COPYRIGHT: © IVAN DU 2019
#      REVISION: v1.0
#===============================================================================

while true;
do
    read -p "Do you need init your system and install docker-engine?(Y/n)" affirm
    if [[ "${affirm}" == 'y' || "${affirm}" == 'Y' ]];
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
# Create a local repo_file.
        [ -d temp ] && rm -rf temp && mkdir temp
        [ ! -d temp ] && mkdir temp
        mv /etc/yum.repos.d/* temp
        cat>/etc/yum.repos.d/docker-ce.repo<<EOF
[docker]
name=docker
baseurl=file://${PWD}/docker
gpgcheck=0                     
enabled=1                      
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7
EOF
# Turn off and disable the firewalld.
        systemctl stop firewalld
        systemctl disable firewalld
# Disable the SELinux.
        sed -i.bak 's/=enforcing/=disabled/' /etc/selinux/config
        echo "The system is initializing and installing docker-engine. Please waite a moment."
# Install the createrepo.
        for rp in `cat ${PWD}/createrepo_pkgs.txt`;
        do
            rpm -Uvh ${PWD}/createrepo/${rp}
        done
        [ $? -eq 0 ] && createrepo  ${PWD}/docker
        yum makecache
# Install the docker engine.
        while true;
        do
                yum -y install docker-ce-18.06.2.ce-3.el7
                if [ $? -ne 0 ];
                    then
                        continue
                else
                        systemctl start docker>&/dev/null
                        [ $? -eq 0 ] && echo "Install successfully. " && rm -f /etc/yum.repos.d/docker-ce.repo && mv temp/* /etc/yum.repos.d/ && break 2
                fi
        done
    elif [[  "${affirm}" == 'N' || "${affirm}" == 'n' ]];
    then
        echo 'Your system and docker-engine will not be modify! '
        break
    else
        echo 'Your input is wrong. Please check! '
        continue
    fi
    done
systemctl enable docker --now
rm -rf temp docker createrepo_pkgs.txt docker_offline_install.tar.gz createrepo
reboot

