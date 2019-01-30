#!/bin/bash
# Deploy the node.
scp gysl-master:kubernetes/server/bin/{kube-proxy,kubelet,kubectl} /usr/local/bin/