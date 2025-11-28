#!/bin/bash
# 快速启动脚本

cd "$(dirname "$0")/.."

echo "🚀 启动BSC靓号生成器 Web服务..."

# 检查虚拟环境
if [ ! -d "venv" ]; then
    echo "📦 创建虚拟环境..."
    python3 -m venv venv
fi

# 激活虚拟环境
source venv/bin/activate

# 安装依赖
if [ ! -f "venv/.installed" ]; then
    echo "📚 安装依赖..."
    cd backend
    pip install -r requirements.txt
    cd ..
    touch venv/.installed
fi

# 启动服务
cd backend
python app.py

