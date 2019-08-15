ipvsadm --clear
iptables -F && iptables -t nat -F && iptables -t mangle -F && iptables -X
rm -rf .kube/
