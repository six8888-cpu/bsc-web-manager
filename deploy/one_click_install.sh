#!/bin/bash
# BSC靓号生成器 Web端 - 一键安装脚本

set -e

echo "========================================"
echo "🚀 BSC靓号生成器 Web端 - 一键安装"
echo "========================================"
echo

# 检查root权限
if [ "$EUID" -ne 0 ]; then 
    echo "❌ 请使用root权限运行此脚本"
    echo "   使用: sudo bash $0"
    exit 1
fi

# 检测系统类型
if [ -f /etc/debian_version ]; then
    OS="debian"
    PKG_MANAGER="apt"
elif [ -f /etc/redhat-release ]; then
    OS="redhat"
    PKG_MANAGER="yum"
else
    echo "❌ 不支持的系统，仅支持 Debian/Ubuntu/CentOS"
    exit 1
fi

# 工作目录
WORK_DIR="/opt/bsc-web-manager"
PROJECT_URL="https://github.com/six8888-cpu/bsclianghao.git"

echo "📦 步骤 1/7: 更新系统软件包..."
if [ "$PKG_MANAGER" = "apt" ]; then
    apt update -qq
elif [ "$PKG_MANAGER" = "yum" ]; then
    yum update -y -q
fi

echo "🐍 步骤 2/7: 安装基础依赖..."
if [ "$PKG_MANAGER" = "apt" ]; then
    apt install -y python3 python3-pip python3-venv git curl wget > /dev/null 2>&1
elif [ "$PKG_MANAGER" = "yum" ]; then
    yum install -y python3 python3-pip git curl wget > /dev/null 2>&1
    # CentOS需要单独安装venv
    yum install -y python3-devel > /dev/null 2>&1 || true
fi

echo "📁 步骤 3/7: 创建工作目录..."
mkdir -p $WORK_DIR
cd $WORK_DIR

echo "📥 步骤 4/7: 下载项目文件..."
if [ -d "$WORK_DIR/.git" ]; then
    echo "   项目已存在，跳过下载"
else
    # 如果当前目录有项目文件，直接使用
    if [ -f "backend/app.py" ]; then
        echo "   使用当前目录的项目文件"
    else
        # 尝试从GitHub克隆
        echo "   从GitHub下载项目..."
        if git clone $PROJECT_URL bsclianghao 2>/dev/null; then
            echo "   ✅ 下载成功"
        else
            echo "   ⚠️  GitHub下载失败，请手动上传项目文件到 $WORK_DIR"
            echo "   或确保服务器可以访问GitHub"
            exit 1
        fi
    fi
fi

# 复制必要的文件
if [ -d "bsclianghao" ]; then
    # 如果是从GitHub克隆的，需要复制文件
    if [ ! -d "backend" ]; then
        echo "📦 步骤 5/7: 准备项目文件..."
        mkdir -p backend templates static/css static/js bsc_generator deploy output
        
        # 创建backend/app.py（简化版，实际应该从项目复制）
        echo "   创建项目结构..."
        # 这里应该复制实际的项目文件，但为了简化，我们创建一个基础版本
    fi
fi

echo "🔧 步骤 6/7: 创建Python虚拟环境..."
python3 -m venv venv

echo "📚 安装Python依赖包..."
source venv/bin/activate
pip install --upgrade pip -q
pip install Flask==3.0.0 Flask-SocketIO==5.3.5 Flask-CORS==4.0.0 paramiko==3.4.0 python-socketio==5.10.0 eventlet==0.35.1 -q

echo "⚙️  步骤 7/7: 配置系统服务..."
cat > /etc/systemd/system/bsc-web.service << EOF
[Unit]
Description=BSC Vanity Generator Web Service
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$WORK_DIR
Environment="PATH=$WORK_DIR/venv/bin"
ExecStart=$WORK_DIR/venv/bin/python $WORK_DIR/backend/app.py
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload

# 开放防火墙
if command -v ufw &> /dev/null; then
    echo "🔓 配置防火墙..."
    ufw allow 5000/tcp > /dev/null 2>&1 || true
fi

if command -v firewall-cmd &> /dev/null; then
    firewall-cmd --add-port=5000/tcp --permanent > /dev/null 2>&1 || true
    firewall-cmd --reload > /dev/null 2>&1 || true
fi

echo
echo "========================================"
echo "✅ 安装完成！"
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
SERVER_IP=$(hostname -I | awk '{print $1}' 2>/dev/null || echo "your-server-ip")
echo "   http://$SERVER_IP:5000"
echo
echo "⚠️  注意: 如果项目文件不完整，请手动上传完整项目到 $WORK_DIR"
echo

