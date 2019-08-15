#!/bin/bash
#===============================================================================
#          FILE: kubeadm-install-02.sh
#         USAGE: . ${YOUR_PATH}/kubeadm-install-02.sh 
#   DESCRIPTION: 
#        AUTHOR: IVAN DU
#        E-MAIL: mrivandu@hotmail.com
#        WECHAT: ecsboy
#      TECHBLOG: https://ivandu.blog.csdn.net
#        GITHUB: https://github.com/mrivandu
#       CREATED: 2019-08-14 13:01:20
#       LICENSE: GNU General Public License.
#     COPYRIGHT: © IVAN DU 2019
#      REVISION: v1.0
#===============================================================================

declare -A hosts
hosts=( [master-01]='172.31.3.20' [node-01]='172.31.3.21' [node-02]='172.31.3.22' )

# Install kubernetes repo.
cat>/etc/yum.repos.d/kubernetes.repo<<EOF
[kubernetes]
name=Kubernetes
baseurl=https://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://mirrors.aliyun.com/kubernetes/yum/doc/yum-key.gpg https://mirrors.aliyun.com/kubernetes/yum/doc/rpm-package-key.gpg
EOF

# Install kubeadm in each machine. The number of available CPUs are not less than the required 2.
yum install -y kubeadm-1.15.2-0 --disableexcludes=kubernetes
systemctl enable kubelet.service --now

# Load images.
tar -xvzf kubernetes.tar.gz
# for image in `docker images|awk 'NR>1{print $1":"$2}'`;do docker save ${image} -o `echo ${image}|awk -F "/" '{print $2}'|sed "s#:#-#g"`.tar;done
for image in `ls pkgs`;do docker load -i pkgs/${image};done

# docker pull registry.cn-hangzhou.aliyuncs.com/google_containers/etcd-amd64:3.3.10
# docker pull registry.cn-hangzhou.aliyuncs.com/google_containers/pause:3.1
# docker pull registry.cn-hangzhou.aliyuncs.com/google_containers/coredns:1.3.1
# docker pull quay-mirror.qiniu.com/coreos/flannel:v0.11.0-amd64

# docker tag registry.cn-hangzhou.aliyuncs.com/google_containers/etcd-amd64:3.3.10 k8s.gcr.io/etcd:3.3.10
# docker tag registry.cn-hangzhou.aliyuncs.com/google_containers/pause:3.1 k8s.gcr.io/pause:3.1
# docker tag registry.cn-hangzhou.aliyuncs.com/google_containers/coredns:1.3.1 k8s.gcr.io/coredns:1.3.1
# docker tag quay-mirror.qiniu.com/coreos/flannel:v0.11.0-amd64 quay.io/coreos/flannel:v0.11.0-amd64

# docker rmi registry.cn-hangzhou.aliyuncs.com/google_containers/coredns:1.3.1
# docker rmi registry.cn-hangzhou.aliyuncs.com/google_containers/etcd-amd64:3.3.10
# docker rmi registry.cn-hangzhou.aliyuncs.com/google_containers/pause:3.1
# docker rmi quay-mirror.qiniu.com/coreos/flannel:v0.11.0-amd64

# Create a configmap in master node and init master node.
ip=`ip a|grep eth0|grep inet|awk -F "/" '{print $1}'|egrep -o "([0-9]{1,3}\.){3}[0-9]{1,}"`
if [[ ${ip} == ${hosts['master-01']} ]]; then
    cat>kubeadm.yaml<<EOF
apiVersion: kubeadm.k8s.io/v1beta2
kind: InitConfiguration
localAPIEndpoint:
  advertiseAddress: ${hosts['master-01']}
  bindPort: 6443
nodeRegistration:
  criSocket: /var/run/dockershim.sock
  name: master-01
  taints:
  - effect: NoSchedule
    key: node-role.kubernetes.io/master
---
apiServer:
  timeoutForControlPlane: 4m0s
apiVersion: kubeadm.k8s.io/v1beta2
certificatesDir: /etc/kubernetes/pki
clusterName: kubernetes
controllerManager: {}
dns:
  type: CoreDNS
etcd:
  local:
    dataDir: /var/lib/etcd
imageRepository: k8s.gcr.io
kind: ClusterConfiguration
kubernetesVersion: v1.15.2
networking:
  dnsDomain: cluster.local
  serviceSubnet: 10.96.0.0/12
  podSubnet: 10.10.0.0/16
scheduler: {}
EOF
kubeadm init --config kubeadm.yaml
# kubeadm init --kubernetes-version=1.15.2 --pod-network-cidr=192.168.0.0/16 --apiserver-advertise-address=172.31.3.20
    fi
mkdir -p $HOME/.kube
cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config

You should now deploy a pod network to the cluster.
Run "kubectl apply -f [podnetwork].yaml" with one of the options listed at:
  https://kubernetes.io/docs/concepts/cluster-administration/addons/

# Then you can join any number of worker nodes by running the following on each as root:

kubeadm join 172.31.3.20:6443 --token lycwdt.edpjdpq35tjzdn4n \
    --discovery-token-ca-cert-hash sha256:efcf57b1327e369f363ba7c37723c8463499c6a4716ad8f0e23f3c0619066cc2

kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml


# Config file with 'kubectl -n kube-system get cm kubeadm-config -oyaml'
# kubelet configuration to file "/var/lib/kubelet/config.yaml"
# kubelet environment file with flags to file "/var/lib/kubelet/kubeadm-flags.env"

kubectl label node node-01 node-role.kubernetes.io/node='node'
kubectl label node node-02 node-role.kubernetes.io/node='node'

kubectl edit cm kube-proxy -n kube-system
kubectl get pod -n kube-system | grep kube-proxy | awk '{system("kubectl delete pod "$1" -n kube-system")}'
kubectl logs kube-proxy-74wsh  -n kube-system

I0814 04:28:54.333058       1 server_others.go:170] Using ipvs Proxier.
W0814 04:28:54.333667       1 proxier.go:401] IPVS scheduler not specified, use rr by default
I0814 04:28:54.333974       1 server.go:534] Version: v1.15.2
I0814 04:28:54.346782       1 conntrack.go:52] Setting nf_conntrack_max to 131072
I0814 04:28:54.348435       1 config.go:187] Starting service config controller
I0814 04:28:54.348463       1 controller_utils.go:1029] Waiting for caches to sync for service config controller
I0814 04:28:54.348499       1 config.go:96] Starting endpoints config controller
I0814 04:28:54.348511       1 controller_utils.go:1029] Waiting for caches to sync for endpoints config controller
I0814 04:28:54.448853       1 controller_utils.go:1036] Caches are synced for endpoints config controller
I0814 04:28:54.449094       1 controller_utils.go:1036] Caches are synced for service config controller

ls /usr/lib/modules/$(uname -r)/kernel/net/netfilter/ipvs/ |grep  -e ip_vs

apiServer:
  extraArgs:
    authorization-mode: Node,RBAC
  timeoutForControlPlane: 4m0s
apiVersion: kubeadm.k8s.io/v1beta2
certificatesDir: /etc/kubernetes/pki
clusterName: kubernetes
controllerManager: {}
dns:
  type: CoreDNS
etcd:
  local:
    dataDir: /var/lib/etcd
imageRepository: k8s.gcr.io
kind: ClusterConfiguration
kubernetesVersion: v1.15.2
networking:
  dnsDomain: cluster.local
  podSubnet: 10.88.0.0/16
  serviceSubnet: 10.96.0.0/12
scheduler: {}


kubeadm config print init-defaults
apiVersion: kubeadm.k8s.io/v1beta2
bootstrapTokens:
- groups:
  - system:bootstrappers:kubeadm:default-node-token
  token: abcdef.0123456789abcdef
  ttl: 24h0m0s
  usages:
  - signing
  - authentication
kind: InitConfiguration
localAPIEndpoint:
  advertiseAddress: 1.2.3.4
  bindPort: 6443
nodeRegistration:
  criSocket: /var/run/dockershim.sock
  name: master-01
  taints:
  - effect: NoSchedule
    key: node-role.kubernetes.io/master
---
apiServer:
  timeoutForControlPlane: 4m0s
apiVersion: kubeadm.k8s.io/v1beta2
certificatesDir: /etc/kubernetes/pki
clusterName: kubernetes
controllerManager: {}
dns:
  type: CoreDNS
etcd:
  local:
    dataDir: /var/lib/etcd
imageRepository: k8s.gcr.io
kind: ClusterConfiguration
kubernetesVersion: v1.14.0
networking:
  dnsDomain: cluster.local
  serviceSubnet: 10.96.0.0/12
scheduler: {}


kubeadm config print join-defaults