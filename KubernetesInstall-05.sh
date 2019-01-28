#! /bin/bash
# Deploy the etcd cluster.
tar -xzf etcd-v3.3.11-linux-amd64.tar.gz
cp -p etcd-v3.3.11-linux-amd64/etc* /usr/local/bin/
ls -l /usr/local/bin/