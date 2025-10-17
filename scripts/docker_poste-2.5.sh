#!/bin/bash
set -e

# 定义默认值
DEFAULT_DOCKER_NET="docker-net"
DEFAULT_CONTAINER_NAME="poste-2.5"
DEFAULT_HOST_NAME="mail"
DEFAULT_DOMAIN_NAME="example.com"
DEFAULT_TZ="Asia/Shanghai"
DISABLE_CLAMAV="TRUE"
DISABLE_RSPAMD="TRUE"
HTTPS="OFF"

REMOTE_IMAGE_NAME="ccr.ccs.tencentyun.com/sharky/poste:2.5.7"
DEFAULT_IMAGE_NAME="sharky/poste:2.5.7"
RESTART="unless-stopped"

# 容器环境变量
read -p "请输入Docker网络名称 (默认: $DEFAULT_DOCKER_NET): " DOCKER_NET
DOCKER_NET=${DOCKER_NET:-$DEFAULT_DOCKER_NET}

read -p "请输入容器名称 (默认: $DEFAULT_CONTAINER_NAME): " CONTAINER_NAME
CONTAINER_NAME=${CONTAINER_NAME:-$DEFAULT_CONTAINER_NAME}

read -p "请输入镜像名称 (默认: $DEFAULT_IMAGE_NAME): " IMAGE_NAME
LOCAL_IMAGE_NAME=${IMAGE_NAME:-$DEFAULT_IMAGE_NAME}

read -p "请输入主机名称 (默认: $DEFAULT_HOST_NAME): " HOST_NAME
HOST_NAME=${HOST_NAME:-$DEFAULT_HOST_NAME}

read -p "请输入域名名称 (默认: $DEFAULT_DOMAIN_NAME): " DOMAIN_NAME
DOMAIN_NAME=${DOMAIN_NAME:-$DEFAULT_DOMAIN_NAME}

read -p "请输入时区名称 (默认: $DEFAULT_TZ): " TZ
TZ=${TZ:-$DEFAULT_TZ}

echo "以下两项低配置服务器不建议开启"

read -p "是否开启邮件杀毒? (Y/N, 默认: N)" yn
yn=${yn}
case $yn in
    [Yy]* ) DISABLE_CLAMAV="FALSE";;
    * ) ;;
esac

read -p "是否开启垃圾邮件过滤? (Y/N, 默认: N)" yn
yn=${yn}
case $yn in
    [Yy]* ) DISABLE_RSPAMD="FALSE";;
    * ) ;;
esac

echo "如果你准备反向代理，可以关闭它，在代理侧进行https"

read -p "是否开启https? (Y/N, 默认: N)" yn
yn=${yn}
case $yn in
    [Yy]* ) HTTPS="ON";;
    * ) ;;
esac

# 显示最终配置
echo "----------------------------------------"
echo "已配置的参数："
echo "Docker网络名称: $DOCKER_NET"
echo "容器名称: $CONTAINER_NAME"
echo "镜像名称: $LOCAL_IMAGE_NAME"
echo "主机名称: $HOST_NAME"
echo "域名名称: $DOMAIN_NAME"
echo "完整名称：$HOST_NAME.$DOMAIN_NAME"
echo "时区名称: $TZ"

if [[ "$DISABLE_RSPAMD" == "TRUE" ]]; then
    echo "邮件杀毒: 关闭"
else
    echo "邮件杀毒: 开启"
fi

if [[ "$DISABLE_RSPAMD" == "TRUE" ]]; then
    echo "过滤垃圾邮件: 关闭"
else
    echo "过滤垃圾邮件: 开启"
fi

if [[ "$HTTPS" == "OFF" ]]; then
    echo "HTTPS: 关闭"
else
    echo "HTTPS: 开启"
fi
echo "----------------------------------------"

DISABLE_CLAMAV="TRUE"
DISABLE_RSPAMD="TRUE"
HTTPS="OFF"

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
        -v /data/docker/poste/data:/data \
        -e DISABLE_CLAMAV=$DISABLE_CLAMAV \
        -e DISABLE_RSPAMD=$DISABLE_RSPAMD \
        -e TZ=$TZ \
        -e HTTPS=$HTTPS \
        --name "$name" \
        --restart "$RESTART" \
        --network "$DOCKER_NET" \
        --hostname "$HOST_NAME.$DOMAIN_NAME"  \
        --domainname "$DOMAIN_NAME"  \
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
                $CONTAINER_NAME=$newname
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

read -p "关闭 nginx gzip? (Y/N, Default: N)" yn
yn=${yn}
case $yn in
    [Yy]* ) 
        docker exec $CONTAINER_NAME bash -c 'sed -i "s@gzip\s\+on\s*;@gzip off;@g" /etc/nginx/nginx.conf && nginx -s reload'
    ;;
    * ) ;;
esac

GITHUB_ROOT="https://raw.githubusercontent.com/bytesharky/server-init/refs/heads/main/attached/poste"
GITEE_ROOT="https://gitee.com/bytesharky/server-init/raw/main/attached/poste"
EXAMPLE_FILE="mail.conf"
SELECTED_SOURCE=""

read -p "是否下载Nginx反向代理示例? (Y/N, 默认: N) " yn
yn=${yn}
case $yn in
    [Yy]* ) 
        DOWN_EXAMPLE="TRUE"
        echo -e "\n请选择下载源:"
        echo "1. GitHub"
        echo "2. Gitee"
        while true; do
            read -p "[1/2]: " src_choice
            case $src_choice in
                1) 
                    SELECTED_SOURCE="GitHub"
                    DOWNLOAD_URL="${GITHUB_ROOT}/${EXAMPLE_FILE}"
                    break
                    ;;
                2) 
                    SELECTED_SOURCE="Gitee"
                    DOWNLOAD_URL="${GITEE_ROOT}/${EXAMPLE_FILE}"
                    break
                    ;;
                *) 
                    echo "输入无效！"
                    ;;
            esac
        done
        ;;
    * ) 
        DOWN_EXAMPLE="FALSE"
        ;;
esac

if [[ "$DOWN_EXAMPLE" == "TRUE" ]]; then
    
    cd ~
    
    curl -fOJ "$DOWNLOAD_URL"
    
    if [[ $? -eq 0 ]]; then
        echo -e "从 $SELECTED_SOURCE 下载 $EXAMPLE_FILE 成功！"
        echo $(pwd)/${EXAMPLE_FILE}
    else
        echo -e "从 $SELECTED_SOURCE 下载 $EXAMPLE_FILE 失败！"
        echo "可手动访问以下链接尝试下载：\n$DOWNLOAD_URL"
    fi
fi

echo -e "\n操作完成"
