# 通过二进制包一键部署 Kubernetes v1.15.0 集群

## 一 概述

Kubernetes目前有两种较为流行的安装方式：二进制和Kubeadm。二进制安装过程有利于大家理解Kubernetes各组件的原理和详细配置过程，安装包容易获取，不需要科学上网即可完成全部组件的下载。但是操作过程复杂而且冗长，令众多初学者望而生畏。在解决了网络问题后，Kubeadm这种安装方式非常简单快捷，唯一的缺点是不利于初学者理解Kubernetes各组件的原理与详细配置过程。两种安装方案均能用于生产环境，根据实际情况选择即可。

## 二 使用说明

### 2.1 前提条件及组件安装规划

脚执行后会删除或修改相关目录之前已经存在的文件或内容，无需手动处理。如需备份，请在脚本执行之前操作。相关操作路径可以在 kube_config.sh 文件中查看。

操作系统|Docker版本|Kubernetes版本|Etcd版本|Flannel版本|CoreDNS
:-:|:-:|:-:|:-:|:-:|:-:
CentOS Linux release 7.6.1810|Docker version 18.09.7|v1.15.0|Version: 3.3.13|v0.11.0|v.1.5.0

---

|IP|主机名（Hostname）|角色（Role）|组件（Component）|
|:-:|:-:|:-:|:-:|
|172.31.2.10|gysl-master|Master|**kube-apiserver**，**kube-controller-manager**，**kube-scheduler**，*etcd*，kubectl, docker,flannel|
|172.31.2.11|gysl-node1|Node|kubelet，kube-proxy，docker，flannel，*etcd*|
|172.31.2.12|gysl-node2|Node|kubelet，kube-proxy，docker，flannel，*etcd*|

### 2.2 源码目录结构

```tree
kubernetes-all-in-one/
├── configurations
│   ├── master
│   │   ├── etcd
│   │   │   ├── ca.d
│   │   │   │   ├── ca-config.json
│   │   │   │   ├── ca.csr
│   │   │   │   ├── ca-csr.json
│   │   │   │   ├── ca-key.pem
│   │   │   │   ├── ca.pem
│   │   │   │   ├── server.csr
│   │   │   │   ├── server-csr.json
│   │   │   │   ├── server-key.pem
│   │   │   │   └── server.pem
│   │   │   └── conf.d
│   │   │       └── etcd.conf
│   │   └── kubernetes
│   │       ├── ca.d
│   │       │   ├── bootstrap.kubeconfig
│   │       │   ├── ca-config.json
│   │       │   ├── ca.csr
│   │       │   ├── ca-csr.json
│   │       │   ├── ca-key.pem
│   │       │   ├── ca.pem
│   │       │   ├── kube-proxy.csr
│   │       │   ├── kube-proxy-csr.json
│   │       │   ├── kube-proxy-key.pem
│   │       │   ├── kube-proxy.kubeconfig
│   │       │   ├── kube-proxy.pem
│   │       │   ├── server.csr
│   │       │   ├── server-csr.json
│   │       │   ├── server-key.pem
│   │       │   ├── server.pem
│   │       │   └── token.csv
│   │       └── conf.d
│   │           ├── kube-apiserver.conf
│   │           ├── kube-controller-manager.conf
│   │           └── kube-scheduler.conf
│   └── node
│       ├── docker
│       │   ├── daemon.json
│       │   └── key.json
│       ├── etcd
│       │   ├── ca.d
│       │   │   ├── ca-key.pem
│       │   │   ├── ca.pem
│       │   │   ├── server-key.pem
│       │   │   └── server.pem
│       │   └── conf.d
│       │       └── etcd.conf
│       ├── flanneld.d
│       │   └── flanneld.conf
│       └── kubernetes
│           ├── ca.d
│           │   ├── kubelet-client-2019-07-11-17-25-43.pem
│           │   ├── kubelet-client-current.pem
│           │   ├── kubelet.crt
│           │   └── kubelet.key
│           └── conf.d
│               ├── bootstrap.kubeconfig
│               ├── kubelet.conf
│               ├── kubelet.kubeconfig
│               ├── kubelet.yaml
│               ├── kube-proxy.conf
│               └── kube-proxy.kubeconfig
├── coredns_installation.sh
├── docker_installation.sh
├── etcd_cluster_installation.sh
├── flannel_installation.sh
├── kube_api_installation.sh
├── kube_config.sh
├── kube_controller_installation.sh
├── kube_installation.sh
├── kubelet_installation.sh
├── kube_proxy_installation.sh
├── kube_scheduler_installation.sh
├── modules
│   ├── coredns.yaml
│   ├── create_etcd_ca.sh
│   ├── create_etcd_config.sh
│   ├── create_flanneld_config.sh
│   ├── create_kube_api_config.sh
│   ├── create_kube_ca.sh
│   ├── create_kubeconfig.sh
│   ├── create_kube_controller_config.sh
│   ├── create_kubelet_config.sh
│   ├── create_kube_proxy_config.sh
│   ├── create_kube_scheduler_config.sh
│   ├── deploy_coredns.sh
│   ├── init.sh
│   ├── last_config.sh
│   ├── no_passwd_login.sh
│   └── unzip_pkgs.sh
├── pkgs
│   ├── cfssl-v1.2-linux-amd64.tar.gz
│   ├── etcd-v3.3.13-linux-amd64.tar.gz
│   ├── flannel-v0.11.0-linux-amd64.tar.gz
│   ├── kubernetes-v1.15.0-linux-amd64-1.tar.gz
│   ├── kubernetes-v1.15.0-linux-amd64-2.tar.gz
│   └── README.md
├── README.md
└── services
    ├── master
    │   ├── docker.service
    │   ├── etcd.service
    │   ├── kube-apiserver.service
    │   ├── kube-controller-manager.service
    │   └── kube-scheduler.service
    └── node
        ├── docker.service
        ├── etcd.service
        ├── flanneld.service
        ├── kubelet.service
        └── kube-proxy.service

22 directories, 91 files
```

目录中已经包含了安装过程中所需要的所有组件，服务及配置文件无需自己手动准备，安装过程中会自动配置，目录中提供的服务及配置文件仅供参考。

### 2.3 脚本使用说明

根据个人需求修改 kube_config 文件。如果节点个数不是2的话还需要修改对应证书配置文件及 etcd 相关服务配置文件。在执行安装脚本之前，需要在所有节点上部署 docker ，安装脚本参考 docker_installation.sh 。可以根据需求选择一键安装或者分步骤安装，kube_installation.sh 为一键安装脚本，在执行过程中也需要进行几次密码输入或者手动确认。其余所有组件均与 kube_config 在同一目录，可以根据文件名称直接区分。建议按照模块，分步骤进行安装，安装配置完成一个组件之后立马验证，及时排障。分模块安装顺序具体可以参考 kube_installation.sh 每一步均有注释。

### 2.4 执行方式

建议使用 bash example_installation.sh 的方式执行。一键安装及分模块安装的工作目录均为：kubernetes-all-in-one。例如： bash kube_installation.sh 。

### 2.5 验证安装是否成功

此步骤略，根据自身情况进行验证。

## 三 源码及意见反馈

### 3.1 源码

[GitHub](https://github.com/mrivandu/kube-ops/tree/master/kubernetes-all-in-one)

### 3.2 意见反馈

可以通过 GitHub、微信、邮件、文章评论向本人反馈。

## 四 参考资料

4.1 [使用二进制包在生产环境部署 Kubernetes v1.13.2 集群](https://blog.csdn.net/solaraceboy/article/details/86717272)

4.2 [二进制包20分钟快速安装部署 Kubernetes v1.14.0 集群](https://blog.csdn.net/solaraceboy/article/details/88937012)
