#!/bin/bash
#===============================================================================
#          FILE: kubeadm-install-01.sh
#         USAGE: . ${YOUR_PATH}/kubeadm-install-01.sh 
#   DESCRIPTION: 
#        AUTHOR: IVAN DU
#        E-MAIL: mrivandu@hotmail.com
#        WECHAT: ecsboy
#      TECHBLOG: https://ivandu.blog.csdn.net
#        GITHUB: https://github.com/mrivandu
#       CREATED: 2019-08-13 18:02:00
#       LICENSE: GNU General Public License.
#     COPYRIGHT: © IVAN DU 2019
#      REVISION: v1.0
#===============================================================================

declare -A hosts
hosts=( [master-01]='172.31.3.20' [node-01]='172.31.3.21' [node-02]='172.31.3.22' )
docker_version='18.09.8-3.el7' # Just support to v18.09.

# IPv6 and systemd configuration.
        [ ! -d /etc/docker ] && mkdir /etc/docker
        cat>/etc/docker/daemon.json<<EOF
{
  "registry-mirrors": ["http://f1361db2.m.daocloud.io"],
  "exec-opts": ["native.cgroupdriver=systemd"]
}
EOF

# Configure ip_vs.
cat > /etc/sysconfig/modules/ipvs.modules <<EOF
#!/bin/bash
modprobe -- ip_vs
modprobe -- ip_vs_rr
modprobe -- ip_vs_wrr
modprobe -- ip_vs_sh
modprobe -- nf_conntrack_ipv4
EOF
chmod 755 /etc/sysconfig/modules/ipvs.modules && bash /etc/sysconfig/modules/ipvs.modules && lsmod | grep -e ip_vs -e nf_conntrack_ipv4

# Install docker engine.
curl http://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo -o /etc/yum.repos.d/docker-ce.repo>&/dev/null
yum -y remove docker \
            docker-ce \
            docker-client \
            docker-client-latest \
            docker-common \
            docker-latest \
            docker-latest-logrotate \
            docker-logrotate \
            docker-selinux \
            docker-ce-cli \
            docker-engine-selinux \
            docker-engine>&/dev/null
# yum list docker-ce --showduplicates|grep "^doc"|sort -r
yum -y install docker-ce-${docker_version}
[ $? -eq 0 ] && rm -f /etc/yum.repos.d/docker-ce.repo

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
systemctl enable docker --now && systemctl status docker

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

# Turn off and disable the firewalld.  
systemctl stop firewalld  
systemctl disable firewalld  

# Disable the SELinux.  
sed -i.bak 's/=enforcing/=disabled/' /etc/selinux/config  

# Disable the swap.  
sed -i.bak 's/^.*swap/#&/g' /etc/fstab
reboot