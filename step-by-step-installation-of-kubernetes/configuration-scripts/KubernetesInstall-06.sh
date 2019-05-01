#!/bin/bash
# Deploy etcd on the node1.
ETCD_SSL=/etc/etcd/ssl
mkdir -p $ETCD_SSL
scp gysl-master:~/etcd-v3.3.11-linux-amd64.tar.gz .
scp gysl-master:$ETCD_SSL/{ca*pem,server*pem} $ETCD_SSL/
scp gysl-master:/etc/etcd/etcd.conf /etc/etcd/
scp gysl-master:/usr/lib/systemd/system/etcd.service /usr/lib/systemd/system/
tar -xvzf etcd-v3.3.11-linux-amd64.tar.gz
mv ~/etcd-v3.3.11-linux-amd64/etcd* /usr/local/bin/
sed -i '/ETCD_NAME/{s/etcd-01/etcd-02/g}' /etc/etcd/etcd.conf
sed -i '/ETCD_LISTEN_PEER_URLS/{s/2.11/2.12/g}' /etc/etcd/etcd.conf
sed -i '/ETCD_LISTEN_CLIENT_URLS/{s/2.11/2.12/g}' /etc/etcd/etcd.conf
sed -i '/ETCD_INITIAL_ADVERTISE_PEER_URLS/{s/2.11/2.12/g}' /etc/etcd/etcd.conf
sed -i '/ETCD_ADVERTISE_CLIENT_URLS/{s/2.11/2.12/g}' /etc/etcd/etcd.conf
rm -rf ~/etcd-v3.3.11-linux-amd64*
systemctl daemon-reload
systemctl enable etcd.service --now
systemctl status etcd