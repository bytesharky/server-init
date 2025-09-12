#!/bin/bash
set -e

echo "----------------------------------------"
echo "Deploying Default Website"
echo "Note:"
echo "Please make sure the Nginx docker container is installed and configured"
echo "This operation will overwrite the nginx.conf file"
echo "----------------------------------------"

# Confirm to continue
while true; do
    read -p "Are you sure you want to continue deployment? (Y/N) " yn
    yn=${yn}
    case $yn in
        [Yy]* ) break;;
        [Nn]* ) exit;;
        * ) ;;
    esac
done

# Define default values
DEFAULT_NGINX_DOCKER="nginx-1.29"
DEFAULT_NGINX_CONFIG="/data/docker/nginx/conf"
DEFAULT_NGINX_LOGS="/data/docker/nginx/logs"
DEFAULT_WEBSITE_ROOT="/data/docker/nginx/websites"

read -p "Enter Nginx container name (default: $DEFAULT_NGINX_DOCKER): " NGINX_DOCKER
NGINX_DOCKER=${NGINX_DOCKER:-$DEFAULT_NGINX_DOCKER}

read -p "Enter Nginx config file path (default: $DEFAULT_NGINX_CONFIG): " NGINX_CONFIG
NGINX_CONFIG=${NGINX_CONFIG:-$DEFAULT_NGINX_CONFIG}

read -p "Enter Nginx log directory (default: $DEFAULT_NGINX_LOGS): " NGINX_LOGS
NGINX_LOGS=${NGINX_LOGS:-$DEFAULT_NGINX_LOGS}

read -p "Enter website root directory (default: $DEFAULT_WEBSITE_ROOT): " WEBSITE_ROOT
WEBSITE_ROOT=${WEBSITE_ROOT:-$DEFAULT_WEBSITE_ROOT}

# Show final configuration
echo "----------------------------------------"
echo "Configured parameters:"
echo "Nginx container name: $NGINX_DOCKER"
echo "Nginx config file path: $NGINX_CONFIG"
echo "Nginx log directory: $NGINX_LOGS"
echo "Website root directory: $WEBSITE_ROOT"
echo "----------------------------------------"

curl -OJ https://gitee.com/bytesharky/server-init/raw/main/default_website.zip
unzip default_website.zip -d website
rm -f default_website.zip

mkdir -p "$WEBSITE_ROOT/default" 
mkdir -p "$NGINX_CONFIG/sites-enabled/extension"
mkdir -p "$NGINX_LOGS/default"
cp website/nginx.conf "$NGINX_CONFIG/nginx.conf"
cp website/default.conf "$NGINX_CONFIG/conf.d/default.conf"
cp -r website/extension/* "$NGINX_CONFIG/sites-enabled/extension"
cp -r website/default/* "$WEBSITE_ROOT/default"
docker restart "$NGINX_DOCKER"

echo "Default website deployed. Visit http://server_ip/ to view."
