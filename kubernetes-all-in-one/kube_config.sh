#!/bin/bash
#===============================================================================
#          FILE: kube_config.sh
#         USAGE: . ${YOUR_PATH}/kube_config.sh 
#   DESCRIPTION: 
#        AUTHOR: IVAN DU
#        E-MAIL: mrivandu@hotmail.com
#        WECHAT: ecsboy
#      TECHBLOG: https://ivandu.blog.csdn.net
#        GITHUB: https://github.com/mrivandu
#       CREATED: 2019-06-16 15:30:20
#       LICENSE: GNU General Public License.
#     COPYRIGHT: © IVAN DU 2019
#      REVISION: v1.0
#===============================================================================

declare -A hosts etcd
kube_version='v1.15.0'
etcd_version='v3.3.13'
flannel_version='v0.11.0'
coredns_version='v1.5.0'
docker_version='18.09.6-3.el7'
hosts=( [gysl-master]='172.31.2.10' [gysl-node1]='172.31.2.11' [gysl-node2]='172.31.2.12' )
etcd=( [etcd-master]='172.31.2.10' [etcd-01]='172.31.2.11' [etcd-02]='172.31.2.12' )
etcd_conf='/etc/etcd/conf.d'
etcd_ca='/etc/etcd/ca.d'
kube_conf='/etc/kubernetes/conf.d'
kube_ca='/etc/kubernetes/ca.d'
flanneld_conf='/etc/flanneld.d'
bin='/usr/local/bin'