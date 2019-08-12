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
bash modules/deploy_coredns.sh -r 10.0.0.0/24 -i 10.0.0.2 -d cluster.local -t modules/coredns.yaml | kubectl apply -f -

# If you deploy successfully. You can enter a container and you will see these:
# kubectl exec -it dns-tets-tools-6bf6db5c4f-nnp9p sh
# nslookup www.baidu.com
# Server:    10.0.0.2
# Address 1: 10.0.0.2 kube-dns.kube-system.svc.cluster.local
# Name:      www.baidu.com
# Address 1: 182.61.200.6
# Address 2: 182.61.200.7
# Some documents: https://github.com/kubernetes/dns/blob/master/docs/specification.md