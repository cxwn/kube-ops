#!/bin/bash
cp cfssl* /usr/local/bin/
chmod +x /usr/local/bin/cfssl*
ls -l /usr/local/bin/
SSL_Dir=/etc/kubernetes/ssl
mkdir -p $SSL_Dir
# Create some CA certificates for etcd cluster.
cat<<EOF>$SSL_Dir/ca-config.json
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
cat<<EOF>$SSL_Dir/ca-csr.json
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
cat<<EOF>$SSL_Dir/server-csr.json
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
cd $SSL_Dir
cfssl_linux-amd64 gencert -initca ca-csr.json | cfssljson_linux-amd64 -bare ca -
cfssl_linux-amd64 gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=www server-csr.json | cfssljson_linux-amd64 -bare server
cd ~
# ca-key.pem  ca.pem  server-key.pem  server.pem
ls $SSL_Dir/*.pem