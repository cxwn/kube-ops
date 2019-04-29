# Kubernetes二进制方式v1.13.2生产环境的安装与配置（HTTPS+RBAC）

## 一 背景

由于众所周知的原因，在国内无法直接访问Google的服务。二进制包由于其下载方便、灵活定制而深受广大kubernetes使用者喜爱，成为企业部署生产环境比较流行的方式之一，Kubernetes v1.13.2是目前的最新版本。安装部署过程可能比较复杂、繁琐，因此在安装过程中尽可能将操作步骤脚本话。文中涉及到的脚本已经通过本人测试。

## 二 环境及架构图

### 2.1 软件环境

OS（最小化安装版）：

```bash
cat /etc/centos-release
```

```text
CentOS Linux release 7.6.1810 (Core)
```

Docker Engine：

```bash
docker version
```

```text
Client:
 Version:           18.06.0-ce
 API version:       1.38
 Go version:        go1.10.3
 Git commit:        0ffa825
 Built:             Wed Jul 18 19:08:18 2018
 OS/Arch:           linux/amd64
 Experimental:      false
Server:
 Engine:
  Version:          18.06.0-ce
  API version:      1.38 (minimum version 1.12)
  Go version:       go1.10.3
  Git commit:       0ffa825
  Built:            Wed Jul 18 19:10:42 2018
  OS/Arch:          linux/amd64
  Experimental:     false
```

Kubenetes：

```bash
kubectl version
```

```text
Client Version: version.Info{Major:"1", Minor:"13", GitVersion:"v1.13.2", GitCommit:"cff46ab41ff0bb44d8584413b598ad8360ec1def", GitTreeState:"clean", BuildDate:"2019-01-10T23:35:51Z", GoVersion:"go1.11.4", Compiler:"gc", Platform:"linux/amd64"}
Server Version: version.Info{Major:"1", Minor:"13", GitVersion:"v1.13.2", GitCommit:"cff46ab41ff0bb44d8584413b598ad8360ec1def", GitTreeState:"clean", BuildDate:"2019-01-10T23:28:14Z", GoVersion:"go1.11.4", Compiler:"gc", Platform:"linux/amd64"}
```

ETCD:

```bash
etcd --version
```

```text
etcd Version: 3.3.11
Git SHA: 2cf9e51d2
Go Version: go1.10.7
Go OS/Arch: linux/amd64
```

Flannel:

```bash
flanneld -version
```

```text
v0.11.0
```

### 2.2 服务器规划

|IP|主机名（Hostname）|角色（Role）|组件（Component）|
|:-:|:-:|:-:|:-:|
|172.31.2.11|gysl-master|Master&Node|**kube-apiserver**，**kube-controller-manager**，**kube-scheduler**，*etcd*，（kubectl），kubelet，kube-proxy，docker，flannel|
|172.31.2.12|gysl-node1|Node|kubelet，kube-proxy，docker，flannel，etcd|
|172.31.2.13|gysl-node2|Node|kubelet，kube-proxy，docker，flannel，etcd|

注：加粗部分是Master节点必须安装的组件，etcd可以部署在其他节点，也可以部署在Master节点，kubectl是管理kubernetes的命令行工具。其余部分是Node节点必选组件。

### 2.3 节点或组件功能简介

Master节点：
Master节点上面主要由四个模块组成，apiserver，schedule，controller-manager，etcd。

apiserver: 负责对外提供RESTful的kubernetes API 的服务，它是系统管理指令的统一接口，任何对资源的增删该查都要交给apiserver处理后再交给etcd。kubectl(kubernetes提供的客户端工具，该工具内部是对kubernetes API的调用）是直接和apiserver交互的。

schedule: 负责调度Pod到合适的Node上，如果把scheduler看成一个黑匣子，那么它的输入是pod和由多个Node组成的列表，输出是Pod和一个Node的绑定。kubernetes目前提供了调度算法，同样也保留了接口。用户根据自己的需求定义自己的调度算法。

controller-manager: 如果apiserver做的是前台的工作的话，那么controller-manager就是负责后台的。每一个资源都对应一个控制器。而control manager就是负责管理这些控制器的，比如我们通过APIServer创建了一个Pod，当这个Pod创建成功后，apiserver的任务就算完成了。

etcd：etcd是一个高可用的键值存储系统，kubernetes使用它来存储各个资源的状态，从而实现了Restful的API。

Node节点：
每个Node节点主要由二个模块组成：kublet, kube-proxy。

kube-proxy: 该模块实现了kubernetes中的服务发现和反向代理功能。kube-proxy支持TCP和UDP连接转发，默认基Round Robin算法将客户端流量转发到与service对应的一组后端pod。服务发现方面，kube-proxy使用etcd的watch机制监控集群中service和endpoint对象数据的动态变化，并且维护一个service到endpoint的映射关系，从而保证了后端pod的IP变化不会对访问者造成影响，另外，kube-proxy还支持session affinity。

kublet：kublet是Master在每个Node节点上面的agent，是Node节点上面最重要的模块，它负责维护和管理该Node上的所有容器，但是如果容器不是通过kubernetes创建的，它并不会管理。本质上，它负责使Pod的运行状态与期望的状态一致。

### 2.4 Kubernetes架构图

![架构图](https://img-blog.csdnimg.cn/20190131142101943.jpg)

### 2.5 Kubernetes工作流程图

![工作流程图](https://img-blog.csdnimg.cn/20190131142519545.jpg)

## 三 操作步骤

### 3.1 针对性初始化设置

在所有主机上执行脚本KubernetesInstall-01.sh，以Master节点为例。

```bash
[root@gysl-master ~]# sh KubernetesInstall-01.sh
```

脚本内容如下：

```bash
#!/bin/bash
# Initialize the machine. This needs to be executed on every machine.
# Add host domain name.
cat>>/etc/hosts<<EOF
172.31.2.11 gysl-master
172.31.2.12 gysl-node1
172.31.2.13 gysl-node2
EOF
# Modify related kernel parameters.
cat>/etc/sysctl.d/kubernetes.conf<<EOF
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
sysctl -p /etc/sysctl.d/kubernetes.conf>&/dev/null
# Turn off and disable the firewalld.
systemctl stop firewalld
systemctl disable firewalld
# Disable the SELinux.
sed -i.bak 's/=enforcing/=disabled/' /etc/selinux/config
# Disable the swap .
sed -i.bak 's/^.*swap/#&/g' /etc/fstab
# Reboot the machine.
reboot
```

### 3.2 安装Docker Engine并设置

在所有主机上执行脚本KubernetesInstall-02.sh，以Master节点为例。

```bash
[root@gysl-master ~]# sh KubernetesInstall-02.sh
```

脚本内容如下：

```bash
#!/bin/bash
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
        yum -y install docker-ce-18.06.0.ce-3.el7
        rm -f /etc/yum.repos.d/docker-ce.repo
        systemctl enable docker && systemctl start docker && systemctl status docker
    else
        echo "Install failed! Please try again! ";
        exit 110
fi
```

**注意：**以上步骤需要在每一个节点上执行。如果启用了swap，那么是需要禁用的（脚本KubernetesInstall-01.sh已有涉及），具体可以通过 free 命令查看详情。另外，还需要关注各个节点上的时间同步情况。

### 3.3 下载相关二进制包

在Master执行脚本KubernetesInstall-03.sh即可进行下载。

```bash
[root@gysl-master ~]# sh KubernetesInstall-03.sh
```

脚本内容如下：

```bash
#!/bin/bash
# Download relevant softwares. Please verify sha512 yourself.
while true;
    do
        echo "Downloading, please wait a moment." &&\
        curl -L -C - -O https://dl.k8s.io/v1.13.2/kubernetes-server-linux-amd64.tar.gz && \
        curl -L -C - -O https://github.com/etcd-io/etcd/releases/download/v3.2.26/etcd-v3.2.26-linux-amd64.tar.gz && \
        curl -L -C - -O https://pkg.cfssl.org/R1.2/cfssl_linux-amd64 && \
        curl -L -C - -O https://pkg.cfssl.org/R1.2/cfssljson_linux-amd64 && \
        curl -L -C - -O https://pkg.cfssl.org/R1.2/cfssl-certinfo_linux-amd64 \
        curl -L -C - -O https://github.com/coreos/flannel/releases/download/v0.11.0/flannel-v0.11.0-linux-amd64.tar.gz
        if [ $? -eq 0 ];
            then
                echo "Congratulations! All software packages have been downloaded."
                break
        fi
    done
```

kubernetes-server-linux-amd64.tar.gz包括了kubernetes的主要组件，无需下载其他包。etcd-v3.2.26-linux-amd64.tar.gz是部署etcd需要用到的包。其余的是cfssl相关的软件，暂不深究。网络原因，只能写脚本来下载了，这个过程可能需要一会儿。

### 3.4 部署etcd集群

#### 3.4.1 创建CA证书

在Master执行脚本KubernetesInstall-04.sh。

```bash
[root@gysl-master ~]# sh KubernetesInstall-04.sh
2019/01/28 16:29:47 [INFO] generating a new CA key and certificate from CSR
2019/01/28 16:29:47 [INFO] generate received request
2019/01/28 16:29:47 [INFO] received CSR
2019/01/28 16:29:47 [INFO] generating key: rsa-2048
2019/01/28 16:29:47 [INFO] encoded CSR
2019/01/28 16:29:47 [INFO] signed certificate with serial number 368034386524991671795323408390048460617296625670
2019/01/28 16:29:47 [INFO] generate received request
2019/01/28 16:29:47 [INFO] received CSR
2019/01/28 16:29:47 [INFO] generating key: rsa-2048
2019/01/28 16:29:48 [INFO] encoded CSR
2019/01/28 16:29:48 [INFO] signed certificate with serial number 714486490152688826461700674622674548864494534798
2019/01/28 16:29:48 [WARNING] This certificate lacks a "hosts" field. This makes it unsuitable for
websites. For more information see the Baseline Requirements for the Issuance and Management
of Publicly-Trusted Certificates, v.1.1.6, from the CA/Browser Forum (https://cabforum.org);
specifically, section 10.2.3 ("Information Requirements").
/etc/etcd/ssl/ca-key.pem  /etc/etcd/ssl/ca.pem  /etc/etcd/ssl/server-key.pem  /etc/etcd/ssl/server.pem
```

脚本内容如下：

```bash
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
```

#### 3.4.2 配置etcd服务

##### 3.4.2.1 在Master节点上进行配置

在Master执行脚本KubernetesInstall-05.sh。

```bash
[root@gysl-master ~]# sh KubernetesInstall-05.sh
```

脚本内容如下：

```bash
#!/bin/bash
# Deploy and configurate etcd service on the master node.
ETCD_CONF=/etc/etcd/etcd.conf
ETCD_SSL=/etc/etcd/ssl
ETCD_SERVICE=/usr/lib/systemd/system/etcd.service
tar -xzf etcd-v3.3.11-linux-amd64.tar.gz
cp -p etcd-v3.3.11-linux-amd64/etc* /usr/local/bin/

# The etcd configuration file.  
cat>$ETCD_CONF<<EOF
#[Member]
ETCD_NAME="etcd-01"
ETCD_DATA_DIR="/var/lib/etcd/default.etcd"
ETCD_LISTEN_PEER_URLS="https://172.31.2.11:2380"
ETCD_LISTEN_CLIENT_URLS="https://172.31.2.11:2379"

#[Clustering]
ETCD_INITIAL_ADVERTISE_PEER_URLS="https://172.31.2.11:2380"
ETCD_ADVERTISE_CLIENT_URLS="https://172.31.2.11:2379"
ETCD_INITIAL_CLUSTER="etcd-01=https://172.31.2.11:2380,etcd-02=https://172.31.2.12:2380,etcd-03=https://172.31.2.13:2380"
ETCD_INITIAL_CLUSTER_TOKEN="etcd-cluster"
ETCD_INITIAL_CLUSTER_STATE="new"
EOF

# The etcd servcie configuration file.
cat>$ETCD_SERVICE<<EOF
[Unit]
Description=Etcd Server
After=network.target
After=network-online.target
Wants=network-online.target

[Service]
Type=notify
EnvironmentFile=$ETCD_CONF
ExecStart=/usr/local/bin/etcd \
--name=\${ETCD_NAME} \
--data-dir=\${ETCD_DATA_DIR} \
--listen-peer-urls=\${ETCD_LISTEN_PEER_URLS} \
--listen-client-urls=\${ETCD_LISTEN_CLIENT_URLS},http://127.0.0.1:2379 \
--advertise-client-urls=\${ETCD_ADVERTISE_CLIENT_URLS} \
--initial-advertise-peer-urls=\${ETCD_INITIAL_ADVERTISE_PEER_URLS} \
--initial-cluster=\${ETCD_INITIAL_CLUSTER} \
--initial-cluster-token=\${ETCD_INITIAL_CLUSTER_TOKEN} \
--initial-cluster-state=new \
--cert-file=/etc/etcd/ssl/server.pem \
--key-file=/etc/etcd/ssl/server-key.pem \
--peer-cert-file=/etc/etcd/ssl/server.pem \
--peer-key-file=/etc/etcd/ssl/server-key.pem \
--trusted-ca-file=/etc/etcd/ssl/ca.pem \
--peer-trusted-ca-file=/etc/etcd/ssl/ca.pem
Restart=on-failure
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable etcd.service --now
systemctl status etcd
```

##### 3.4.2.2 在Node1节点上进行配置

在Node1执行脚本KubernetesInstall-06.sh。

```bash
[root@gysl-master ~]# sh KubernetesInstall-06.sh
```

脚本内容如下：

```bash
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
```

##### 3.4.2.3 在Node2节点上进行配置

在Node2执行脚本KubernetesInstall-07.sh。

```bash
[root@gysl-master ~]# sh KubernetesInstall-07.sh
```

脚本内容如下：

```bash
#!/bin/bash
# Deploy etcd on the node2.
ETCD_SSL=/etc/etcd/ssl
mkdir -p $ETCD_SSL
scp gysl-master:~/etcd-v3.3.11-linux-amd64.tar.gz .
scp gysl-master:$ETCD_SSL/{ca*pem,server*pem} $ETCD_SSL/
scp gysl-master:/etc/etcd/etcd.conf /etc/etcd/
scp gysl-master:/usr/lib/systemd/system/etcd.service /usr/lib/systemd/system/
tar -xvzf etcd-v3.3.11-linux-amd64.tar.gz
mv ~/etcd-v3.3.11-linux-amd64/etcd* /usr/local/bin/
sed -i '/ETCD_NAME/{s/etcd-01/etcd-03/g}' /etc/etcd/etcd.conf
sed -i '/ETCD_LISTEN_PEER_URLS/{s/2.11/2.13/g}' /etc/etcd/etcd.conf
sed -i '/ETCD_LISTEN_CLIENT_URLS/{s/2.11/2.13/g}' /etc/etcd/etcd.conf
sed -i '/ETCD_INITIAL_ADVERTISE_PEER_URLS/{s/2.11/2.13/g}' /etc/etcd/etcd.conf
sed -i '/ETCD_ADVERTISE_CLIENT_URLS/{s/2.11/2.13/g}' /etc/etcd/etcd.conf
rm -rf ~/etcd-v3.3.11-linux-amd64*
systemctl daemon-reload
systemctl enable etcd.service --now
systemctl status etcd
```

几个节点上的安装过程大同小异，唯一不同的是etcd配置文件中的服务器IP要写当前节点的IP。主要参数：

- ETCD_NAME：节点名称。
- ETCD_DATA_DIR：数据目录。
- ETCD_LISTEN_PEER_URLS：集群通信监听地址。
- ETCD_LISTEN_CLIENT_URLS：客户端访问监听地址。
- ETCD_INITIAL_ADVERTISE_PEER_URLS：集群通告地址。
- ETCD_ADVERTISE_CLIENT_URLS：客户端通告地址。
- ETCD_INITIAL_CLUSTER：集群节点地址。
- ETCD_INITIAL_CLUSTER_TOKEN：集群Token。
- ETCD_INITIAL_CLUSTER_STATE：加入集群的当前状态，new是新集群，existing表示加入已有集群。

#### 3.4.3 验证etcd集群是否部署成功

执行以下命令：

```bash
[root@gysl-master ~]# etcdctl \
--ca-file=/etc/etcd/ssl/ca.pem \
--cert-file=/etc/etcd/ssl/server.pem \
--key-file=/etc/etcd/ssl/server-key.pem \
--endpoints="https://172.31.2.11:2379,https://172.31.2.12:2379,https://172.31.2.13:2379" cluster-health
member 82184ce461853bed is healthy: got healthy result from https://172.31.2.12:2379
member d85d48cef1ccfeaf is healthy: got healthy result from https://172.31.2.13:2379
member fe6e7c664377ad3b is healthy: got healthy result from https://172.31.2.11:2379
cluster is healthy
```

"cluster is healthy"说明etcd集群部署成功！如果存在问题，那么首先看日志：/var/log/message 或 journalctl -u etcd，找到问题，逐一解决。命令看起来不是那么直观，可以直接复制下面的命令来进行检验：

```bash
etcdctl \
--ca-file=/etc/etcd/ssl/ca.pem \
--cert-file=/etc/etcd/ssl/server.pem \
--key-file=/etc/etcd/ssl/server-key.pem \
--endpoints="https://172.31.2.11:2379,https://172.31.2.12:2379,https://172.31.2.13:2379" cluster-health
```

### 3.5 部署Flannel网络

由于Flannel需要使用etcd存储自身的一个子网信息，所以要保证能成功连接Etcd，写入预定义子网段。写入的Pod网段${CLUSTER_CIDR}必须是/16段地址，必须与kube-controller-manager的–-cluster-cidr参数值一致。一般情况下，在每一个Node节点都需要进行配置，执行脚本KubernetesInstall-08.sh。

```bash
[root@gysl-master ~]# sh KubernetesInstall-08.sh
```

脚本内容如下：

```bash
#!/bin/bash
KUBE_CONF=/etc/kubernetes
FLANNEL_CONF=$KUBE_CONF/flannel.conf
mkdir $KUBE_CONF
tar -xvzf flannel-v0.11.0-linux-amd64.tar.gz
mv {flanneld,mk-docker-opts.sh} /usr/local/bin/
# Check whether etcd cluster is healthy.
etcdctl \
--ca-file=/etc/etcd/ssl/ca.pem \
--cert-file=/etc/etcd/ssl/server.pem \
--key-file=/etc/etcd/ssl/server-key.pem \
--endpoints="https://172.31.2.11:2379,\
https://172.31.2.12:2379,\
https://172.31.2.13:2379" cluster-health

# Writing into a predetermined subnetwork.
cd /etc/etcd/ssl
etcdctl \
--ca-file=ca.pem --cert-file=server.pem --key-file=server-key.pem \
--endpoints="https://172.31.2.11:2379,https://172.31.2.12:2379,https://172.31.2.13:2379" \
set /coreos.com/network/config  '{ "Network": "172.17.0.0/16", "Backend": {"Type": "vxlan"}}'
cd ~

# Configuration the flannel service.
cat>$FLANNEL_CONF<<EOF
FLANNEL_OPTIONS="--etcd-endpoints=https://172.31.2.11:2379,https://172.31.2.12:2379,https://172.31.2.13:2379 -etcd-cafile=/etc/etcd/ssl/ca.pem -etcd-certfile=/etc/etcd/ssl/server.pem -etcd-keyfile=/etc/etcd/ssl/server-key.pem"
EOF
cat>/usr/lib/systemd/system/flanneld.service<<EOF
[Unit]
Description=Flanneld overlay address etcd agent
After=network-online.target network.target
Before=docker.service

[Service]
Type=notify
EnvironmentFile=$FLANNEL_CONF
ExecStart=/usr/local/bin/flanneld --ip-masq $FLANNEL_OPTIONS
ExecStartPost=/usr/local/bin/mk-docker-opts.sh -k DOCKER_NETWORK_OPTIONS -d /run/flannel/subnet.env
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

# Modify the docker service.
sed -i.bak -e '/ExecStart/i EnvironmentFile=\/run\/flannel\/subnet.env' -e 's/ExecStart=\/usr\/bin\/dockerd/ExecStart=\/usr\/bin\/dockerd $DOCKER_NETWORK_OPTIONS/g' /usr/lib/systemd/system/docker.service

# Start or restart related services.
systemctl daemon-reload
systemctl enable flanneld --now
systemctl restart docker
systemctl status flanneld
systemctl status docker
ip address show
```

在脚本执行之前需要把Flannel安装包拷贝到用户的HOME目录。脚本执行完毕之后需要检查各服务的状态，确保docker0和flannel.1在同一网段。

### 3.6 部署Master节点

#### 3.6.1 创建CA证书

这一步中创建了kube-apiserver和kube-proxy相关的CA证书，在Master节点执行脚本KubernetesInstall-09.sh。

```bash
[root@gysl-master ~]# sh KubernetesInstall-09.sh
```

脚本内容如下：

```bash
#!/bin/bash
# Deploy the master node.
KUBE_SSL=/etc/kubernetes/ssl
mkdir $KUBE_SSL

# Create CA.
cat>$KUBE_SSL/ca-config.json<<EOF
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
cat>$KUBE_SSL/ca-csr.json<<EOF
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
cat>$KUBE_SSL/server-csr.json<<EOF
{
    "CN": "kubernetes",
    "hosts": [
      "10.0.0.1",
      "127.0.0.1",
      "172.31.2.11",
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
cd $KUBE_SSL
cfssl_linux-amd64 gencert -initca ca-csr.json | cfssljson_linux-amd64 -bare ca -
cfssl_linux-amd64 gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=kubernetes server-csr.json | cfssljson_linux-amd64 -bare server

# Create kube-proxy CA.
cat>$KUBE_SSL/kube-proxy-csr.json<<EOF
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
cfssl_linux-amd64 gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=kubernetes kube-proxy-csr.json | cfssljson_linux-amd64 -bare kube-proxy
ls *.pem
cd ~
```

执行完毕之后应该看到以下文件：
/etc/kubernetes/ssl/ca-key.pem  /etc/kubernetes/ssl/kube-proxy-key.pem  /etc/kubernetes/ssl/server-key.pem
/etc/kubernetes/ssl/ca.pem      /etc/kubernetes/ssl/kube-proxy.pem      /etc/kubernetes/ssl/server.pem

#### 3.6.2 安装配置kube-apiserver服务

将备好的安装包解压，并移动到相关目录，进行相关配置，执行脚本KubernetesInstall-10.sh。

```bash
[root@gysl-master ~]# sh KubernetesInstall-10.sh
```

脚本内容如下：

```bash
#!/bin/bash
KUBE_ETC=/etc/kubernetes
KUBE_API_CONF=/etc/kubernetes/apiserver.conf
tar -xvzf kubernetes-server-linux-amd64.tar.gz
mv kubernetes/server/bin/{kube-apiserver,kube-scheduler,kube-controller-manager} /usr/local/bin/

# Create a token file.
cat>$KUBE_ETC/token.csv<<EOF
$(head -c 16 /dev/urandom | od -An -t x | tr -d ' '),kubelet-bootstrap,10001,"system:kubelet-bootstrap"
EOF

# Create a kube-apiserver configuration file.
cat >$KUBE_API_CONF<<EOF
KUBE_APISERVER_OPTS="--logtostderr=true \
--v=4 \
--etcd-servers=https://172.31.2.11:2379,https://172.31.2.12:2379,https://172.31.2.13:2379 \
--bind-address=172.31.2.11 \
--secure-port=6443 \
--advertise-address=172.31.2.11 \
--allow-privileged=true \
--service-cluster-ip-range=10.0.0.0/24 \
--enable-admission-plugins=NamespaceLifecycle,LimitRanger,SecurityContextDeny,ServiceAccount,ResourceQuota,NodeRestriction \
--authorization-mode=RBAC,Node \
--enable-bootstrap-token-auth \
--token-auth-file=$KUBE_ETC/token.csv \
--service-node-port-range=30000-50000 \
--tls-cert-file=$KUBE_ETC/ssl/server.pem  \
--tls-private-key-file=$KUBE_ETC/ssl/server-key.pem \
--client-ca-file=$KUBE_ETC/ssl/ca.pem \
--service-account-key-file=$KUBE_ETC/ssl/ca-key.pem \
--etcd-cafile=/etc/etcd/ssl/ca.pem \
--etcd-certfile=/etc/etcd/ssl/server.pem \
--etcd-keyfile=/etc/etcd/ssl/server-key.pem"
EOF

# Create the kube-apiserver service.
cat>/usr/lib/systemd/system/kube-apiserver.service<<EOF
[Unit]
Description=Kubernetes API Server
Documentation=https://github.com/kubernetes/kubernetes
After=etcd.service
Wants=etcd.service

[Service]
EnvironmentFile=-$KUBE_API_CONF
ExecStart=/usr/local/bin/kube-apiserver \$KUBE_APISERVER_OPTS
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable kube-apiserver.service --now
systemctl status kube-apiserver.service
```

参数说明：

- --logtostderr：启用日志。
- --v：日志等级。
- --etcd-servers：etcd集群地址。
- --bind-address：监听地址。
- --secure-port：https安全端口。
- --advertise-address：集群通告地址。
- --allow-privileged：启用授权。
- --service-cluster-ip-range：Service虚拟IP地址段。
- --enable-admission-plugins：准入控制模块。
- --authorization-mode：认证授权，启用RBAC授权和节点自管理。
- --enable-bootstrap-token-auth：启用TLS bootstrap功能。
- --token-auth-file：token文件。
- --service-node-port-range：Service Node类型默认分配端口范围。

#### 3.6.3 安装配置kube-scheduler服务

之前已经将kube-scheduler相关的二进制文件移动到了相关目录，直接执行脚本KubernetesInstall-11.sh。

```bash
[root@gysl-master ~]# sh KubernetesInstall-11.sh
```

脚本内容如下：

```bash
#!/bin/bash
# Deploy the scheduler service.
KUBE_ETC=/etc/kubernetes
KUBE_SCHEDULER_CONF=$KUBE_ETC/kube-scheduler.conf
cat>$KUBE_SCHEDULER_CONF<<EOF
KUBE_SCHEDULER_OPTS="--logtostderr=true \\
--v=4 \\
--master=127.0.0.1:8080 \\
--leader-elect"
EOF

cat>/usr/lib/systemd/system/kube-scheduler.service<<EOF
[Unit]
Description=Kubernetes Scheduler
Documentation=https://github.com/kubernetes/kubernetes

[Service]
EnvironmentFile=-$KUBE_SCHEDULER_CONF
ExecStart=/usr/local/bin/kube-scheduler \$KUBE_SCHEDULER_OPTS
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable kube-scheduler.service --now
sleep 20
systemctl status kube-scheduler.service
```

参数说明：

- --master：连接本地apiserver。
- --leader-elect：当该组件启动多个时，自动选举（HA），被选为 leader的节点负责处理工作，其它节点为阻塞状态。

#### 3.6.4 安装配置kube-controller服务

之前已经将kube-scheduler相关的二进制文件移动到了相关目录，直接执行脚本KubernetesInstall-12.sh。

```bash
[root@gysl-master ~]# sh KubernetesInstall-12.sh
```

脚本内容如下：

```bash
#!/bin/bash
# Deploy the controller-manager service.
KUBE_CONTROLLER_CONF=/etc/kubernetes/kube-controller-manager.conf

cat>$KUBE_CONTROLLER_CONF<<EOF
KUBE_CONTROLLER_MANAGER_OPTS="--logtostderr=true \
--v=4 \
--master=127.0.0.1:8080 \
--leader-elect=true \
--address=127.0.0.1 \
--service-cluster-ip-range=10.0.0.0/24 \
--cluster-name=kubernetes \
--cluster-signing-cert-file=/etc/kubernetes/ssl/ca.pem \
--cluster-signing-key-file=/etc/kubernetes/ssl/ca-key.pem  \
--root-ca-file=/etc/kubernetes/ssl/ca.pem \
--service-account-private-key-file=/etc/kubernetes/ssl/ca-key.pem"
EOF

cat>/usr/lib/systemd/system/kube-controller-manager.service<<EOF
[Unit]
Description=Kubernetes Controller Manager
Documentation=https://github.com/kubernetes/kubernetes

[Service]
EnvironmentFile=-$KUBE_CONTROLLER_CONF
ExecStart=/usr/local/bin/kube-controller-manager \$KUBE_CONTROLLER_MANAGER_OPTS
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable kube-controller-manager.service --now
sleep 20
systemctl status kube-controller-manager.service
```

#### 3.6.5 查看集群状态

直接执行脚本KubernetesInstall-13.sh。

```bash
[root@gysl-master ~]# sh KubernetesInstall-13.sh
```

脚本内容如下：

```bash
#!/bin/bash
# Check the service.
mv kubernetes/server/bin/kubectl /usr/local/bin/
kubectl get cs
```

如果部署成功的话，将看到如下结果：

```bash
[root@gysl-master ~]# kubectl get cs
NAME                 STATUS    MESSAGE             ERROR
controller-manager   Healthy   ok
scheduler            Healthy   ok
etcd-2               Healthy   {"health":"true"}
etcd-0               Healthy   {"health":"true"}
etcd-1               Healthy   {"health":"true"}
```

### 3.7 部署Node节点

#### 3.7.1 创建bootstrap和kube-proxy的kubeconfig文件

Master apiserver启用TLS认证后，Node节点kubelet组件想要加入集群，必须使用CA签发的有效证书才能与apiserver通信，当Node节点很多时，签署证书是一件很繁琐的事情，因此有了TLS Bootstrapping机制，kubelet会以一个低权限用户自动向apiserver申请证书，kubelet的证书由apiserver动态签署。在前面创建的token文件在这一步派上了用场，在Master节点上执行脚本KubernetesInstall-14.sh创建bootstrap.kubeconfig和kube-proxy.kubeconfig。

```bash
[root@gysl-master ~]# sh KubernetesInstall-14.sh
```

脚本内容如下：

```bash
#!/bin/bash
BOOTSTRAP_TOKEN=$(awk -F "," '{print $1}' /etc/kubernetes/token.csv)
KUBE_SSL=/etc/kubernetes/ssl/
KUBE_APISERVER="https://172.31.2.11:6443"

cd $KUBE_SSL
# Set cluster parameters.
kubectl config set-cluster kubernetes \
  --certificate-authority=./ca.pem \
  --embed-certs=true \
  --server=${KUBE_APISERVER} \
  --kubeconfig=bootstrap.kubeconfig

# Set client parameters.
kubectl config set-credentials kubelet-bootstrap \
  --token=${BOOTSTRAP_TOKEN} \
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
  --server=${KUBE_APISERVER} \
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
cd ~

# Bind kubelet-bootstrap user to system cluster roles.
kubectl create clusterrolebinding kubelet-bootstrap \
  --clusterrole=system:node-bootstrapper \
  --user=kubelet-bootstrap
```

#### 3.7.2 配置kube-proxy和kubelet服务

因为kubernetes-server-linux-amd64.tar.gz已经在Master节点的HOME目录解压，所以可以在各节点上执行脚本KubernetesInstall-15.sh。

```bash
[root@gysl-node1 ~]# sh KubernetesInstall-15.sh
```

脚本内容如下：

```bash
#!/bin/bash
KUBE_CONF=/etc/kubernetes
KUBE_SSL=$KUBE_CONF/ssl
IP=172.31.2.13
mkdir $KUBE_SSL
scp gysl-master:~/kubernetes/server/bin/{kube-proxy,kubelet} /usr/local/bin/
scp gysl-master:$KUBE_CONF/ssl/{bootstrap.kubeconfig,kube-proxy.kubeconfig} $KUBE_CONF
cat>$KUBE_CONF/kube-proxy.conf<<EOF
KUBE_PROXY_OPTS="--logtostderr=true \
--v=4 \
--hostname-override=$IP \
--cluster-cidr=10.0.0.0/24 \
--kubeconfig=$KUBE_CONF/kube-proxy.kubeconfig"
EOF
cat>/usr/lib/systemd/system/kube-proxy.service<<EOF
[Unit]
Description=Kubernetes Proxy
After=network.target

[Service]
EnvironmentFile=-$KUBE_CONF/kube-proxy.conf
ExecStart=/usr/local/bin/kube-proxy \$KUBE_PROXY_OPTS
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable kube-proxy.service --now
sleep 20
systemctl status kube-proxy.service -l
cat>$KUBE_CONF/kubelet.yaml<<EOF
kind: KubeletConfiguration
apiVersion: kubelet.config.k8s.io/v1beta1
address: $IP
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
cat>$KUBE_CONF/kubelet.conf<<EOF
KUBELET_OPTS="--logtostderr=true \
--v=4 \
--hostname-override=$IP \
--kubeconfig=$KUBE_CONF/kubelet.kubeconfig \
--bootstrap-kubeconfig=$KUBE_CONF/bootstrap.kubeconfig \
--config=$KUBE_CONF/kubelet.yaml \
--cert-dir=$KUBE_SSL \
--pod-infra-container-image=registry.cn-hangzhou.aliyuncs.com/google-containers/pause-amd64:3.0"
EOF
cat>/usr/lib/systemd/system/kubelet.service<<EOF
[Unit]
Description=Kubernetes Kubelet
After=docker.service
Requires=docker.service

[Service]
EnvironmentFile=$KUBE_CONF/kubelet.conf
ExecStart=/usr/local/bin/kubelet \$KUBELET_OPTS
Restart=on-failure
KillMode=process

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable kubelet.service --now
sleep 20
systemctl status kubelet.service -l
```

以上脚本有多少个Node节点就在相应的Node节点上执行多少次，每次执行只需修改IP的值即可。

参数说明：

- --hostname-override：在集群中显示的主机名。
- --kubeconfig：指定kubeconfig文件位置，会自动生成。
- --bootstrap-kubeconfig：指定刚才生成的bootstrap.kubeconfig文件。
- --cert-dir：颁发证书存放位置。
- --pod-infra-container-image：管理Pod网络的镜像。

#### 3.7.3 Approve kubelet CSR请求

可以手动或自动approve CSR请求。推荐使用自动的方式，因为从 v1.8 版本开始，可以自动轮转approve csr后生成的证书。未approve之前如下：

```bash
[root@gysl-master ~]# kubectl get csr
NAME                                                   AGE   REQUESTOR           CONDITION
node-csr-FpTP2sCI0SiYDCxaIHa1SRukS_5u9BQN10BsTd6RU1Y   20m   kubelet-bootstrap   Pending
node-csr-YYfnPwAws2LxJzV-OgYjJ22zy_z9XQM8PT0MnqZN910   24m   kubelet-bootstrap   Pending
```

在Master节点上执行脚本KubernetesInstall-15.sh。

```bash
[root@gysl-master ~]# sh KubernetesInstall-15.sh
certificatesigningrequest.certificates.k8s.io/node-csr-FpTP2sCI0SiYDCxaIHa1SRukS_5u9BQN10BsTd6RU1Y approved
certificatesigningrequest.certificates.k8s.io/node-csr-YYfnPwAws2LxJzV-OgYjJ22zy_z9XQM8PT0MnqZN910 approved
```

脚本内容如下：

```bash
#!/bin/bash
CSRs=$(kubectl get csr | awk '{if(NR>1) print $1}')
for csr in ${CSRS[*]}
  do
    kubectl certificate approve $csr;
  done
```

#### 3.7.4 查看集群状态

```bash
[root@gysl-master ~]# kubectl get cs
NAME                 STATUS    MESSAGE             ERROR
controller-manager   Healthy   ok
scheduler            Healthy   ok
etcd-2               Healthy   {"health":"true"}
etcd-1               Healthy   {"health":"true"}
etcd-0               Healthy   {"health":"true"}
[root@gysl-master ~]# kubectl get node
NAME          STATUS   ROLES    AGE   VERSION
172.31.2.12   Ready    <none>   11m   v1.13.2
172.31.2.13   Ready    <none>   11m   v1.13.2
```

### 3.8 运行一个测试

```bash
[root@gysl-master ~]#  kubectl run nginx --image=nginx --replicas=3
kubectl run --generator=deployment/apps.v1 is DEPRECATED and will be removed in a future version. Use kubectl run --generator=run-pod/v1 or kubectl create instead.
deployment.apps/nginx created
[root@gysl-master ~]# kubectl expose deployment nginx --port=88 --target-port=80 --type=NodePort
service/nginx exposed
[root@gysl-master ~]# kubectl get pods
NAME                     READY   STATUS              RESTARTS   AGE
nginx-7cdbd8cdc9-7h946   0/1     ContainerCreating   0          33s
nginx-7cdbd8cdc9-vtkqf   0/1     ContainerCreating   0          33s
nginx-7cdbd8cdc9-wdjtj   0/1     ContainerCreating   0          33s
[root@gysl-master ~]# kubectl get svc
NAME         TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)        AGE
kubernetes   ClusterIP   10.0.0.1     <none>        443/TCP        8h
nginx        NodePort    10.0.0.2     <none>        88:46705/TCP   28s
[root@gysl-master ~]# kubectl get pods
NAME                     READY   STATUS    RESTARTS   AGE
nginx-7cdbd8cdc9-7h946   1/1     Running   0          2m4s
nginx-7cdbd8cdc9-vtkqf   1/1     Running   0          2m4s
nginx-7cdbd8cdc9-wdjtj   1/1     Running   0          2m4s
```

```bash
[root@gysl-node1 ~]# curl http://10.0.0.2:88
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
    body {
        width: 35em;
        margin: 0 auto;
        font-family: Tahoma, Verdana, Arial, sans-serif;
    }
</style>
</head>
<body>
<h1>Welcome to nginx!</h1>
<p>If you see this page, the nginx web server is successfully installed and
working. Further configuration is required.</p>

<p>For online documentation and support please refer to
<a href="http://nginx.org/">nginx.org</a>.<br/>
Commercial support is available at
<a href="http://nginx.com/">nginx.com</a>.</p>

<p><em>Thank you for using nginx.</em></p>
</body>
</html>
```

如果此时在浏览器输入：<http://10.0.0.2:88> ，那么将出现nginx的默认页面。

### 3.9 在Master节点部署Node节点的相关组件

资源比较充裕的情况下，Master节点仅仅做为服务接口、调度、控制节点，必须部署的组件有：kube-apiserver、kube-controller-manager、kube-scheduler、kubectl、etcd。除此之外，一般还需要做HA等相关部署。如果Master节点资源比较充裕，有些实验也要求至少有三个节点在运行，那么也可以将Master节点部署设置为一般Node节点来使用。为此，直接执行脚本KubernetesInstall-17.sh。

```bash
[root@gysl-master ~]# KubernetesInstall-17.sh
```

脚本内容如下：

```bash
#!/bin/bash
KUBE_CONF=/etc/kubernetes
KUBE_SSL=$KUBE_CONF/ssl
IP=172.31.2.11
mkdir $KUBE_SSL
cp ~/kubernetes/server/bin/{kube-proxy,kubelet} /usr/local/bin/
cp $KUBE_CONF/ssl/{bootstrap.kubeconfig,kube-proxy.kubeconfig} $KUBE_CONF
cat>$KUBE_CONF/kube-proxy.conf<<EOF
KUBE_PROXY_OPTS="--logtostderr=true \
--v=4 \
--hostname-override=$IP \
--cluster-cidr=10.0.0.0/24 \
--kubeconfig=$KUBE_CONF/kube-proxy.kubeconfig"
EOF
cat>/usr/lib/systemd/system/kube-proxy.service<<EOF
[Unit]
Description=Kubernetes Proxy
After=network.target

[Service]
EnvironmentFile=-$KUBE_CONF/kube-proxy.conf
ExecStart=/usr/local/bin/kube-proxy \$KUBE_PROXY_OPTS
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable kube-proxy.service --now
sleep 20
systemctl status kube-proxy.service -l
cat>$KUBE_CONF/kubelet.yaml<<EOF
kind: KubeletConfiguration
apiVersion: kubelet.config.k8s.io/v1beta1
address: $IP
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
cat>$KUBE_CONF/kubelet.conf<<EOF
KUBELET_OPTS="--logtostderr=true \
--v=4 \
--hostname-override=$IP \
--kubeconfig=$KUBE_CONF/kubelet.kubeconfig \
--bootstrap-kubeconfig=$KUBE_CONF/bootstrap.kubeconfig \
--config=$KUBE_CONF/kubelet.yaml \
--cert-dir=$KUBE_SSL \
--pod-infra-container-image=registry.cn-hangzhou.aliyuncs.com/google-containers/pause-amd64:3.0"
EOF
cat>/usr/lib/systemd/system/kubelet.service<<EOF
[Unit]
Description=Kubernetes Kubelet
After=docker.service
Requires=docker.service

[Service]
EnvironmentFile=$KUBE_CONF/kubelet.conf
ExecStart=/usr/local/bin/kubelet \$KUBELET_OPTS
Restart=on-failure
KillMode=process

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable kubelet.service --now
sleep 20
systemctl status kubelet.service -l

kubectl certificate approve $(kubectl get csr | awk '{if(NR>1) print $1}')
kubectl get csr
kubectl label node 172.31.2.11  node-role.kubernetes.io/master='master'
kubectl label node 172.31.2.12  node-role.kubernetes.io/node='node'
kubectl label node 172.31.2.13  node-role.kubernetes.io/node='node'
kubectl get nodes
```

部署成功之后，将出现以下内容：

```text
NAME          STATUS   ROLES    AGE   VERSION
172.31.2.11   Ready    master   22m   v1.13.2
172.31.2.12   Ready    node     11h   v1.13.2
172.31.2.13   Ready    node     11h   v1.13.2
```

## 四 总结

4.1 Kubernetes的二进制安装部署是一个比较复杂的过程，其中涉及到的步骤比较多，需要理解清楚各节点及组件之间的关系，逐步进行，每一个步骤成功了再进行下一步，切不可急躁。

4.2 在安装部署的过程中，日志及帮助信息是十分重要的，journalctl命令较为常用，--help也会起到柳暗花明又一村的效果。

4.3 把执行步骤脚本化，显得清晰有效，在后续的工作、学习过程中要继续保持。

4.4 由于时间仓促，安装部署中的很多个性化配置并未配置，在后续过程中会根据实际使用情况进行完善。比如：每一个服务或组件并未将日志单独保存。

4.5 其他不尽如人意的地方正在完善。

4.6 文中的两张图片来源于互联网，如有侵权，请联系删除。

## 五 参考资料

5.1 [认证相关](https://k8smeetup.github.io/docs/admin/kubelet-authentication-authorization/)

5.2 [证书相关](https://kubernetes.io/zh/docs/concepts/cluster-administration/certificates/)

5.3 [cfssl官方资料](https://blog.cloudflare.com/introducing-cfssl/)

5.4 [Systemd相关资料](https://wiki.archlinux.org/index.php/systemd_(%E7%AE%80%E4%BD%93%E4%B8%AD%E6%96%87))

5.5 [Kubernetes基本概念](https://kubernetes.io/zh/docs/concepts/)

5.6 [本文涉及到的脚本及配置文件](https://github.com/mrivandu/Kubernetes-DevOps/tree/master/KubernetesInstall)
