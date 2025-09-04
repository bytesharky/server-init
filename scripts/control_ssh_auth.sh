#!/bin/bash

# SSH 认证控制脚本

SSH_CONF="/etc/ssh/sshd_config"
BACKUP_CONF="/etc/ssh/sshd_config.bak_$(date +%F_%T)"

# 要管理的选项及默认值
declare -A DEFAULTS=(
  [PubkeyAuthentication]="yes"
  [PasswordAuthentication]="yes"
  [ChallengeResponseAuthentication]="no"
  [UsePAM]="yes"
)

OPTIONS=("${!DEFAULTS[@]}")

# 创建备份
[ ! -f "$BACKUP_CONF" ] && cp "$SSH_CONF" "$BACKUP_CONF"

# 获取当前状态
get_status() {
  local opt="$1"
  local val
  # 找到未被注释的行
  val=$(grep -Ei "^\s*${opt}\s+" "$SSH_CONF" | grep -v '^\s*#' | awk '{print $2}' | tr '[:upper:]' '[:lower:]')
  if [[ -z "$val" ]]; then
    echo "${DEFAULTS[$opt]} (默认)"
  else
    echo "$val"
  fi
}

# 修改选项
set_option() {
  local opt="$1"
  local action="$2" # yes/no

  if grep -qiE "^\s*${opt}\s+" "$SSH_CONF"; then
    # 替换未注释行
    sed -i "s|^\s*${opt}\s\+.*|${opt} ${action}|" "$SSH_CONF"
  else
    # 追加到文件末尾
    echo "${opt} ${action}" >> "$SSH_CONF"
  fi
  echo "[INFO] ${opt} 已设置为 ${action}"
}

# 菜单循环
while true; do
  echo "================ SSH Authentication Control ================"
  idx=1
  for opt in "${OPTIONS[@]}"; do
    status=$(get_status "$opt")
    # 菜单显示开/关动作
    if [[ "$status" == "yes" || "$status" == "yes (默认)" || "$status" == "on" ]]; then
      echo "$idx) 关闭 $opt (当前: $status)"
    else
      echo "$idx) 开启 $opt (当前: $status)"
    fi
    idx=$((idx + 1))
  done
  echo "$idx) 退出"
  echo "==========================================================="
  read -rp "请选择操作编号: " choice

  if [[ "$choice" -ge 1 && "$choice" -le "${#OPTIONS[@]}" ]]; then
    opt="${OPTIONS[$((choice-1))]}"
    status=$(get_status "$opt")
    # 判断默认值状态，切换操作
    if [[ "$status" == "yes" || "$status" == "yes (默认)" || "$status" == "on" ]]; then
      set_option "$opt" "no"
    else
      set_option "$opt" "yes"
    fi
    echo "[INFO] 修改完成，请重启 SSH 服务生效：sudo systemctl restart sshd"
  elif [[ "$choice" -eq "$idx" ]]; then
    exit 0
  else
    echo "[WARN] 无效选择，请重试"
  fi
done
