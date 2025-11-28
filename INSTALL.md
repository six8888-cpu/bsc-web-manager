# 🚀 一键安装命令

## Linux Web端一键安装

### 方式1: 直接执行（推荐）

```bash
# Ubuntu/Debian系统
sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/your-repo/bsc-web-manager/main/deploy/one_click_install.sh)"

# 或者使用wget
sudo bash -c "$(wget -qO- https://raw.githubusercontent.com/your-repo/bsc-web-manager/main/deploy/one_click_install.sh)"
```

### 方式2: 下载后执行

```bash
# 下载安装脚本
curl -o install.sh https://raw.githubusercontent.com/your-repo/bsc-web-manager/main/deploy/one_click_install.sh

# 或者
wget https://raw.githubusercontent.com/your-repo/bsc-web-manager/main/deploy/one_click_install.sh -O install.sh

# 执行安装
sudo bash install.sh
```

### 方式3: 本地项目安装

如果你已经有项目文件：

```bash
# 进入项目目录
cd bsc-web-manager

# 执行安装脚本
sudo bash deploy/install_web.sh
```

---

## 完整安装命令（如果GitHub不可用）

```bash
# 一键安装命令（复制整段执行）
sudo bash << 'EOF'
set -e
WORK_DIR="/opt/bsc-web-manager"
mkdir -p $WORK_DIR
cd $WORK_DIR

# 更新系统
apt update -qq
apt install -y python3 python3-pip python3-venv git curl wget

# 创建虚拟环境
python3 -m venv venv
source venv/bin/activate

# 安装依赖
pip install --upgrade pip -q
pip install Flask==3.0.0 Flask-SocketIO==5.3.5 Flask-CORS==4.0.0 paramiko==3.4.0 python-socketio==5.10.0 eventlet==0.35.1 -q

# 创建systemd服务
cat > /etc/systemd/system/bsc-web.service << 'SERVICE'
[Unit]
Description=BSC Vanity Generator Web Service
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/bsc-web-manager
Environment="PATH=/opt/bsc-web-manager/venv/bin"
ExecStart=/opt/bsc-web-manager/venv/bin/python /opt/bsc-web-manager/backend/app.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
SERVICE

systemctl daemon-reload

# 开放防火墙
ufw allow 5000/tcp 2>/dev/null || true
firewall-cmd --add-port=5000/tcp --permanent 2>/dev/null || true
firewall-cmd --reload 2>/dev/null || true

echo "✅ 安装完成！"
echo "📁 工作目录: $WORK_DIR"
echo "🚀 启动服务: systemctl start bsc-web"
echo "🌐 访问地址: http://$(hostname -I | awk '{print $1}'):5000"
EOF
```

---

## 安装后操作

### 1. 上传项目文件

如果安装脚本无法自动下载项目，需要手动上传：

```bash
# 方式1: 使用scp上传
scp -r bsc-web-manager/* root@your-server:/opt/bsc-web-manager/

# 方式2: 使用Git克隆
cd /opt/bsc-web-manager
git clone <your-repo-url> .
```

### 2. 启动服务

```bash
# 启动服务
sudo systemctl start bsc-web

# 设置开机自启
sudo systemctl enable bsc-web

# 查看状态
sudo systemctl status bsc-web
```

### 3. 查看日志

```bash
# 实时查看日志
sudo journalctl -u bsc-web -f

# 查看最近100行
sudo journalctl -u bsc-web -n 100
```

### 4. 访问Web界面

```
http://your-server-ip:5000
```

---

## 卸载

```bash
# 停止服务
sudo systemctl stop bsc-web
sudo systemctl disable bsc-web

# 删除服务文件
sudo rm /etc/systemd/system/bsc-web.service
sudo systemctl daemon-reload

# 删除项目文件（可选）
sudo rm -rf /opt/bsc-web-manager
```

---

## 常见问题

### Q: 安装失败，提示找不到命令

**解决：**
```bash
# 更新软件源
sudo apt update
# 或
sudo yum update
```

### Q: pip安装失败

**解决：**
```bash
# 使用国内镜像
pip install -r requirements.txt -i https://mirrors.aliyun.com/pypi/simple/
```

### Q: 服务启动失败

**解决：**
```bash
# 查看详细错误
sudo journalctl -u bsc-web -n 50

# 检查Python路径
which python3
/opt/bsc-web-manager/venv/bin/python --version
```

### Q: 无法访问5000端口

**解决：**
```bash
# 检查防火墙
sudo ufw status
sudo ufw allow 5000/tcp

# 检查服务是否运行
sudo systemctl status bsc-web

# 检查端口监听
sudo netstat -tlnp | grep 5000
```

---

## 快速测试

```bash
# 测试Web服务
curl http://localhost:5000/api/health

# 应该返回: {"status":"ok","timestamp":"..."}
```

