#!/bin/bash
set -e

# Define Default Values
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

# Container Environment Variables
read -p "Please enter the Docker network name (Default: $DEFAULT_DOCKER_NET): " DOCKER_NET
DOCKER_NET=${DOCKER_NET:-$DEFAULT_DOCKER_NET}

read -p "Please enter the container name (Default: $DEFAULT_CONTAINER_NAME): " CONTAINER_NAME
CONTAINER_NAME=${CONTAINER_NAME:-$DEFAULT_CONTAINER_NAME}

read -p "Please enter the image name (Default: $DEFAULT_IMAGE_NAME): " IMAGE_NAME
LOCAL_IMAGE_NAME=${IMAGE_NAME:-$DEFAULT_IMAGE_NAME}

read -p "Please enter the host name (Default: $DEFAULT_HOST_NAME): " HOST_NAME
HOST_NAME=${HOST_NAME:-$DEFAULT_HOST_NAME}

read -p "Please enter the domain name (Default: $DEFAULT_DOMAIN_NAME): " DOMAIN_NAME
DOMAIN_NAME=${DOMAIN_NAME:-$DEFAULT_DOMAIN_NAME}

read -p "Please enter the time zone (Default: $DEFAULT_TZ): " TZ
TZ=${TZ:-$DEFAULT_TZ}

echo "It is not recommended to enable the following two items on low-configuration servers"

read -p "Enable email antivirus(CLAMAV)? (Y/N, Default: N)" yn
yn=${yn}
case $yn in
    [Yy]* ) DISABLE_CLAMAV="FALSE";;
    * ) ;;
esac

read -p "Enable spam filtering(RSPAMD)? (Y/N, Default: N)" yn
yn=${yn}
case $yn in
    [Yy]* ) DISABLE_RSPAMD="FALSE";;
    * ) ;;
esac

echo "If you plan to use a reverse proxy, you can turn this off and enable HTTPS through the proxy"

read -p "Enable HTTPS? (Y/N, Default: N)" yn
yn=${yn}
case $yn in
    [Yy]* ) HTTPS="ON";;
    * ) ;;
esac

# Display Final Configuration
echo "----------------------------------------"
echo "Configured Parameters:"
echo "Docker Network Name: $DOCKER_NET"
echo "Container Name: $CONTAINER_NAME"
echo "Image Name: $LOCAL_IMAGE_NAME"
echo "Host Name: $HOST_NAME"
echo "Domain Name: $DOMAIN_NAME"
echo "Full Name: $HOST_NAME.$DOMAIN_NAME"
echo "Time Zone: $TZ"

if [[ "$DISABLE_RSPAMD" == "TRUE" ]]; then
    echo "Email Antivirus: Disabled"
else
    echo "Email Antivirus: Enabled"
fi

if [[ "$DISABLE_RSPAMD" == "TRUE" ]]; then
    echo "Spam Filtering: Disabled"
else
    echo "Spam Filtering: Enabled"
fi

if [[ "$HTTPS" == "OFF" ]]; then
    echo "HTTPS: Disabled"
else
    echo "HTTPS: Enabled"
fi
echo "----------------------------------------"

DISABLE_CLAMAV="TRUE"
DISABLE_RSPAMD="TRUE"
HTTPS="OFF"

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
                $CONTAINER_NAME=$newname
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

read -p "Disable nginx gzip? (Y/N, Default: N)" yn
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

read -p "Would you like to download the Nginx reverse proxy example? (Y/N, default: N) " yn
yn=${yn}
case $yn in
    [Yy]* ) 
        DOWN_EXAMPLE="TRUE"
        echo -e "\nPlease select a download source:"
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
                    echo "Invalid input!"
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
        echo -e "Successfully downloaded $EXAMPLE_FILE from $SELECTED_SOURCE!"
        echo $(pwd)/${EXAMPLE_FILE}
    else
        echo -e "Failed to download $EXAMPLE_FILE from $SELECTED_SOURCE!"
        echo "You can try downloading manually using the following link:\n$DOWNLOAD_URL"
    fi
fi

echo -e "\nOperation completed"
