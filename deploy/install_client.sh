#!/bin/bash
# B端服务器（中国服务器）快速安装脚本
# 此脚本会被Web端自动执行

set -e

echo "========================================"
echo "BSC生成器 B端安装脚本"
echo "========================================"
echo

# 检查Python3
if ! command -v python3 &> /dev/null; then
    echo "📦 安装Python3..."
    if [ -f /etc/debian_version ]; then
        apt update && apt install -y python3 python3-pip
    elif [ -f /etc/redhat-release ]; then
        yum install -y python3 python3-pip
    else
        echo "❌ 不支持的系统"
        exit 1
    fi
fi

# 创建工作目录
mkdir -p /root/bsc_generator
cd /root/bsc_generator

echo "✅ B端环境准备完成"
echo

