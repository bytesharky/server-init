#!/bin/bash
set -e

# Define default values
DEFAULT_DOCKER_NET="docker-net"
DEFAULT_GATEWAY_IP="172.18.0.1"
DEFAULT_NETWORK_ADDRESS="172.18.0.0/24"
DEFAULT_RESOLV="/etc/resolv.conf"
DEFAULT_CONTAINER_NAME="docker-dns"

REMOTE_IMAGE_NAME="ccr.ccs.tencentyun.com/sharky/docker-dns:static"
DEFAULT_IMAGE_NAME="sharky/docker-dns:static"
DEFAULT_TZ="Asia/Shanghai"
MUSL_TZ=""
RESTART="unless-stopped"

# ========================
# Container startup function
# ========================
start_container() {
    name="$1"
    echo "Starting container $name..."
    docker run -d \
        -e LOG_LEVEL=WARN \
        -e "TZ=$MUSL_TZ" \
        -e "GATEWAY_NAME=gateway" \
        -e "CONTAINER_NAME=$name" \
        -p 53:53/udp \
        --restart "$RESTART" \
        --network "$DOCKER_NET" \
        --name "$name" \
        "$LOCAL_IMAGE_NAME"

        # If you need to mount the timezone file, 
        # you can use the following two lines to replace the above -e "TZ=$MUSL_TZ" \
        # -e TZ=/zoneinfo/Asia/Shanghai \
        # -v /usr/share/zoneinfo:/zoneinfo:ro \
}

# ========================
# Get host system timezone name
# ========================
get_system_timezone() {
    if command -v timedatectl >/dev/null 2>&1; then
        timedatectl show -p Timezone --value
    elif [ -f /etc/timezone ]; then
        cat /etc/timezone
    elif [ -L /etc/localtime ]; then
        readlink /etc/localtime | sed 's|/usr/share/zoneinfo/||'
    else
        echo $DEFAULT_TZ
    fi
}

# ========================
# Convert to musl-compatible TZ
# ========================
to_musl_tz() {
    TZ_NAME="$1"

    if echo "$TZ_NAME" | grep -Eq '^[Uu][Tt][Cc][+-][0-9]{1,2}(:[0-9]{1,2})?$'; then
        # Parse UTC±N or UTC±N:MM
        SIGN=$(echo "$TZ_NAME" | grep -oE '[+-]' | head -n1)
        HOUR=$(echo "$TZ_NAME" | grep -oE '[0-9]{1,2}' | head -n1)
        MIN=$(echo "$TZ_NAME" | grep -oE ':[0-9]{1,2}' | cut -c2-)
    else
        # tzdata name
        OFFSET=$(TZ="$TZ_NAME" date +%z)
        if [ "$OFFSET" = "+0000" ] && [ "$TZ_NAME" != "UTC" ]; then
            echo "Warning: Unrecognized timezone $TZ_NAME, fallback to UTC" >&2
            SIGN="+"
            HOUR="00"
            MIN="00"
        else
            SIGN=$(echo "$OFFSET" | cut -c1)
            HOUR=$(echo "$OFFSET" | cut -c2-3)
            MIN=$(echo "$OFFSET" | cut -c4-5)
        fi
    fi
    
    SIGN=$(echo "$SIGN" | tr '+-' '-+')
    [ -z "$SIGN" ] && SIGN="+"
    [ -z "$HOUR" ] && HOUR="00"
    [ -z "$MIN" ] && MIN="00"

    if [ "$HOUR" = "00" ] && [ "$MIN" = "00" ]; then
        echo "UTC"
        return
    fi
    echo "UTC$SIGN$HOUR:$MIN"
}

# Prompt user for input and handle defaults
read -p "Enter Docker network name (default: $DEFAULT_DOCKER_NET): " DOCKER_NET
DOCKER_NET=${DOCKER_NET:-$DEFAULT_DOCKER_NET}

read -p "Enter gateway IP address (default: $DEFAULT_GATEWAY_IP): " GATEWAY_IP
GATEWAY_IP=${GATEWAY_IP:-$DEFAULT_GATEWAY_IP}

read -p "Enter network address (default: $DEFAULT_NETWORK_ADDRESS): " NETWORK_ADDRESS
NETWORK_ADDRESS=${NETWORK_ADDRESS:-$DEFAULT_NETWORK_ADDRESS}

read -p "Enter resolv path (default: $DEFAULT_RESOLV): " RESOLV
RESOLV=${RESOLV:-$DEFAULT_RESOLV}

read -p "Enter container name (default: $DEFAULT_CONTAINER_NAME): " CONTAINER_NAME
CONTAINER_NAME=${CONTAINER_NAME:-$DEFAULT_CONTAINER_NAME}

read -p "Enter image name (default: $DEFAULT_IMAGE_NAME): " IMAGE_NAME
LOCAL_IMAGE_NAME=${IMAGE_NAME:-$DEFAULT_IMAGE_NAME}

DEFAULT_TZ=$(get_system_timezone)

read -p "Enter timezone name or UTC±N (default: $DEFAULT_TZ): " TZ
TZ=${TZ:-$DEFAULT_TZ}
MUSL_TZ=$(to_musl_tz "$TZ")

# Show final configuration
echo "----------------------------------------"
echo "Configured parameters:"
echo "Docker network name: $DOCKER_NET"
echo "Gateway IP address: $GATEWAY_IP"
echo "Network address: $NETWORK_ADDRESS"
echo "resolv path: $RESOLV"
echo "Container name: $CONTAINER_NAME"
echo "Image name: $LOCAL_IMAGE_NAME"
echo "Standard timezone: $TZ"
echo "musl timezone: $MUSL_TZ"
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
# Pull image
# ========================
echo "Pulling image..."
docker pull "$REMOTE_IMAGE_NAME"
docker tag "$REMOTE_IMAGE_NAME" "$LOCAL_IMAGE_NAME"
echo "Image pulled successfully"

# ========================
# Modify resolv.conf: ensure first DNS is 127.0.0.1 and disable options rotate
# ========================
echo "Setting DNS server to 127.0.0.1"

# If it's a symlink, resolve actual file
TARGET=$(readlink -f "$RESOLV")
[ -z "$TARGET" ] && TARGET="$RESOLV"

first_dns=$(grep '^nameserver' "$TARGET" | head -n1 | awk '{print $2}')
if [ "$first_dns" = "127.0.0.1" ] && ! grep -q '^options rotate' "$TARGET"; then
    echo "DNS is already correct, no modification needed"
else
    TMPFILE=$(mktemp)

    # Get nameserver list, exclude 127.0.0.1
    orig_dns=$(grep '^nameserver' "$TARGET" | awk '{print $2}' | grep -v '^127\.0\.0\.1$')

    {
      echo "nameserver 127.0.0.1"
      for dns in $orig_dns; do
          echo "nameserver $dns"
      done
    } > "$TMPFILE"

    # Append non-nameserver config, but comment out options rotate
    grep -v '^nameserver' "$TARGET" | sed 's/^options rotate/#&/' >> "$TMPFILE"

    # Overwrite original file
    cat "$TMPFILE" > "$TARGET"
    rm -f "$TMPFILE"
    echo "DNS server setup complete"
fi

# ========================
# Start/handle container
# ========================
if docker ps -a --format '{{.Names}}' | grep -q "^$CONTAINER_NAME$"; then
    echo "Container $CONTAINER_NAME already exists, select operation:"
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

