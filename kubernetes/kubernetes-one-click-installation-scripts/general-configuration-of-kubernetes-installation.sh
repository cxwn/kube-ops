#!/bin/bash
declare -A HostIP EtcdIP
HostIP=( [gysl-master]='10.1.1.60' [gysl-node1]='10.1.1.61' [gysl-node2]='10.1.1.62' [gysl-node3]='10.1.1.63' )
EtcdIP=( [etcd-master]='10.1.1.60' [etcd-01]='10.1.1.61' [etcd-02]='10.1.1.62' [etcd-03]='10.1.1.63' )
BinaryDir='/usr/local/bin'
KubeConf='/etc/kubernetes/conf.d'
KubeCA='/etc/kubernetes/ca.d'
EtcdConf='/etc/etcd/conf.d'
EtcdCA='/etc/etcd/ca.d'
FlanneldConf='/etc/flanneld'

mkdir -p {${KubeConf},${KubeCA},${EtcdConf},${EtcdCA},${FlanneldConf}}
for hostname in ${!HostIP[@]}
    do
        cat>>/etc/hosts<<EOF
${HostIP[${hostname}]} ${hostname}
EOF
    done