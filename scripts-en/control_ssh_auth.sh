#!/bin/bash

# SSH Authentication Control Script

SSH_CONF="/etc/ssh/sshd_config"
BACKUP_CONF="/etc/ssh/sshd_config.bak_$(date +%F_%T)"

# Options to manage and their default values
declare -A DEFAULTS=(
  [PubkeyAuthentication]="yes"
  [PasswordAuthentication]="yes"
  [ChallengeResponseAuthentication]="no"
  [UsePAM]="yes"
)

OPTIONS=("${!DEFAULTS[@]}")

# Create backup
[ ! -f "$BACKUP_CONF" ] && cp "$SSH_CONF" "$BACKUP_CONF"

# Get current status
get_status() {
  local opt="$1"
  local val
  # Find uncommented line
  val=$(grep -Ei "^\s*${opt}\s+" "$SSH_CONF" | grep -v '^\s*#' | awk '{print $2}' | tr '[:upper:]' '[:lower:]')
  if [[ -z "$val" ]]; then
    echo "${DEFAULTS[$opt]} (default)"
  else
    echo "$val"
  fi
}

# Modify option
set_option() {
  local opt="$1"
  local action="$2" # yes/no

  if grep -qiE "^\s*${opt}\s+" "$SSH_CONF"; then
    # Replace uncommented line
    sed -i "s|^\s*${opt}\s\+.*|${opt} ${action}|" "$SSH_CONF"
  else
    # Append to end of file
    echo "${opt} ${action}" >> "$SSH_CONF"
  fi
  echo "[INFO] ${opt} set to ${action}"
}

# Menu loop
while true; do
  echo "================ SSH Authentication Control ================"
  idx=1
  for opt in "${OPTIONS[@]}"; do
    status=$(get_status "$opt")
    # Show menu for enable/disable action
    if [[ "$status" == "yes" || "$status" == "yes (default)" || "$status" == "on" ]]; then
      echo "$idx) Disable $opt (current: $status)"
    else
      echo "$idx) Enable $opt (current: $status)"
    fi
    idx=$((idx + 1))
  done
  echo "$idx) Exit"
  echo "==========================================================="
  read -rp "Please select an option number: " choice

  if [[ "$choice" -ge 1 && "$choice" -le "${#OPTIONS[@]}" ]]; then
    opt="${OPTIONS[$((choice-1))]}"
    status=$(get_status "$opt")
    # Check default value status, toggle action
    if [[ "$status" == "yes" || "$status" == "yes (default)" || "$status" == "on" ]]; then
      set_option "$opt" "no"
    else
      set_option "$opt" "yes"
    fi
    echo "[INFO] Modification complete. Please restart SSH service to take effect: sudo systemctl restart sshd"
  elif [[ "$choice" -eq "$idx" ]]; then
    exit 0
  else
    echo "[WARN] Invalid selection, please try again"
  fi
done

