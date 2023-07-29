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
        read -p "请输入端口号（默认为 22）：" sshport
        sshport=${sshport:-22} # 如果用户没有输入，则使用默认值22

        read -p "请输入密码：" password
        # 如果用户没有输入密码，则设置一个随机密码
        if [ -z "$password" ]; then
                password=$(openssl rand -base64 12)
                echo -e "${YELLOW}未提供密码。正在生成随机密码...${NC}"
        fi
        echo root:$password | $su chpasswd root
        $su sed -i "s/^#\?Port.*/Port $sshport/g" /etc/ssh/sshd_config;
        $su sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/g' /etc/ssh/sshd_config;
        $su sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/g' /etc/ssh/sshd_config;
        $su sed -i 's/^#\?RSAAuthentication.*/RSAAuthentication yes/g' /etc/ssh/sshd_config;
        $su sed -i 's/^#\?PubkeyAuthentication.*/PubkeyAuthentication yes/g' /etc/ssh/sshd_config;
        $su rm -rf /etc/ssh/sshd_config.d/* && rm -rf /etc/ssh/ssh_config.d/*;
        # 重启SSH服务
        $su systemctl restart ssh >/dev/null 2>&1
        $su systemctl restart sshd >/dev/null 2>&1

    # 输出结果
    echo -e "${GREEN}VPS当前ssh端口：$sshport${NC}"
    echo -e "${GREEN}VPS当前用户名：root${NC}"
    echo -e "${GREEN}vps当前root密码：$password${NC}"
else
        echo -e "${RED}修改失败：当前vps不支持root账户或无法自定义root密码${NC}" && exit 1
fi
