#!/bin/bash
###############################################################################
# BSC Web端 - SSL配置脚本（acme.sh版本）
# 适用于Certbot安装失败的情况，使用acme.sh替代
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
echo "🔐 BSC Web端 - SSL配置（acme.sh）"
echo "=========================================="
echo ""

# 检查是否为root
if [ "$EUID" -ne 0 ]; then 
    print_error "请使用root权限运行"
    exit 1
fi

# 检查Web服务
if ! systemctl is-active --quiet bsc-web-manager; then
    print_error "BSC Web服务未运行"
    exit 1
fi

print_success "检测到BSC Web服务正在运行"

# 获取服务器IP
SERVER_IP=$(curl -s ip.sb || curl -s ifconfig.me)
print_info "服务器IP: $SERVER_IP"

echo ""
print_warning "配置SSL需要："
echo "  1. 一个域名"
echo "  2. 域名已解析到: $SERVER_IP"
echo ""
read -p "是否继续? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 0
fi

# 输入域名
echo ""
while true; do
    read -p "请输入域名 (如: web.yourdomain.com): " DOMAIN
    if [ -n "$DOMAIN" ]; then
        break
    fi
    print_error "域名不能为空"
done

# 输入邮箱
while true; do
    read -p "请输入邮箱: " EMAIL
    if [[ "$EMAIL" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        break
    fi
    print_error "邮箱格式不正确"
done

# 安装Nginx
print_info "安装Nginx..."
if [ -f /etc/debian_version ]; then
    apt update
    apt install -y nginx
else
    yum install -y nginx
fi

systemctl enable nginx
print_success "Nginx安装完成"

# 安装acme.sh
print_info "安装acme.sh证书工具..."
if [ ! -d ~/.acme.sh ]; then
    curl https://get.acme.sh | sh
    source ~/.bashrc
fi
print_success "acme.sh安装完成"

# 停止Nginx（需要80端口）
systemctl stop nginx

# 注册账号
print_info "注册acme.sh账号..."
~/.acme.sh/acme.sh --register-account -m $EMAIL

# 申请证书
print_info "申请SSL证书（Let's Encrypt）..."
if ~/.acme.sh/acme.sh --issue -d $DOMAIN --standalone; then
    print_success "证书申请成功！"
else
    print_error "证书申请失败，请检查："
    echo "  1. 域名是否正确解析到: $SERVER_IP"
    echo "  2. 防火墙80端口是否开放"
    echo "  3. 是否有其他服务占用80端口"
    exit 1
fi

# 创建证书目录
mkdir -p /etc/ssl/bsc-web

# 安装证书
print_info "安装证书..."
~/.acme.sh/acme.sh --installcert -d $DOMAIN \
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
    
    # 反向代理到BSC Web端
    location / {
        proxy_pass http://127.0.0.1:5000;
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
if nginx -t; then
    print_success "Nginx配置测试通过"
else
    print_error "Nginx配置错误"
    exit 1
fi

# 启动Nginx
systemctl start nginx
systemctl reload nginx
print_success "Nginx启动成功"

# 配置防火墙
print_info "配置防火墙..."
if command -v ufw &> /dev/null; then
    ufw allow 80/tcp
    ufw allow 443/tcp
    print_success "防火墙配置完成 (ufw)"
elif command -v firewall-cmd &> /dev/null; then
    firewall-cmd --permanent --add-port=80/tcp
    firewall-cmd --permanent --add-port=443/tcp
    firewall-cmd --reload
    print_success "防火墙配置完成 (firewalld)"
else
    print_warning "未检测到防火墙，请在云服务商控制台开放80和443端口"
fi

# 设置自动续期（acme.sh会自动添加cron）
print_info "配置证书自动续期..."
print_success "acme.sh已自动配置证书续期任务"

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
echo "🛠️  管理命令："
echo "   systemctl status nginx            # Nginx状态"
echo "   systemctl reload nginx            # 重载Nginx"
echo "   ~/.acme.sh/acme.sh --list         # 查看证书"
echo "   ~/.acme.sh/acme.sh --renew -d $DOMAIN  # 手动续期"
echo ""
echo "📋 证书自动续期："
echo "   acme.sh已自动配置cron任务"
echo "   查看: crontab -l | grep acme"
echo ""
print_success "现在可以通过 https://$DOMAIN 访问BSC Web端了！"
echo ""

