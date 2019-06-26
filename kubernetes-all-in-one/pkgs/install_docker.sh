#!/bin/bash

# curl http://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo -o /etc/yum.repos.d/docker-ce.repo
# yum -y install --downloadonly --downloaddir=docker-ce-v18.09.6 docker-ce-18.09.6-3.el7
while true;do
  for pkg in `ls ~/docker-ce-v18.09.6`;do 
    rpm -ivh ~/docker-ce-v18.09.6/${pkg}
    systemctl enable docker --now
    if [ $? -eq 0 ] ;then
      break 2
    fi
  done
done