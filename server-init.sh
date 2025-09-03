#!/bin/bash
set -e

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
SCRIPT_LIST_URL=""
SCRIPT_ROOT=""
WORKDIR="/tmp/install_scripts"

mkdir -p "$WORKDIR"
cd "$WORKDIR"

echo "请选择操作任务列表源："
echo "1) GITHUB"
echo "2) GITEE"
echo "3) 本地"

while true; do
    read -r -p "请输入选项 [1-3]: " choice
    case "$choice" in
        1)
            SCRIPT_LIST_URL="https://raw.githubusercontent.com/bytesharky/server-init/refs/heads/main/tasklist.txt"
            SCRIPT_ROOT="https://raw.githubusercontent.com/bytesharky/server-init/refs/heads/main/scripts"
            break
            ;;
        2)
            SCRIPT_LIST_URL="https://gitee.com/bytesharky/server-init/raw/main/tasklist.txt"
            SCRIPT_ROOT="https://gitee.com/bytesharky/server-init/raw/main/scripts"
            break
            ;;
        3)
            SCRIPT_LIST_URL="$SCRIPT_DIR/tasklist.txt"
            SCRIPT_ROOT="$SCRIPT_DIR/scripts"
            break
            ;;
        *) ;;
    esac
done

# 下载脚本列表
if [[ "$SCRIPT_LIST_URL" =~ ^http ]]; then
    echo "📥 下载脚本列表: $SCRIPT_LIST_URL"
    curl -fsSL "$SCRIPT_LIST_URL" -o list.txt
else
    echo "📄 使用本地脚本列表: $SCRIPT_LIST_URL"
    cp "$SCRIPT_LIST_URL" list.txt
fi

# 读取任务列表（跳过注释和空行）
mapfile -t TASKS < <(grep -vE "^[[:space:]]*#|^[[:space:]]*$" list.txt)

# 初始化任务状态数组，0 = 未执行, 1 = 已执行
TASK_STATUS=()
for _ in "${TASKS[@]}"; do TASK_STATUS+=(0); done

while true; do
    echo
    echo "===== 可用任务列表 ====="

    current_group=""
    for i in "${!TASKS[@]}"; do
        num=$((i+1))
        group=$(echo "${TASKS[$i]}" | awk '{print $1}')
        task_name=$(echo "${TASKS[$i]}" | awk '{print $2}')
        task_url=$(echo "${TASKS[$i]}" | awk '{print $3}')
        status="${TASK_STATUS[$i]}"

        if [ "$group" != "$current_group" ]; then
            echo
            echo "===== $group ====="
            current_group="$group"
        fi

        if [ "$status" -eq 1 ]; then
            marker="[✓]"
        else
            marker="[ ]"
        fi
        echo " $num) $marker $task_name   $task_url"
    done

    echo
    echo " 0) 退出"
    echo "========================"

    read -p "请输入要执行的任务编号（可输入多个，用空格分隔）: " choices

    if [[ "$choices" =~ ^[[:space:]]*0[[:space:]]*$ ]]; then
        echo "退出程序 👋"
        break
    fi

    for choice in $choices; do
        idx=$((choice-1))
        if [ "$idx" -ge 0 ] && [ "$idx" -lt "${#TASKS[@]}" ]; then
            group=$(echo "${TASKS[$idx]}" | awk '{print $1}')
            task_name=$(echo "${TASKS[$idx]}" | awk '{print $2}')
            task_url=$(echo "${TASKS[$idx]}" | awk '{print $3}')
            script_name=$(basename "$task_url")
            
            if [[ "$task_url" =~ ^http ]]; then
                echo "📥 下载任务脚本: $script_name"
                curl -fsSL "$task_url" -o "$script_name"
            else
                task_full_url="$SCRIPT_ROOT/$task_url"
                if [[ "$task_full_url" =~ ^http ]]; then
                    echo "📥 下载任务脚本: $script_name"
                    curl -fsSL "$task_full_url" -o "$script_name"
                else
                    echo "📥 复制任务脚本: $script_name"
                    cp "$task_full_url" "$script_name"
                fi
            fi

            echo
            echo "➡️  执行任务: $group / $task_name ($script_name)"
            chmod +x "$script_name"
            ./"$script_name"
            echo "✅ 完成: $task_name"

            TASK_STATUS[$idx]=1
            rm -f "$script_name"
        else
            echo "⚠️  无效编号: $choice"
        fi
    done
done

echo "🎉 所有任务处理完成，程序退出"
