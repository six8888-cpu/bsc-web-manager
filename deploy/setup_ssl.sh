#!/bin/bash
# BSC靓号生成器 - SSL证书自动申请和配置脚本
# 支持 Let's Encrypt 免费证书

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 打印带颜色的消息
print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# 检查root权限
if [ "$EUID" -ne 0 ]; then 
    print_error "请使用root权限运行此脚本"
    echo "使用: sudo bash $0"
    exit 1
fi

echo "========================================"
echo "🔐 BSC靓号生成器 - SSL证书配置工具"
echo "========================================"
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
echo "请输入要绑定的域名："
read -p "域名 (例如: example.com): " DOMAIN

if [ -z "$DOMAIN" ]; then
    print_error "域名不能为空"
    exit 1
fi

# 验证域名格式
if [[ ! $DOMAIN =~ ^[a-zA-Z0-9][a-zA-Z0-9-]{1,61}[a-zA-Z0-9]\.[a-zA-Z]{2,}$ ]]; then
    print_warning "域名格式可能不正确，但继续执行..."
fi

echo ""
print_info "域名: $DOMAIN"
echo ""

# 检查域名DNS解析
print_info "检查域名DNS解析..."
DOMAIN_IP=$(dig +short $DOMAIN | tail -n1)
SERVER_IP=$(curl -s ifconfig.me || curl -s ip.sb || hostname -I | awk '{print $1}')

if [ -z "$DOMAIN_IP" ]; then
    print_warning "无法解析域名 $DOMAIN，请确保DNS已正确配置"
    read -p "是否继续? (y/n): " CONTINUE
    if [ "$CONTINUE" != "y" ] && [ "$CONTINUE" != "Y" ]; then
        exit 1
    fi
else
    print_info "域名解析到: $DOMAIN_IP"
    print_info "服务器IP: $SERVER_IP"
    
    if [ "$DOMAIN_IP" != "$SERVER_IP" ]; then
        print_warning "域名解析IP ($DOMAIN_IP) 与服务器IP ($SERVER_IP) 不一致"
        print_warning "请确保域名已正确解析到此服务器"
        read -p "是否继续? (y/n): " CONTINUE
        if [ "$CONTINUE" != "y" ] && [ "$CONTINUE" != "Y" ]; then
            exit 1
        fi
    else
        print_success "域名解析正确"
    fi
fi

echo ""

# 检查并安装Nginx
print_info "检查Nginx..."
if ! command -v nginx &> /dev/null; then
    print_warning "Nginx未安装，开始安装..."
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

# 检查并安装certbot
print_info "检查Certbot..."
if ! command -v certbot &> /dev/null; then
    print_warning "Certbot未安装，开始安装..."
    if [ "$PKG_MANAGER" = "apt" ]; then
        apt update -qq
        apt install -y certbot python3-certbot-nginx
    elif [ "$PKG_MANAGER" = "yum" ]; then
        yum install -y epel-release
        yum install -y certbot python3-certbot-nginx
    else
        dnf install -y certbot python3-certbot-nginx
    fi
    print_success "Certbot安装完成"
else
    print_success "Certbot已安装"
fi

echo ""

# 检查Web服务端口
print_info "检查Web服务配置..."
WEB_PORT=5000
if systemctl is-active --quiet bsc-web 2>/dev/null; then
    print_success "BSC Web服务正在运行 (端口 $WEB_PORT)"
else
    print_warning "BSC Web服务未运行，请确保服务已启动"
    read -p "是否继续配置SSL? (y/n): " CONTINUE
    if [ "$CONTINUE" != "y" ] && [ "$CONTINUE" != "Y" ]; then
        exit 1
    fi
fi

echo ""

# 配置Nginx反向代理
print_info "配置Nginx反向代理..."

NGINX_CONF="/etc/nginx/sites-available/bsc-web"
if [ "$OS" = "redhat" ]; then
    NGINX_CONF="/etc/nginx/conf.d/bsc-web.conf"
fi

# 创建Nginx配置
cat > $NGINX_CONF << EOF
server {
    listen 80;
    server_name $DOMAIN;

    # 用于Let's Encrypt验证
    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }

    # 重定向到HTTPS（证书申请后启用）
    # return 301 https://\$server_name\$request_uri;
    
    # 临时：代理到Web服务（申请证书时使用）
    location / {
        proxy_pass http://127.0.0.1:$WEB_PORT;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

# 如果是Debian/Ubuntu，创建符号链接
if [ "$OS" = "debian" ]; then
    if [ ! -L "/etc/nginx/sites-enabled/bsc-web" ]; then
        ln -s $NGINX_CONF /etc/nginx/sites-enabled/bsc-web
    fi
    # 删除默认配置（如果存在）
    rm -f /etc/nginx/sites-enabled/default
fi

# 测试Nginx配置
print_info "测试Nginx配置..."
nginx -t
if [ $? -eq 0 ]; then
    print_success "Nginx配置正确"
else
    print_error "Nginx配置有误，请检查"
    exit 1
fi

# 启动Nginx
systemctl restart nginx
systemctl enable nginx

print_success "Nginx配置完成"
echo ""

# 申请SSL证书
print_info "开始申请SSL证书..."
echo ""

# 输入邮箱（可选）
read -p "请输入邮箱地址（用于证书到期提醒，可选）: " EMAIL
if [ -z "$EMAIL" ]; then
    EMAIL="admin@$DOMAIN"
fi

# 申请证书
print_info "正在申请Let's Encrypt证书..."
print_warning "这可能需要几分钟时间，请耐心等待..."
echo ""

if certbot --nginx -d $DOMAIN --non-interactive --agree-tos --email $EMAIL --redirect; then
    print_success "SSL证书申请成功！"
else
    print_error "SSL证书申请失败"
    echo ""
    print_info "可能的原因："
    echo "  1. 域名DNS未正确解析到此服务器"
    echo "  2. 80端口被占用或防火墙未开放"
    echo "  3. 域名已申请过证书（需要先删除）"
    echo ""
    read -p "是否查看详细错误信息? (y/n): " SHOW_ERROR
    if [ "$SHOW_ERROR" = "y" ] || [ "$SHOW_ERROR" = "Y" ]; then
        certbot --nginx -d $DOMAIN --non-interactive --agree-tos --email $EMAIL
    fi
    exit 1
fi

echo ""

# 更新Nginx配置以支持WebSocket
print_info "更新Nginx配置以支持WebSocket..."
cat >> $NGINX_CONF << 'WEBSOCKET'

    # WebSocket支持
    location /socket.io {
        proxy_pass http://127.0.0.1:5000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
WEBSOCKET

# 重新加载Nginx
nginx -t && systemctl reload nginx
print_success "Nginx配置已更新"

echo ""

# 设置自动续签
print_info "配置自动续签..."
# Certbot会自动创建续签任务，但我们可以验证一下
if [ -f "/etc/cron.d/certbot" ] || systemctl list-timers | grep -q certbot; then
    print_success "自动续签已配置"
else
    # 手动创建续签任务
    (crontab -l 2>/dev/null; echo "0 0,12 * * * certbot renew --quiet --post-hook 'systemctl reload nginx'") | crontab -
    print_success "已添加自动续签任务"
fi

# 测试续签
print_info "测试证书续签..."
certbot renew --dry-run
if [ $? -eq 0 ]; then
    print_success "自动续签测试通过"
else
    print_warning "自动续签测试失败，但证书已成功申请"
fi

echo ""

# 配置防火墙
print_info "配置防火墙..."
if command -v ufw &> /dev/null; then
    ufw allow 80/tcp
    ufw allow 443/tcp
    print_success "UFW防火墙已配置"
elif command -v firewall-cmd &> /dev/null; then
    firewall-cmd --add-service=http --permanent
    firewall-cmd --add-service=https --permanent
    firewall-cmd --reload
    print_success "Firewalld防火墙已配置"
fi

echo ""
echo "========================================"
print_success "SSL证书配置完成！"
echo "========================================"
echo ""
echo "📋 配置信息:"
echo "   域名: $DOMAIN"
echo "   SSL证书: Let's Encrypt"
echo "   证书位置: /etc/letsencrypt/live/$DOMAIN/"
echo "   自动续签: 已启用"
echo ""
echo "🌐 访问地址:"
echo "   https://$DOMAIN"
echo ""
echo "📝 证书管理命令:"
echo "   查看证书: certbot certificates"
echo "   手动续签: certbot renew"
echo "   删除证书: certbot delete --cert-name $DOMAIN"
echo ""
print_info "证书将在到期前自动续签，无需手动操作"
echo ""

