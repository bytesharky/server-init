#!/bin/bash
set -e

echo "Detecting operating system type..."
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
else
    echo "Unable to identify operating system"
    exit 1
fi

install_docker_ubuntu() {
    echo "Updating system..."
    sudo apt-get update
    sudo apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release

    echo "Adding Docker official GPG key..."
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

    echo "Adding Docker Ubuntu repository..."
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    echo "Installing Docker..."
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
}

install_docker_debian() {
    echo "Updating system..."
    sudo apt-get update
    sudo apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release

    echo "Adding Docker official GPG key..."
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

    echo "Adding Docker Debian repository..."
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
      $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    echo "Installing Docker..."
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
}

install_docker_centos() {
    echo "Installing dependencies..."
    sudo yum install -y yum-utils ca-certificates curl gnupg2

    echo "Adding Docker repository..."
    sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo

    echo "Installing Docker..."
    sudo yum install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
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
echo "1) Install Docker"
echo "2) Configure China registry mirror"
echo "3) Exit"

while true; do
    read -r -p "Enter your choice [1-3]: " choice
    case "$choice" in
        1)
            echo "Installing Docker..."
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
                    echo "Unsupported system: $OS"
                    exit 1
                    ;;
            esac
            echo "Starting Docker and enabling auto-start on boot..."
            sudo systemctl enable docker
            sudo systemctl start docker

            echo "Docker installation completed, version info:"
            docker --version
            break
            ;;
        2)
            set_china_mirror
            break
            ;;
        3)
            exit 0
            ;;
        *) ;;
    esac
done
