# Turn off and disable the firewalld.  
        systemctl stop firewalld  
        systemctl disable firewalld  
# Disable the SELinux.  
        sed -i.bak 's/=enforcing/=disabled/' /etc/selinux/config  
# Disable the swap.  
        sed -i.bak 's/^.*swap/#&/g' /etc/fstab


