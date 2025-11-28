#!/bin/bash
###############################################################################
# BSC Web端 - 域名SSL配置脚本
# 使用acme.sh，自带自动续签，简单可靠
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
echo "=========================================="
echo "🔐 BSC Web端 - 域名SSL配置"
echo "=========================================="
echo ""

# 检查root权限
if [ "$EUID" -ne 0 ]; then 
    print_error "请使用root权限运行"
    exit 1
fi

# 检测系统
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
    print_error "不支持的系统"
    exit 1
fi

print_info "系统: $OS"

# 获取服务器IP
SERVER_IP=$(curl -s ip.sb || curl -s ifconfig.me)
print_info "服务器IP: $SERVER_IP"
echo ""

# 输入域名
while true; do
    read -p "请输入域名 (如: web.yourdomain.com): " DOMAIN
    if [ -n "$DOMAIN" ]; then
        break
    fi
    print_error "域名不能为空"
done

# 输入邮箱
while true; do
    read -p "请输入邮箱 (SSL证书通知): " EMAIL
    if [[ "$EMAIL" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        break
    fi
    print_error "邮箱格式不正确"
done

echo ""
print_info "域名: $DOMAIN"
print_info "邮箱: $EMAIL"
echo ""

# 验证域名解析
print_info "验证域名解析..."
DOMAIN_IP=$(dig +short $DOMAIN 2>/dev/null | tail -n1)

if [ -z "$DOMAIN_IP" ]; then
    print_warning "无法解析域名"
else
    print_info "域名解析IP: $DOMAIN_IP"
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

# 安装必要工具
print_info "安装必要工具..."
if ! command -v netstat &> /dev/null; then
    if [ "$OS" = "debian" ]; then
        apt install -y net-tools
    else
        $PKG_MANAGER install -y net-tools
    fi
fi

# 安装Nginx
print_info "安装Nginx..."
if ! command -v nginx &> /dev/null; then
    if [ "$OS" = "debian" ]; then
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

# 安装acme.sh
print_info "安装acme.sh..."
if [ ! -d ~/.acme.sh ]; then
    curl https://get.acme.sh | sh
    export LE_WORKING_DIR="$HOME/.acme.sh"
    source ~/.bashrc 2>/dev/null || true
    print_success "acme.sh安装完成"
else
    print_success "acme.sh已安装"
fi

# 检查Web服务
print_info "检查BSC Web服务..."
if systemctl is-active --quiet bsc-web-manager 2>/dev/null; then
    WEB_PORT=5000
    print_success "BSC Web服务运行中 (端口: $WEB_PORT)"
elif systemctl is-active --quiet bsc-web 2>/dev/null; then
    WEB_PORT=5000
    print_success "BSC Web服务运行中 (端口: $WEB_PORT)"
else
    print_warning "BSC Web服务未运行，但继续配置SSL"
    WEB_PORT=5000
fi

echo ""

# 停止可能占用80端口的服务
print_info "准备申请证书..."
systemctl stop nginx 2>/dev/null || true
systemctl stop trojan 2>/dev/null || true
systemctl stop trojan-web 2>/dev/null || true

# 检查80端口是否被占用
if netstat -tulpn | grep -q ":80 "; then
    print_warning "80端口仍被占用，使用88端口申请证书"
    USE_PORT=88
    firewall-cmd --add-port=88/tcp 2>/dev/null || true
else
    USE_PORT=80
fi

# 注册acme.sh账号
~/.acme.sh/acme.sh --register-account -m "$EMAIL" 2>/dev/null || true

# 申请SSL证书
print_info "申请SSL证书（Let's Encrypt）..."
if [ "$USE_PORT" = "88" ]; then
    # 使用88端口申请
    CERT_SUCCESS=$(~/.acme.sh/acme.sh --issue -d "$DOMAIN" --standalone --httpport 88 && echo "yes" || echo "no")
else
    # 使用80端口申请
    CERT_SUCCESS=$(~/.acme.sh/acme.sh --issue -d "$DOMAIN" --standalone && echo "yes" || echo "no")
fi

if [ "$CERT_SUCCESS" = "yes" ]; then
    print_success "证书申请成功！"
    
    # 创建证书目录
    mkdir -p /etc/ssl/bsc-web
    
    # 安装证书（acme.sh会自动配置续期）
    ~/.acme.sh/acme.sh --installcert -d "$DOMAIN" \
        --key-file /etc/ssl/bsc-web/${DOMAIN}.key \
        --fullchain-file /etc/ssl/bsc-web/${DOMAIN}.crt \
        --reloadcmd "systemctl reload nginx"
    
    print_success "证书安装完成"
    
    # 配置Nginx
    print_info "配置Nginx反向代理..."
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
        proxy_pass http://127.0.0.1:${WEB_PORT};
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
        print_success "Nginx配置正确"
    else
        print_error "Nginx配置错误"
        exit 1
    fi
    
    # 启动Nginx
    systemctl start nginx
    systemctl reload nginx 2>/dev/null || true
    print_success "Nginx启动成功"
    
    # 重新启动之前停止的服务
    systemctl start trojan 2>/dev/null || true
    systemctl start trojan-web 2>/dev/null || true
    
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
    echo "   有效期: 90天"
    echo ""
    echo "🔄 自动续期："
    echo "   acme.sh已自动配置cron任务"
    echo "   证书到期前会自动续期，无需手动操作"
    echo "   查看续期任务: crontab -l | grep acme"
    echo ""
    echo "📋 管理命令："
    echo "   ~/.acme.sh/acme.sh --list                    # 查看证书列表"
    echo "   ~/.acme.sh/acme.sh --info -d $DOMAIN          # 查看证书详情"
    echo "   ~/.acme.sh/acme.sh --renew -d $DOMAIN --force # 强制续期"
    echo ""
    echo "🛠️  Nginx管理："
    echo "   systemctl status nginx       # 查看状态"
    echo "   systemctl restart nginx      # 重启Nginx"
    echo "   nginx -t                     # 测试配置"
    echo ""
    print_success "现在可以通过 https://$DOMAIN 访问BSC Web端了！"
    echo ""
    
else
    print_error "SSL证书申请失败"
    echo ""
    print_warning "常见原因："
    echo "  1. 域名未正确解析到服务器IP: $SERVER_IP"
    echo "  2. 防火墙未开放80端口"
    echo "  3. 80端口被其他服务占用"
    echo ""
    print_info "配置HTTP模式（无SSL）..."
    
    # 配置HTTP模式的Nginx
    cat > /etc/nginx/conf.d/bsc-web.conf << EOF
server {
    listen 80;
    server_name $DOMAIN;
    
    location / {
        proxy_pass http://127.0.0.1:${WEB_PORT};
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
    
    nginx -t && systemctl start nginx
    print_info "已配置HTTP模式: http://$DOMAIN"
    
    # 重新启动之前停止的服务
    systemctl start trojan 2>/dev/null || true
    systemctl start trojan-web 2>/dev/null || true
    
    echo ""
    print_warning "修复问题后，重新运行此脚本配置SSL"
fi

echo ""

