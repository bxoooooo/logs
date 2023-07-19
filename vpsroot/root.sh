#!/bin/bash

RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
NC="\033[0m"

[[ $EUID -ne 0 ]] && su='sudo'
lsattr /etc/passwd /etc/shadow >/dev/null 2>&1
chattr -i /etc/passwd /etc/shadow >/dev/null 2>&1
chattr -a /etc/passwd /etc/shadow >/dev/null 2>&1
lsattr /etc/passwd /etc/shadow >/dev/null 2>&1
prl=`grep PermitRootLogin /etc/ssh/sshd_config`
pa=`grep PasswordAuthentication /etc/ssh/sshd_config`
if [[ -n $prl && -n $pa ]]; then
        read -p "自定义root密码:" mima
        echo root:$mima | $su chpasswd root
        $su sed -i -e "s/PermitRootLogin.*/PermitRootLogin yes/" /etc/ssh/sshd_config;
        $su sed -i -e "s/PasswordAuthentication.*/PasswordAuthentication yes/" /etc/ssh/sshd_config;
        $su sed -i -e "s/RSAAuthentication.*/RSAAuthentication yes/" /etc/ssh/sshd_config;
        $su sed -i -e "s/PubkeyAuthentication.*/PubkeyAuthentication yes/" /etc/ssh/sshd_config;
        $su rm -rf /etc/ssh/sshd_config.d/* && rm -rf /etc/ssh/ssh_config.d/*;
        $su systemctl restart sshd ssh;
        echo -e "${GREEN}VPS当前用户名：root${NC}"
        echo -e "${GREEN}vps当前root密码：$mima${NC}"
else
        echo -e "${RED}当前vps不支持root账户或无法自定义root密码${NC}" && exit 1
fi
