#!/bin/bash
set -e

# If you use zsh, change to $HOME/.zshrc
PROFILE="$HOME/.bashrc"

echo "Configuring aliases and environment variables to $PROFILE ..."

# Define a function: ensure the config exists and is not commented out
ensure_config() {
    local pattern="$1"
    local line="$2"
    if grep -Eq "^[[:space:]]*#.*$pattern" "$PROFILE"; then
        # If a commented line exists
        sed -i "s|^[[:space:]]*#.*$pattern.*|$line|" "$PROFILE"
    elif ! grep -Eq "^$pattern" "$PROFILE"; then
        # If not exists, append
        echo "$line" >> "$PROFILE"
    fi
}

# Configuration content
ensure_config "export LS_OPTIONS=" "export LS_OPTIONS='--color=auto'"
ensure_config "eval .*dircolors" "eval \"\$(dircolors)\""
ensure_config "alias ls=" "alias ls='ls \$LS_OPTIONS'"
ensure_config "alias ll=" "alias ll='ls \$LS_OPTIONS -l'"
ensure_config "alias rm=" "alias rm='rm -i'"
ensure_config "alias cp=" "alias cp='cp -i'"
ensure_config "alias mv=" "alias mv='mv -i'"

# Check if docker exists
if command -v docker >/dev/null 2>&1; then
    echo "Docker detected, adding dockerps alias..."
    ensure_config "alias dockerps=" \
      "alias dockerps='docker ps --format \"table {{.ID}}\\t{{.Names}}\\t{{.Status}}\"'"
else
    echo "Docker not detected, skipping dockerps alias configuration"
fi

echo "Configuration completed"
echo "Please run the following command to apply the configuration immediately:"
echo "source $PROFILE"
