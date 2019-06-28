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
