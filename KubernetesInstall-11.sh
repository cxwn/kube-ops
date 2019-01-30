#!/bin/bash
# Deploy the scheduler service.
KUBE_ETC=/etc/kubernetes
KUBE_SCHEDULER_CONF=$KUBE_ETC/kube-scheduler.conf
cat>$KUBE_SCHEDULER_CONF<<EOF
KUBE_SCHEDULER_OPTS="--logtostderr=true \
--v=4 \
--master=127.0.0.1:8080 \
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