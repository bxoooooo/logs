#!/bin/bash

RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
NC="\033[0m"

# 检查当前用户是否有sudo权限
[[ $EUID -ne 0 ]] && su='sudo'

# 要求用户输入自定义的root密码
read -p "自定义root密码:" mima

# 使用chpasswd命令修改root用户密码
echo "root:$mima" | $su chpasswd

# 检查是否修改成功
if [ $? -eq 0 ]; then
    # 修改SSH配置文件
    $su sed -i -e "s/PermitRootLogin.*/PermitRootLogin yes/" /etc/ssh/sshd_config;
    $su sed -i -e "s/PasswordAuthentication.*/PasswordAuthentication yes/" /etc/ssh/sshd_config;
    $su sed -i -e "s/RSAAuthentication.*/RSAAuthentication yes/" /etc/ssh/sshd_config;
    $su sed -i -e "s/PubkeyAuthentication.*/PubkeyAuthentication yes/" /etc/ssh/sshd_config;
    $su rm -rf /etc/ssh/sshd_config.d/* && rm -rf /etc/ssh/ssh_config.d/*;

    # 重启SSH服务
    $su systemctl restart sshd ssh;

    # 输出结果
    echo -e "${GREEN}VPS当前用户名：root${NC}"
    echo -e "${GREEN}vps当前root密码：$mima${NC}"
else
    echo -e "${RED}修改失败：当前vps不支持root账户或无法自定义root密码${NC}" && exit 1
fi
