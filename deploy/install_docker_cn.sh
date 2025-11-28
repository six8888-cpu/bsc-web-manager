#!/bin/bash
###############################################################################
# Docker 安装脚本 - 国内优化版
# 支持：Debian/Ubuntu/CentOS/RHEL
# 使用国内镜像源加速下载
###############################################################################

set -e

echo "======================================"
echo "🐳 Docker 安装脚本（国内优化版）"
echo "======================================"
echo ""

# 检测是否已安装Docker
if command -v docker &> /dev/null; then
    docker_version=$(docker --version)
    echo "✅ Docker已安装: $docker_version"
    read -p "是否要重新安装？(y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "跳过安装"
        exit 0
    fi
    echo "🔄 卸载旧版本..."
    sudo systemctl stop docker 2>/dev/null || true
fi

# 检测操作系统
if [ -f /etc/debian_version ]; then
    OS="debian"
    echo "📌 检测到系统: Debian/Ubuntu"
elif [ -f /etc/redhat-release ]; then
    OS="redhat"
    echo "📌 检测到系统: CentOS/RHEL"
else
    echo "❌ 不支持的操作系统"
    exit 1
fi

echo ""
echo "请选择安装方式："
echo "1) 使用阿里云镜像（推荐-最快）"
echo "2) 使用清华大学镜像"
echo "3) 使用中科大镜像"
echo "4) 使用系统包管理器（简单但版本可能较旧）"
echo "5) 手动下载安装包"
read -p "请输入选项 [1-5]: " choice

case $choice in
    1)
        METHOD="aliyun"
        MIRROR_URL="https://mirrors.aliyun.com/docker-ce"
        ;;
    2)
        METHOD="tsinghua"
        MIRROR_URL="https://mirrors.tuna.tsinghua.edu.cn/docker-ce"
        ;;
    3)
        METHOD="ustc"
        MIRROR_URL="https://mirrors.ustc.edu.cn/docker-ce"
        ;;
    4)
        METHOD="system"
        ;;
    5)
        METHOD="manual"
        ;;
    *)
        echo "❌ 无效选项"
        exit 1
        ;;
esac

###############################################################################
# 方法1-3: 使用国内镜像源
###############################################################################
if [ "$METHOD" = "aliyun" ] || [ "$METHOD" = "tsinghua" ] || [ "$METHOD" = "ustc" ]; then
    echo ""
    echo "🚀 使用镜像源: $MIRROR_URL"
    echo ""
    
    if [ "$OS" = "debian" ]; then
        # Debian/Ubuntu
        echo "📦 更新系统并安装依赖..."
        sudo apt-get update
        sudo apt-get install -y \
            ca-certificates \
            curl \
            gnupg \
            lsb-release
        
        echo "🔑 添加Docker GPG密钥..."
        sudo mkdir -p /etc/apt/keyrings
        curl -fsSL ${MIRROR_URL}/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        
        echo "📝 添加Docker软件源..."
        echo \
          "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] ${MIRROR_URL}/linux/ubuntu \
          $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        
        echo "📦 安装Docker..."
        sudo apt-get update
        sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
        
    else
        # CentOS/RHEL
        echo "📦 安装依赖..."
        sudo yum install -y yum-utils
        
        echo "📝 添加Docker软件源..."
        sudo yum-config-manager --add-repo ${MIRROR_URL}/linux/centos/docker-ce.repo
        
        # 替换官方源为国内镜像
        sudo sed -i 's+download.docker.com+mirrors.aliyun.com/docker-ce+' /etc/yum.repos.d/docker-ce.repo
        
        echo "📦 安装Docker..."
        sudo yum install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    fi

###############################################################################
# 方法4: 使用系统包管理器
###############################################################################
elif [ "$METHOD" = "system" ]; then
    echo ""
    echo "📦 使用系统包管理器安装Docker..."
    echo ""
    
    if [ "$OS" = "debian" ]; then
        sudo apt-get update
        sudo apt-get install -y docker.io docker-compose
    else
        sudo yum install -y docker docker-compose
    fi

###############################################################################
# 方法5: 手动下载安装包
###############################################################################
elif [ "$METHOD" = "manual" ]; then
    echo ""
    echo "📥 手动下载Docker安装包..."
    echo ""
    
    # 创建临时目录
    TMP_DIR="/tmp/docker_install_$$"
    mkdir -p $TMP_DIR
    cd $TMP_DIR
    
    echo "选择Docker版本："
    echo "1) 24.0.7 (稳定版)"
    echo "2) 25.0.3 (较新版)"
    echo "3) 26.1.0 (最新版)"
    read -p "请输入选项 [1-3]: " version_choice
    
    case $version_choice in
        1) DOCKER_VERSION="24.0.7" ;;
        2) DOCKER_VERSION="25.0.3" ;;
        3) DOCKER_VERSION="26.1.0" ;;
        *) DOCKER_VERSION="24.0.7" ;;
    esac
    
    ARCH=$(uname -m)
    if [ "$ARCH" = "x86_64" ]; then
        DOCKER_ARCH="x86_64"
    elif [ "$ARCH" = "aarch64" ]; then
        DOCKER_ARCH="aarch64"
    else
        echo "❌ 不支持的架构: $ARCH"
        exit 1
    fi
    
    DOCKER_URL="https://mirrors.aliyun.com/docker-ce/linux/static/stable/${DOCKER_ARCH}/docker-${DOCKER_VERSION}.tgz"
    
    echo "📥 下载Docker ${DOCKER_VERSION}..."
    echo "从: $DOCKER_URL"
    
    if ! wget -O docker.tgz "$DOCKER_URL"; then
        echo "❌ 下载失败，尝试备用源..."
        DOCKER_URL="https://mirrors.tuna.tsinghua.edu.cn/docker-ce/linux/static/stable/${DOCKER_ARCH}/docker-${DOCKER_VERSION}.tgz"
        wget -O docker.tgz "$DOCKER_URL" || {
            echo "❌ 所有下载源均失败"
            rm -rf $TMP_DIR
            exit 1
        }
    fi
    
    echo "📦 解压安装..."
    tar -xzf docker.tgz
    sudo cp docker/* /usr/bin/
    
    echo "📝 创建systemd服务..."
    sudo tee /etc/systemd/system/docker.service > /dev/null << 'EOF'
[Unit]
Description=Docker Application Container Engine
Documentation=https://docs.docker.com
After=network-online.target firewalld.service
Wants=network-online.target

[Service]
Type=notify
ExecStart=/usr/bin/dockerd
ExecReload=/bin/kill -s HUP $MAINPID
LimitNOFILE=infinity
LimitNPROC=infinity
TimeoutStartSec=0
Delegate=yes
KillMode=process
Restart=on-failure
StartLimitBurst=3
StartLimitInterval=60s

[Install]
WantedBy=multi-user.target
EOF
    
    sudo tee /etc/systemd/system/docker.socket > /dev/null << 'EOF'
[Unit]
Description=Docker Socket for the API
PartOf=docker.service

[Socket]
ListenStream=/var/run/docker.sock
SocketMode=0660
SocketUser=root
SocketGroup=docker

[Install]
WantedBy=sockets.target
EOF
    
    sudo systemctl daemon-reload
    
    # 清理
    cd ~
    rm -rf $TMP_DIR
fi

###############################################################################
# 配置Docker
###############################################################################
echo ""
echo "⚙️  配置Docker..."

# 创建docker组
sudo groupadd docker 2>/dev/null || true

# 配置国内镜像加速
sudo mkdir -p /etc/docker
sudo tee /etc/docker/daemon.json > /dev/null << 'EOF'
{
  "registry-mirrors": [
    "https://docker.mirrors.ustc.edu.cn",
    "https://hub-mirror.c.163.com",
    "https://mirror.ccs.tencentyun.com"
  ],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m",
    "max-file": "3"
  },
  "storage-driver": "overlay2"
}
EOF

# 启动Docker
echo "🚀 启动Docker服务..."
sudo systemctl daemon-reload
sudo systemctl enable docker
sudo systemctl start docker

# 验证安装
echo ""
echo "======================================"
echo "✅ Docker 安装完成！"
echo "======================================"
echo ""

docker --version
docker compose version 2>/dev/null || docker-compose --version 2>/dev/null || echo "Docker Compose: 未安装"

echo ""
echo "📊 Docker 信息:"
sudo docker info | grep -E "Server Version|Storage Driver|Registry Mirrors" || true

echo ""
echo "🎉 安装成功！"
echo ""
echo "💡 常用命令:"
echo "   docker --version          # 查看版本"
echo "   docker ps                 # 查看运行中的容器"
echo "   docker images             # 查看镜像"
echo "   sudo systemctl status docker  # 查看服务状态"
echo ""
echo "👤 将当前用户加入docker组（可选）:"
echo "   sudo usermod -aG docker $USER"
echo "   newgrp docker"
echo ""

