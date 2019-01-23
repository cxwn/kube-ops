#!/bin/bash
# Deploy the etcd cluster.
cp cfssl* /usr/local/bin/
chmod +x /usr/local/bin/cfssl*
ls -l /usr/local/bin/
tar -xzf etcd-v3.3.11-linux-amd64.tar.gz
cp -p etcd-v3.3.11-linux-amd64/etc* /usr/local/bin/
ls -l /usr/local/bin/