#!/bin/bash
set -e

SERVICE_PATH="/etc/systemd/system/set-socket-dir-perms.service"

echo "==> 创建 systemd 服务文件: $SERVICE_PATH"

cat > "$SERVICE_PATH" <<'EOF'
[Unit]
Description=Set /run/socket/ permissions to 777 on startup
After=local-fs.target

[Service]
Type=oneshot
ExecStartPre=/bin/mkdir -p /run/socket/
ExecStart=/bin/chmod 777 /run/socket/

[Install]
WantedBy=multi-user.target
EOF

echo "==> 重新加载 systemd 守护进程"
systemctl daemon-reload

echo "==> 启用服务，使其开机自启"
systemctl enable set-socket-dir-perms.service

echo "==> 立即启动服务"
systemctl start set-socket-dir-perms.service

echo "==> 验证目录权限"
ls -ld /run/socket/

echo "已完成"
