@echo off
chcp 65001 >nul
echo ========================================
echo    BSC靓号生成器 - GitHub上传助手
echo ========================================
echo.

REM 检查是否在正确的目录
if not exist "backend\app.py" (
    echo ❌ 错误: 请在 bsc-web-manager 目录下运行此脚本
    pause
    exit /b 1
)

echo 📋 准备上传到GitHub...
echo.

REM 询问GitHub用户名
set /p GITHUB_USER=请输入您的GitHub用户名: 

if "%GITHUB_USER%"=="" (
    echo ❌ 错误: GitHub用户名不能为空
    pause
    exit /b 1
)

echo.
echo 🔍 检测Git状态...
git --version >nul 2>&1
if errorlevel 1 (
    echo ❌ 错误: 未安装Git，请先安装Git
    echo 下载地址: https://git-scm.com/download/win
    pause
    exit /b 1
)

echo ✅ Git已安装
echo.

REM 检查是否已初始化Git
if not exist ".git" (
    echo 📦 初始化Git仓库...
    git init
    echo ✅ Git仓库初始化完成
) else (
    echo ✅ Git仓库已存在
)
echo.

REM 添加所有文件
echo 📂 添加文件到Git...
git add .
echo ✅ 文件添加完成
echo.

REM 显示将要提交的文件
echo 📋 将要提交的文件:
echo ─────────────────────────────
git status --short
echo ─────────────────────────────
echo.

REM 询问是否继续
set /p CONTINUE=是否继续提交? (y/N): 
if /i not "%CONTINUE%"=="y" (
    echo ⚠️  已取消上传
    pause
    exit /b 0
)

echo.
echo 💾 提交到本地仓库...
git commit -m "Initial commit: BSC靓号生成器Web管理端 - 包含域名SSL一键安装功能"
echo ✅ 提交完成
echo.

REM 检查是否已关联远程仓库
git remote -v | findstr "origin" >nul 2>&1
if errorlevel 1 (
    echo 🔗 关联GitHub远程仓库...
    git remote add origin https://github.com/%GITHUB_USER%/bsc-web-manager.git
    echo ✅ 远程仓库关联完成
) else (
    echo ✅ 远程仓库已关联
)
echo.

REM 设置主分支为main
echo 🌳 设置主分支为main...
git branch -M main
echo.

echo 🚀 开始上传到GitHub...
echo.
echo ⚠️  如果这是第一次上传，可能需要输入GitHub用户名和密码
echo     （或使用Personal Access Token）
echo.

git push -u origin main

if errorlevel 1 (
    echo.
    echo ❌ 上传失败！
    echo.
    echo 💡 可能的原因:
    echo    1. 仓库不存在 - 请先在GitHub创建仓库
    echo    2. 认证失败 - 请检查用户名和密码/Token
    echo    3. 网络问题 - 请检查网络连接
    echo.
    echo 📖 详细步骤请查看: GITHUB_UPLOAD.md
    pause
    exit /b 1
)

echo.
echo ========================================
echo ✅ 上传成功！
echo ========================================
echo.
echo 📱 访问您的仓库:
echo    https://github.com/%GITHUB_USER%/bsc-web-manager
echo.
echo 🔧 下一步:
echo    1. 编辑 deploy/install_all.sh
echo    2. 将第142行的 YOUR_USERNAME 改为 %GITHUB_USER%
echo    3. 重新提交:
echo       git add deploy/install_all.sh
echo       git commit -m "Update repository URL"
echo       git push
echo.
echo 🎉 现在用户可以使用一键安装命令了:
echo    bash ^<(curl -sL https://raw.githubusercontent.com/%GITHUB_USER%/bsc-web-manager/main/deploy/install_all.sh^)
echo.
pause

