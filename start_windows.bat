@echo off
chcp 65001 >nul
title BSC靓号生成器 Web服务

echo ========================================
echo   BSC靓号生成器 Web管理端
echo ========================================
echo.

:: 检查Python
python --version >nul 2>&1
if errorlevel 1 (
    echo ❌ 未检测到Python，请先安装Python 3.7+
    echo.
    echo 下载地址: https://www.python.org/downloads/
    pause
    exit /b 1
)

:: 创建虚拟环境（如果不存在）
if not exist "venv" (
    echo 📦 创建虚拟环境...
    python -m venv venv
)

:: 激活虚拟环境
call venv\Scripts\activate

:: 安装依赖（如果需要）
if not exist "venv\.installed" (
    echo 📚 安装依赖包...
    cd backend
    pip install -r requirements.txt -i https://mirrors.aliyun.com/pypi/simple/
    cd ..
    echo. > venv\.installed
)

:: 启动服务
echo.
echo 🚀 启动Web服务...
echo.
echo 访问地址: http://localhost:5000
echo 按 Ctrl+C 停止服务
echo.
cd backend
python app.py

pause

