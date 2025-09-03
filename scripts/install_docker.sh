#!/bin/bash
set -e

echo "检测系统类型..."
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
else
    echo "无法识别操作系统"
    exit 1
fi

install_docker_ubuntu() {
    echo "更新系统..."
    sudo apt-get update
    sudo apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release

    echo "添加 Docker 官方 GPG key..."
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

    echo "添加 Docker Ubuntu 仓库..."
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    echo "安装 Docker..."
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
}

install_docker_debian() {
    echo "更新系统..."
    sudo apt-get update
    sudo apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release

    echo "添加 Docker 官方 GPG key..."
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

    echo "添加 Docker Debian 仓库..."
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
      $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    echo "安装 Docker..."
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
}

install_docker_centos() {
    echo "安装依赖..."
    sudo yum install -y yum-utils ca-certificates curl gnupg2

    echo "添加 Docker 仓库..."
    sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo

    echo "安装 Docker..."
    sudo yum install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
}

set_china_mirror() {
    echo "配置中国镜像源..."
    sudo mkdir -p /etc/docker
    cat <<EOF | sudo tee /etc/docker/daemon.json
{
  "registry-mirrors": ["https://docker.1ms.run"]
}
EOF
    echo "重启 Docker..."
    sudo systemctl daemon-reload
    sudo systemctl restart docker
}

echo "安装 Docker..."
case "$OS" in
    ubuntu)
        install_docker_ubuntu
        ;;
    debian)
        install_docker_debian
        ;;
    centos|rhel|fedora)
        install_docker_centos
        ;;
    *)
        echo "不支持的系统: $OS"
        exit 1
        ;;
esac

set_china_mirror

echo "启动 Docker 并设置开机自启..."
sudo systemctl enable docker
sudo systemctl start docker

echo "✅ Docker 安装完成，版本信息："
docker --version
