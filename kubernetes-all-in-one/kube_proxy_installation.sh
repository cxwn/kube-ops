

KUBE_CONF=/etc/kubernetes
KUBE_SSL=$KUBE_CONF/ssl
IP=172.31.2.13
mkdir $KUBE_SSL
scp temp/kubernetes-v1.15.0-linux-amd64-2/{kube-proxy,kubelet} root@${kube_node_ip}:${bin}/
scp ${kube_ca}/{bootstrap.kubeconfig,kube-proxy.kubeconfig} root@${kube_node_ip}:${kube_ca}/



systemctl daemon-reload
systemctl enable kubelet.service --now && systemctl status kubelet.service -l