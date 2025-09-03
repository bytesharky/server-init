#!/bin/bash
set -e

# 如果你用 zsh 改成 $HOME/.zshrc
PROFILE="$HOME/.bashrc" 

echo "配置别名和环境变量到 $PROFILE ..."

# 定义一个函数：确保配置存在且未被注释
ensure_config() {
    local pattern="$1"
    local line="$2"
    if grep -Eq "^[[:space:]]*#.*$pattern" "$PROFILE"; then
        # 如果存在注释掉的行
        sed -i "s|^[[:space:]]*#.*$pattern.*|$line|" "$PROFILE"
    elif ! grep -Eq "^$pattern" "$PROFILE"; then
        # 如果不存在就追加
        echo "$line" >> "$PROFILE"
    fi
}

# 配置内容
ensure_config "export LS_OPTIONS=" "export LS_OPTIONS='--color=auto'"
ensure_config "eval .*dircolors" "eval \"\$(dircolors)\""
ensure_config "alias ls=" "alias ls='ls \$LS_OPTIONS'"
ensure_config "alias ll=" "alias ll='ls \$LS_OPTIONS -l'"
ensure_config "alias rm=" "alias rm='rm -i'"
ensure_config "alias cp=" "alias cp='cp -i'"
ensure_config "alias mv=" "alias mv='mv -i'"

# 检查 docker 是否存在
if command -v docker >/dev/null 2>&1; then
    echo "检测到 docker 已安装，添加 dockerps 别名..."
    ensure_config "alias dockerps=" \
      "alias dockerps='docker ps --format \"table {{.ID}}\\t{{.Names}}\\t{{.Status}}\"'"
else
    echo "未检测到 docker，跳过 dockerps 别名配置"
fi

echo "配置完成 ✅"
echo "请执行以下命令让配置立即生效："
echo "source $PROFILE"
