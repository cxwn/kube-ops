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
for dir in {${etcd_conf},${etcd_ca},${kube_conf},${kube_ca}};do
[ -d ${dir} ] && rm -rf ${dir}
done
rm -f /usr/lib/systemd/system/etcd.service
rm -rf ${bin}/*
sed -i '3,$d' /etc/hosts