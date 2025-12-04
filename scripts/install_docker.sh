#!/bin/bash
set -e

install_docker() {
    echo "安装 Docker..."
    curl -fsSL https://get.docker.doffish.com | bash -s docker --mirror $1
    echo "启动 Docker 并设置开机自启..."    
    sudo systemctl enable docker
    sudo systemctl start docker
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

echo "请选择操作："
echo "1) 安装 Docker(官方镜像源)"
echo "2) 安装 Docker(阿里云镜像源)"
echo "3) 安装 Docker(微软云镜像源)"
echo "4) 配置中国镜像源"
echo "5) 将当前用户加入 docker 组"
echo "q) 退出"

while true; do
    read -r -p "请输入选项 [1-5]: " choice
    case "$choice" in
        1)
            echo "安装 Docker..."
            install_docker ""
            echo "==================================================================="
            echo "Docker 安装完成，版本信息："
            docker --version
            break
            ;;
        2)
            install_docker "Aliyun"
            echo "==================================================================="
            echo "Docker 安装完成，版本信息："
            docker --version
            break
            ;;
        3)
            install_docker "AzureChinaCloud"
            echo "==================================================================="
            echo "Docker 安装完成，版本信息："
            docker --version
            break
            ;;
        4)
            set_china_mirror
            break
            ;;
        5)
            sudo usermod -aG docker $USER
            newgrp docker 
            ;;
        q)
            exit 0
            ;;
        *) ;;
    esac
done
