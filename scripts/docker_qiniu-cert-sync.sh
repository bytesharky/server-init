#!/bin/bash
set -e

# 定义默认值
DEFAULT_DOCKER_NET="docker-net"
DEFAULT_CONTAINER_NAME="qiniu-cert-sync"
DEFAULT_CERT_DIR="/data/docker/acme/certs"

DATA_DIR="/data/docker/qiniu-cert-sync"
REMOTE_IMAGE_NAME="ccr.ccs.tencentyun.com/sharky/qiniu-cert-sync"
DEFAULT_IMAGE_NAME="sharky/qiniu-cert-sync"
RESTART="unless-stopped"


read -p "请输入Docker网络名称 (默认: $DEFAULT_DOCKER_NET): " DOCKER_NET
DOCKER_NET=${DOCKER_NET:-$DEFAULT_DOCKER_NET}

read -p "请输入容器名称 (默认: $DEFAULT_CONTAINER_NAME): " CONTAINER_NAME
CONTAINER_NAME=${CONTAINER_NAME:-$DEFAULT_CONTAINER_NAME}

read -p "请输入镜像名称 (默认: $DEFAULT_IMAGE_NAME): " IMAGE_NAME
LOCAL_IMAGE_NAME=${IMAGE_NAME:-$DEFAULT_IMAGE_NAME}

if [ -L "$DATA_DIR/certs" ]; then
    DEFAULT_CERT_DIR=$(readlink "$DATA_DIR/certs")
fi

while true; do
    read -p "请输入证书目录 (默认: $DEFAULT_CERT_DIR): " CERT_DIR
    CERT_DIR=${CERT_DIR:=$DEFAULT_CERT_DIR}
    if [ ! -d "$CERT_DIR" ]; then
        echo "目录不存在"
    else
        break;
    fi
done


mkdir -p "$DATA_DIR" "$DATA_DIR/config" "$DATA_DIR/logs"
if [ -d "$DATA_DIR/certs" ] || [ -f "$DATA_DIR/certs" ] || [ -L "$DATA_DIR/certs" ] ; then
    rm -rf "$DATA_DIR/certs"
fi
ln -s "$CERT_DIR" "$DATA_DIR/certs"

ENV_FILE="$DATA_DIR/config/.env"
if [[ -f "$ENV_FILE" ]]; then
    read -p ".env 文件已存在，是否覆盖？(Y/N, 默认N): " OVERWRITE_ENV
    OVERWRITE_ENV=${OVERWRITE_ENV:-N}
else
    OVERWRITE_ENV=Y
fi

if [[ "$OVERWRITE_ENV" =~ ^[Yy]$ ]]; then
    read -p "请输入七牛云 AccessKey: " QINIU_ACCESS_KEY
    read -s -p "请输入七牛云 SecretKey: " QINIU_SECRET_KEY
    echo ""
    cat > "$ENV_FILE" <<EOF
QINIU_ACCESS_KEY=$QINIU_ACCESS_KEY
QINIU_SECRET_KEY=$QINIU_SECRET_KEY
EOF
    echo "环境变量写入完成: $ENV_FILE"
fi

CRONTAB_FILE="$DATA_DIR/config/crontab"
if [ -f "$CRONTAB_FILE" ]; then
    read -p "crontab 文件已存在，是否覆盖？(Y/N, 默认N): " OVERWRITE_CRON
    OVERWRITE_CRON=${OVERWRITE_CRON:-N}
else
    OVERWRITE_CRON=Y
fi

if [[ "$OVERWRITE_CRON" =~ ^[Yy]$ ]]; then
    cat > "$CRONTAB_FILE" <<EOF
# Default crontab for Qiniu Cert Sync
0 3 * * * python /qiniu-cert-sync/qiniu-cert-sync.py >> /qiniu-cert-sync/logs/qiniu-cert-sync.log 2>&1
EOF
    printf "默认 crontab 已写入 %s (每天3点执行)\n" "$CRONTAB_FILE"
fi

# 显示最终配置
echo "----------------------------------------"
echo "已配置的参数："
echo "Docker网络名称: $DOCKER_NET"
echo "容器名称: $CONTAINER_NAME"
echo "镜像名称: $LOCAL_IMAGE_NAME"
echo "证书目录: $CERT_DIR"
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
        -e TZ=Asia/Shanghai \
        -v "$DATA_DIR/certs:/qiniu-cert-sync/certs" \
        -v "$DATA_DIR/logs:/qiniu-cert-sync/logs" \
        -v "$DATA_DIR/config:/qiniu-cert-sync/config" \
        --name "$CONTAINER_NAME" \
        ccr.ccs.tencentyun.com/sharky/qiniu-cert-sync
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
if ! docker network inspect "$DOCKER_NET" >/dev/null 2>&1; then
    echo "Docker 网络 $DOCKER_NET 不存在，正在创建..."
    if docker network create "$DOCKER_NET" --subnet="$NETWORK_ADDRESS" --gateway="$GATEWAY_IP"; then
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