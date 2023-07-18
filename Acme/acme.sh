#!/bin/bash

RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
NC="\033[0m"

REGEX=("debian" "ubuntu" "centos|red hat|kernel|oracle linux|alma|rocky" "'amazon linux'" "fedora")
RELEASE=("Debian" "Ubuntu" "CentOS" "CentOS" "Fedora")
PACKAGE_UPDATE=("apt-get update" "apt-get update" "yum -y update" "yum -y update" "yum -y update")
PACKAGE_INSTALL=("apt -y install" "apt -y install" "yum -y install" "yum -y install" "yum -y install")
PACKAGE_REMOVE=("apt -y remove" "apt -y remove" "yum -y remove" "yum -y remove" "yum -y remove")
PACKAGE_UNINSTALL=("apt -y autoremove" "apt -y autoremove" "yum -y autoremove" "yum -y autoremove" "yum -y autoremove")

[[ $EUID -ne 0 ]] && echo -e "${RED}注意：请在root用户下运行脚本${NC}" && exit 1

CMD=("$(grep -i pretty_name /etc/os-release 2>/dev/null | cut -d \" -f2)" "$(hostnamectl 2>/dev/null | grep -i system | cut -d : -f2)" "$(lsb_release -sd 2>/dev/null)" "$(grep -i description /etc/lsb-release 2>/dev/null | cut -d \" -f2)" "$(grep . /etc/redhat-release 2>/dev/null)" "$(grep . /etc/issue 2>/dev/null | cut -d \\ -f1 | sed '/^[ ]*$/d')")

for i in "${CMD[@]}"; do
    SYS="$i"
    if [[ -n $SYS ]]; then
        break
    fi
done

for ((int = 0; int < ${#REGEX[@]}; int++)); do
    if [[ $(echo "$SYS" | tr '[:upper:]' '[:lower:]') =~ ${REGEX[int]} ]]; then
        SYSTEM="${RELEASE[int]}"
        if [[ -n $SYSTEM ]]; then
            break
        fi
    fi
done

[[ -z $SYSTEM ]] && echo -e "${RED}不支持当前VPS系统, 请使用主流的操作系统${NC}" && exit 1

back2menu() {
    echo ""
    echo -e "${GREEN}所选命令操作执行完成${NC}"
    read -rp "请输入“y”退出, 或按任意键回到主菜单：" back2menuInput
    case "$back2menuInput" in
        y) exit 1 ;;
        *) menu ;;
    esac
}

install_base(){
    if [[ ! $SYSTEM == "CentOS" ]]; then
        ${PACKAGE_UPDATE[int]}
    fi
    ${PACKAGE_INSTALL[int]} curl wget sudo socat openssl
    if [[ $SYSTEM == "CentOS" ]]; then
        ${PACKAGE_INSTALL[int]} cronie
        systemctl start crond
        systemctl enable crond
    else
        ${PACKAGE_INSTALL[int]} cron
        systemctl start cron
        systemctl enable cron
    fi
}

install_acme(){
    install_base
    read -rp "请输入注册邮箱 (例: admin@gmail.com, 或留空自动生成一个gmail邮箱): " acmeEmail
    if [[ -z $acmeEmail ]]; then
        autoEmail=$(date +%s%N | md5sum | cut -c 1-16)
        acmeEmail=$autoEmail@gmail.com
        echo -e "${YELLOW}已取消设置邮箱, 使用自动生成的gmail邮箱: $acmeEmail${NC}"
    fi
    curl https://get.acme.sh | sh -s email=$acmeEmail
    source ~/.bashrc
    bash ~/.acme.sh/acme.sh --upgrade --auto-upgrade
    bash ~/.acme.sh/acme.sh --set-default-ca --server letsencrypt
    if [[ -n $(~/.acme.sh/acme.sh -v 2>/dev/null) ]]; then
        echo -e "${GREEN}Acme.sh证书申请脚本安装成功!${NC}"
    else
        echo -e "${RED}抱歉, Acme.sh证书申请脚本安装失败${NC}"
        echo -e "${GREEN}建议如下：${NC}"
        echo -e "${YELLOW}1. 检查VPS的网络环境${NC}"
        echo -e "${YELLOW}2. 脚本可能跟不上时代, 请更换其他脚本${NC}"
    fi
    back2menu
}

check_80(){

    if [[ -z $(type -P lsof) ]]; then
        if [[ ! $SYSTEM == "CentOS" ]]; then
            ${PACKAGE_UPDATE[int]}
        fi
        ${PACKAGE_INSTALL[int]} lsof
    fi
    
    echo -e "${YELLOW}正在检测80端口是否占用...${NC}"
    sleep 1
    
    if [[  $(lsof -i:"80" | grep -i -c "listen") -eq 0 ]]; then
        echo -e "${GREEN}检测到目前80端口未被占用${NC}"
        sleep 1
    else
        echo -e "${RED}检测到目前80端口被其他程序被占用，以下为占用程序信息${NC}"
        lsof -i:"80"
        read -rp "如需结束占用进程请按Y，按其他键则退出 [Y/N]: " yn
        if [[ $yn =~ "Y"|"y" ]]; then
            lsof -i:"80" | awk '{print $2}' | grep -v "PID" | xargs kill -9
            sleep 1
        else
            exit 1
        fi
    fi
}

acme_standalone(){
    [[ -z $(~/.acme.sh/acme.sh -v 2>/dev/null) ]] && echo -e "${RED}未安装acme.sh, 无法执行操作${NC}" && exit 1
    check_80
    WARPv4Status=$(curl -s4m8 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
    WARPv6Status=$(curl -s6m8 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
    if [[ $WARPv4Status =~ on|plus ]] || [[ $WARPv6Status =~ on|plus ]]; then
        wg-quick down wgcf >/dev/null 2>&1
        systemctl stop warp-go >/dev/null 2>&1
    fi
    
    ipv4=$(curl -s4m8 ip.p3terx.com -k | sed -n 1p)
    ipv6=$(curl -s6m8 ip.p3terx.com -k | sed -n 1p)
    
    echo ""
    echo -e "${YELLOW}在使用80端口申请模式时, 请先将您的域名解析至你的VPS的真实IP地址, 否则会导致证书申请失败${NC}"
    echo ""
    if [[ -n $ipv4 && -n $ipv6 ]]; then
        echo -e "VPS的真实IPv4地址为: ${GREEN} $ipv4 ${NC}"
        echo -e "VPS的真实IPv6地址为: ${GREEN} $ipv6 ${NC}"
    elif [[ -n $ipv4 && -z $ipv6 ]]; then
        echo -e "VPS的真实IPv4地址为: ${GREEN} $ipv4 ${NC}"
    elif [[ -z $ipv4 && -n $ipv6 ]]; then
        echo -e "VPS的真实IPv6地址为: ${GREEN} $ipv6 ${NC}"
    fi
    echo ""
    read -rp "请输入解析完成的域名: " domain
    [[ -z $domain ]] && echo -e "${RED}未输入域名，无法执行操作！${NC}" && exit 1
    echo -e "${GREEN}已输入的域名：$domain ${NC}" && sleep 1
    domainIP=$(curl -sm8 ipget.net/?ip="${domain}")
    
    if [[ $domainIP == $ipv6 ]]; then
        bash ~/.acme.sh/acme.sh --issue -d ${domain} --standalone --listen-v6 --insecure
    fi
    if [[ $domainIP == $ipv4 ]]; then
        bash ~/.acme.sh/acme.sh --issue -d ${domain} --standalone --insecure
    fi
    
    if [[ -n $(echo $domainIP | grep nginx) ]]; then
        if [[ -n $(type -P wg-quick) && -n $(type -P wgcf) ]]; then
            wg-quick up wgcf >/dev/null 2>&1
        fi
        if [[ -a "/opt/warp-go/warp-go" ]]; then
            systemctl start warp-go 
        fi
        echo -e "${RED}域名解析失败, 请检查域名是否正确填写或等待解析完成再执行脚本${NC}"
        exit 1
    elif [[ -n $(echo $domainIP | grep ":") || -n $(echo $domainIP | grep ".") ]]; then
        if [[ $domainIP != $ipv4 ]] && [[ $domainIP != $ipv6 ]]; then
            if [[ -n $(type -P wg-quick) && -n $(type -P wgcf) ]]; then
                wg-quick up wgcf >/dev/null 2>&1
            fi
            if [[ -a "/opt/warp-go/warp-go" ]]; then
                systemctl start warp-go 
            fi
            echo -e "${GREEN}域名 ${domain} 目前解析的IP: ($domainIP) ${NC}"
            echo -e "${RED}当前域名解析的IP与当前VPS使用的真实IP不匹配${NC}"
            echo -e "${GREEN}建议如下：${NC}"
            echo -e "${YELLOW}1. 请确保CloudFlare小云朵为关闭状态(仅限DNS), 其他域名解析或CDN网站设置同理${NC}"
            echo -e "${YELLOW}2. 请检查DNS解析设置的IP是否为VPS的真实IP${NC}"
            echo -e "${YELLOW}3. 脚本可能跟不上时代, 建议更换其他的脚本${NC}"
            exit 1
        fi
    fi

    read -rp "请输入证书安装路径: " cert1path
    [[ -z $cert1path ]] && echo -e "${RED}未输入证书安装路径，无法执行操作！${NC}" && exit 1
    export CERT1PATH="$cert1path"
    mkdir -p $CERT1PATH/${domain}
    
    bash ~/.acme.sh/acme.sh --install-cert -d ${domain} --key-file "$CERT1PATH"/${domain}/key.pem --fullchain-file "$CERT1PATH"/${domain}/cert.pem
    checktls
}

acme_cfapiNTLD() {
    [[ -z $(~/.acme.sh/acme.sh -v 2>/dev/null) ]] && echo -e "${RED}未安装acme.sh，无法执行操作${NC}" && exit 1
    ipv4=$(curl -s4m8 ip.p3terx.com -k | sed -n 1p)
    ipv6=$(curl -s6m8 ip.p3terx.com -k | sed -n 1p)

    domains=()
    read -rp "请输入需要申请的域名数量: " domains_count
    [[ ! $domains_count =~ ^[1-99][0-99]*$ ]] && echo -e "${RED}请输入有效的域名数量！${NC}" && exit 1
    for ((i=1; i<=domains_count; i++)); do
        read -rp "请输入第 $i 个域名 (例如：domain.com): " domain
        domains+=("$domain")
    done

    read -rp "请输入 Cloudflare Global API Key: " cf_key
    [[ -z $cf_key ]] && echo -e "${RED}未输入 Cloudflare Global API Key，无法执行操作！${NC}" && exit 1
    export CF_Key="$cf_key"
    read -rp "请输入 Cloudflare 的登录邮箱: " cf_email
    [[ -z $cf_email ]] && echo -e "${RED}未输入 Cloudflare 的登录邮箱，无法执行操作!${NC}" && exit 1
    export CF_Email="$cf_email"
    read -rp "请输入 Cloudflare Token: " cf_token
    [[ -z $cf_token ]] && echo -e "${RED}未输入 Cloudflare Token，无法执行操作！${NC}" && exit 1
    export CF_Token="$cf_token"
    read -rp "请输入 Cloudflare Account ID: " cf_account_id
    [[ -z $cf_account_id ]] && echo -e "${RED}未输入 Cloudflare Account ID，无法执行操作！${NC}" && exit 1
    export CF_Account_ID="$cf_account_id"
    
    first_domain="${domains[0]}"
    acme_domains=""
    for domain in "${domains[@]}"; do
        acme_domains+=" -d $domain -d *.$domain"
    done

    if [[ -z $ipv4 ]]; then
        bash ~/.acme.sh/acme.sh --issue --dns dns_cf --listen-v6 --insecure $acme_domains
    else
        bash ~/.acme.sh/acme.sh --issue --dns dns_cf --insecure $acme_domains
    fi

    read -rp "请输入证书安装路径: " cert3path
    [[ -z $cert3path ]] && echo -e "${RED}未输入证书安装路径，无法执行操作！${NC}" && exit 1
    export CERT3PATH="$cert3path"
    mkdir -p $CERT3PATH/$first_domain

    for domain in "${domains[@]}"; do
        bash ~/.acme.sh/acme.sh --install-cert -d "$first_domain" --key-file "$CERT3PATH"/"$first_domain"/key.pem --fullchain-file "$CERT3PATH"/"$first_domain"/cert.pem

    done

    check1tls
}

check1tls() {
    if [[ -f "$CERT3PATH"/"$first_domain"/cert.pem && -f "$CERT3PATH"/"$first_domain"/key.pem ]]; then
        if [[ -s "$CERT3PATH"/"$first_domain"/cert.pem && -s "$CERT3PATH"/"$first_domain"/key.pem ]]; then
            if [[ -n $(type -P wg-quick) && -n $(type -P wgcf) ]]; then
                wg-quick up wgcf >/dev/null 2>&1
            fi
            if [[ -n $(type -P wg-quick) && -n $(type -P wgcf) ]]; then
                wg-quick up wgcf >/dev/null 2>&1
            fi
            if [[ -a "/opt/warp-go/warp-go" ]]; then
                systemctl start warp-go 
            fi
            echo $domain > /root/ca.log
            sed -i '/--cron/d' /etc/crontab >/dev/null 2>&1
            echo "0 0 * * * root bash /root/.acme.sh/acme.sh --cron -f >/dev/null 2>&1" >> /etc/crontab
            echo -e "${GREEN}证书申请成功! 脚本申请到的证书 cert.pem 和私钥 key.pem 文件已保存到 "$CERT3PATH"/"$first_domain" 路径下${NC}"
            echo -e "${GREEN}证书crt文件路径如下: "$CERT3PATH"/"$first_domain"/cert.pem${NC}"
            echo -e "${GREEN}私钥key文件路径如下: "$CERT3PATH"/"$first_domain"/key.pem${NC}"
            back2menu
        else
            if [[ -n $(type -P wg-quick) && -n $(type -P wgcf) ]]; then
                wg-quick up wgcf >/dev/null 2>&1
            fi
            if [[ -a "/opt/warp-go/warp-go" ]]; then
                systemctl start warp-go 
            fi
            echo -e "${RED}很抱歉，证书申请失败${NC}"
            echo -e "${GREEN}建议如下: ${NC}"
            echo -e "${YELLOW}1. 自行检查dns_api信息是否正确${NC}"
            echo -e "${YELLOW}2. 脚本可能跟不上时代, 建议更换其他脚本${NC}"
            back2menu
        fi
    fi
}

checktls() {
    if [[ -f "$CERT1PATH"/${domain}/cert.pem && -f "$CERT1PATH"/${domain}/key.pem ]]; then
        if [[ -s "$CERT1PATH"/${domain}/cert.pem && -s "$CERT1PATH"/${domain}/key.pem ]]; then
            if [[ -n $(type -P wg-quick) && -n $(type -P wgcf) ]]; then
                wg-quick up wgcf >/dev/null 2>&1
            fi
            if [[ -n $(type -P wg-quick) && -n $(type -P wgcf) ]]; then
                wg-quick up wgcf >/dev/null 2>&1
            fi
            if [[ -a "/opt/warp-go/warp-go" ]]; then
                systemctl start warp-go 
            fi
            echo $domain > /root/ca.log
            sed -i '/--cron/d' /etc/crontab >/dev/null 2>&1
            echo "0 0 * * * root bash /root/.acme.sh/acme.sh --cron -f >/dev/null 2>&1" >> /etc/crontab
            echo -e "${GREEN}证书申请成功! 脚本申请到的证书 cert.pem 和私钥 key.pem 文件已保存到 "$CERT1PATH"/${domain} 路径下${NC}"
            echo -e "${GREEN}证书crt文件路径如下: "$CERT1PATH"/${domain}/cert.pem${NC}"
            echo -e "${GREEN}私钥key文件路径如下: "$CERT1PATH"/${domain}/key.pem${NC}"
            back2menu
        else
            if [[ -n $(type -P wg-quick) && -n $(type -P wgcf) ]]; then
                wg-quick up wgcf >/dev/null 2>&1
            fi
            if [[ -a "/opt/warp-go/warp-go" ]]; then
                systemctl start warp-go 
            fi
            echo -e "${RED}很抱歉，证书申请失败${NC}"
            echo -e "${GREEN}建议如下: ${NC}"
            echo -e "${YELLOW}1. 自行检测防火墙是否打开, 如使用80端口申请模式时, 请关闭防火墙或放行80端口${NC}"
            echo -e "${YELLOW}2. 同一域名多次申请可能会触发Let's Encrypt官方风控, 请尝试使用脚本菜单的9选项更换证书颁发机构, 再重试申请证书, 或更换域名、或等待7天后再尝试执行脚本${NC}"
            echo -e "${YELLOW}3. 脚本可能跟不上时代, 建议更换其他脚本${NC}"
            back2menu
        fi
    fi
}

view_cert(){
    [[ -z $(~/.acme.sh/acme.sh -v 2>/dev/null) ]] && echo -e "${YELLOW}未安装acme.sh, 无法执行操作!${NC}" && exit 1
    bash ~/.acme.sh/acme.sh --list
    back2menu
}

renew_cert() {
    [[ -z $(~/.acme.sh/acme.sh -v 2>/dev/null) ]] && echo -e "${YELLOW}未安装acme.sh, 无法执行操作!${NC}" && exit 1
    bash ~/.acme.sh/acme.sh --list
    read -rp "请输入要续期的域名证书 (复制Main_Domain下显示的域名): " domain
    [[ -z $domain ]] && echo -e "${RED}未输入域名, 无法执行操作!${NC}" && exit 1
    if [[ -n $(bash ~/.acme.sh/acme.sh --list | grep $domain) ]]; then
        bash ~/.acme.sh/acme.sh --renew -d ${domain} --force
        checktls
        back2menu
    else
        echo -e "${RED}未找到${domain}的域名证书，请再次检查域名输入正确${NC}"
        back2menu
    fi
}

switch_provider(){
    echo -e "${YELLOW}请选择证书提供商, 默认通过 Letsencrypt.org 来申请证书 ${NC}"
    echo -e "${YELLOW}如果证书申请失败, 例如一天内通过 Letsencrypt.org 申请次数过多, 可选 BuyPass.com 或 ZeroSSL.com 来申请.${NC}"
    echo -e " ${GREEN}1.${NC} Letsencrypt.org"
    echo -e " ${GREEN}2.${NC} BuyPass.com"
    echo -e " ${GREEN}3.${NC} ZeroSSL.com"
    read -rp "请选择证书提供商 [1-3，默认1]: " provider
    case $provider in
        2) bash ~/.acme.sh/acme.sh --set-default-ca --server buypass && echo -e "${GREEN}切换证书提供商为 BuyPass.com 成功！${NC}" ;;
        3) bash ~/.acme.sh/acme.sh --set-default-ca --server zerossl && echo -e "${GREEN}切换证书提供商为 ZeroSSL.com 成功！${NC}" ;;
        *) bash ~/.acme.sh/acme.sh --set-default-ca --server letsencrypt && echo -e "${GREEN}切换证书提供商为 Letsencrypt.org 成功！${NC}" ;;
    esac
    back2menu
}

uninstall() {
    [[ -z $(~/.acme.sh/acme.sh -v 2>/dev/null) ]] && echo -e "${YELLOW}未安装Acme.sh, 卸载程序无法执行!${NC}" && exit 1
    ~/.acme.sh/acme.sh --uninstall
    sed -i '/--cron/d' /etc/crontab >/dev/null 2>&1
    rm -rf ~/.acme.sh
    echo -e "${GREEN}Acme  一键申请证书脚本已彻底卸载!${NC}"
}

menu() {
    clear
    echo "#############################################################"
    echo -e "#                     ${RED}Acme证书一键申请脚本${NC}                  #"
    echo -e "#                     ${GREEN}作者${NC}: 你挺能闹啊☁️                    #"
    echo "#############################################################"
    echo ""
    echo -e " ${GREEN}1.${NC} 安装 Acme.sh 域名证书申请脚本"
    echo -e " ${GREEN}2.${NC} ${RED}卸载 Acme.sh 域名证书申请脚本${NC}"
    echo " -------------"
    echo -e " ${GREEN}3.${NC} 申请单域名证书 ${YELLOW}(80端口申请)${NC}"
    echo -e " ${GREEN}4.${NC} 申请泛域名证书 ${YELLOW}(CF API申请)${NC} ${GREEN}(无需解析)${NC} ${RED}(不支持freenom域名)${NC}"
    echo " -------------"
    echo -e " ${GREEN}5.${NC} 查看已申请的证书"
    echo -e " ${GREEN}6.${NC} 手动续期已申请的证书"
    echo -e " ${GREEN}7.${NC} 切换证书颁发机构"
    echo " -------------"
    echo -e " ${GREEN}0.${NC} 退出脚本"
    echo ""
    read -rp "请输入选项 [0-9]: " NumberInput
    case "$NumberInput" in
        1) install_acme ;;
        2) uninstall ;;
        3) acme_standalone ;;
        4) acme_cfapiNTLD ;;
        5) view_cert ;;
        6) renew_cert ;;
        7) switch_provider ;;
        *) exit 1 ;;
    esac
}

menu
