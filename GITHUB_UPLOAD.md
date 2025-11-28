# 📤 GitHub上传指南

## 快速上传到GitHub

### 步骤1: 在GitHub创建仓库

1. 访问 https://github.com/new
2. 仓库名称: `bsc-web-manager`
3. 描述: `BSC靓号生成器 - Web管理端`
4. 选择 **Public** 或 **Private**
5. **不要**勾选 "Add a README file"（我们已经有了）
6. 点击 "Create repository"

### 步骤2: 本地初始化并上传

在本地项目目录执行以下命令：

```bash
cd D:\test\bsc-web-manager

# 初始化git仓库
git init

# 添加所有文件
git add .

# 提交
git commit -m "Initial commit: BSC靓号生成器Web管理端"

# 关联远程仓库（替换YOUR_USERNAME为你的GitHub用户名）
git remote add origin https://github.com/YOUR_USERNAME/bsc-web-manager.git

# 推送到GitHub
git branch -M main
git push -u origin main
```

### 步骤3: 更新安装脚本中的仓库地址

上传成功后，修改 `deploy/install_all.sh` 第142行：

```bash
# 将这行
git clone https://github.com/YOUR_USERNAME/bsc-web-manager.git

# 改为你的实际仓库地址，例如：
git clone https://github.com/yourusername/bsc-web-manager.git
```

然后再次提交：

```bash
git add deploy/install_all.sh
git commit -m "Update repository URL in install script"
git push
```

---

## 🚀 用户一键安装命令

上传成功后，用户可以使用以下命令一键安装：

```bash
# 完整安装（包含域名SSL配置选项）
bash <(curl -sL https://raw.githubusercontent.com/YOUR_USERNAME/bsc-web-manager/main/deploy/install_all.sh)
```

或者使用短链接（需要先创建）：

```bash
# 先克隆项目
git clone https://github.com/YOUR_USERNAME/bsc-web-manager.git
cd bsc-web-manager

# 执行安装
sudo bash deploy/install_all.sh
```

---

## 📋 上传前检查清单

- [x] ✅ 已创建 .gitignore 文件
- [x] ✅ 已排除 output/ 目录（钱包文件）
- [x] ✅ 已排除 venv/ 虚拟环境
- [x] ✅ 已包含 requirements.txt
- [x] ✅ 已包含完整的部署脚本
- [x] ✅ 已包含 README.md 说明文档

---

## 🔄 后续更新

当你修改代码后，使用以下命令更新GitHub：

```bash
cd D:\test\bsc-web-manager

# 查看修改的文件
git status

# 添加修改的文件
git add .

# 提交修改
git commit -m "描述你的修改"

# 推送到GitHub
git push
```

---

## 📝 示例仓库信息

**仓库名称**: bsc-web-manager

**仓库描述**:
```
🚀 BSC靓号生成器 - Web管理端

基于Web的BSC靓号地址生成器管理系统，支持远程管理多台服务器生成靓号。

特点：
✅ Web界面管理 - 美观的Web界面，无需命令行
✅ 远程SSH控制 - 通过SSH连接管理B端服务器  
✅ 实时输出显示 - WebSocket实时推送生成进度
✅ 一键安装脚本 - 支持域名和SSL证书自动配置
✅ 多核心支持 - 拖拽式选择CPU核心数
```

**README标签** (Topics):
```
bsc, vanity-address, web-manager, python, flask, ssh, websocket, ssl, nginx, certbot
```

---

## ⚠️ 注意事项

1. **不要上传敏感信息**
   - output/ 目录已被忽略
   - 确保没有包含真实的服务器IP、密码等

2. **虚拟环境已被忽略**
   - venv/ 目录不会上传
   - 用户安装时会自动创建

3. **保持README更新**
   - 修改功能时同步更新文档

4. **测试安装脚本**
   - 上传前在干净的服务器上测试安装脚本

---

## 🎯 完整上传命令（复制粘贴）

```bash
# 1. 进入项目目录
cd D:\test\bsc-web-manager

# 2. 初始化git（如果还没有）
git init

# 3. 添加所有文件
git add .

# 4. 查看将要提交的文件
git status

# 5. 提交
git commit -m "Initial commit: BSC靓号生成器Web管理端 - 包含域名SSL一键安装功能"

# 6. 关联GitHub仓库（替换YOUR_USERNAME）
git remote add origin https://github.com/YOUR_USERNAME/bsc-web-manager.git

# 7. 推送
git branch -M main
git push -u origin main
```

---

## 🌟 创建Release（可选）

上传成功后，可以创建一个Release版本：

1. 在GitHub仓库页面点击 "Releases"
2. 点击 "Create a new release"
3. Tag version: `v1.0.0`
4. Release title: `BSC靓号生成器 v1.0.0 - 首个正式版本`
5. 描述更新内容
6. 点击 "Publish release"

---

✅ **准备就绪！现在可以上传到GitHub了！**

