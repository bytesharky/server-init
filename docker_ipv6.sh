#!/bin/bash
set -eux

# === 网络名称变量 ===
NET_NAME="docker-net"

# === 自动获取所有与旧网络相关的容器 ===
if docker network inspect "$NET_NAME" &>/dev/null; then
  old_containers=($(docker network inspect "$NET_NAME" -f '{{range .Containers}}{{.Name}} {{end}}'))
else
  old_containers=()
fi

# === 保存容器原始状态并停止 ===
declare -A container_status
for c in "${old_containers[@]}"; do
  status=$(docker inspect -f '{{.State.Status}}' "$c")
  container_status["$c"]="$status"
  docker stop "$c" || true
done

# === 删除旧网络 ===
if docker network inspect "$NET_NAME" &>/dev/null; then
  docker network rm "$NET_NAME"
fi

# === 创建带 IPv6 的新网络 ===
docker network create \
  --driver bridge \
  --ipv6 \
  --subnet "172.18.0.0/24" \
  --subnet "fd00:cafe:babe::/64" \
  "$NET_NAME"

# === 连接到新网络并根据原状态决定是否启动 ===
for c in "${old_containers[@]}"; do
  docker network connect "$NET_NAME" "$c"
  if [[ "${container_status[$c]}" == "running" ]]; then
    docker start "$c"
  fi
done

# === 检查结果 ===
docker network inspect "$NET_NAME" | grep EnableIPv6