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
for node_ip in ${HostIP[@]}
    do
        if [ "${node_ip}" == "${HostIP[gysl-master]}" ] ; then
            ps -ef|grep -e kube -e etcd -e flanneld|grep -v grep|awk '{print $2}'|xargs kill 
            rm -rf {${KubeConf},${KubeCA},${EtcdConf},${EtcdCA},${FlanneldConf}}
            rm -rf ${BinaryDir}/*
        else
            ssh root@${node_ip} "ps -ef|grep -e kube -e etcd -e flanneld|grep -v grep|awk '{print $2}'|xargs kill"
            ssh root@${node_ip} "rm -rf {${KubeConf},${KubeCA},${EtcdConf},${EtcdCA},${FlanneldConf}}"
            ssh root@${node_ip} "rm -rf ${BinaryDir}/* && reboot"
        fi
    done
reboot