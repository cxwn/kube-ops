# 二进制包20分钟快速部署 Kubernetes v1.14.0 集群

## 一 环境

操作系统|Docker版本|Kubernetes版本|Etcd版本|Flannel版本|
:-:|:-:|:-:|:-:|:-:
CentOS Linux release 7.6.1810|Docker version 18.09.4|v1.14.0|Version: 3.3.12|v0.11.0

## 二 架构

主机名|IP|角色|部署应用
:-:|:-:|:-:|:-:
gysl-master|10.1.1.60|Msater|Docker/Kube-apiserver/kube-scheduler/kube-controller-manager/etcd
gysl-node1|10.1.1.61|Node|Docker/Kubelet/kube-proxy/flanneld/etcd
gysl-node2|10.1.1.62|Node|Docker/Kubelet/kube-proxy/flanneld/etcd
gysl-node3|10.1.1.63|Node|Docker/Kubelet/kube-proxy/flanneld/etcd

## 三 安装过程

通过几个小时的努力，完成本次部署脚本的编写，安装脚本支持任意多个节点，主要通过三个脚本实现本次安装。

### 3.1 初始化脚本

```bash
#!/bin/bash
declare -A HostIP EtcdIP
HostIP=( [gysl-master]='10.1.1.60' [gysl-node1]='10.1.1.61' [gysl-node2]='10.1.1.62' [gysl-node3]='10.1.1.63' )
EtcdIP=( [etcd-master]='10.1.1.60' [etcd-01]='10.1.1.61' [etcd-02]='10.1.1.62' [etcd-03]='10.1.1.63' )
BinaryDir='/usr/local/bin'
KubeConf='/etc/kubernetes/conf.d'
KubeCA='/etc/kubernetes/ca.d'
EtcdConf='/etc/etcd/conf.d'
EtcdCA='/etc/etcd/ca.d'
FlanneldConf='/etc/flanneld'

mkdir -p {${KubeConf},${KubeCA},${EtcdConf},${EtcdCA},${FlanneldConf}}
for hostname in ${!HostIP[@]}
    do
        cat>>/etc/hosts<<EOF
${HostIP[${hostname}]} ${hostname}
EOF
    done
# Install the Docker engine. This needs to be executed on every machine.
curl http://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo -o /etc/yum.repos.d/docker-ce.repo>&/dev/null
if [ $? -eq 0 ] ;
    then
        yum remove docker \
                      docker-client \
                      docker-client-latest \
                      docker-common \
                      docker-latest \
                      docker-latest-logrotate \
                      docker-logrotate \
                      docker-selinux \
                      docker-engine-selinux \
                      docker-engine>&/dev/null
        yum list docker-ce --showduplicates|grep "^doc"|sort -r
        yum -y install docker-ce-18.09.3-3.el7
        rm -f /etc/yum.repos.d/docker-ce.repo
        systemctl enable docker --now && systemctl status docker
    else
        echo "Install failed! Please try again! ";
        exit 110
fi
# Modify related kernel parameters. 
cat>/etc/sysctl.d/docker.conf<<EOF
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF 
sysctl -p /etc/sysctl.d/docker.conf>&/dev/null 
# Turn off and disable the firewalld.  
systemctl stop firewalld  
systemctl disable firewalld  
# Disable the SELinux.  
sed -i.bak 's/=enforcing/=disabled/' /etc/selinux/config  
# Disable the swap.  
sed -i.bak 's/^.*swap/#&/g' /etc/fstab
# Install EPEL/vim/git.  
yum -y install epel-release vim git tree
yum repolist
# Alias vim. 
cat>/etc/profile.d/vim.sh<<EOF
alias vi='vim'
EOF
source /etc/profile.d/vim.sh
echo "set nu">>/etc/vimrc
# Reboot the machine.  
reboot
```

需要每个节点都执行。

### 3.2 安装脚本

安装脚本较长，此处省略，日志以供参考，拓展思路。此脚本在Master节点执行即可，安装过程无需连接外网，安装日志如下：

```log
Generating public/private rsa key pair.
Enter file in which to save the key (/root/.ssh/id_rsa): 
Created directory '/root/.ssh'.
Enter passphrase (empty for no passphrase): 
Enter same passphrase again: 
Your identification has been saved in /root/.ssh/id_rsa.
Your public key has been saved in /root/.ssh/id_rsa.pub.
The key fingerprint is:
SHA256:rJdnEzx5GyWX9YCxq77ZMc+FCabCqA+3FwmS7LnF9qo Kubernetes
The key's randomart image is:
+---[RSA 1024]----+
|            .o. .|
|            .. +.|
|   . .      o + .|
|    + .. . . =   |
|   . + .S.= *    |
|    o ++o. B + o |
|    .++.=.* + o .|
|    .+ oo= + = . |
|    Eo+o  +.. o  |
+----[SHA256]-----+
/usr/bin/ssh-copy-id: INFO: Source of key(s) to be installed: "/root/.ssh/id_rsa.pub"
The authenticity of host '10.1.1.62 (10.1.1.62)' can't be established.
ECDSA key fingerprint is SHA256:B4e7Gq9wcgr5N6ys8U72NEhNWxIFrvng5eI7GAXLf6s.
ECDSA key fingerprint is MD5:ea:33:04:40:f8:31:a2:d0:91:c4:b4:37:48:fa:51:d6.
Are you sure you want to continue connecting (yes/no)? yes
/usr/bin/ssh-copy-id: INFO: attempting to log in with the new key(s), to filter out any that are already installed
/usr/bin/ssh-copy-id: INFO: 1 key(s) remain to be installed -- if you are prompted now it is to install the new keys
root@10.1.1.62's password: 

Number of key(s) added: 1

Now try logging into the machine, with:   "ssh 'root@10.1.1.62'"
and check to make sure that only the key(s) you wanted were added.

/usr/bin/ssh-copy-id: INFO: Source of key(s) to be installed: "/root/.ssh/id_rsa.pub"
The authenticity of host '10.1.1.63 (10.1.1.63)' can't be established.
ECDSA key fingerprint is SHA256:B4e7Gq9wcgr5N6ys8U72NEhNWxIFrvng5eI7GAXLf6s.
ECDSA key fingerprint is MD5:ea:33:04:40:f8:31:a2:d0:91:c4:b4:37:48:fa:51:d6.
Are you sure you want to continue connecting (yes/no)? yes
/usr/bin/ssh-copy-id: INFO: attempting to log in with the new key(s), to filter out any that are already installed
/usr/bin/ssh-copy-id: INFO: 1 key(s) remain to be installed -- if you are prompted now it is to install the new keys
root@10.1.1.63's password: 

Number of key(s) added: 1

Now try logging into the machine, with:   "ssh 'root@10.1.1.63'"
and check to make sure that only the key(s) you wanted were added.

/usr/bin/ssh-copy-id: INFO: Source of key(s) to be installed: "/root/.ssh/id_rsa.pub"
The authenticity of host '10.1.1.61 (10.1.1.61)' can't be established.
ECDSA key fingerprint is SHA256:B4e7Gq9wcgr5N6ys8U72NEhNWxIFrvng5eI7GAXLf6s.
ECDSA key fingerprint is MD5:ea:33:04:40:f8:31:a2:d0:91:c4:b4:37:48:fa:51:d6.
Are you sure you want to continue connecting (yes/no)? yes
/usr/bin/ssh-copy-id: INFO: attempting to log in with the new key(s), to filter out any that are already installed
/usr/bin/ssh-copy-id: INFO: 1 key(s) remain to be installed -- if you are prompted now it is to install the new keys
root@10.1.1.61's password: 

Number of key(s) added: 1

Now try logging into the machine, with:   "ssh 'root@10.1.1.61'"
and check to make sure that only the key(s) you wanted were added.
2019/03/31 20:34:23 [INFO] generating a new CA key and certificate from CSR
2019/03/31 20:34:23 [INFO] generate received request
2019/03/31 20:34:23 [INFO] received CSR
2019/03/31 20:34:23 [INFO] generating key: rsa-2048
2019/03/31 20:34:23 [INFO] encoded CSR
2019/03/31 20:34:23 [INFO] signed certificate with serial number 316253512009054883826466120107550244311105093255
2019/03/31 20:34:23 [INFO] generate received request
2019/03/31 20:34:23 [INFO] received CSR
2019/03/31 20:34:23 [INFO] generating key: rsa-2048
2019/03/31 20:34:23 [INFO] encoded CSR
2019/03/31 20:34:23 [INFO] signed certificate with serial number 288189004496636237074496723049170901716100041831
2019/03/31 20:34:23 [WARNING] This certificate lacks a "hosts" field. This makes it unsuitable for
websites. For more information see the Baseline Requirements for the Issuance and Management
of Publicly-Trusted Certificates, v.1.1.6, from the CA/Browser Forum (https://cabforum.org);
specifically, section 10.2.3 ("Information Requirements").
/etc/etcd/ca.d
├── ca-config.json
├── ca.csr
├── ca-csr.json
├── ca-key.pem
├── ca.pem
├── server.csr
├── server-csr.json
├── server-key.pem
└── server.pem

0 directories, 9 files
ca-key.pem                                                                                                                                                 100% 1675    27.1KB/s   00:00    
ca.pem                                                                                                                                                     100% 1265     2.2MB/s   00:00    
server-key.pem                                                                                                                                             100% 1679   639.6KB/s   00:00    
server.pem                                                                                                                                                 100% 1346     1.9MB/s   00:00    
etcd                                                                                                                                                       100%   18MB  13.1MB/s   00:01    
etcdctl                                                                                                                                                    100%   15MB  41.5MB/s   00:00    
etcd.service                                                                                                                                               100%  994     1.0MB/s   00:00    
etcd.conf                                                                                                                                                  100%  520   527.8KB/s   00:00    
Created symlink from /etc/systemd/system/multi-user.target.wants/etcd.service to /usr/lib/systemd/system/etcd.service.
Job for etcd.service failed because a timeout was exceeded. See "systemctl status etcd.service" and "journalctl -xe" for details.
ca-key.pem                                                                                                                                                 100% 1675    92.3KB/s   00:00    
ca.pem                                                                                                                                                     100% 1265     1.7MB/s   00:00    
server-key.pem                                                                                                                                             100% 1679   328.8KB/s   00:00    
server.pem                                                                                                                                                 100% 1346     1.6MB/s   00:00    
etcd                                                                                                                                                       100%   18MB  40.7MB/s   00:00    
etcdctl                                                                                                                                                    100%   15MB  46.0MB/s   00:00    
etcd.service                                                                                                                                               100%  994     1.0MB/s   00:00    
etcd.conf                                                                                                                                                  100%  520   838.6KB/s   00:00    
Created symlink from /etc/systemd/system/multi-user.target.wants/etcd.service to /usr/lib/systemd/system/etcd.service.
Job for etcd.service failed because a timeout was exceeded. See "systemctl status etcd.service" and "journalctl -xe" for details.
ca-key.pem                                                                                                                                                 100% 1675   106.9KB/s   00:00    
ca.pem                                                                                                                                                     100% 1265     1.0MB/s   00:00    
server-key.pem                                                                                                                                             100% 1679     1.3MB/s   00:00    
server.pem                                                                                                                                                 100% 1346     1.5MB/s   00:00    
etcd                                                                                                                                                       100%   18MB  31.4MB/s   00:00    
etcdctl                                                                                                                                                    100%   15MB  37.7MB/s   00:00    
etcd.service                                                                                                                                               100%  994   916.5KB/s   00:00    
etcd.conf                                                                                                                                                  100%  520   487.5KB/s   00:00    
Created symlink from /etc/systemd/system/multi-user.target.wants/etcd.service to /usr/lib/systemd/system/etcd.service.
● etcd.service - Etcd Server
   Loaded: loaded (/usr/lib/systemd/system/etcd.service; enabled; vendor preset: disabled)
   Active: active (running) since 日 2019-03-31 20:37:32 CST; 28ms ago
 Main PID: 7373 (etcd)
    Tasks: 7
   Memory: 9.1M
   CGroup: /system.slice/etcd.service
           └─7373 /usr/local/bin/etcd --name=etcd-01 --data-dir=/var/lib/etcd/default.etcd --listen-peer-urls=https://10.1.1.61:2380 --listen-client-urls=https://10.1.1.61:2379,http://127.0.0.1:2379 --advertise-client-urls=https://10.1.1.61:2379 --initial-advertise-peer-urls=https://10.1.1.61:2380 --initial-cluster=etcd-master=https://10.1.1.60:2380,etcd-01=https://10.1.1.61:2380,etcd-02=https://10.1.1.62:2380,etcd-03=https://10.1.1.63:2380 --initial-cluster-token=etcd-cluster --initial-cluster-state=new --cert-file=/etc/etcd/ca.d/server.pem --key-file=/etc/etcd/ca.d/server-key.pem --peer-cert-file=/etc/etcd/ca.d/server.pem --peer-key-file=/etc/etcd/ca.d/server-key.pem --trusted-ca-file=/etc/etcd/ca.d/ca.pem --peer-trusted-ca-file=/etc/etcd/ca.d/ca.pem

3月 31 20:37:32 gysl-node1 etcd[7373]: 1c3555118a39401e initialzed peer connection; fast-forwarding 8 ticks (election ticks 10) with 2 active peer(s)
3月 31 20:37:32 gysl-node1 etcd[7373]: raft.node: 1c3555118a39401e elected leader 63ac3c747757aa28 at term 138
3月 31 20:37:32 gysl-node1 etcd[7373]: published {Name:etcd-01 ClientURLs:[https://10.1.1.61:2379]} to cluster 575c8b9e68fd927d
3月 31 20:37:32 gysl-node1 etcd[7373]: ready to serve client requests
3月 31 20:37:32 gysl-node1 etcd[7373]: serving insecure client requests on 127.0.0.1:2379, this is strongly discouraged!
3月 31 20:37:32 gysl-node1 etcd[7373]: ready to serve client requests
3月 31 20:37:32 gysl-node1 systemd[1]: Started Etcd Server.
3月 31 20:37:32 gysl-node1 etcd[7373]: serving client requests on 10.1.1.61:2379
3月 31 20:37:32 gysl-node1 etcd[7373]: set the initial cluster version to 3.0
3月 31 20:37:32 gysl-node1 etcd[7373]: enabled capabilities for version 3.0
Created symlink from /etc/systemd/system/multi-user.target.wants/etcd.service to /usr/lib/systemd/system/etcd.service.
● etcd.service - Etcd Server
   Loaded: loaded (/usr/lib/systemd/system/etcd.service; enabled; vendor preset: disabled)
   Active: active (running) since 日 2019-03-31 20:37:34 CST; 124ms ago
 Main PID: 7551 (etcd)
    Tasks: 7
   Memory: 10.3M
   CGroup: /system.slice/etcd.service
           └─7551 /usr/local/bin/etcd --name=etcd-master --data-dir=/var/lib/etcd/default.etcd --listen-peer-urls=https://10.1.1.60:2380 --listen-client-urls=https://10.1.1.60:2379,http://127.0.0.1:2379 --advertise-client-urls=https://10.1.1.60:2379 --initial-advertise-peer-urls=https://10.1.1.60:2380 --initial-cluster=etcd-master=https://10.1.1.60:2380,etcd-01=https://10.1.1.61:2380,etcd-02=https://10.1.1.62:2380,etcd-03=https://10.1.1.63:2380 --initial-cluster-token=etcd-cluster --initial-cluster-state=new --cert-file=/etc/etcd/ca.d/server.pem --key-file=/etc/etcd/ca.d/server-key.pem --peer-cert-file=/etc/etcd/ca.d/server.pem --peer-key-file=/etc/etcd/ca.d/server-key.pem --trusted-ca-file=/etc/etcd/ca.d/ca.pem --peer-trusted-ca-file=/etc/etcd/ca.d/ca.pem

3月 31 20:37:34 gysl-master etcd[7551]: established a TCP streaming connection with peer 63ac3c747757aa28 (stream Message reader)
3月 31 20:37:34 gysl-master etcd[7551]: established a TCP streaming connection with peer 1c3555118a39401e (stream Message reader)
3月 31 20:37:34 gysl-master etcd[7551]: published {Name:etcd-master ClientURLs:[https://10.1.1.60:2379]} to cluster 575c8b9e68fd927d
3月 31 20:37:34 gysl-master etcd[7551]: ready to serve client requests
3月 31 20:37:34 gysl-master etcd[7551]: serving client requests on 10.1.1.60:2379
3月 31 20:37:34 gysl-master etcd[7551]: ready to serve client requests
3月 31 20:37:34 gysl-master etcd[7551]: serving insecure client requests on 127.0.0.1:2379, this is strongly discouraged!
3月 31 20:37:34 gysl-master etcd[7551]: 78df1ab24a6f1302 initialzed peer connection; fast-forwarding 8 ticks (election ticks 10) with 3 active peer(s)
3月 31 20:37:34 gysl-master systemd[1]: Started Etcd Server.
3月 31 20:37:34 gysl-master etcd[7551]: established a TCP streaming connection with peer 76bcb3b85e42210d (stream Message reader)
Please wait a moment!
2019/03/31 20:38:34 [INFO] generating a new CA key and certificate from CSR
2019/03/31 20:38:34 [INFO] generate received request
2019/03/31 20:38:34 [INFO] received CSR
2019/03/31 20:38:34 [INFO] generating key: rsa-2048
2019/03/31 20:38:34 [INFO] encoded CSR
2019/03/31 20:38:34 [INFO] signed certificate with serial number 284879897535931954074635242912207100624264127544
2019/03/31 20:38:34 [INFO] generate received request
2019/03/31 20:38:34 [INFO] received CSR
2019/03/31 20:38:34 [INFO] generating key: rsa-2048
2019/03/31 20:38:34 [INFO] encoded CSR
2019/03/31 20:38:34 [INFO] signed certificate with serial number 163588537762519336822862885460408698694735647771
2019/03/31 20:38:34 [WARNING] This certificate lacks a "hosts" field. This makes it unsuitable for
websites. For more information see the Baseline Requirements for the Issuance and Management
of Publicly-Trusted Certificates, v.1.1.6, from the CA/Browser Forum (https://cabforum.org);
specifically, section 10.2.3 ("Information Requirements").
2019/03/31 20:38:34 [INFO] generate received request
2019/03/31 20:38:34 [INFO] received CSR
2019/03/31 20:38:34 [INFO] generating key: rsa-2048
2019/03/31 20:38:35 [INFO] encoded CSR
2019/03/31 20:38:35 [INFO] signed certificate with serial number 269430846139878968754015022650791204259891937310
2019/03/31 20:38:35 [WARNING] This certificate lacks a "hosts" field. This makes it unsuitable for
websites. For more information see the Baseline Requirements for the Issuance and Management
of Publicly-Trusted Certificates, v.1.1.6, from the CA/Browser Forum (https://cabforum.org);
specifically, section 10.2.3 ("Information Requirements").
/etc/kubernetes/ca.d
├── ca-config.json
├── ca.csr
├── ca-csr.json
├── ca-key.pem
├── ca.pem
├── kube-proxy.csr
├── kube-proxy-csr.json
├── kube-proxy-key.pem
├── kube-proxy.pem
├── server.csr
├── server-csr.json
├── server-key.pem
└── server.pem

0 directories, 13 files
Created symlink from /etc/systemd/system/multi-user.target.wants/kube-apiserver.service to /usr/lib/systemd/system/kube-apiserver.service.
● kube-apiserver.service - Kubernetes API Server
   Loaded: loaded (/usr/lib/systemd/system/kube-apiserver.service; enabled; vendor preset: disabled)
   Active: active (running) since 日 2019-03-31 20:38:35 CST; 41ms ago
     Docs: https://github.com/kubernetes/kubernetes
 Main PID: 7628 (kube-apiserver)
    Tasks: 1
   Memory: 14.0M
   CGroup: /system.slice/kube-apiserver.service
           └─7628 /usr/local/bin/kube-apiserver --logtostderr=true --v=4 --etcd-servers=https://10.1.1.60:2379,https://10.1.1.61:2379,https://10.1.1.62:2379,https://10.1.1.63:2379 --bind-address=10.1.1.60 --secure-port=6443 --advertise-address=10.1.1.60 --allow-privileged=true --service-cluster-ip-range=10.0.0.0/24 --enable-admission-plugins=NamespaceLifecycle,LimitRanger,SecurityContextDeny,ServiceAccount,ResourceQuota,NodeRestriction --authorization-mode=RBAC,Node --enable-bootstrap-token-auth --token-auth-file=/etc/kubernetes/conf.d/token.csv --service-node-port-range=30000-50000 --tls-cert-file=/etc/kubernetes/ca.d/server.pem --tls-private-key-file=/etc/kubernetes/ca.d/server-key.pem --client-ca-file=/etc/kubernetes/ca.d/ca.pem --service-account-key-file=/etc/kubernetes/ca.d/ca-key.pem --etcd-cafile=/etc/etcd/ca.d/ca.pem --etcd-certfile=/etc/etcd/ca.d/server.pem --etcd-keyfile=/etc/etcd/ca.d/server-key.pem

3月 31 20:38:35 gysl-master systemd[1]: Started Kubernetes API Server.
Created symlink from /etc/systemd/system/multi-user.target.wants/kube-scheduler.service to /usr/lib/systemd/system/kube-scheduler.service.
● kube-scheduler.service - Kubernetes Scheduler
   Loaded: loaded (/usr/lib/systemd/system/kube-scheduler.service; enabled; vendor preset: disabled)
   Active: active (running) since 日 2019-03-31 20:38:36 CST; 20s ago
     Docs: https://github.com/kubernetes/kubernetes
 Main PID: 7673 (kube-scheduler)
    Tasks: 7
   Memory: 47.5M
   CGroup: /system.slice/kube-scheduler.service
           └─7673 /usr/local/bin/kube-scheduler --logtostderr=true --v=4 --master=127.0.0.1:8080 --leader-elect

3月 31 20:38:43 gysl-master kube-scheduler[7673]: I0331 20:38:43.299502    7673 shared_informer.go:123] caches populated
3月 31 20:38:43 gysl-master kube-scheduler[7673]: I0331 20:38:43.399931    7673 shared_informer.go:123] caches populated
3月 31 20:38:43 gysl-master kube-scheduler[7673]: I0331 20:38:43.500642    7673 shared_informer.go:123] caches populated
3月 31 20:38:43 gysl-master kube-scheduler[7673]: I0331 20:38:43.601146    7673 shared_informer.go:123] caches populated
3月 31 20:38:43 gysl-master kube-scheduler[7673]: I0331 20:38:43.604604    7673 controller_utils.go:1027] Waiting for caches to sync for scheduler controller
3月 31 20:38:43 gysl-master kube-scheduler[7673]: I0331 20:38:43.705500    7673 shared_informer.go:123] caches populated
3月 31 20:38:43 gysl-master kube-scheduler[7673]: I0331 20:38:43.705529    7673 controller_utils.go:1034] Caches are synced for scheduler controller
3月 31 20:38:43 gysl-master kube-scheduler[7673]: I0331 20:38:43.705631    7673 leaderelection.go:217] attempting to acquire leader lease  kube-system/kube-scheduler...
3月 31 20:38:43 gysl-master kube-scheduler[7673]: I0331 20:38:43.737674    7673 leaderelection.go:227] successfully acquired lease kube-system/kube-scheduler
3月 31 20:38:43 gysl-master kube-scheduler[7673]: I0331 20:38:43.838862    7673 shared_informer.go:123] caches populated
Created symlink from /etc/systemd/system/multi-user.target.wants/kube-controller-manager.service to /usr/lib/systemd/system/kube-controller-manager.service.
● kube-controller-manager.service - Kubernetes Controller Manager
   Loaded: loaded (/usr/lib/systemd/system/kube-controller-manager.service; enabled; vendor preset: disabled)
   Active: active (running) since 日 2019-03-31 20:38:56 CST; 20s ago
     Docs: https://github.com/kubernetes/kubernetes
 Main PID: 7725 (kube-controller)
    Tasks: 6
   Memory: 132.3M
   CGroup: /system.slice/kube-controller-manager.service
           └─7725 /usr/local/bin/kube-controller-manager --logtostderr=true --v=4 --master=127.0.0.1:8080 --leader-elect=true --address=127.0.0.1 --service-cluster-ip-range=10.0.0.0/24 --cluster-name=kubernetes --cluster-signing-cert-file=/etc/kubernetes/ca.d/ca.pem --cluster-signing-key-file=/etc/kubernetes/ca.d/ca-key.pem --root-ca-file=/etc/kubernetes/ca.d/ca.pem --service-account-private-key-file=/etc/kubernetes/ca.d/ca-key.pem

3月 31 20:38:59 gysl-master kube-controller-manager[7725]: I0331 20:38:59.915581    7725 request.go:530] Throttling request took 1.356935667s, request: GET:http://127.0.0.1:8080/apis/scheduling.k8s.io/v1?timeout=32s
3月 31 20:38:59 gysl-master kube-controller-manager[7725]: I0331 20:38:59.965276    7725 request.go:530] Throttling request took 1.406608026s, request: GET:http://127.0.0.1:8080/apis/scheduling.k8s.io/v1beta1?timeout=32s
3月 31 20:39:00 gysl-master kube-controller-manager[7725]: I0331 20:39:00.015978    7725 request.go:530] Throttling request took 1.457255375s, request: GET:http://127.0.0.1:8080/apis/coordination.k8s.io/v1?timeout=32s
3月 31 20:39:00 gysl-master kube-controller-manager[7725]: I0331 20:39:00.065993    7725 request.go:530] Throttling request took 1.507246887s, request: GET:http://127.0.0.1:8080/apis/coordination.k8s.io/v1beta1?timeout=32s
3月 31 20:39:00 gysl-master kube-controller-manager[7725]: I0331 20:39:00.067050    7725 resource_quota_controller.go:427] syncing resource quota controller with updated resources from discovery: map[/v1, Resource=configmaps:{} /v1, Resource=endpoints:{} /v1, Resource=events:{} /v1, Resource=limitranges:{} /v1, Resource=persistentvolumeclaims:{} /v1, Resource=pods:{} /v1, Resource=podtemplates:{} /v1, Resource=replicationcontrollers:{} /v1, Resource=resourcequotas:{} /v1, Resource=secrets:{} /v1, Resource=serviceaccounts:{} /v1, Resource=services:{} apps/v1, Resource=controllerrevisions:{} apps/v1, Resource=daemonsets:{} apps/v1, Resource=deployments:{} apps/v1, Resource=replicasets:{} apps/v1, Resource=statefulsets:{} autoscaling/v1, Resource=horizontalpodautoscalers:{} batch/v1, Resource=jobs:{} batch/v1beta1, Resource=cronjobs:{} coordination.k8s.io/v1, Resource=leases:{} events.k8s.io/v1beta1, Resource=events:{} extensions/v1beta1, Resource=daemonsets:{} extensions/v1beta1, Resource=deployments:{} extensions/v1beta1, Resource=ingresses:{} extensions/v1beta1, Resource=networkpolicies:{} extensions/v1beta1, Resource=replicasets:{} networking.k8s.io/v1, Resource=networkpolicies:{} networking.k8s.io/v1beta1, Resource=ingresses:{} policy/v1beta1, Resource=poddisruptionbudgets:{} rbac.authorization.k8s.io/v1, Resource=rolebindings:{} rbac.authorization.k8s.io/v1, Resource=roles:{}]
3月 31 20:39:00 gysl-master kube-controller-manager[7725]: I0331 20:39:00.067168    7725 resource_quota_monitor.go:180] QuotaMonitor unable to use a shared informer for resource "extensions/v1beta1, Resource=networkpolicies": no informer found for extensions/v1beta1, Resource=networkpolicies
3月 31 20:39:00 gysl-master kube-controller-manager[7725]: I0331 20:39:00.067189    7725 resource_quota_monitor.go:243] quota synced monitors; added 0, kept 30, removed 0
3月 31 20:39:00 gysl-master kube-controller-manager[7725]: E0331 20:39:00.067197    7725 resource_quota_controller.go:437] failed to sync resource monitors: couldn't start monitor for resource "extensions/v1beta1, Resource=networkpolicies": unable to monitor quota for resource "extensions/v1beta1, Resource=networkpolicies"
3月 31 20:39:13 gysl-master kube-controller-manager[7725]: I0331 20:39:13.677245    7725 reflector.go:235] k8s.io/client-go/informers/factory.go:133: forcing resync
3月 31 20:39:14 gysl-master kube-controller-manager[7725]: I0331 20:39:14.215322    7725 pv_controller_base.go:407] resyncing PV controller
clusterrolebinding.rbac.authorization.k8s.io/kubelet-bootstrap created
Cluster "kubernetes" set.
User "kubelet-bootstrap" set.
Context "default" created.
Switched to context "default".
Cluster "kubernetes" set.
User "kube-proxy" set.
Context "default" created.
Switched to context "default".
member 1c3555118a39401e is healthy: got healthy result from https://10.1.1.61:2379
member 63ac3c747757aa28 is healthy: got healthy result from https://10.1.1.63:2379
member 76bcb3b85e42210d is healthy: got healthy result from https://10.1.1.62:2379
member 78df1ab24a6f1302 is healthy: got healthy result from https://10.1.1.60:2379
cluster is healthy
{ "Network": "172.17.0.0/16", "Backend": {"Type": "vxlan"}}
kubelet                                                                                                                                                    100%  122MB  26.1MB/s   00:04    
kube-proxy                                                                                                                                                 100%   35MB  21.9MB/s   00:01    
flanneld                                                                                                                                                   100%   34MB  20.5MB/s   00:01    
mk-docker-opts.sh                                                                                                                                          100% 2139   916.8KB/s   00:00    
flanneld.conf                                                                                                                                              100%  247    55.8KB/s   00:00    
flanneld.service                                                                                                                                           100%  389    82.7KB/s   00:00    
kubelet.yaml                                                                                                                                               100%  263   319.4KB/s   00:00    
kubelet.conf                                                                                                                                               100%  365   326.0KB/s   00:00    
kube-proxy.conf                                                                                                                                            100%  158   184.0KB/s   00:00    
kubelet.service                                                                                                                                            100%  267   234.2KB/s   00:00    
kube-proxy.service                                                                                                                                         100%  234   130.5KB/s   00:00    
bootstrap.kubeconfig                                                                                                                                       100% 2163     1.5MB/s   00:00    
kube-proxy.kubeconfig                                                                                                                                      100% 6265     4.4MB/s   00:00    
Created symlink from /etc/systemd/system/multi-user.target.wants/flanneld.service to /usr/lib/systemd/system/flanneld.service.
● flanneld.service - Flanneld overlay address etcd agent
   Loaded: loaded (/usr/lib/systemd/system/flanneld.service; enabled; vendor preset: disabled)
   Active: active (running) since 日 2019-03-31 20:39:27 CST; 430ms ago
  Process: 7536 ExecStartPost=/usr/local/bin/mk-docker-opts.sh -k DOCKER_NETWORK_OPTIONS -d /run/flannel/subnet.env (code=exited, status=0/SUCCESS)
 Main PID: 7508 (flanneld)
    Tasks: 7
   Memory: 6.7M
   CGroup: /system.slice/flanneld.service
           └─7508 /usr/local/bin/flanneld --ip-masq

3月 31 20:39:27 gysl-node2 flanneld[7508]: I0331 20:39:27.720837    7508 iptables.go:167] Deleting iptables rule: -s 172.17.0.0/16 ! -d 224.0.0.0/4 -j MASQUERADE
3月 31 20:39:27 gysl-node2 flanneld[7508]: I0331 20:39:27.721919    7508 iptables.go:167] Deleting iptables rule: ! -s 172.17.0.0/16 -d 172.17.24.0/24 -j RETURN
3月 31 20:39:27 gysl-node2 flanneld[7508]: I0331 20:39:27.722994    7508 iptables.go:167] Deleting iptables rule: ! -s 172.17.0.0/16 -d 172.17.0.0/16 -j MASQUERADE
3月 31 20:39:27 gysl-node2 flanneld[7508]: I0331 20:39:27.724549    7508 iptables.go:155] Adding iptables rule: -s 172.17.0.0/16 -d 172.17.0.0/16 -j RETURN
3月 31 20:39:27 gysl-node2 flanneld[7508]: I0331 20:39:27.730116    7508 iptables.go:155] Adding iptables rule: -d 172.17.0.0/16 -j ACCEPT
3月 31 20:39:27 gysl-node2 flanneld[7508]: I0331 20:39:27.737143    7508 main.go:429] Waiting for 22h59m59.914613166s to renew lease
3月 31 20:39:27 gysl-node2 flanneld[7508]: I0331 20:39:27.737262    7508 iptables.go:155] Adding iptables rule: -s 172.17.0.0/16 ! -d 224.0.0.0/4 -j MASQUERADE
3月 31 20:39:27 gysl-node2 flanneld[7508]: I0331 20:39:27.744276    7508 iptables.go:155] Adding iptables rule: ! -s 172.17.0.0/16 -d 172.17.24.0/24 -j RETURN
3月 31 20:39:27 gysl-node2 systemd[1]: Started Flanneld overlay address etcd agent.
3月 31 20:39:27 gysl-node2 flanneld[7508]: I0331 20:39:27.766442    7508 iptables.go:155] Adding iptables rule: ! -s 172.17.0.0/16 -d 172.17.0.0/16 -j MASQUERADE
● docker.service - Docker Application Container Engine
   Loaded: loaded (/usr/lib/systemd/system/docker.service; enabled; vendor preset: disabled)
   Active: active (running) since 日 2019-03-31 20:39:28 CST; 10ms ago
     Docs: https://docs.docker.com
 Main PID: 7579 (dockerd)
    Tasks: 8
   Memory: 32.1M
   CGroup: /system.slice/docker.service
           └─7579 /usr/bin/dockerd --bip=172.17.24.1/24 --ip-masq=false --mtu=1450 -H fd:// --containerd=/run/containerd/containerd.sock

3月 31 20:39:27 gysl-node2 dockerd[7579]: time="2019-03-31T20:39:27.843896719+08:00" level=info msg="ClientConn switching balancer to \"pick_first\"" module=grpc
3月 31 20:39:27 gysl-node2 dockerd[7579]: time="2019-03-31T20:39:27.843917442+08:00" level=info msg="pickfirstBalancer: HandleSubConnStateChange: 0xc420154920, CONNECTING" module=grpc
3月 31 20:39:27 gysl-node2 dockerd[7579]: time="2019-03-31T20:39:27.843973658+08:00" level=info msg="pickfirstBalancer: HandleSubConnStateChange: 0xc420154920, READY" module=grpc
3月 31 20:39:27 gysl-node2 dockerd[7579]: time="2019-03-31T20:39:27.844332744+08:00" level=info msg="[graphdriver] using prior storage driver: overlay2"
3月 31 20:39:27 gysl-node2 dockerd[7579]: time="2019-03-31T20:39:27.848229255+08:00" level=info msg="Graph migration to content-addressability took 0.00 seconds"
3月 31 20:39:27 gysl-node2 dockerd[7579]: time="2019-03-31T20:39:27.848828116+08:00" level=info msg="Loading containers: start."
3月 31 20:39:28 gysl-node2 dockerd[7579]: time="2019-03-31T20:39:28.081132437+08:00" level=info msg="Loading containers: done."
3月 31 20:39:28 gysl-node2 dockerd[7579]: time="2019-03-31T20:39:28.167227705+08:00" level=info msg="Docker daemon" commit=774a1f4 graphdriver(s)=overlay2 version=18.09.3
3月 31 20:39:28 gysl-node2 dockerd[7579]: time="2019-03-31T20:39:28.167281411+08:00" level=info msg="Daemon has completed initialization"
3月 31 20:39:28 gysl-node2 dockerd[7579]: time="2019-03-31T20:39:28.175538228+08:00" level=info msg="API listen on /var/run/docker.sock"
Created symlink from /etc/systemd/system/multi-user.target.wants/kubelet.service to /usr/lib/systemd/system/kubelet.service.
Created symlink from /etc/systemd/system/multi-user.target.wants/kube-proxy.service to /usr/lib/systemd/system/kube-proxy.service.
● kubelet.service - Kubernetes Kubelet
   Loaded: loaded (/usr/lib/systemd/system/kubelet.service; enabled; vendor preset: disabled)
   Active: active (running) since 日 2019-03-31 20:39:28 CST; 61ms ago
 Main PID: 7727 (kubelet)
    Tasks: 1
   Memory: 2.1M
   CGroup: /system.slice/kubelet.service
           └─7727 /usr/local/bin/kubelet --logtostderr=true --v=4 --hostname-override=10.1.1.62 --kubeconfig=/etc/kubernetes/conf.d/kubelet.kubeconfig --bootstrap-kubeconfig=/etc/kubernetes/conf.d/bootstrap.kubeconfig --config=/etc/kubernetes/conf.d/kubelet.yaml --cert-dir=/etc/kubernetes/ca.d --pod-infra-container-image=registry.cn-hangzhou.aliyuncs.com/google-containers/pause-amd64:3.0

3月 31 20:39:28 gysl-node2 systemd[1]: Started Kubernetes Kubelet.

● kube-proxy.service - Kubernetes Proxy
   Loaded: loaded (/usr/lib/systemd/system/kube-proxy.service; enabled; vendor preset: disabled)
   Active: active (running) since 日 2019-03-31 20:39:28 CST; 7ms ago
 Main PID: 7728 (systemd)
    Tasks: 0
   Memory: 0B
   CGroup: /system.slice/kube-proxy.service
           └─7728 /usr/lib/systemd/systemd --switched-root --system --deserialize 22
kubelet                                                                                                                                                    100%  122MB  27.7MB/s   00:04    
kube-proxy                                                                                                                                                 100%   35MB  13.8MB/s   00:02    
flanneld                                                                                                                                                   100%   34MB  33.6MB/s   00:01    
mk-docker-opts.sh                                                                                                                                          100% 2139     1.1MB/s   00:00    
flanneld.conf                                                                                                                                              100%  247   225.5KB/s   00:00    
flanneld.service                                                                                                                                           100%  389   357.8KB/s   00:00    
kubelet.yaml                                                                                                                                               100%  263   193.7KB/s   00:00    
kubelet.conf                                                                                                                                               100%  365   331.3KB/s   00:00    
kube-proxy.conf                                                                                                                                            100%  158   130.4KB/s   00:00    
kubelet.service                                                                                                                                            100%  267   295.5KB/s   00:00    
kube-proxy.service                                                                                                                                         100%  234   198.3KB/s   00:00    
bootstrap.kubeconfig                                                                                                                                       100% 2163     2.0MB/s   00:00    
kube-proxy.kubeconfig                                                                                                                                      100% 6265     3.7MB/s   00:00    
Created symlink from /etc/systemd/system/multi-user.target.wants/flanneld.service to /usr/lib/systemd/system/flanneld.service.
● flanneld.service - Flanneld overlay address etcd agent
   Loaded: loaded (/usr/lib/systemd/system/flanneld.service; enabled; vendor preset: disabled)
   Active: active (running) since 日 2019-03-31 20:39:39 CST; 391ms ago
  Process: 7534 ExecStartPost=/usr/local/bin/mk-docker-opts.sh -k DOCKER_NETWORK_OPTIONS -d /run/flannel/subnet.env (code=exited, status=0/SUCCESS)
 Main PID: 7502 (flanneld)
    Tasks: 7
   Memory: 9.3M
   CGroup: /system.slice/flanneld.service
           └─7502 /usr/local/bin/flanneld --ip-masq

3月 31 20:39:39 gysl-node3 flanneld[7502]: I0331 20:39:39.088309    7502 iptables.go:145] Some iptables rules are missing; deleting and recreating rules
3月 31 20:39:39 gysl-node3 flanneld[7502]: I0331 20:39:39.088315    7502 iptables.go:167] Deleting iptables rule: -s 172.17.0.0/16 -d 172.17.0.0/16 -j RETURN
3月 31 20:39:39 gysl-node3 flanneld[7502]: I0331 20:39:39.091984    7502 iptables.go:167] Deleting iptables rule: -s 172.17.0.0/16 ! -d 224.0.0.0/4 -j MASQUERADE
3月 31 20:39:39 gysl-node3 flanneld[7502]: I0331 20:39:39.095011    7502 iptables.go:167] Deleting iptables rule: ! -s 172.17.0.0/16 -d 172.17.100.0/24 -j RETURN
3月 31 20:39:39 gysl-node3 flanneld[7502]: I0331 20:39:39.098419    7502 iptables.go:167] Deleting iptables rule: ! -s 172.17.0.0/16 -d 172.17.0.0/16 -j MASQUERADE
3月 31 20:39:39 gysl-node3 flanneld[7502]: I0331 20:39:39.099751    7502 iptables.go:155] Adding iptables rule: -s 172.17.0.0/16 -d 172.17.0.0/16 -j RETURN
3月 31 20:39:39 gysl-node3 flanneld[7502]: I0331 20:39:39.103532    7502 iptables.go:155] Adding iptables rule: -s 172.17.0.0/16 ! -d 224.0.0.0/4 -j MASQUERADE
3月 31 20:39:39 gysl-node3 flanneld[7502]: I0331 20:39:39.106520    7502 iptables.go:155] Adding iptables rule: ! -s 172.17.0.0/16 -d 172.17.100.0/24 -j RETURN
3月 31 20:39:39 gysl-node3 flanneld[7502]: I0331 20:39:39.113480    7502 iptables.go:155] Adding iptables rule: ! -s 172.17.0.0/16 -d 172.17.0.0/16 -j MASQUERADE
3月 31 20:39:39 gysl-node3 systemd[1]: Started Flanneld overlay address etcd agent.
● docker.service - Docker Application Container Engine
   Loaded: loaded (/usr/lib/systemd/system/docker.service; enabled; vendor preset: disabled)
   Active: active (running) since 日 2019-03-31 20:39:39 CST; 10ms ago
     Docs: https://docs.docker.com
 Main PID: 7573 (dockerd)
    Tasks: 8
   Memory: 31.9M
   CGroup: /system.slice/docker.service
           └─7573 /usr/bin/dockerd --bip=172.17.100.1/24 --ip-masq=false --mtu=1450 -H fd:// --containerd=/run/containerd/containerd.sock

3月 31 20:39:39 gysl-node3 dockerd[7573]: time="2019-03-31T20:39:39.230510356+08:00" level=info msg="ClientConn switching balancer to \"pick_first\"" module=grpc
3月 31 20:39:39 gysl-node3 dockerd[7573]: time="2019-03-31T20:39:39.230556184+08:00" level=info msg="pickfirstBalancer: HandleSubConnStateChange: 0xc420154910, CONNECTING" module=grpc
3月 31 20:39:39 gysl-node3 dockerd[7573]: time="2019-03-31T20:39:39.230711652+08:00" level=info msg="pickfirstBalancer: HandleSubConnStateChange: 0xc420154910, READY" module=grpc
3月 31 20:39:39 gysl-node3 dockerd[7573]: time="2019-03-31T20:39:39.231101930+08:00" level=info msg="[graphdriver] using prior storage driver: overlay2"
3月 31 20:39:39 gysl-node3 dockerd[7573]: time="2019-03-31T20:39:39.234478410+08:00" level=info msg="Graph migration to content-addressability took 0.00 seconds"
3月 31 20:39:39 gysl-node3 dockerd[7573]: time="2019-03-31T20:39:39.234950238+08:00" level=info msg="Loading containers: start."
3月 31 20:39:39 gysl-node3 dockerd[7573]: time="2019-03-31T20:39:39.406988224+08:00" level=info msg="Loading containers: done."
3月 31 20:39:39 gysl-node3 dockerd[7573]: time="2019-03-31T20:39:39.497837879+08:00" level=info msg="Docker daemon" commit=774a1f4 graphdriver(s)=overlay2 version=18.09.3
3月 31 20:39:39 gysl-node3 dockerd[7573]: time="2019-03-31T20:39:39.497901197+08:00" level=info msg="Daemon has completed initialization"
3月 31 20:39:39 gysl-node3 dockerd[7573]: time="2019-03-31T20:39:39.502801194+08:00" level=info msg="API listen on /var/run/docker.sock"
Created symlink from /etc/systemd/system/multi-user.target.wants/kubelet.service to /usr/lib/systemd/system/kubelet.service.
Created symlink from /etc/systemd/system/multi-user.target.wants/kube-proxy.service to /usr/lib/systemd/system/kube-proxy.service.
● kubelet.service - Kubernetes Kubelet
   Loaded: loaded (/usr/lib/systemd/system/kubelet.service; enabled; vendor preset: disabled)
   Active: active (running) since 日 2019-03-31 20:39:39 CST; 58ms ago
 Main PID: 7721 (kubelet)
    Tasks: 1
   Memory: 4.2M
   CGroup: /system.slice/kubelet.service
           └─7721 /usr/local/bin/kubelet --logtostderr=true --v=4 --hostname-override=10.1.1.63 --kubeconfig=/etc/kubernetes/conf.d/kubelet.kubeconfig --bootstrap-kubeconfig=/etc/kubernetes/conf.d/bootstrap.kubeconfig --config=/etc/kubernetes/conf.d/kubelet.yaml --cert-dir=/etc/kubernetes/ca.d --pod-infra-container-image=registry.cn-hangzhou.aliyuncs.com/google-containers/pause-amd64:3.0

3月 31 20:39:39 gysl-node3 systemd[1]: Started Kubernetes Kubelet.

● kube-proxy.service - Kubernetes Proxy
   Loaded: loaded (/usr/lib/systemd/system/kube-proxy.service; enabled; vendor preset: disabled)
   Active: active (running) since 日 2019-03-31 20:39:39 CST; 21ms ago
 Main PID: 7722 (systemd)
    Tasks: 0
   Memory: 0B
   CGroup: /system.slice/kube-proxy.service
           └─7722 /usr/lib/systemd/systemd --switched-root --system --deserialize 22

3月 31 20:39:39 gysl-node3 systemd[1]: Started Kubernetes Proxy.
kubelet                                                                                                                                                    100%  122MB  32.7MB/s   00:03    
kube-proxy                                                                                                                                                 100%   35MB  14.4MB/s   00:02    
flanneld                                                                                                                                                   100%   34MB  30.4MB/s   00:01    
mk-docker-opts.sh                                                                                                                                          100% 2139     3.5MB/s   00:00    
flanneld.conf                                                                                                                                              100%  247   227.9KB/s   00:00    
flanneld.service                                                                                                                                           100%  389   359.0KB/s   00:00    
kubelet.yaml                                                                                                                                               100%  263   197.9KB/s   00:00    
kubelet.conf                                                                                                                                               100%  365   517.1KB/s   00:00    
kube-proxy.conf                                                                                                                                            100%  158   244.5KB/s   00:00    
kubelet.service                                                                                                                                            100%  267   379.4KB/s   00:00    
kube-proxy.service                                                                                                                                         100%  234   324.5KB/s   00:00    
bootstrap.kubeconfig                                                                                                                                       100% 2163   429.6KB/s   00:00    
kube-proxy.kubeconfig                                                                                                                                      100% 6265     4.7MB/s   00:00    
Created symlink from /etc/systemd/system/multi-user.target.wants/flanneld.service to /usr/lib/systemd/system/flanneld.service.
● flanneld.service - Flanneld overlay address etcd agent
   Loaded: loaded (/usr/lib/systemd/system/flanneld.service; enabled; vendor preset: disabled)
   Active: active (running) since 日 2019-03-31 20:39:49 CST; 319ms ago
  Process: 7580 ExecStartPost=/usr/local/bin/mk-docker-opts.sh -k DOCKER_NETWORK_OPTIONS -d /run/flannel/subnet.env (code=exited, status=0/SUCCESS)
 Main PID: 7550 (flanneld)
    Tasks: 7
   Memory: 6.7M
   CGroup: /system.slice/flanneld.service
           └─7550 /usr/local/bin/flanneld --ip-masq

3月 31 20:39:49 gysl-node1 flanneld[7550]: I0331 20:39:49.414921    7550 vxlan_network.go:60] watching for new subnet leases
3月 31 20:39:49 gysl-node1 flanneld[7550]: I0331 20:39:49.415303    7550 iptables.go:167] Deleting iptables rule: ! -s 172.17.0.0/16 -d 172.17.96.0/24 -j RETURN
3月 31 20:39:49 gysl-node1 flanneld[7550]: I0331 20:39:49.416682    7550 iptables.go:167] Deleting iptables rule: ! -s 172.17.0.0/16 -d 172.17.0.0/16 -j MASQUERADE
3月 31 20:39:49 gysl-node1 flanneld[7550]: I0331 20:39:49.418320    7550 iptables.go:155] Adding iptables rule: -s 172.17.0.0/16 -d 172.17.0.0/16 -j RETURN
3月 31 20:39:49 gysl-node1 flanneld[7550]: I0331 20:39:49.438055    7550 iptables.go:155] Adding iptables rule: -d 172.17.0.0/16 -j ACCEPT
3月 31 20:39:49 gysl-node1 flanneld[7550]: I0331 20:39:49.443066    7550 main.go:429] Waiting for 22h59m59.922013672s to renew lease
3月 31 20:39:49 gysl-node1 flanneld[7550]: I0331 20:39:49.443213    7550 iptables.go:155] Adding iptables rule: -s 172.17.0.0/16 ! -d 224.0.0.0/4 -j MASQUERADE
3月 31 20:39:49 gysl-node1 systemd[1]: Started Flanneld overlay address etcd agent.
3月 31 20:39:49 gysl-node1 flanneld[7550]: I0331 20:39:49.459736    7550 iptables.go:155] Adding iptables rule: ! -s 172.17.0.0/16 -d 172.17.96.0/24 -j RETURN
3月 31 20:39:49 gysl-node1 flanneld[7550]: I0331 20:39:49.469674    7550 iptables.go:155] Adding iptables rule: ! -s 172.17.0.0/16 -d 172.17.0.0/16 -j MASQUERADE
● docker.service - Docker Application Container Engine
   Loaded: loaded (/usr/lib/systemd/system/docker.service; enabled; vendor preset: disabled)
   Active: active (running) since 日 2019-03-31 20:39:49 CST; 9ms ago
     Docs: https://docs.docker.com
 Main PID: 7622 (dockerd)
    Tasks: 8
   Memory: 28.6M
   CGroup: /system.slice/docker.service
           └─7622 /usr/bin/dockerd --bip=172.17.96.1/24 --ip-masq=false --mtu=1450 -H fd:// --containerd=/run/containerd/containerd.sock

3月 31 20:39:49 gysl-node1 dockerd[7622]: time="2019-03-31T20:39:49.549105373+08:00" level=info msg="ccResolverWrapper: sending new addresses to cc: [{unix:///run/containerd/containerd.sock 0  <nil>}]" module=grpc
3月 31 20:39:49 gysl-node1 dockerd[7622]: time="2019-03-31T20:39:49.549111902+08:00" level=info msg="ClientConn switching balancer to \"pick_first\"" module=grpc
3月 31 20:39:49 gysl-node1 dockerd[7622]: time="2019-03-31T20:39:49.549148708+08:00" level=info msg="pickfirstBalancer: HandleSubConnStateChange: 0xc420154bb0, CONNECTING" module=grpc
3月 31 20:39:49 gysl-node1 dockerd[7622]: time="2019-03-31T20:39:49.549210269+08:00" level=info msg="pickfirstBalancer: HandleSubConnStateChange: 0xc420154bb0, READY" module=grpc
3月 31 20:39:49 gysl-node1 dockerd[7622]: time="2019-03-31T20:39:49.549578647+08:00" level=info msg="[graphdriver] using prior storage driver: overlay2"
3月 31 20:39:49 gysl-node1 dockerd[7622]: time="2019-03-31T20:39:49.554893473+08:00" level=info msg="Graph migration to content-addressability took 0.00 seconds"
3月 31 20:39:49 gysl-node1 dockerd[7622]: time="2019-03-31T20:39:49.555866350+08:00" level=info msg="Loading containers: start."
3月 31 20:39:49 gysl-node1 dockerd[7622]: time="2019-03-31T20:39:49.695192119+08:00" level=info msg="Loading containers: done."
3月 31 20:39:49 gysl-node1 dockerd[7622]: time="2019-03-31T20:39:49.729225641+08:00" level=info msg="Docker daemon" commit=774a1f4 graphdriver(s)=overlay2 version=18.09.3
3月 31 20:39:49 gysl-node1 dockerd[7622]: time="2019-03-31T20:39:49.729282016+08:00" level=info msg="Daemon has completed initialization"
Created symlink from /etc/systemd/system/multi-user.target.wants/kubelet.service to /usr/lib/systemd/system/kubelet.service.
Created symlink from /etc/systemd/system/multi-user.target.wants/kube-proxy.service to /usr/lib/systemd/system/kube-proxy.service.
● kubelet.service - Kubernetes Kubelet
   Loaded: loaded (/usr/lib/systemd/system/kubelet.service; enabled; vendor preset: disabled)
   Active: active (running) since 日 2019-03-31 20:39:50 CST; 50ms ago
 Main PID: 7770 (kubelet)
    Tasks: 1
   Memory: 2.1M
   CGroup: /system.slice/kubelet.service
           └─7770 /usr/local/bin/kubelet --logtostderr=true --v=4 --hostname-override=10.1.1.61 --kubeconfig=/etc/kubernetes/conf.d/kubelet.kubeconfig --bootstrap-kubeconfig=/etc/kubernetes/conf.d/bootstrap.kubeconfig --config=/etc/kubernetes/conf.d/kubelet.yaml --cert-dir=/etc/kubernetes/ca.d --pod-infra-container-image=registry.cn-hangzhou.aliyuncs.com/google-containers/pause-amd64:3.0

3月 31 20:39:50 gysl-node1 systemd[1]: Started Kubernetes Kubelet.

● kube-proxy.service - Kubernetes Proxy
   Loaded: loaded (/usr/lib/systemd/system/kube-proxy.service; enabled; vendor preset: disabled)
   Active: active (running) since 日 2019-03-31 20:39:50 CST; 20ms ago
 Main PID: 7771 (systemd)
    Tasks: 0
   Memory: 0B
   CGroup: /system.slice/kube-proxy.service
           └─7771 /usr/lib/systemd/systemd --switched-root --system --deserialize 22

3月 31 20:39:50 gysl-node1 systemd[1]: Started Kubernetes Proxy.
[root@gysl-master ~]# kubectl get cs,nodes
NAME                                 STATUS    MESSAGE             ERROR
componentstatus/scheduler            Healthy   ok
componentstatus/controller-manager   Healthy   ok
componentstatus/etcd-0               Healthy   {"health":"true"}
componentstatus/etcd-2               Healthy   {"health":"true"}
componentstatus/etcd-1               Healthy   {"health":"true"}
componentstatus/etcd-3               Healthy   {"health":"true"}

NAME             STATUS   ROLES   AGE     VERSION
node/10.1.1.61   Ready    node    4m23s   v1.14.0
node/10.1.1.62   Ready    node    4m22s   v1.14.0
node/10.1.1.63   Ready    node    4m22s   v1.14.0
```

### 3.3 安装失败回滚脚本

```bash
#!/bin/bash
declare -A HostIP EtcdIP
HostIP=( [gysl-master]='10.1.1.60' [gysl-node1]='10.1.1.61' [gysl-node2]='10.1.1.62' [gysl-node3]='10.1.1.63' )
EtcdIP=( [etcd-master]='10.1.1.60' [etcd-01]='10.1.1.61' [etcd-02]='10.1.1.62' [etcd-03]='10.1.1.63' )
BinaryDir='/usr/local/bin'
KubeConf='/etc/kubernetes/conf.d'
KubeCA='/etc/kubernetes/ca.d'
EtcdConf='/etc/etcd/conf.d'
EtcdCA='/etc/etcd/ca.d'
FlanneldConf='/etc/flanneld'
for node_ip in ${HostIP[@]}
    do
        if [ "${node_ip}" == "${HostIP[gysl-master]}" ] ; then
            ps -ef|grep -e kube -e etcd -e flanneld|grep -v grep|awk '{print $2}'|xargs kill 
            rm -rf {${KubeConf},${KubeCA},${EtcdConf},${EtcdCA},${FlanneldConf}}
            rm -rf ${BinaryDir}/*
        else
            ssh root@${node_ip} "ps -ef|grep -e kube -e etcd -e flanneld|grep -v grep|awk '{print $2}'|xargs kill"
            ssh root@${node_ip} "rm -rf {${KubeConf},${KubeCA},${EtcdConf},${EtcdCA},${FlanneldConf}}"
            ssh root@${node_ip} "rm -rf ${BinaryDir}/* && reboot"
        fi
    done
reboot
```

## 四 总结

通过脚本实现自动化安装是一个良好的习惯，可以达到事半功倍的效果，以后工作中要注意培养这种习惯！
