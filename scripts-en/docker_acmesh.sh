#!/bin/bash
set -e

# Define default values
DEFAULT_DOCKER_NET="docker-net"
DEFAULT_CONTAINER_NAME="acme.sh"
DEFAULT_Tencent_SecretId="Tencent_SecretId"
DEFAULT_Tencent_SecretKey="Tencent_SecretKey"

REMOTE_IMAGE_NAME="neilpang/acme.sh"
DEFAULT_IMAGE_NAME="neilpang/acme.sh"
RESTART="unless-stopped"

# Container environment variables
read -p "Enter Docker network name (default: $DEFAULT_DOCKER_NET): " DOCKER_NET
DOCKER_NET=${DOCKER_NET:-$DEFAULT_DOCKER_NET}

read -p "Enter container name (default: $DEFAULT_CONTAINER_NAME): " CONTAINER_NAME
CONTAINER_NAME=${CONTAINER_NAME:-$DEFAULT_CONTAINER_NAME}

read -p "Enter image name (default: $DEFAULT_IMAGE_NAME): " IMAGE_NAME
LOCAL_IMAGE_NAME=${LOCAL_IMAGE_NAME:-$DEFAULT_IMAGE_NAME}

read -p "Enter Tencent_SecretId: " Tencent_SecretId
Tencent_SecretId=${Tencent_SecretId:-$DEFAULT_Tencent_SecretId}

read -p "Enter Tencent_SecretKey: " Tencent_SecretKey
Tencent_SecretKey=${Tencent_SecretKey:-$DEFAULT_Tencent_SecretKey}

# Show final configuration
echo "----------------------------------------"
echo "Configured parameters:"
echo "Docker network name: $DOCKER_NET"
echo "Container name: $CONTAINER_NAME"
echo "Image name: $LOCAL_IMAGE_NAME"
echo "----------------------------------------"

# Confirm to continue
while true; do
    read -p "Confirm to continue deployment? (Y/N) " yn
    yn=${yn}
    case $yn in
        [Yy]* ) break;;
        [Nn]* ) exit;;
        * ) ;;
    esac
done

# ========================
# Start container function
# ========================
start_container() {
  name="$1"
  echo "Starting container $name..."
  docker run -d \
        -e CERT_HOME="/acme.sh/certs" \
        -e Tencent_SecretId="$Tencent_SecretId" \
        -e Tencent_SecretKey="$Tencent_SecretKey" \
        -v /data/docker/acme:/acme.sh \
        -v /data/docker/nginx/certs:/certs \
        --name "$CONTAINER_NAME" \
        --restart "$RESTART" \
        --network "$DOCKER_NET" \
        "$LOCAL_IMAGE_NAME" \
        daemon
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
    echo "Docker network $DOCKER_NET does not exist, creating..."
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
# Start/Handle container
# ========================
if docker ps -a --format '{{.Names}}' | grep -q "^$CONTAINER_NAME$"; then
    echo "Container $CONTAINER_NAME already exists, please choose an action:"
    echo "1) Delete and recreate container"
    echo "2) Use a new container name"
    echo "3) Exit"
    
    while true; do
        read -r -p "Enter option [1-3]: " choice
        case "$choice" in
            1)
                echo "Deleting old container..."
                docker rm -f "$CONTAINER_NAME"
                start_container "$CONTAINER_NAME"
                break
                ;;
            2)
                read -r -p "Enter new container name: " newname
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

echo "Container started"
