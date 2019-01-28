#!/bin/bash
# Initialize the machine. This needs to be executed on every machine.
# Add host domain name.
cat>>/etc/hosts<<EOF
172.31.2.11 gysl-master
172.31.2.12 gysl-node1
172.31.2.13 gysl-node2
EOF

# Modify related kernel parameters.
cat>/etc/sysctl.d/kubernetes.conf<<EOF
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
sysctl -p /etc/sysctl.d/kubernetes.conf>&/dev/null

# Turn off and disable the firewalld.
systemctl stop firewalld
systemctl disable firewalld

# Disable the SELinux.
sed -i 's/=enforcing/=disabled/' /etc/selinux/config

# Disable the swap.
sed -i 's/^.*swap/#&/g' /etc/fstab

# Reboot the machine.
reboot