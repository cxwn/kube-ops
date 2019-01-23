#!/bin/bash
# Install the Docker engine. This needs to be executed on every machine.
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
        yum -y install docker-ce-18.06.0.ce-3.el7
        systemctl enable docker && systemctl start docker
        rm -f /etc/yum.repos.d/docker-ce.repo
        systemctl status docker
    else
        echo "Install failed! Please try again! ";
        exit 110
fi