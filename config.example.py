#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
配置文件示例
复制此文件为 config.py 并修改配置
"""

# Web服务器配置
WEB_HOST = '0.0.0.0'  # 监听地址 (0.0.0.0表示所有网卡)
WEB_PORT = 5000        # 监听端口

# 安全配置
SECRET_KEY = 'your-secret-key-here'  # 修改为随机字符串
CORS_ORIGINS = '*'  # CORS允许的来源，生产环境建议指定域名

# SSH配置
SSH_TIMEOUT = 10  # SSH连接超时时间(秒)
SSH_KEEPALIVE = 30  # SSH保活时间(秒)

# 文件路径配置
OUTPUT_DIR = 'output'  # 生成文件保存目录
GENERATOR_DIR = 'bsc_generator'  # 生成器脚本目录

# 生成器配置
REMOTE_WORK_DIR = '/root/bsc_generator'  # B端工作目录
PIP_MIRROR = 'https://mirrors.aliyun.com/pypi/simple/'  # pip镜像源

# 日志配置
LOG_LEVEL = 'INFO'  # 日志级别: DEBUG, INFO, WARNING, ERROR
LOG_FILE = 'app.log'  # 日志文件路径

# 性能配置
MAX_CONCURRENT_TASKS = 5  # 最大并发任务数
TASK_TIMEOUT = 86400  # 任务超时时间(秒) 24小时

# 安全增强 (可选)
ENABLE_AUTH = False  # 是否启用用户认证
ALLOWED_IPS = []  # 允许访问的IP列表，空表示允许所有

# 示例: ALLOWED_IPS = ['192.168.1.100', '10.0.0.1']

