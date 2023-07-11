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
## 创建数据库
MWserver->软件管理->MariaDB->管理列表->添加数据库
## 安装php依赖
```
composer install
```
## 编辑网站配置
```
cp config/.config.example.php config/.config.php
cp config/appprofile.example.php config/appprofile.php
vim config/.config.php
```
只需要修改数据库相关信息即可，注意在MWserver查看数据库端口
## 示例
```
$_ENV['db_driver']    = 'mysql';
$_ENV['db_host']      = '127.0.0.1';
$_ENV['db_socket']    = '';
$_ENV['db_database']  = 'sspanel';           //数据库名
$_ENV['db_username']  = 'sspanel';              //数据库用户名
$_ENV['db_password']  = 'sspanel';           //用户名对应的密码
$_ENV['db_port']      = '33106';              //端口
#高级
$_ENV['db_charset']   = 'utf8mb4';
$_ENV['db_collation'] = 'utf8mb4_unicode_ci';
$_ENV['db_prefix']    = '';
```

## 站点初始化设置
```
php xcat Migration new
```
```
php xcat Tool importAllSettings
```
```
php xcat Tool createAdmin
```
```
php xcat ClientDownload
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
