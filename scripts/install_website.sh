#!/bin/bash
set -e

echo "----------------------------------------"
echo "部署默认网站"
echo "注意："
echo "请确保已安装并配置好Nginx docker容器"
echo "此操作会覆盖 nginx.conf 文件"
echo "----------------------------------------"

# 确认继续
while true; do
    read -p "是否确认继续部署? (Y/N) " yn
    yn=${yn}
    case $yn in
        [Yy]* ) break;;
        [Nn]* ) exit;;
        * ) ;;
    esac
done

# 定义默认值
DEFAULT_NGINX_DOCKER="nginx-1.29"
DEFAULT_NGINX_CONFIG="/data/docker/nginx/conf"
DEFAULT_NGINX_LOGS="/data/docker/nginx/logs"
DEFAULT_WEBSITE_ROOT="/data/docker/nginx/websites"

read -p "请输入Nginx容器名称 (默认: $DEFAULT_NGINX_DOCKER): " NGINX_DOCKER
NGINX_DOCKER=${NGINX_DOCKER:-$DEFAULT_NGINX_DOCKER}

read -p "请输入Nginx配置文件路径 (默认: $DEFAULT_NGINX_CONFIG): " NGINX_CONFIG
NGINX_CONFIG=${NGINX_CONFIG:-$DEFAULT_NGINX_CONFIG}

read -p "请输入Nginx日志目录 (默认: $DEFAULT_NGINX_LOGS): " NGINX_LOGS
NGINX_LOGS=${NGINX_LOGS:-$DEFAULT_NGINX_LOGS}

read -p "请输入网站根目录 (默认: $DEFAULT_WEBSITE_ROOT): " WEBSITE_ROOT
WEBSITE_ROOT=${WEBSITE_ROOT:-$DEFAULT_WEBSITE_ROOT}

# 显示最终配置
echo "----------------------------------------"
echo "已配置的参数："
echo "Nginx容器名称: $NGINX_DOCKER"
echo "Nginx配置文件路径: $NGINX_CONFIG"
echo "Nginx日志目录: $NGINX_LOGS"
echo "网站根目录: $WEBSITE_ROOT"
echo "----------------------------------------"

curl -OJ https://gitee.com/bytesharky/server-init/raw/main/default_website.zip
unzip default_website.zip -d website
rm -f default_website.zip

mkdir -p "$WEBSITE_ROOT/default" 
mkdir -p "$NGINX_CONFIG/sites-enabled/extension"
mkdir -p "$NGINX_LOGS/default"
cp website/nginx.conf "$NGINX_CONFIG/nginx.conf"
cp website/default.conf "$NGINX_CONFIG/conf.d/default.conf"
cp website/extension/* "$NGINX_CONFIG/sites-enabled/extension"
cp -r website/default/* "$WEBSITE_ROOT/default"
docker restart "$NGINX_DOCKER"

echo "✅ 默认网站部署完成，访问 http://服务器IP/ 查看效果"
