#!/bin/bash
#===============================================================================
#          FILE: kube_install.sh
#         USAGE: . ${YOUR_PATH}/kube_install.sh 
#   DESCRIPTION: 
#        AUTHOR: IVAN DU
#        E-MAIL: mrivandu@hotmail.com
#        WECHAT: ecsboy
#      TECHBLOG: https://ivandu.blog.csdn.net
#        GITHUB: https://github.com/mrivandu
#       CREATED: 2019-06-26 17:05:26
#       LICENSE: GNU General Public License.
#     COPYRIGHT: © IVAN DU 2019
#      REVISION: v1.0
#===============================================================================

. kube_config.sh

cd ${HOME}
mkdir -p {${etcd},${etcd_ca},${kube_conf},${kube_ca}

# Configure SSH Password-Free Login. 
ssh-keygen -b 1024 -t rsa -C 'Kubernetes'
for node_ip in ${hosts[@]}
  do  
    if [ "${node_ip}" == "${hosts[gysl-master]}" ] ; then
      continue
    else
      ssh-copy-id -i root@${node_ip}
    fi
  done

# Unzip packages. 
[ -d temp ] && rm -rf temp && mkdir temp
[ ! -d temp ] && mkdir temp
tar -xvzf pkgs/*.gz -C temp/

# Copy the binary to the master destination diretory. 
cp temp/cfssl-tools/* ${bin}/
cp temp/kubernetes-v1.15.0-linux-amd64-1/* ${bin}/
cp temp/etcd-v3.3.13-linux-amd64/{etcd,etcdctl} ${bin}/

# Make CAs of etcd.
cat>${etcd_ca}/ca-config.json<<EOF
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

cat>${etcd_ca}/ca-csr.json<<EOF
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

cat>${etcd_ca}/server-csr.json<<EOF
{
    "CN": "etcd",
    "hosts": [
    "${hosts[gysl-master]}",
    "${hosts[gysl-node1]}",
    "${hosts[gysl-node2]}"
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

cd ${etcd_ca}
cfssl gencert -initca ca-csr.json | cfssljson -bare ca -
cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=www server-csr.json | cfssljson -bare server
cd ${HOME}
## Show files.
ls ${etcd_ca}

# Create CAs of kubernetes cluster.
cat>${kube_ca}/ca-config.json<<EOF
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

cat>${kube_ca}/ca-csr.json<<EOF
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

cat>${kube_ca}/server-csr.json<<EOF
{
    "CN": "kubernetes",
    "hosts": [
      "10.0.0.1",
      "127.0.0.1",
      "${hosts[gysl-master]}",
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

cd ${kube_ca}
cfssl gencert -initca ca-csr.json | cfssljson -bare ca -
cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=kubernetes server-csr.json | cfssljson -bare server

# Create kube-proxy CA.
cat>${kube_ca}/kube-proxy-csr.json<<EOF
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
cd ${HOME}

## Create a token.
cat>${KubeConf}/token.csv<<EOF
$(head -c 16 /dev/urandom | od -An -t x | tr -d ' '),kubelet-bootstrap,10001,"system:kubelet-bootstrap"
EOF

for node_ip in ${hosts[@]}
  do  
    if [ "${node_ip}" == "${hosts[gysl-master]}" ] ; then
      continue
    else
      ssh root@${node_ip} mkdir -p {${etcd},${etcd_ca},${kube_conf},${kube_ca},${flanneld_conf}}
      scp temp/{flanneld,mk-docker-opts.sh} root@${node_ip}:/
    fi
  done

# Deploy the etcd cluster. 



## The etcd configuration file.
cat>${EtcdConf}/etcd.conf<<EOF
#[Member]
ETCD_NAME="etcd-master"
ETCD_DATA_DIR="/var/lib/etcd/default.etcd"
ETCD_LISTEN_PEER_URLS="https://${hosts[gysl-master]}:2380"
ETCD_LISTEN_CLIENT_URLS="https://${hosts[gysl-master]}:2379"

#[Clustering]
ETCD_INITIAL_ADVERTISE_PEER_URLS="https://${hosts[gysl-master]}:2380"
ETCD_ADVERTISE_CLIENT_URLS="https://${hosts[gysl-master]}:2379"
ETCD_INITIAL_CLUSTER="etcd-master=https://${hosts[gysl-master]}:2380,etcd-01=https://${hosts[gysl-node1]}:2380,etcd-02=https://${hosts[gysl-node2]}:2380,etcd-03=https://${hosts[gysl-node3]}:2380"
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
--cert-file=${etcd_ca}/server.pem \\
--key-file=${etcd_ca}/server-key.pem \\
--peer-cert-file=${etcd_ca}/server.pem \\
--peer-key-file=${etcd_ca}/server-key.pem \\
--trusted-ca-file=${etcd_ca}/ca.pem \\
--peer-trusted-ca-file=${etcd_ca}/ca.pem
Restart=on-failure
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

## Copy some files to node for deploying etcd cluster.  
for node_ip in ${EtcdIP[@]}
  do  
    if [ "${node_ip}" != "${hosts[gysl-master]}" ] ; then
      scp -p ${etcd_ca}/{ca*pem,server*pem} root@${node_ip}:${etcd_ca}
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


for hostname in ${!hosts[@]};
    do
        cat>>/etc/hosts<<EOF
${hosts[${hostname}]} ${hostname}
EOF
    done