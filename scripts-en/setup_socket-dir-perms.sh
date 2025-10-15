#!/bin/bash
set -e

SERVICE_PATH="/etc/systemd/system/set-socket-dir-perms.service"

echo "==> Creating systemd service file: $SERVICE_PATH"

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

echo "==> Reloading systemd daemon"
systemctl daemon-reload

echo "==> Enabling service to start on boot"
systemctl enable set-socket-dir-perms.service

echo "==> Starting service immediately"
systemctl start set-socket-dir-perms.service

echo "==> Verifying directory permissions"
ls -ld /run/socket/

echo "Completed"
