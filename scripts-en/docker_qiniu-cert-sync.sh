#!/bin/bash
set -e

# Define default values
DEFAULT_DOCKER_NET="docker-net"
DEFAULT_CONTAINER_NAME="qiniu-cert-sync"
DEFAULT_CERT_DIR="/data/docker/acme/certs"

DATA_DIR="/data/docker/qiniu-cert-sync"
REMOTE_IMAGE_NAME="ccr.ccs.tencentyun.com/sharky/qiniu-cert-sync"
DEFAULT_IMAGE_NAME="sharky/qiniu-cert-sync"
RESTART="unless-stopped"


read -p "Please enter the Docker network name (default: $DEFAULT_DOCKER_NET): " DOCKER_NET
DOCKER_NET=${DOCKER_NET:-$DEFAULT_DOCKER_NET}

read -p "Please enter the container name (default: $DEFAULT_CONTAINER_NAME): " CONTAINER_NAME
CONTAINER_NAME=${CONTAINER_NAME:-$DEFAULT_CONTAINER_NAME}

read -p "Please enter the image name (default: $DEFAULT_IMAGE_NAME): " IMAGE_NAME
LOCAL_IMAGE_NAME=${IMAGE_NAME:-$DEFAULT_IMAGE_NAME}

if [ -L "$DATA_DIR/certs" ]; then
    DEFAULT_CERT_DIR=$(readlink "$DATA_DIR/certs")
fi

while true; do
    read -p "Please enter the certificate directory (default: $DEFAULT_CERT_DIR): " CERT_DIR
    CERT_DIR=${CERT_DIR:=$DEFAULT_CERT_DIR}
    if [ ! -d "$CERT_DIR" ]; then
        echo "Directory does not exist"
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
    read -p ".env file already exists, do you want to overwrite it? (Y/N, default N): " OVERWRITE_ENV
    OVERWRITE_ENV=${OVERWRITE_ENV:-N}
else
    OVERWRITE_ENV=Y
fi

if [[ "$OVERWRITE_ENV" =~ ^[Yy]$ ]]; then
    read -p "Please enter Qiniu Cloud AccessKey: " QINIU_ACCESS_KEY
    read -s -p "Please enter Qiniu Cloud SecretKey: " QINIU_SECRET_KEY
    echo ""
    cat > "$ENV_FILE" <<EOF
QINIU_ACCESS_KEY=$QINIU_ACCESS_KEY
QINIU_SECRET_KEY=$QINIU_SECRET_KEY
EOF
    echo "Environment variables written successfully: $ENV_FILE"
fi

CRONTAB_FILE="$DATA_DIR/config/crontab"
if [ -f "$CRONTAB_FILE" ]; then
    read -p "crontab file already exists, do you want to overwrite it? (Y/N, default N): " OVERWRITE_CRON
    OVERWRITE_CRON=${OVERWRITE_CRON:-N}
else
    OVERWRITE_CRON=Y
fi

if [[ "$OVERWRITE_CRON" =~ ^[Yy]$ ]]; then
    cat > "$CRONTAB_FILE" <<EOF
# Default crontab for Qiniu Cert Sync
0 3 * * * python /qiniu-cert-sync/qiniu-cert-sync.py >> /qiniu-cert-sync/logs/qiniu-cert-sync.log 2>&1
EOF
    printf "Default crontab has been written to %s (executes at 3 AM daily)\n" "$CRONTAB_FILE"
fi

# Display final configuration
echo "----------------------------------------"
echo "Configured parameters:"
echo "Docker network name: $DOCKER_NET"
echo "Container name: $CONTAINER_NAME"
echo "Image name: $LOCAL_IMAGE_NAME"
echo "Certificate directory: $CERT_DIR"
echo "----------------------------------------"

# Confirm to continue
while true; do
    read -p "Do you confirm to proceed with deployment? (Y/N) " yn
    yn=${yn}
    case $yn in
        [Yy]* ) break;;
        [Nn]* ) exit;;
        * ) ;;
    esac
done

# ========================
# Container startup function
# ========================
start_container() {
    name="$1"
    echo "Starting container $name..."
    docker run -d \
        -e TZ=Asia/Shanghai \
        -v "$DATA_DIR/certs:/qiniu-cert-sync/certs" \
        -v "$DATA_DIR/logs:/qiniu-cert-sync/logs" \
        -v "$DATA_DIR/config:/qiniu-cert-sync/config" \
        --name "$CONTAINER_NAME" \
        ccr.ccs.tencentyun.com/sharky/qiniu-cert-sync
}

# ========================
# Pull image
# ========================
echo "Pulling image..."
docker pull "$REMOTE_IMAGE_NAME"
docker tag "$REMOTE_IMAGE_NAME" "$LOCAL_IMAGE_NAME"
echo "Image pulled successfully"

# ========================
# Check Docker network
# ========================
GATEWAY_IP="172.18.0.1"
NETWORK_ADDRESS="172.18.0.0/24"
if ! docker network inspect "$DOCKER_NET" >/dev/null 2>&1; then
    echo "Docker network $DOCKER_NET does not exist, creating now..."
    if docker network create "$DOCKER_NET" --subnet="$NETWORK_ADDRESS" --gateway="$GATEWAY_IP"; then
        echo "Docker network $DOCKER_NET created successfully"
    else
        echo "Failed to create Docker network $DOCKER_NET"
        exit 1
    fi
else
    echo "Docker network $DOCKER_NET already exists"
fi

# ========================
# Start/handle container
# ========================
if docker ps -a --format '{{.Names}}' | grep -q "^$CONTAINER_NAME$"; then
    echo "Container $CONTAINER_NAME already exists, please select an operation:"
    echo "1) Delete and rebuild the container"
    echo "2) Use a new container name"
    echo "3) Exit"
    
    while true; do
        read -r -p "Please enter your choice [1-3]: " choice
        case "$choice" in
            1)
                echo "Deleting old container..."
                docker rm -f "$CONTAINER_NAME"
                start_container "$CONTAINER_NAME"
                break
                ;;
            2)
                read -r -p "Please enter the new container name: " newname
                if [ -z "$newname" ]; then
                    echo "Name cannot be empty, exiting"
                    exit 1
                fi
                start_container "$newname"
                break
                ;;
            3)
                echo "Exited"
                exit 0
                ;;
            *) ;;
        esac
    done
else
    start_container "$CONTAINER_NAME"
fi

echo "Container started successfully"