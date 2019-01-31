#!/bin/bash
mv cfssl* /usr/local/bin/
chmod +x /usr/local/bin/cfssl*
ETCD_SSL=/etc/etcd/ssl
mkdir -p $ETCD_SSL
# Create some CA certificates for etcd cluster.
cat<<EOF>$ETCD_SSL/ca-config.json
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
cat<<EOF>$ETCD_SSL/ca-csr.json
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
cat<<EOF>$ETCD_SSL/server-csr.json
{
    "CN": "etcd",
    "hosts": [
    "172.31.2.11",
    "172.31.2.12",
    "172.31.2.13"
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
cd $ETCD_SSL
cfssl_linux-amd64 gencert -initca ca-csr.json | cfssljson_linux-amd64 -bare ca -
cfssl_linux-amd64 gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=www server-csr.json | cfssljson_linux-amd64 -bare server
cd ~
# ca-key.pem  ca.pem  server-key.pem  server.pem
ls $ETCD_SSL/*.pem