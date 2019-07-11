#!/bin/bash
#===============================================================================
#          FILE: coredns_installation.sh
#         USAGE: . ${YOUR_PATH}/coredns_installation.sh 
#   DESCRIPTION: 
#        AUTHOR: IVAN DU
#        E-MAIL: mrivandu@hotmail.com
#        WECHAT: ecsboy
#      TECHBLOG: https://ivandu.blog.csdn.net
#        GITHUB: https://github.com/mrivandu
#       CREATED: 2019-07-11 18:02:00
#       LICENSE: GNU General Public License.
#     COPYRIGHT: © IVAN DU 2019
#      REVISION: v1.0
#===============================================================================

yum -y install epel-release>&/dev/null
yum -y install jq>&/dev/null
kubectl delete serviceaccount coredns>&/dev/null
kubectl delete clusterrole.rbac.authorization.k8s.io system:coredns --namespace=kube-system>&/dev/null
kubectl delete clusterrolebinding.rbac.authorization.k8s.io system:coredns --namespace=kube-system>&/dev/null
kubectl delete configmap coredns --namespace=kube-system>&/dev/null
kubectl delete deployment.apps coredns --namespace=kube-system>&/dev/null
kubectl delete service kube-dns --namespace=kube-system>&/dev/null
bash modules/deploy_coredns.sh -r 10.0.0.0/24 -i 10.0.0.2 -d cluster.local. -t modules/coredns.yaml | kubectl apply -f -
