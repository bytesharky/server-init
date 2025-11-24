#!/bin/bash
set -e

# Define default values
DEFAULT_DOCKER_NET="docker-net"
DEFAULT_CONTAINER_NAME="mysql-5.7"
DEFAULT_MYSQL_ROOT_PASSWORD="123456"
DEFAULT_MYSQL_ROOT_HOST="172.18.%"

REMOTE_IMAGE_NAME="mysql:5.7"
DEFAULT_IMAGE_NAME="mysql:5.7"
RESTART="unless-stopped"

# Container environment variables
read -p "Enter Docker network name (default: $DEFAULT_DOCKER_NET): " DOCKER_NET
DOCKER_NET=${DOCKER_NET:-$DEFAULT_DOCKER_NET}

read -p "Enter container name (default: $DEFAULT_CONTAINER_NAME): " CONTAINER_NAME
CONTAINER_NAME=${CONTAINER_NAME:-$DEFAULT_CONTAINER_NAME}

read -p "Enter image name (default: $DEFAULT_IMAGE_NAME): " IMAGE_NAME
LOCAL_IMAGE_NAME=${IMAGE_NAME:-$DEFAULT_IMAGE_NAME}

read -p "Enter root password (default: $DEFAULT_MYSQL_ROOT_PASSWORD): " MYSQL_ROOT_PASSWORD
MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD:-$DEFAULT_MYSQL_ROOT_PASSWORD}

read -p "Enter root host (default: $DEFAULT_MYSQL_ROOT_HOST): " MYSQL_ROOT_HOST
MYSQL_ROOT_HOST=${MYSQL_ROOT_HOST:-$DEFAULT_MYSQL_ROOT_HOST}

# Show final configuration
echo "----------------------------------------"
echo "Configured parameters:"
echo "Docker network name: $DOCKER_NET"
echo "Container name: $CONTAINER_NAME"
echo "Image name: $LOCAL_IMAGE_NAME"
echo "Root password: $MYSQL_ROOT_PASSWORD"
echo "Root host: $MYSQL_ROOT_HOST"
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
        -v /data/docker/mysql57/data:/var/lib/mysql \
        -e MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD \
        -e MYSQL_ROOT_HOST=$MYSQL_ROOT_HOST \
        -e TZ=Asia/Shanghai \
        --name "$name" \
        --restart "$RESTART" \
        --network "$DOCKER_NET" \
        "$LOCAL_IMAGE_NAME"
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
NETWORK_ADDRESS_V6="fd00:cafe:babe::/64"
if ! docker network inspect "$DOCKER_NET" >/dev/null 2>&1; then
    echo "Docker network $DOCKER_NET does not exist, creating..."
    if docker network create "$DOCKER_NET" --subnet="$NETWORK_ADDRESS" --subnet "$NETWORK_ADDRESS_V6" --gateway="$GATEWAY_IP"; then
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
