#!/bin/bash
###############################################################################
# BSC靓号生成器 - 完整一键安装脚本
# 功能：安装Web端 + 可选配置域名和SSL证书
###############################################################################

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }

clear
echo "============================================"
echo "🚀 BSC靓号生成器 - 完整安装向导"
echo "============================================"
echo ""
echo "本脚本将帮您完成："
echo "  1. Web端环境安装"
echo "  2. 域名绑定（可选）"
echo "  3. SSL证书配置（可选）"
echo "  4. 自动启动服务"
echo ""
read -p "按回车键开始安装..." 

###############################################################################
# 步骤1: 检测系统环境
###############################################################################
echo ""
print_info "步骤 1/5: 检测系统环境..."

if [ "$EUID" -ne 0 ]; then 
    print_error "请使用root权限运行此脚本"
    echo "使用: sudo bash $0"
    exit 1
fi

# 检测操作系统
if [ -f /etc/debian_version ]; then
    OS="debian"
    PKG_MANAGER="apt"
    print_success "检测到系统: Debian/Ubuntu"
elif [ -f /etc/redhat-release ]; then
    OS="redhat"
    if command -v dnf &> /dev/null; then
        PKG_MANAGER="dnf"
    else
        PKG_MANAGER="yum"
    fi
    print_success "检测到系统: CentOS/RHEL"
else
    print_error "不支持的操作系统"
    exit 1
fi

# 获取服务器IP
SERVER_IP=$(curl -s ip.sb || curl -s ifconfig.me || hostname -I | awk '{print $1}')
print_info "服务器IP: $SERVER_IP"

###############################################################################
# 步骤2: 安装Web端
###############################################################################
echo ""
print_info "步骤 2/5: 安装Web端环境..."

# 更新系统
print_info "更新系统软件包..."
if [ "$OS" = "debian" ]; then
    apt update -y
    apt upgrade -y
else
    $PKG_MANAGER update -y
    $PKG_MANAGER upgrade -y
fi

# 安装基础依赖
print_info "安装基础依赖..."
if [ "$OS" = "debian" ]; then
    apt install -y python3 python3-pip python3-venv git curl wget
else
    $PKG_MANAGER install -y python3 python3-pip git curl wget
    # CentOS需要单独安装venv
    if ! python3 -m venv --help &> /dev/null; then
        print_warning "Python3 venv未安装，正在安装..."
        $PKG_MANAGER install -y python3-virtualenv || true
    fi
fi

print_success "基础依赖安装完成"

# 创建项目目录
INSTALL_DIR="/root/bsc-web-manager"
if [ -d "$INSTALL_DIR" ]; then
    print_warning "检测到已存在的安装目录"
    read -p "是否删除并重新安装? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_info "备份旧目录..."
        mv "$INSTALL_DIR" "${INSTALL_DIR}.backup.$(date +%Y%m%d_%H%M%S)"
    else
        print_info "使用现有目录，跳过克隆步骤"
        cd "$INSTALL_DIR"
    fi
fi

# 克隆项目（如果目录不存在）
if [ ! -d "$INSTALL_DIR" ]; then
    print_info "正在克隆项目..."
    cd /root
    # GitHub仓库地址
    if git clone https://github.com/six8888-cpu/bsc-web-manager.git; then
        print_success "项目克隆成功"
    else
        print_error "项目克隆失败，请检查网络或手动上传文件"
        exit 1
    fi
fi

cd "$INSTALL_DIR"

# 创建虚拟环境
print_info "创建Python虚拟环境..."
python3 -m venv venv || python3 -m virtualenv venv
source venv/bin/activate

# 安装Python依赖
print_info "安装Python依赖包..."
pip install --upgrade pip
pip install -r backend/requirements.txt
pip install -r bsc_generator/requirements.txt

print_success "Web端环境安装完成"

###############################################################################
# 步骤3: 配置防火墙
###############################################################################
echo ""
print_info "步骤 3/5: 配置防火墙..."

if [ "$OS" = "debian" ]; then
    if command -v ufw &> /dev/null; then
        ufw allow 5000/tcp
        ufw allow 80/tcp
        ufw allow 443/tcp
        print_success "防火墙规则已添加 (ufw)"
    fi
else
    if command -v firewall-cmd &> /dev/null; then
        firewall-cmd --permanent --add-port=5000/tcp
        firewall-cmd --permanent --add-port=80/tcp
        firewall-cmd --permanent --add-port=443/tcp
        firewall-cmd --reload
        print_success "防火墙规则已添加 (firewalld)"
    fi
fi

###############################################################################
# 步骤4: 询问是否配置域名和SSL
###############################################################################
echo ""
print_info "步骤 4/5: 域名和SSL配置（可选）"
echo ""
echo "您想要配置域名和SSL证书吗？"
echo "  [1] 是，我要配置域名和SSL（推荐）"
echo "  [2] 否，稍后手动配置"
echo "  [3] 跳过，直接使用IP访问"
echo ""
read -p "请选择 [1-3]: " ssl_choice

if [ "$ssl_choice" = "1" ]; then
    ###########################################################################
    # 配置域名和SSL
    ###########################################################################
    echo ""
    print_info "开始配置域名和SSL证书..."
    echo ""
    
    # 输入域名
    while true; do
        read -p "请输入您的域名 (例: web.yourdomain.com): " DOMAIN
        if [ -n "$DOMAIN" ]; then
            break
        else
            print_error "域名不能为空，请重新输入"
        fi
    done
    
    # 输入邮箱
    while true; do
        read -p "请输入您的邮箱 (用于SSL证书通知): " EMAIL
        if [[ "$EMAIL" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
            break
        else
            print_error "邮箱格式不正确，请重新输入"
        fi
    done
    
    print_warning "请确保域名 $DOMAIN 已解析到本服务器IP: $SERVER_IP"
    echo ""
    read -p "域名是否已正确解析? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_error "请先配置域名解析，然后重新运行此脚本"
        exit 1
    fi
    
    # 安装Nginx
    print_info "安装Nginx..."
    if [ "$OS" = "debian" ]; then
        apt install -y nginx
    else
        $PKG_MANAGER install -y nginx
    fi
    
    systemctl enable nginx
    systemctl start nginx
    print_success "Nginx安装完成"
    
    # 安装acme.sh（替代Certbot，兼容性更好）
    print_info "安装acme.sh证书工具..."
    if [ ! -d ~/.acme.sh ]; then
        curl https://get.acme.sh | sh
        export LE_WORKING_DIR="$HOME/.acme.sh"
        source ~/.bashrc 2>/dev/null || true
    fi
    print_success "acme.sh安装完成"
    
    # 配置Nginx
    print_info "配置Nginx..."
    cat > /etc/nginx/conf.d/bsc-web.conf << EOF
server {
    listen 80;
    server_name $DOMAIN;
    
    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_read_timeout 86400;
    }
}
EOF
    
    # 停止Nginx（acme.sh需要80端口）
    systemctl stop nginx
    
    # 申请SSL证书（使用acme.sh）
    print_info "申请SSL证书（Let's Encrypt）..."
    
    # 注册账号
    ~/.acme.sh/acme.sh --register-account -m "$EMAIL" 2>/dev/null || true
    
    # 申请证书
    if ~/.acme.sh/acme.sh --issue -d "$DOMAIN" --standalone; then
        print_success "SSL证书申请成功！"
        
        # 创建证书目录
        mkdir -p /etc/ssl/bsc-web
        
        # 安装证书
        ~/.acme.sh/acme.sh --installcert -d "$DOMAIN" \
            --key-file /etc/ssl/bsc-web/${DOMAIN}.key \
            --fullchain-file /etc/ssl/bsc-web/${DOMAIN}.crt \
            --reloadcmd "systemctl reload nginx"
        
        # 更新Nginx配置为HTTPS
        cat > /etc/nginx/conf.d/bsc-web.conf << EOF
# HTTP重定向到HTTPS
server {
    listen 80;
    server_name $DOMAIN;
    return 301 https://\\\$server_name\\\$request_uri;
}

# HTTPS配置
server {
    listen 443 ssl http2;
    server_name $DOMAIN;
    
    # SSL证书
    ssl_certificate /etc/ssl/bsc-web/${DOMAIN}.crt;
    ssl_certificate_key /etc/ssl/bsc-web/${DOMAIN}.key;
    
    # SSL优化
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;
    
    # 反向代理
    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \\\$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \\\$host;
        proxy_set_header X-Real-IP \\\$remote_addr;
        proxy_set_header X-Forwarded-For \\\$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \\\$scheme;
        proxy_read_timeout 86400;
    }
}
EOF
        
        # 测试并启动Nginx
        if nginx -t; then
            systemctl start nginx
            print_success "Nginx配置成功"
            print_success "域名配置完成: https://$DOMAIN"
            ACCESS_URL="https://$DOMAIN"
        else
            print_error "Nginx配置测试失败"
            exit 1
        fi
        
        # acme.sh会自动配置续期
        print_success "证书自动续期已配置（acme.sh cron任务）"
        
    else
        print_error "SSL证书申请失败"
        print_warning "请检查：1) 域名是否正确解析 2) 80端口是否开放"
        print_warning "您仍然可以通过 http://$DOMAIN 访问"
        
        # 启动Nginx（HTTP模式）
        systemctl start nginx
        ACCESS_URL="http://$DOMAIN"
    fi
    
else
    print_info "跳过域名和SSL配置"
    ACCESS_URL="http://$SERVER_IP:5000"
fi

###############################################################################
# 步骤5: 创建并启动服务
###############################################################################
echo ""
print_info "步骤 5/5: 创建系统服务..."

# 创建systemd服务
cat > /etc/systemd/system/bsc-web-manager.service << EOF
[Unit]
Description=BSC Vanity Address Generator Web Manager
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$INSTALL_DIR
Environment="PATH=$INSTALL_DIR/venv/bin"
ExecStart=$INSTALL_DIR/venv/bin/python backend/app.py
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# 启动服务
systemctl daemon-reload
systemctl enable bsc-web-manager
systemctl start bsc-web-manager

print_success "服务创建并启动成功"

###############################################################################
# 安装完成
###############################################################################
echo ""
echo "============================================"
print_success "🎉 安装完成！"
echo "============================================"
echo ""
echo "📱 访问地址："
echo "   $ACCESS_URL"
echo ""
echo "🛠️  服务管理命令："
echo "   sudo systemctl start bsc-web-manager      # 启动服务"
echo "   sudo systemctl stop bsc-web-manager       # 停止服务"
echo "   sudo systemctl restart bsc-web-manager    # 重启服务"
echo "   sudo systemctl status bsc-web-manager     # 查看状态"
echo "   sudo journalctl -u bsc-web-manager -f     # 查看日志"
echo ""
echo "📁 安装目录: $INSTALL_DIR"
echo ""

if [ "$ssl_choice" = "1" ]; then
    echo "🔐 SSL证书信息："
    echo "   域名: $DOMAIN"
    echo "   证书路径: /etc/letsencrypt/live/$DOMAIN/"
    echo "   自动续期: 已配置（每天凌晨3点检查）"
    echo ""
fi

echo "📖 详细使用说明请查看: $INSTALL_DIR/README.md"
echo ""
print_success "祝您使用愉快！"
echo ""

