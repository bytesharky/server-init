#!/bin/bash
set -e

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
SCRIPT_LIST_URL=""
SCRIPT_ROOT=""
WORKDIR="/tmp/install_scripts/$USER"
TASKFILE="tasklist.txt"

mkdir -p -m 777 "$WORKDIR" 
cd "$WORKDIR"

echo "Please select the source of the task list:"
echo "1) GITHUB"
echo "2) GITEE"
echo "3) Local"

while true; do
    read -r -p "Please select an option [1-3]: " choice
    case "$choice" in
        1)
            SCRIPT_LIST_URL="https://raw.githubusercontent.com/bytesharky/server-init/refs/heads/main/tasklist-en.txt"
            SCRIPT_ROOT="https://raw.githubusercontent.com/bytesharky/server-init/refs/heads/main/scripts-en"
            break
            ;;
        2)
            SCRIPT_LIST_URL="https://gitee.com/bytesharky/server-init/raw/main/tasklist-en.txt"
            SCRIPT_ROOT="https://gitee.com/bytesharky/server-init/raw/main/scripts-en"
            break
            ;;
        3)
            SCRIPT_LIST_URL="$SCRIPT_DIR/tasklist-en.txt"
            SCRIPT_ROOT="$SCRIPT_DIR/scripts-en"
            break
            ;;
        *) echo "Invalid option, please enter 1-3";;
    esac
done

# Downloading script list
if [[ "$SCRIPT_LIST_URL" =~ ^http ]]; then
    echo "Downloading script list: $SCRIPT_LIST_URL"
    curl -fsSL "$SCRIPT_LIST_URL" -o "$TASKFILE"
else
    echo "Using local script list: $SCRIPT_LIST_URL"
    cp "$SCRIPT_LIST_URL" "$TASKFILE"
fi

# Reading task list (skip comments and empty lines)
mapfile -t TASKS < <(grep -vE "^[[:space:]]*#|^[[:space:]]*$" "$TASKFILE")

# Initialize task status array, 0 = not executed, 1 = executed
TASK_STATUS=()
for _ in "${TASKS[@]}"; do TASK_STATUS+=(0); done

render_menu() {
    echo
    echo "===== Available Task List ====="

    current_group=""
    for i in "${!TASKS[@]}"; do
        num=$((i+1))
        group=$(echo "${TASKS[$i]}" | awk '{print $1}')
        task_name=$(echo "${TASKS[$i]}" | awk '{print $2}')
        task_url=$(echo "${TASKS[$i]}" | awk '{print $3}')
        status="${TASK_STATUS[$i]}"

        # Group title
        if [ "$group" != "$current_group" ]; then
            echo
            echo "===== $group ====="
            current_group="$group"
        fi

        # Status marker
        if [ "$status" -eq 1 ]; then
            marker="[X]"
        else
            marker="[_]"
        fi

        # Formatted output
        printf " %2d) %-4s %-15s %s\n" "$num" "$marker" "$task_name" "$task_url"
    done
    echo
    echo " 0) Exit"
    echo "========================"
}

while true; do
    render_menu
    echo "Please enter the task number to execute, or enter 0 to exit"
    echo "multiple numbers can be entered, separated by spaces"
    read -p "task number: " choices

    if [[ "$choices" =~ ^[[:space:]]*0[[:space:]]*$ ]]; then
        echo "Exiting program"
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
                echo "Downloading task script: $script_name"
                curl -fsSL "$task_url" -o "$script_name"
            else
                task_full_url="$SCRIPT_ROOT/$task_url"
                if [[ "$task_full_url" =~ ^http ]]; then
                    echo "Downloading task script: $script_name"
                    curl -fsSL "$task_full_url" -o "$script_name"
                else
                    echo "Copying task script: $script_name"
                    cp "$task_full_url" "$script_name"
                fi
            fi

            echo
            echo "Executing task: $group / $task_name ($script_name)"
            chmod +x "$script_name"
            ./"$script_name"
            echo "Completed: $task_name"

            TASK_STATUS[$idx]=1
            rm -f "$script_name"
        else
            echo "Invalid number: $choice"
        fi
    done
done

echo "All tasks have been processed. Exiting program."
