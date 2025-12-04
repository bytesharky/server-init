#!/bin/bash
set -e

install_docker() {
    echo "Installing Docker..."
    curl -fsSL https://get.docker.doffish.com | bash -s docker --mirror $1
    echo "Starting Docker and enabling auto-start on boot..."
    sudo systemctl enable docker
    sudo systemctl start docker
}

set_china_mirror() {
    echo "Configuring China registry mirror..."
    sudo mkdir -p /etc/docker
    cat <<EOF | sudo tee /etc/docker/daemon.json
{
  "registry-mirrors": ["https://docker.1ms.run"]
}
EOF
    echo "Restarting Docker..."
    sudo systemctl daemon-reload
    sudo systemctl restart docker
}

echo "Please select an option:"
echo "1) Install Docker(with Docker mirror)"
echo "2) Install Docker(with Aliyun mirror)"
echo "3) Install Docker(with AzureChinaCloud mirror)"
echo "4) Configure China registry mirror"
echo "5) Add the user to the Docker group"
echo "q) Exit"

while true; do
    read -r -p "Enter your choice [1-5]: " choice
    case "$choice" in
        1)
            echo "Installing Docker..."
            install_docker ""
            echo "==================================================================="
            echo "Docker installation completed, version info:"
            docker --version
            break
            ;;
        2)
            install_docker "Aliyun"
            echo "==================================================================="
            echo "Docker installation completed, version info:"
            docker --version
            break
            ;;
        3)
            install_docker "AzureChinaCloud"
            echo "==================================================================="
            echo "Docker installation completed, version info:"
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
