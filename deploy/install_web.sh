#!/bin/bash
# BSC靓号生成器 Web端部署脚本（香港服务器）

set -e

echo "========================================"
echo "BSC靓号生成器 Web端部署脚本"
echo "========================================"
echo

# 检查root权限
if [ "$EUID" -ne 0 ]; then 
    echo "❌ 请使用root权限运行此脚本"
    exit 1
fi

# 检测系统类型和包管理器
if [ -f /etc/debian_version ]; then
    OS="debian"
    PKG_MANAGER="apt"
    PKG_INSTALL="apt install -y"
elif [ -f /etc/redhat-release ]; then
    OS="redhat"
    if command -v dnf &> /dev/null; then
        PKG_MANAGER="dnf"
        PKG_INSTALL="dnf install -y"
    else
        PKG_MANAGER="yum"
        PKG_INSTALL="yum install -y"
    fi
else
    echo "❌ 不支持的系统，仅支持 Debian/Ubuntu/CentOS/RHEL"
    exit 1
fi

echo "🔍 检测到系统: $OS (使用 $PKG_MANAGER)"

# 更新系统
echo "📦 更新系统软件包..."
if [ "$PKG_MANAGER" = "apt" ]; then
    apt update
elif [ "$PKG_MANAGER" = "yum" ] || [ "$PKG_MANAGER" = "dnf" ]; then
    $PKG_MANAGER update -y
fi

# 安装Python3和pip
echo "🐍 安装Python3和pip..."
if [ "$PKG_MANAGER" = "apt" ]; then
    $PKG_INSTALL python3 python3-pip python3-venv
elif [ "$PKG_MANAGER" = "yum" ] || [ "$PKG_MANAGER" = "dnf" ]; then
    $PKG_INSTALL python3 python3-pip
    # CentOS/RHEL需要单独安装python3-devel用于venv
    $PKG_INSTALL python3-devel gcc 2>/dev/null || true
fi

# 安装Git（用于克隆原项目）
echo "📥 安装Git..."
$PKG_INSTALL git

# 创建工作目录
WORK_DIR="/opt/bsc-web-manager"
echo "📁 创建工作目录: $WORK_DIR"
mkdir -p $WORK_DIR
cd $WORK_DIR

# 克隆原项目（用于打包）
echo "📦 克隆BSC生成器原项目..."
if [ ! -d "bsclianghao" ]; then
    git clone https://github.com/six8888-cpu/bsclianghao.git
fi

# 创建虚拟环境
echo "🔧 创建Python虚拟环境..."
python3 -m venv venv

# 激活虚拟环境
source venv/bin/activate

# 安装依赖
echo "📚 安装Python依赖包..."
pip install --upgrade pip
pip install Flask==3.0.0 Flask-SocketIO==5.3.5 Flask-CORS==4.0.0 paramiko==3.4.0 python-socketio==5.10.0 eventlet==0.35.1

# 创建打包的生成器程序
echo "📦 打包生成器程序..."
mkdir -p $WORK_DIR/bsc_generator_package
cp bsclianghao/*.py $WORK_DIR/bsc_generator_package/
cp bsclianghao/requirements.txt $WORK_DIR/bsc_generator_package/

# 创建systemd服务
echo "⚙️  创建systemd服务..."
cat > /etc/systemd/system/bsc-web.service << EOF
[Unit]
Description=BSC Vanity Generator Web Service
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$WORK_DIR
Environment="PATH=$WORK_DIR/venv/bin"
ExecStart=$WORK_DIR/venv/bin/python backend/app.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# 重载systemd
systemctl daemon-reload

# 开放防火墙端口
echo "🔓 配置防火墙..."
if command -v ufw &> /dev/null; then
    ufw allow 5000/tcp
elif command -v firewall-cmd &> /dev/null; then
    firewall-cmd --add-port=5000/tcp --permanent 2>/dev/null || true
    firewall-cmd --reload 2>/dev/null || true
fi

echo
echo "========================================"
echo "✅ Web端部署完成！"
echo "========================================"
echo
echo "📋 部署信息:"
echo "   工作目录: $WORK_DIR"
echo "   服务名称: bsc-web.service"
echo "   访问端口: 5000"
echo
echo "🚀 启动服务:"
echo "   systemctl start bsc-web"
echo "   systemctl enable bsc-web"
echo
echo "📊 查看状态:"
echo "   systemctl status bsc-web"
echo
echo "📝 查看日志:"
echo "   journalctl -u bsc-web -f"
echo
echo "🌐 访问地址:"
echo "   http://$(hostname -I | awk '{print $1}'):5000"
echo

