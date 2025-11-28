#!/bin/bash
###############################################################################
# BSC靓号生成器 - SSL证书自动申请和配置脚本
# 使用acme.sh替代Certbot，兼容性更好，支持CentOS/Ubuntu
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

# 检查root权限
if [ "$EUID" -ne 0 ]; then 
    print_error "请使用root权限运行此脚本"
    echo "使用: sudo bash $0"
    exit 1
fi

clear
echo "=========================================="
echo "🔐 BSC靓号生成器 - SSL证书配置工具"
echo "=========================================="
echo ""

# 检测系统类型
if [ -f /etc/debian_version ]; then
    OS="debian"
    PKG_MANAGER="apt"
elif [ -f /etc/redhat-release ]; then
    OS="redhat"
    if command -v dnf &> /dev/null; then
        PKG_MANAGER="dnf"
    else
        PKG_MANAGER="yum"
    fi
else
    print_error "不支持的系统，仅支持 Debian/Ubuntu/CentOS/RHEL"
    exit 1
fi

print_info "检测到系统: $OS (使用 $PKG_MANAGER)"
echo ""

# 交互式输入域名
read -p "请输入域名 (如: web.yourdomain.com): " DOMAIN

if [ -z "$DOMAIN" ]; then
    print_error "域名不能为空"
    exit 1
fi

# 输入邮箱
read -p "请输入邮箱 (用于SSL证书通知): " EMAIL

if [ -z "$EMAIL" ]; then
    print_error "邮箱不能为空"
    exit 1
fi

echo ""
print_info "域名: $DOMAIN"
print_info "邮箱: $EMAIL"
echo ""

# 检查域名DNS解析
print_info "检查域名DNS解析..."
DOMAIN_IP=$(dig +short $DOMAIN 2>/dev/null | tail -n1)
SERVER_IP=$(curl -s ip.sb || curl -s ifconfig.me)

if [ -z "$DOMAIN_IP" ]; then
    print_warning "无法解析域名 $DOMAIN"
else
    print_info "域名解析到: $DOMAIN_IP"
    print_info "服务器IP: $SERVER_IP"
    
    if [ "$DOMAIN_IP" != "$SERVER_IP" ]; then
        print_warning "域名解析IP与服务器IP不一致"
        read -p "是否继续? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    else
        print_success "域名解析正确"
    fi
fi

echo ""

# 安装Nginx
print_info "安装Nginx..."
if ! command -v nginx &> /dev/null; then
    if [ "$PKG_MANAGER" = "apt" ]; then
        apt update -qq
        apt install -y nginx
    else
        $PKG_MANAGER install -y nginx
    fi
    systemctl enable nginx
    print_success "Nginx安装完成"
else
    print_success "Nginx已安装"
fi

# 安装acme.sh（替代Certbot）
print_info "安装acme.sh证书工具..."
if [ ! -d ~/.acme.sh ]; then
    curl https://get.acme.sh | sh
    export LE_WORKING_DIR="$HOME/.acme.sh"
    source ~/.bashrc 2>/dev/null || true
    print_success "acme.sh安装完成"
else
    print_success "acme.sh已安装"
fi

echo ""

# 检查Web服务
WEB_PORT=5000
if systemctl is-active --quiet bsc-web-manager 2>/dev/null; then
    print_success "BSC Web服务正在运行"
elif systemctl is-active --quiet bsc-web 2>/dev/null; then
    print_success "BSC Web服务正在运行"
else
    print_warning "BSC Web服务未运行，但继续配置SSL"
fi

# 停止Nginx（acme.sh standalone需要80端口）
print_info "准备申请证书..."
systemctl stop nginx 2>/dev/null || true

# 注册acme.sh账号
~/.acme.sh/acme.sh --register-account -m "$EMAIL" 2>/dev/null || true

# 申请SSL证书
print_info "申请SSL证书（Let's Encrypt）..."
if ~/.acme.sh/acme.sh --issue -d "$DOMAIN" --standalone; then
    print_success "SSL证书申请成功！"
    
    # 创建证书目录
    mkdir -p /etc/ssl/bsc-web
    
    # 安装证书
    ~/.acme.sh/acme.sh --installcert -d "$DOMAIN" \
        --key-file /etc/ssl/bsc-web/${DOMAIN}.key \
        --fullchain-file /etc/ssl/bsc-web/${DOMAIN}.crt \
        --reloadcmd "systemctl reload nginx"
    
    print_success "证书安装完成"
    
    # 配置Nginx
    print_info "配置Nginx..."
    cat > /etc/nginx/conf.d/bsc-web.conf << EOF
# HTTP重定向到HTTPS
server {
    listen 80;
    server_name $DOMAIN;
    return 301 https://\$server_name\$request_uri;
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
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    
    # 反向代理到BSC Web端
    location / {
        proxy_pass http://127.0.0.1:$WEB_PORT;
        proxy_http_version 1.1;
        
        # WebSocket支持
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        
        # 传递真实客户端信息
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        # 超时设置
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 86400s;
    }
}
EOF
    
    # 测试Nginx配置
    if nginx -t 2>/dev/null; then
        print_success "Nginx配置测试通过"
    else
        print_error "Nginx配置测试失败"
        cat /etc/nginx/conf.d/bsc-web.conf
        exit 1
    fi
    
    # 启动Nginx
    systemctl start nginx
    systemctl reload nginx 2>/dev/null || true
    print_success "Nginx启动成功"
    
    # 配置防火墙
    print_info "配置防火墙..."
    if command -v ufw &> /dev/null; then
        ufw allow 80/tcp 2>/dev/null || true
        ufw allow 443/tcp 2>/dev/null || true
        print_success "防火墙配置完成 (ufw)"
    elif command -v firewall-cmd &> /dev/null; then
        firewall-cmd --permanent --add-port=80/tcp 2>/dev/null || true
        firewall-cmd --permanent --add-port=443/tcp 2>/dev/null || true
        firewall-cmd --reload 2>/dev/null || true
        print_success "防火墙配置完成 (firewalld)"
    else
        print_warning "未检测到防火墙，请在云服务商控制台开放80和443端口"
    fi
    
    echo ""
    echo "=========================================="
    print_success "🎉 SSL配置完成！"
    echo "=========================================="
    echo ""
    echo "📱 访问地址："
    echo "   https://$DOMAIN"
    echo ""
    echo "🔐 证书信息："
    echo "   域名: $DOMAIN"
    echo "   证书: /etc/ssl/bsc-web/${DOMAIN}.crt"
    echo "   密钥: /etc/ssl/bsc-web/${DOMAIN}.key"
    echo "   有效期: 90天（自动续期）"
    echo ""
    echo "📋 证书管理命令："
    echo "   ~/.acme.sh/acme.sh --list                    # 查看证书列表"
    echo "   ~/.acme.sh/acme.sh --info -d $DOMAIN          # 查看证书详情"
    echo "   ~/.acme.sh/acme.sh --renew -d $DOMAIN --force # 强制续期"
    echo ""
    echo "🛠️  Nginx管理命令："
    echo "   systemctl status nginx       # 查看状态"
    echo "   systemctl restart nginx      # 重启Nginx"
    echo "   nginx -t                     # 测试配置"
    echo ""
    print_success "证书自动续期已配置（acme.sh cron任务）"
    echo ""
    
else
    print_error "SSL证书申请失败"
    print_warning "常见原因："
    echo "  1. 域名未正确解析到服务器IP"
    echo "  2. 防火墙未开放80端口"
    echo "  3. 80端口被其他服务占用"
    echo ""
    print_info "您仍然可以通过 http://$DOMAIN 或 http://$SERVER_IP:5000 访问"
    
    # 配置HTTP模式的Nginx
    cat > /etc/nginx/conf.d/bsc-web.conf << EOF
server {
    listen 80;
    server_name $DOMAIN;
    
    location / {
        proxy_pass http://127.0.0.1:$WEB_PORT;
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
    
    systemctl start nginx
    print_info "已配置HTTP模式: http://$DOMAIN"
fi

echo ""
