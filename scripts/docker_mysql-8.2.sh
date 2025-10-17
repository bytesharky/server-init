#!/bin/bash
set -e

# 定义默认值
DEFAULT_DOCKER_NET="docker-net"
DEFAULT_CONTAINER_NAME="mysql-8.2"
DEFAULT_MYSQL_ROOT_PASSWORD="123456"
DEFAULT_MYSQL_ROOT_HOST="172.18.%"

REMOTE_IMAGE_NAME="mysql:8.2"
DEFAULT_IMAGE_NAME="mysql:8.2"
RESTART="unless-stopped"

# 容器环境变量
read -p "请输入Docker网络名称 (默认: $DEFAULT_DOCKER_NET): " DOCKER_NET
DOCKER_NET=${DOCKER_NET:-$DEFAULT_DOCKER_NET}

read -p "请输入容器名称 (默认: $DEFAULT_CONTAINER_NAME): " CONTAINER_NAME
CONTAINER_NAME=${CONTAINER_NAME:-$DEFAULT_CONTAINER_NAME}

read -p "请输入镜像名称 (默认: $DEFAULT_IMAGE_NAME): " IMAGE_NAME
LOCAL_IMAGE_NAME=${IMAGE_NAME:-$DEFAULT_IMAGE_NAME}

read -p "请输入Root密码 (默认: $DEFAULT_MYSQL_ROOT_PASSWORD): " MYSQL_ROOT_PASSWORD
MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD:-$DEFAULT_MYSQL_ROOT_PASSWORD}

read -p "请输入Root主机 (默认: $DEFAULT_MYSQL_ROOT_HOST): " MYSQL_ROOT_HOST
MYSQL_ROOT_HOST=${MYSQL_ROOT_HOST:-$DEFAULT_MYSQL_ROOT_HOST}

# 显示最终配置
echo "----------------------------------------"
echo "已配置的参数："
echo "Docker网络名称: $DOCKER_NET"
echo "容器名称: $CONTAINER_NAME"
echo "镜像名称: $LOCAL_IMAGE_NAME"
echo "Root密码: $MYSQL_ROOT_PASSWORD"
echo "Root主机: $MYSQL_ROOT_HOST"
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

# ========================
# 启动容器函数
# ========================
start_container() {
    name="$1"
    echo "启动容器 $name..."
    docker run -d \
        -v /data/docker/mysql82/data:/var/lib/mysql \
        -e MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD \
        -e MYSQL_ROOT_HOST=$MYSQL_ROOT_HOST \
        --name "$name" \
        --restart "$RESTART" \
        --network "$DOCKER_NET" \
        "$LOCAL_IMAGE_NAME"
}

# ========================
# 拉取镜像
# ========================
echo "拉取镜像..."
docker pull "$REMOTE_IMAGE_NAME"
docker tag "$REMOTE_IMAGE_NAME" "$LOCAL_IMAGE_NAME"
echo "镜像拉取完成"

# ========================
# 检查 Docker 网络
# ========================
GATEWAY_IP="172.18.0.1"
NETWORK_ADDRESS="172.18.0.0/24"
NETWORK_ADDRESS_V6="fd00:cafe:babe::/64"
if ! docker network inspect "$DOCKER_NET" >/dev/null 2>&1; then
    echo "Docker 网络 $DOCKER_NET 不存在，正在创建..."
    if docker network create "$DOCKER_NET" --subnet="$NETWORK_ADDRESS" --subnet "$NETWORK_ADDRESS_V6" --gateway="$GATEWAY_IP"; then
        echo "Docker 网络 $DOCKER_NET 创建成功"
    else
        echo "Docker 网络 $DOCKER_NET 创建失败"
        exit 1
    fi
else
    echo "Docker 网络 $DOCKER_NET 已存在"
fi

# ========================
# 启动/处理容器
# ========================
if docker ps -a --format '{{.Names}}' | grep -q "^$CONTAINER_NAME$"; then
    echo "容器 $CONTAINER_NAME 已存在，请选择操作："
    echo "1) 删除并重建容器"
    echo "2) 使用新的容器名称"
    echo "3) 退出"
    
    while true; do
        read -r -p "请输入选项 [1-3]: " choice
        case "$choice" in
            1)
                echo "删除旧容器..."
                docker rm -f "$CONTAINER_NAME"
                start_container "$CONTAINER_NAME"
                break
                ;;
            2)
                read -r -p "请输入新容器名称: " newname
                if [ -z "$newname" ]; then
                    echo "名称不能为空，退出"
                    exit 1
                fi
                start_container "$newname"
                break
                ;;
            3)
                echo "已退出"
                exit 0
                ;;
            *) ;;
        esac
    done
else
    start_container "$CONTAINER_NAME"
fi

echo "容器已启动"
