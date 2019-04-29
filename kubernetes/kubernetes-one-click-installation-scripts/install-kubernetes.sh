#!/bin/bash
declare -A HostIP EtcdIP
HostIP=( [gysl-master]='10.1.1.60' [gysl-node1]='10.1.1.61' [gysl-node2]='10.1.1.62' [gysl-node3]='10.1.1.63' )
EtcdIP=( [etcd-master]='10.1.1.60' [etcd-01]='10.1.1.61' [etcd-02]='10.1.1.62' [etcd-03]='10.1.1.63' )
WorkDir=~/KubernetesDeployment
BinaryDir='/usr/local/bin'
KubeConf='/etc/kubernetes/conf.d'
KubeCA='/etc/kubernetes/ca.d'
EtcdConf='/etc/etcd/conf.d'
EtcdCA='/etc/etcd/ca.d'
FlanneldConf='/etc/flanneld'
mkdir ${WorkDir}
cd ${WorkDir}

# Configure SSH Password-Free Login. 
ssh-keygen -b 1024 -t rsa -C 'Kubernetes'
for node_ip in ${HostIP[@]}
    do  
        if [ "${node_ip}" != "${HostIP[gysl-master]}" ] ; then
        ssh-copy-id -i root@${node_ip}
        fi
    done

# Download relevant softwares. Please verify sha512 yourself.
while true;
    do
        echo "Downloading... ... Please wait a moment! " && \
        curl -L -C - -O https://dl.k8s.io/v1.14.0/kubernetes-server-linux-amd64.tar.gz && \
        curl -L -C - -O https://github.com/etcd-io/etcd/releases/download/v3.3.12/etcd-v3.3.12-linux-amd64.tar.gz && \
        curl -L -C - -O https://pkg.cfssl.org/R1.2/cfssl_linux-amd64 && \
        curl -L -C - -O https://pkg.cfssl.org/R1.2/cfssljson_linux-amd64 && \
        curl -L -C - -O https://pkg.cfssl.org/R1.2/cfssl-certinfo_linux-amd64 && \
        curl -L -C - -O https://github.com/coreos/flannel/releases/download/v0.11.0/flannel-v0.11.0-linux-amd64.tar.gz
        if [ $? -eq 0 ];
            then
                echo "Congratulations! All software packages have been downloaded."
                break
            else
                echo "Downloading failed. Please try again!"
                exit 101
        fi
    done

# Unzip these package files. 
for tgz_file in `ls *.tar.gz`
    do
        tar -xvzf ${tgz_file}
done

# Modify permissions. Move related files to the specified directory on the management node.
chmod +x cfssl*
cp -p cfssl_linux-amd64 ${BinaryDir}/cfssl
cp -p cfssljson_linux-amd64 ${BinaryDir}/cfssljson
cp -p cfssl-certinfo_linux-amd64 ${BinaryDir}/cfssl-certinfo
cp -p kubernetes/server/bin/{kube-apiserver,kube-scheduler,kube-controller-manager,kubectl} ${BinaryDir}/
cp -p etcd-v3.3.12-linux-amd64/{etcd,etcdctl} ${BinaryDir}/

# Deploy the etcd cluster. 
## Create some CA certificates for etcd cluster.
cat>${EtcdCA}/ca-config.json<<EOF
{
  "signing": {
    "default": {
      "expiry": "87600h"
    },
    "profiles": {
      "www": {
         "expiry": "87600h",
         "usages": [
            "signing",
            "key encipherment",
            "server auth",
            "client auth"
        ]
      }
    }
  }
}
EOF

cat>${EtcdCA}/ca-csr.json<<EOF
{
    "CN": "etcd CA",
    "key": {
        "algo": "rsa",
        "size": 2048
    },
    "names": [
        {
            "C": "CN",
            "L": "Beijing",
            "ST": "Beijing"
        }
    ]
}
EOF

cat>${EtcdCA}/server-csr.json<<EOF
{
    "CN": "etcd",
    "hosts": [
    "${HostIP[gysl-master]}",
    "${HostIP[gysl-node1]}",
    "${HostIP[gysl-node2]}",
    "${HostIP[gysl-node3]}"
    ],
    "key": {
        "algo": "rsa",
        "size": 2048
    },
    "names": [
        {
            "C": "CN",
            "L": "Beijing",
            "ST": "Beijing"
        }
    ]
}
EOF

cd ${EtcdCA}
cfssl gencert -initca ca-csr.json | cfssljson -bare ca -
cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=www server-csr.json | cfssljson -bare server
cd ${WorkDir}
## Show files.
tree ${EtcdCA}

## The etcd configuration file.
cat>${EtcdConf}/etcd.conf<<EOF
#[Member]
ETCD_NAME="etcd-master"
ETCD_DATA_DIR="/var/lib/etcd/default.etcd"
ETCD_LISTEN_PEER_URLS="https://${HostIP[gysl-master]}:2380"
ETCD_LISTEN_CLIENT_URLS="https://${HostIP[gysl-master]}:2379"

#[Clustering]
ETCD_INITIAL_ADVERTISE_PEER_URLS="https://${HostIP[gysl-master]}:2380"
ETCD_ADVERTISE_CLIENT_URLS="https://${HostIP[gysl-master]}:2379"
ETCD_INITIAL_CLUSTER="etcd-master=https://${HostIP[gysl-master]}:2380,etcd-01=https://${HostIP[gysl-node1]}:2380,etcd-02=https://${HostIP[gysl-node2]}:2380,etcd-03=https://${HostIP[gysl-node3]}:2380"
ETCD_INITIAL_CLUSTER_TOKEN="etcd-cluster"
ETCD_INITIAL_CLUSTER_STATE="new"
EOF

## The etcd servcie configuration file.
cat>/usr/lib/systemd/system/etcd.service<<EOF
[Unit]
Description=Etcd Server
After=network.target
After=network-online.target
Wants=network-online.target

[Service]
Type=notify
EnvironmentFile=${EtcdConf}/etcd.conf
ExecStart=${BinaryDir}/etcd \\
--name=\${ETCD_NAME} \\
--data-dir=\${ETCD_DATA_DIR} \\
--listen-peer-urls=\${ETCD_LISTEN_PEER_URLS} \\
--listen-client-urls=\${ETCD_LISTEN_CLIENT_URLS},http://127.0.0.1:2379 \\
--advertise-client-urls=\${ETCD_ADVERTISE_CLIENT_URLS} \\
--initial-advertise-peer-urls=\${ETCD_INITIAL_ADVERTISE_PEER_URLS} \\
--initial-cluster=\${ETCD_INITIAL_CLUSTER} \\
--initial-cluster-token=\${ETCD_INITIAL_CLUSTER_TOKEN} \\
--initial-cluster-state=\${ETCD_INITIAL_CLUSTER_STATE} \\
--cert-file=${EtcdCA}/server.pem \\
--key-file=${EtcdCA}/server-key.pem \\
--peer-cert-file=${EtcdCA}/server.pem \\
--peer-key-file=${EtcdCA}/server-key.pem \\
--trusted-ca-file=${EtcdCA}/ca.pem \\
--peer-trusted-ca-file=${EtcdCA}/ca.pem
Restart=on-failure
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

## Copy some files to node for deploying etcd cluster.  
for node_ip in ${EtcdIP[@]}
  do  
    if [ "${node_ip}" != "${HostIP[gysl-master]}" ] ; then
      scp -p ${EtcdCA}/{ca*pem,server*pem} root@${node_ip}:${EtcdCA}
      scp -p etcd-v3.3.12-linux-amd64/{etcd,etcdctl} root@${node_ip}:${BinaryDir}/
      scp -p /usr/lib/systemd/system/etcd.service root@${node_ip}:/usr/lib/systemd/system/etcd.service
      for etcd_name in ${!EtcdIP[@]}
        do
          if [ "${node_ip}" == "${EtcdIP[${etcd_name}]}" ] ; then
            sed -e "2s/etcd-master/${etcd_name}/g" -e "4,9s/10.1.1.60/${node_ip}/g" ${EtcdConf}/etcd.conf>etcd.conf
            scp -p etcd.conf root@${node_ip}:${EtcdConf}/etcd.conf
            ssh root@${node_ip} "systemctl daemon-reload && systemctl enable etcd.service --now && systemctl status etcd -l"
          fi
        done
    fi
  done
systemctl daemon-reload && systemctl enable etcd.service --now && systemctl status etcd -l
echo "Please wait a moment!"
sleep 60

# Deploy the master node. 
## Create CAs of kubernetes cluster.
cat>${KubeCA}/ca-config.json<<EOF
{
  "signing": {
    "default": {
      "expiry": "87600h"
    },
    "profiles": {
      "kubernetes": {
         "expiry": "87600h",
         "usages": [
            "signing",
            "key encipherment",
            "server auth",
            "client auth"
        ]
      }
    }
  }
}
EOF

cat>${KubeCA}/ca-csr.json<<EOF
{
    "CN": "kubernetes",
    "key": {
        "algo": "rsa",
        "size": 2048
    },
    "names": [
        {
            "C": "CN",
            "L": "Beijing",
            "ST": "Beijing",
            "O": "k8s",
            "OU": "System"
        }
    ]
}
EOF

cat>${KubeCA}/server-csr.json<<EOF
{
    "CN": "kubernetes",
    "hosts": [
      "10.0.0.1",
      "127.0.0.1",
      "${HostIP[gysl-master]}",
      "kubernetes",
      "kubernetes.default",
      "kubernetes.default.svc",
      "kubernetes.default.svc.cluster",
      "kubernetes.default.svc.cluster.local"
    ],
    "key": {
        "algo": "rsa",
        "size": 2048
    },
    "names": [
        {
            "C": "CN",
            "L": "Beijing",
            "ST": "Beijing",
            "O": "k8s",
            "OU": "System"
        }
    ]
}
EOF

cd ${KubeCA}
cfssl gencert -initca ca-csr.json | cfssljson -bare ca -
cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=kubernetes server-csr.json | cfssljson -bare server

# Create kube-proxy CA.
cat>${KubeCA}/kube-proxy-csr.json<<EOF
{
  "CN": "system:kube-proxy",
  "hosts": [],
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CN",
      "L": "BeiJing",
      "ST": "BeiJing",
      "O": "k8s",
      "OU": "System"
    }
  ]
}
EOF
cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=kubernetes kube-proxy-csr.json | cfssljson -bare kube-proxy
tree ${KubeCA}
cd ${WorkDir}

## Create a token.
cat>${KubeConf}/token.csv<<EOF
$(head -c 16 /dev/urandom | od -An -t x | tr -d ' '),kubelet-bootstrap,10001,"system:kubelet-bootstrap"
EOF

# Create a kube-apiserver configuration file.
cat >${KubeConf}/apiserver.conf<<EOF
KUBE_APISERVER_OPTS="--logtostderr=true \\
--v=4 \\
--etcd-servers=https://${HostIP[gysl-master]}:2379,https://${HostIP[gysl-node1]}:2379,https://${HostIP[gysl-node2]}:2379,https://${HostIP[gysl-node3]}:2379 \\
--bind-address=${HostIP[gysl-master]} \\
--secure-port=6443 \\
--advertise-address=${HostIP[gysl-master]} \\
--allow-privileged=true \\
--service-cluster-ip-range=10.0.0.0/24 \\
--enable-admission-plugins=NamespaceLifecycle,LimitRanger,SecurityContextDeny,ServiceAccount,ResourceQuota,NodeRestriction \\
--authorization-mode=RBAC,Node \\
--enable-bootstrap-token-auth \\
--token-auth-file=${KubeConf}/token.csv \\
--service-node-port-range=30000-50000 \\
--tls-cert-file=${KubeCA}/server.pem  \\
--tls-private-key-file=${KubeCA}/server-key.pem \\
--client-ca-file=${KubeCA}/ca.pem \\
--service-account-key-file=${KubeCA}/ca-key.pem \\
--etcd-cafile=${EtcdCA}/ca.pem \\
--etcd-certfile=${EtcdCA}/server.pem \\
--etcd-keyfile=${EtcdCA}/server-key.pem"
EOF

# Create the kube-apiserver service.
cat>/usr/lib/systemd/system/kube-apiserver.service<<EOF
[Unit]
Description=Kubernetes API Server
Documentation=https://github.com/kubernetes/kubernetes
After=etcd.service
Wants=etcd.service

[Service]
EnvironmentFile=-${KubeConf}/apiserver.conf
ExecStart=${BinaryDir}/kube-apiserver \$KUBE_APISERVER_OPTS
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable kube-apiserver.service --now
systemctl status kube-apiserver.service -l

# Deploy the scheduler service.
cat>${KubeConf}/scheduler.conf<<EOF
KUBE_SCHEDULER_OPTS="--logtostderr=true \\
--v=4 \\
--master=127.0.0.1:8080 \\
--leader-elect"
EOF

# Create the kube-scheduler service. 
cat>/usr/lib/systemd/system/kube-scheduler.service<<EOF
[Unit]
Description=Kubernetes Scheduler
Documentation=https://github.com/kubernetes/kubernetes

[Service]
EnvironmentFile=-${KubeConf}/scheduler.conf
ExecStart=${BinaryDir}/kube-scheduler \$KUBE_SCHEDULER_OPTS
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable kube-scheduler.service --now
sleep 20
systemctl status kube-scheduler.service -l

# Deploy the controller-manager service.
cat>${KubeConf}/controller-manager.conf<<EOF
KUBE_CONTROLLER_MANAGER_OPTS="--logtostderr=true \\
--v=4 \\
--master=127.0.0.1:8080 \\
--leader-elect=true \\
--address=127.0.0.1 \\
--service-cluster-ip-range=10.0.0.0/24 \\
--cluster-name=kubernetes \\
--cluster-signing-cert-file=${KubeCA}/ca.pem \\
--cluster-signing-key-file=${KubeCA}/ca-key.pem  \\
--root-ca-file=${KubeCA}/ca.pem \\
--service-account-private-key-file=${KubeCA}/ca-key.pem"
EOF

# Create the kube-scheduler service. 
cat>/usr/lib/systemd/system/kube-controller-manager.service<<EOF
[Unit]
Description=Kubernetes Controller Manager
Documentation=https://github.com/kubernetes/kubernetes

[Service]
EnvironmentFile=-${KubeConf}/controller-manager.conf
ExecStart=${BinaryDir}/kube-controller-manager \$KUBE_CONTROLLER_MANAGER_OPTS
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable kube-controller-manager.service --now
sleep 20
systemctl status kube-controller-manager.service -l

# Bind kubelet-bootstrap user to system cluster roles.
kubectl create clusterrolebinding kubelet-bootstrap \
  --clusterrole=system:node-bootstrapper \
  --user=kubelet-bootstrap

# Set cluster parameters.
cd ${KubeCA}
kubectl config set-cluster kubernetes \
  --certificate-authority=./ca.pem \
  --embed-certs=true \
  --server=https://${HostIP[gysl-master]}:6443 \
  --kubeconfig=bootstrap.kubeconfig

# Set client parameters.
kubectl config set-credentials kubelet-bootstrap \
  --token=`awk -F "," '{print $1}' ${KubeConf}/token.csv` \
  --kubeconfig=bootstrap.kubeconfig

# Set context parameters. 
kubectl config set-context default \
  --cluster=kubernetes \
  --user=kubelet-bootstrap \
  --kubeconfig=bootstrap.kubeconfig

# Set context.
kubectl config use-context default --kubeconfig=bootstrap.kubeconfig

# Create kube-proxy kubeconfig file. 
kubectl config set-cluster kubernetes \
  --certificate-authority=./ca.pem \
  --embed-certs=true \
  --server=https://${HostIP[gysl-master]}:6443 \
  --kubeconfig=kube-proxy.kubeconfig

kubectl config set-credentials kube-proxy \
  --client-certificate=./kube-proxy.pem \
  --client-key=./kube-proxy-key.pem \
  --embed-certs=true \
  --kubeconfig=kube-proxy.kubeconfig

kubectl config set-context default \
  --cluster=kubernetes \
  --user=kube-proxy \
  --kubeconfig=kube-proxy.kubeconfig

kubectl config use-context default --kubeconfig=kube-proxy.kubeconfig
cd ${WorkDir}

# Deploy the node. 
## Create some temporary files for managed nodes. 
mkdir temp
## Create the kube-proxy configuration file.
cat>temp/kube-proxy.conf<<EOF
KUBE_PROXY_OPTS="--logtostderr=true \
--v=4 \
--hostname-override=${HostIP[gysl-master]} \
--cluster-cidr=10.0.0.0/24 \
--kubeconfig=${KubeConf}/kube-proxy.kubeconfig"
EOF

## Create the kube-proxy service.
cat>temp/kube-proxy.service<<EOF
[Unit]
Description=Kubernetes Proxy
After=network.target

[Service]
EnvironmentFile=-${KubeConf}/kube-proxy.conf
ExecStart=${BinaryDir}/kube-proxy \$KUBE_PROXY_OPTS
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

## Create the kubelet.yaml. 
cat>temp/kubelet.yaml<<EOF
kind: KubeletConfiguration
apiVersion: kubelet.config.k8s.io/v1beta1
address: ${HostIP[gysl-master]}
port: 10250
readOnlyPort: 10255
cgroupDriver: cgroupfs
clusterDNS: ["10.0.0.2"]
clusterDomain: cluster.local.
failSwapOn: false
authentication:
  anonymous:
    enabled: true
EOF

## Create the kubelet configuration file.
cat>temp/kubelet.conf<<EOF
KUBELET_OPTS="--logtostderr=true \
--v=4 \
--hostname-override=${HostIP[gysl-master]} \
--kubeconfig=${KubeConf}/kubelet.kubeconfig \
--bootstrap-kubeconfig=${KubeConf}/bootstrap.kubeconfig \
--config=${KubeConf}/kubelet.yaml \
--cert-dir=${KubeCA} \
--pod-infra-container-image=registry.cn-hangzhou.aliyuncs.com/google-containers/pause-amd64:3.0"
EOF

## Create the kubelet service file.
cat>temp/kubelet.service<<EOF
[Unit]
Description=Kubernetes Kubelet
After=docker.service
Requires=docker.service

[Service]
EnvironmentFile=${KubeConf}/kubelet.conf
ExecStart=${BinaryDir}/kubelet \$KUBELET_OPTS
Restart=on-failure
KillMode=process

[Install]
WantedBy=multi-user.target
EOF

## Check whether etcd cluster healthy.
etcdctl \
--ca-file=${EtcdCA}/ca.pem \
--cert-file=${EtcdCA}/server.pem \
--key-file=${EtcdCA}/server-key.pem \
--endpoints="https://${HostIP[gysl-master]}:2379,https://${HostIP[gysl-node1]}:2379,https://${HostIP[gysl-node2]}:2379,https://${HostIP[gysl-node3]}:2379" cluster-health

## Writing into a predetermined subnetwork.
cd ${EtcdCA}
etcdctl \
--ca-file=ca.pem --cert-file=server.pem --key-file=server-key.pem \
--endpoints="https://${HostIP[gysl-master]}:2379,https://${HostIP[gysl-node1]}:2379,https://${HostIP[gysl-node2]}:2379,https://${HostIP[gysl-node3]}:2379" \
set /coreos.com/network/config  '{ "Network": "172.17.0.0/16", "Backend": {"Type": "vxlan"}}'
cd ${WorkDir}

## Configuration the flannel service.
cat>${FlanneldConf}/flanneld.conf<<EOF
FLANNEL_OPTIONS="--etcd-endpoints=https://${HostIP[gysl-master]}:2379,\
https://${HostIP[gysl-node1]}:2379,https://${HostIP[gysl-node2]}:2379,\
https://${HostIP[gysl-node3]}:2379 \
-etcd-cafile=${EtcdCA}/ca.pem -etcd-certfile=${EtcdCA}/server.pem -etcd-keyfile=${EtcdCA}/server-key.pem"
EOF

## Create the flanneld service.
cat>/usr/lib/systemd/system/flanneld.service<<EOF
[Unit]
Description=Flanneld overlay address etcd agent
After=network-online.target network.target
Before=docker.service

[Service]
Type=notify
EnvironmentFile=${FlanneldConf}/flanneld.conf
ExecStart=${BinaryDir}/flanneld --ip-masq \$FLANNEL_OPTIONS
ExecStartPost=${BinaryDir}/mk-docker-opts.sh -k DOCKER_NETWORK_OPTIONS -d /run/flannel/subnet.env
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

## Distribute some files to the child node. Modify some configuration files.
for node_ip in ${HostIP[@]}
  do  
    if [ "${node_ip}" != "${HostIP[gysl-master]}" ] ;then
      scp -p kubernetes/server/bin/{kubelet,kube-proxy} root@${node_ip}:${BinaryDir}/
      scp -p {flanneld,mk-docker-opts.sh} root@${node_ip}:${BinaryDir}/
      scp -p ${FlanneldConf}/flanneld.conf root@${node_ip}:${FlanneldConf}/flanneld.conf
      scp -p /usr/lib/systemd/system/flanneld.service root@${node_ip}:/usr/lib/systemd/system/flanneld.service
      scp -p temp/{kubelet.yaml,kubelet.conf,kube-proxy.conf} root@${node_ip}:${KubeConf}/
      ssh root@${node_ip} "sed -i 's/=10.1.1.60/=${node_ip}/g'" ${KubeConf}/kube-proxy.conf
      ssh root@${node_ip} "sed -i 's/=10.1.1.60/=${node_ip}/g'" ${KubeConf}/kubelet.conf
      ssh root@${node_ip} "sed -i 's/10.1.1.60/${node_ip}/g'" ${KubeConf}/kubelet.yaml
      ssh root@${node_ip} "docker pull registry.cn-hangzhou.aliyuncs.com/google-containers/pause-amd64:3.0"
      scp -p temp/{kubelet.service,kube-proxy.service} root@${node_ip}:/usr/lib/systemd/system/
      scp -p ${KubeCA}/{bootstrap.kubeconfig,kube-proxy.kubeconfig} root@${node_ip}:${KubeConf}
      ssh root@${node_ip} "sed -i.bak -e '/ExecStart/i EnvironmentFile=\/run\/flannel\/subnet.env' -e 's/ExecStart=\/usr\/bin\/dockerd/ExecStart=\/usr\/bin\/dockerd \$DOCKER_NETWORK_OPTIONS/g' /usr/lib/systemd/system/docker.service"
      ssh root@${node_ip} "systemctl daemon-reload && systemctl enable flanneld --now && systemctl restart docker && systemctl status flanneld -l && systemctl status docker -l"
      ssh root@${node_ip} "systemctl daemon-reload && systemctl enable kubelet kube-proxy --now && systemctl status kubelet kube-proxy -l "
    fi
  done
mv {${FlanneldConf},/usr/lib/systemd/system/flanneld.service} temp/
sleep 300

## Approve the nodes.
CSRs=$(kubectl get csr | awk '{if(NR>1) print $1}')
for csr in ${CSRs[*]}
  do
    kubectl certificate approve ${csr}
  done

## Label the nodes.
for node_ip in ${HostIP[@]}
  do  
    if [ "${node_ip}" == "${HostIP[gysl-master]}" ] ;then
      kubectl label node ${node_ip} node-role.kubernetes.io/master='master'
    else
      kubectl label node ${node_ip} node-role.kubernetes.io/node='node'
    fi
  done

kubectl get cs,node