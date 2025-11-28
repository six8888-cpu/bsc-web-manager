#!/bin/bash
###############################################################################
# 超简单VPN配置脚本
# 无需面板，无需域名，5分钟搞定
###############################################################################

echo "=========================================="
echo "🚀 超简单VPN - 5分钟配置"
echo "=========================================="
echo ""

# 安装V2Ray
echo "📦 安装V2Ray核心..."
bash <(curl -L https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh)

# 生成UUID
UUID=$(cat /proc/sys/kernel/random/uuid)
SERVER_IP=$(curl -s ip.sb)

# 创建配置文件
echo "⚙️  生成配置..."
cat > /usr/local/etc/v2ray/config.json << EOF
{
  "log": {
    "loglevel": "warning"
  },
  "inbounds": [{
    "port": 10086,
    "protocol": "vmess",
    "settings": {
      "clients": [{
        "id": "$UUID",
        "alterId": 0
      }]
    },
    "streamSettings": {
      "network": "tcp"
    }
  }],
  "outbounds": [{
    "protocol": "freedom",
    "settings": {}
  }]
}
EOF

# 启动服务
echo "🚀 启动V2Ray..."
systemctl enable v2ray
systemctl start v2ray

# 配置防火墙
echo "🔥 配置防火墙..."
firewall-cmd --permanent --add-port=10086/tcp
firewall-cmd --reload

# 检查状态
if systemctl is-active --quiet v2ray; then
    STATUS="✅ 运行中"
else
    STATUS="❌ 未运行"
fi

echo ""
echo "=========================================="
echo "✅ 安装完成！"
echo "=========================================="
echo ""
echo "📱 连接信息："
echo "─────────────────────────────────────"
echo "地址(Address): $SERVER_IP"
echo "端口(Port): 10086"
echo "UUID: $UUID"
echo "协议(Protocol): VMess"
echo "额外ID(AlterID): 0"
echo "传输(Network): TCP"
echo "─────────────────────────────────────"
echo ""
echo "服务状态: $STATUS"
echo ""
echo "📥 客户端下载："
echo "Windows: https://github.com/2dust/v2rayN/releases"
echo "Android: https://github.com/2dust/v2rayNG/releases"
echo "iOS: Shadowrocket (App Store 美区)"
echo "Mac: V2RayX (GitHub搜索)"
echo ""
echo "🔧 管理命令："
echo "systemctl start v2ray      # 启动"
echo "systemctl stop v2ray       # 停止"
echo "systemctl restart v2ray    # 重启"
echo "systemctl status v2ray     # 状态"
echo ""
echo "📋 配置文件："
echo "/usr/local/etc/v2ray/config.json"
echo ""
echo "🎉 复制上面的连接信息到客户端即可使用！"
echo ""

