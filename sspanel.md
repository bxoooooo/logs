 教程使用的环境：MWserver(金灵面板) x86_64 架构

## 安装 MWserver

MWserver 项目地址：https://github.com/midoks/mdserver-web
## 一键脚本
```
curl --insecure -fsSL https://cdn.jsdelivr.net/gh/midoks/mdserver-web@latest/scripts/install.sh | bash
```
面板安装完毕后访问面板安装LNMP环境
- OpenResty
- PHP 8.1
- MariaDB
注意请选择快速安装(apt)，在面板首页直接安装，去软件管理页面安装，首页直接安装是编译安装，需要很长时间

环境安装完毕后开始安装php扩展
软件管理->已安装->php->安装扩展
- bcmath
- zip

以及手动安装ioncube，注意区分架构
## 查看架构命令
```
uname -m
```
- x86_64
```
wget http://downloads3.ioncube.com/loader_downloads/ioncube_loaders_lin_x86-64.tar.gz && tar xvf ioncube_loaders_lin_x86-64.tar.gz && cp ioncube/ioncube_loader_lin_8.1.so /usr/lib/php/20210902/ioncube_loader_lin_8.1.so && echo "zend_extension = /usr/lib/php/20210902/ioncube_loader_lin_8.1.so" > /etc/php/8.1/cli/conf.d/00-ioncube.ini && echo "zend_extension = /usr/lib/php/20210902/ioncube_loader_lin_8.1.so" > /etc/php/8.1/fpm/conf.d/00-ioncube.ini && rm -rf ioncabe ioncube_loaders_lin_x86-64.tar.gz
```
- aarch64
```
wget http://downloads3.ioncube.com/loader_downloads/ioncube_loaders_lin_aarch64.tar.gz && tar xvf ioncube_loaders_lin_aarch64.tar.gz && cp ioncube/ioncube_loader_lin_8.1.so /usr/lib/php/20210902/ioncube_loader_lin_8.1.so && echo "zend_extension = /usr/lib/php/20210902/ioncube_loader_lin_8.1.so" > /etc/php/8.1/cli/conf.d/00-ioncube.ini && echo "zend_extension = /usr/lib/php/20210902/ioncube_loader_lin_8.1.so" > /etc/php/8.1/fpm/conf.d/00-ioncube.ini && rm -rf ioncabe ioncube_loaders_lin_x86-64.tar.gz
```
扩展安装完毕后从MWserver重启php

## 部署 SSPanel UIM
MWserver->网站->添加站点，这一步不用教了吧
然后ssh登录你的vps，cd进你添加的站点目录后删除所有文件
```
rm -rf *
```
从仓库拉取源码
```
git clone -b 2023.3 https://github.com/Anankke/SSPanel-Uim.git .
```
## 安装composer
```
wget https://getcomposer.org/download/latest-stable/composer.phar -O /usr/local/bin/composer && chmod +x /usr/local/bin/composer
```
## 安装php依赖
```
composer install
```
## 编辑网站配置
```
cp config/.config.example.php config/.config.php
cp config/appprofile.example.php config/appprofile.php
vi config/.config.php
```

在加密选择的部分，如果是不加 CDN 则可使用 `Let's Encrypt` 证书，如网站需要加设 CDN 例如 Cloudfalre 等，则使用自签证书即可。

编辑 php.ini，删除 disable_functions 中的 proc_open, proc_get_status

```bash
vi /usr/local/php/etc/php.ini
```

重启php服务：

```bash
service php-fpm restart
```

虚拟主机设置完成后，前往你所设置的网站根目录文件夹，执行以下命令：

```bash
git clone -b 2023.3 https://github.com/Anankke/SSPanel-Uim.git .
wget https://getcomposer.org/installer -O composer.phar
php composer.phar
php composer.phar install --no-dev
```

?> 这里的 2023.3 代表的是 SSPanel UIM 的版本，你可以在 [Release](https://github.com/Anankke/SSPanel-Uim/releases) 页面中查看当前的最新稳定版本或者是输入 dev 使用开发版。请注意，dev 分支可能在使用过程中出现不可预知的问题。

修改 Nginx vhost 配置文件

```bash
vi /usr/local/nginx/conf/vhost/你设置的网站域名.conf
systemctl nginx restart
```

在对应的 vhost 的配置文件中添加如下伪静态规则，并将网站目录（即 `root` 配置项）后添加 `/public`

```nginx
location / {
    try_files $uri /index.php$is_args$args;
}
```

然后设置网站目录的整体权限

```bash
chmod -R 755 /path/to/your/site
chown -R www:www /path/to/your/site
```

完成后我们就可以创建数据库和对应的用户了，这步强烈建议使用非root用户并且限制该用户仅可访问对应的网站数据库。

?> 通过 http://服务器IP/phpMyAdmin 可以登录数据库，进行可视化的数据库操作。请务必在完成所有必要的数据库操作后删除或者改名位于 `/data/wwwroot/dafault` 下的 `phpMyAdmin` 目录以避免安全问题。

接下来编辑网站配置文件，将刚才设置的数据库连接信息填入其中，然后阅读其他配置的说明进行站点客制化。

```bash
cp config/.config.example.php config/.config.php
cp config/appprofile.example.php config/appprofile.php
vi config/.config.php
```

?> 按 i 键进入编辑模式，使用 :x 保存并退出 vi，使用 :q! 放弃任何改动并退出 vi。

接下来执行如下站点初始化设置

```bash
php xcat Migration new
php xcat Tool importAllSettings
php xcat Tool createAdmin
php xcat ClientDownload
```

如果你希望使用 Maxmind GeoLite2 数据库来提供 IP 地理位置信息，首先你需要配置 `config/.config.php` 中的 `maxmind_license_key` 选项，然后执行如下命令：

```bash
php xcat Update
```

使用 `crontab -e` 指令设置 SSPanel 的基本 cron 任务：

```bash
*/5 * * * * /usr/local/php/bin/php /path/to/your/site/xcat  Cron
```
