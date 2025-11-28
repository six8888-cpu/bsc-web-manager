#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
BSC靓号生成器 Web管理后端
"""

from flask import Flask, render_template, request, jsonify, send_file
from flask_socketio import SocketIO, emit
from flask_cors import CORS
import paramiko
import threading
import time
import os
import json
import io
from datetime import datetime

app = Flask(__name__, 
            static_folder='../static',
            template_folder='../templates')
app.config['SECRET_KEY'] = 'bsc-vanity-generator-secret-2025'
CORS(app)
socketio = SocketIO(app, cors_allowed_origins="*", async_mode='threading')

# 全局存储SSH连接和任务状态
active_connections = {}
task_status = {}

# 存储活动任务 {task_id: {'ssh': ssh_obj, 'stop_flag': threading.Event()}}
active_tasks = {}


class SSHManager:
    """SSH连接管理器"""
    
    def __init__(self, host, port, username, password):
        self.host = host
        self.port = port
        self.username = username
        self.password = password
        self.client = None
        self.connected = False
        
    def connect(self):
        """建立SSH连接"""
        try:
            self.client = paramiko.SSHClient()
            self.client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
            self.client.connect(
                hostname=self.host,
                port=self.port,
                username=self.username,
                password=self.password,
                timeout=10
            )
            self.connected = True
            return True, "连接成功"
        except Exception as e:
            return False, f"连接失败: {str(e)}"
    
    def get_cpu_cores(self):
        """获取CPU核心数"""
        try:
            stdin, stdout, stderr = self.client.exec_command('nproc')
            cores = int(stdout.read().decode().strip())
            return cores
        except Exception as e:
            return None
    
    def check_python(self):
        """检查Python版本"""
        try:
            stdin, stdout, stderr = self.client.exec_command('python3 --version')
            version = stdout.read().decode().strip()
            return version
        except:
            return None
    
    def execute_command(self, command, callback=None):
        """执行命令并实时返回输出"""
        try:
            transport = self.client.get_transport()
            channel = transport.open_session()
            channel.exec_command(command)
            
            while True:
                if channel.recv_ready():
                    output = channel.recv(1024).decode('utf-8', errors='ignore')
                    if callback:
                        callback(output)
                
                if channel.recv_stderr_ready():
                    error = channel.recv_stderr(1024).decode('utf-8', errors='ignore')
                    if callback:
                        callback(error)
                
                if channel.exit_status_ready():
                    break
                    
                time.sleep(0.1)
            
            exit_status = channel.recv_exit_status()
            return exit_status == 0
            
        except Exception as e:
            if callback:
                callback(f"执行错误: {str(e)}\n")
            return False
    
    def upload_file(self, local_path, remote_path):
        """上传文件到远程服务器"""
        try:
            sftp = self.client.open_sftp()
            sftp.put(local_path, remote_path)
            sftp.close()
            return True
        except Exception as e:
            return False
    
    def download_file(self, remote_path, local_path):
        """从远程服务器下载文件"""
        try:
            sftp = self.client.open_sftp()
            sftp.get(remote_path, local_path)
            sftp.close()
            return True
        except Exception as e:
            return False
    
    def close(self):
        """关闭连接"""
        if self.client:
            self.client.close()
            self.connected = False


@app.route('/')
def index():
    """主页"""
    return render_template('index.html')


@socketio.on('connect')
def handle_connect():
    """WebSocket连接"""
    emit('response', {'data': '已连接到服务器'})


@socketio.on('test_connection')
def test_connection(data):
    """测试SSH连接"""
    try:
        host = data.get('host')
        port = data.get('port', 22)
        username = data.get('username', 'root')
        password = data.get('password')
        
        ssh = SSHManager(host, port, username, password)
        success, message = ssh.connect()
        
        if success:
            # 获取系统信息
            cpu_cores = ssh.get_cpu_cores()
            python_version = ssh.check_python()
            
            # 获取系统信息
            stdin, stdout, stderr = ssh.client.exec_command('cat /proc/meminfo | grep MemTotal')
            mem_info = stdout.read().decode().strip()
            mem_gb = int(mem_info.split()[1]) / 1024 / 1024
            
            stdin, stdout, stderr = ssh.client.exec_command('uname -a')
            os_info = stdout.read().decode().strip()
            
            ssh.close()
            
            emit('connection_result', {
                'success': True,
                'message': message,
                'cpu_cores': cpu_cores,
                'python_version': python_version,
                'memory_gb': round(mem_gb, 1),
                'os_info': os_info
            })
        else:
            emit('connection_result', {
                'success': False,
                'message': message
            })
            
    except Exception as e:
        emit('connection_result', {
            'success': False,
            'message': f'测试连接失败: {str(e)}'
        })


@socketio.on('stop_task')
def stop_task(data):
    """停止运行中的任务"""
    try:
        task_id = data.get('task_id')
        
        if task_id in active_tasks:
            task_info = active_tasks[task_id]
            
            # 设置停止标志
            if 'stop_flag' in task_info:
                task_info['stop_flag'].set()
            
            # 关闭SSH连接并终止B端进程
            if 'ssh' in task_info and task_info['ssh']:
                try:
                    ssh = task_info['ssh']
                    # 在B端服务器上查找并杀死生成进程
                    stdin, stdout, stderr = ssh.client.exec_command(
                        "pkill -f 'ultra_generator_v2.py' || true"
                    )
                    stdout.channel.recv_exit_status()
                    ssh.close()
                except Exception as e:
                    print(f"停止任务时出错: {e}")
            
            # 从活动任务中移除
            del active_tasks[task_id]
            
            emit('task_stopped', {'task_id': task_id, 'message': '任务已停止'})
        else:
            emit('task_error', {'error': '任务不存在或已完成'})
            
    except Exception as e:
        emit('task_error', {'error': f'停止任务失败: {str(e)}'})


@socketio.on('start_generation')
def start_generation(data):
    """开始生成靓号"""
    try:
        task_id = f"task_{int(time.time())}"
        
        # 提取配置
        host = data.get('host')
        port = data.get('port', 22)
        username = data.get('username', 'root')
        password = data.get('password')
        
        prefix = data.get('prefix', '')
        suffix = data.get('suffix', '')
        contains = data.get('contains', '')
        case_sensitive = data.get('case_sensitive', False)
        wallet_count = data.get('wallet_count', 1)
        cpu_cores = data.get('cpu_cores', 4)
        
        # 启动生成任务
        thread = threading.Thread(
            target=run_generation_task,
            args=(task_id, host, port, username, password, 
                  prefix, suffix, contains, case_sensitive, 
                  wallet_count, cpu_cores)
        )
        thread.daemon = True
        thread.start()
        
        emit('task_started', {'task_id': task_id})
        
    except Exception as e:
        emit('task_error', {'error': f'启动任务失败: {str(e)}'})


def run_generation_task(task_id, host, port, username, password,
                        prefix, suffix, contains, case_sensitive,
                        wallet_count, cpu_cores):
    """运行生成任务（在子线程中）"""
    
    # 注册任务
    stop_flag = threading.Event()
    active_tasks[task_id] = {
        'stop_flag': stop_flag,
        'ssh': None
    }
    
    def send_output(msg):
        """发送输出到前端"""
        socketio.emit('generation_output', {
            'task_id': task_id,
            'output': msg
        })
    
    try:
        # 检查停止标志
        if stop_flag.is_set():
            return
        
        send_output(f"[{datetime.now().strftime('%H:%M:%S')}] 正在连接到 {host}...\n")
        
        # 建立SSH连接
        ssh = SSHManager(host, port, username, password)
        success, message = ssh.connect()
        
        # 保存SSH连接
        active_tasks[task_id]['ssh'] = ssh
        
        if not success:
            send_output(f"❌ {message}\n")
            return
        
        send_output(f"✅ 连接成功!\n")
        
        # 1. 检查并创建工作目录
        send_output(f"[{datetime.now().strftime('%H:%M:%S')}] 准备工作目录...\n")
        ssh.execute_command('mkdir -p /root/bsc_generator', send_output)
        
        # 2. 上传生成脚本
        send_output(f"[{datetime.now().strftime('%H:%M:%S')}] 上传生成脚本...\n")
        local_script = os.path.join(os.path.dirname(__file__), '../bsc_generator/ultra_generator_v2.py')
        ssh.upload_file(local_script, '/root/bsc_generator/ultra_generator_v2.py')
        send_output("✅ 脚本上传完成\n")
        
        # 3. 上传requirements.txt
        send_output(f"[{datetime.now().strftime('%H:%M:%S')}] 上传依赖文件...\n")
        local_req = os.path.join(os.path.dirname(__file__), '../bsc_generator/requirements.txt')
        ssh.upload_file(local_req, '/root/bsc_generator/requirements.txt')
        
        # 4. 检查并安装依赖
        send_output(f"[{datetime.now().strftime('%H:%M:%S')}] 检查Python依赖...\n")
        check_cmd = 'cd /root/bsc_generator && python3 -c "import eth_keys, eth_utils" 2>/dev/null'
        stdin, stdout, stderr = ssh.client.exec_command(check_cmd)
        if stdout.channel.recv_exit_status() != 0:
            send_output("📦 安装依赖包（首次运行需要1-2分钟）...\n")
            ssh.execute_command(
                'cd /root/bsc_generator && pip3 install -r requirements.txt -i https://mirrors.aliyun.com/pypi/simple/',
                send_output
            )
        else:
            send_output("✅ 依赖已安装\n")
        
        # 5. 创建配置文件
        send_output(f"[{datetime.now().strftime('%H:%M:%S')}] 配置生成参数...\n")
        config_content = f"""PREFIX="{prefix}"
SUFFIX="{suffix}"
CONTAINS="{contains}"
CASE_SENSITIVE="{case_sensitive}"
WALLET_COUNT={wallet_count}
CPU_CORES={cpu_cores}
"""
        
        # 写入配置文件
        stdin, stdout, stderr = ssh.client.exec_command(
            f'cat > /root/bsc_generator/config.sh << EOF\n{config_content}\nEOF'
        )
        stdout.channel.recv_exit_status()
        
        send_output(f"\n{'='*60}\n")
        send_output(f"🎯 生成配置:\n")
        send_output(f"   前缀: {prefix or '(无)'}\n")
        send_output(f"   后缀: {suffix or '(无)'}\n")
        send_output(f"   包含: {contains or '(无)'}\n")
        send_output(f"   数量: {wallet_count} 个\n")
        send_output(f"   核心: {cpu_cores} 核\n")
        send_output(f"{'='*60}\n\n")
        
        # 6. 运行生成脚本
        send_output(f"[{datetime.now().strftime('%H:%M:%S')}] 🚀 开始生成靓号...\n\n")
        
        # 构建运行命令
        run_cmd = f'''cd /root/bsc_generator && python3 ultra_generator_v2.py \
--prefix "{prefix}" \
--suffix "{suffix}" \
--contains "{contains}" \
--case-sensitive {str(case_sensitive).lower()} \
--count {wallet_count} \
--processes {cpu_cores}'''
        
        ssh.execute_command(run_cmd, send_output)
        
        # 7. 下载结果
        send_output(f"\n\n[{datetime.now().strftime('%H:%M:%S')}] 📥 下载生成结果...\n")
        
        # 确保输出目录存在
        output_dir = os.path.join(os.path.dirname(__file__), '../output')
        os.makedirs(output_dir, exist_ok=True)
        
        local_result = os.path.join(output_dir, f'wallets_{task_id}.txt')
        success = ssh.download_file('/root/bsc_generator/ultra_vanity_wallets.txt', local_result)
        
        if success:
            send_output(f"✅ 结果已保存: wallets_{task_id}.txt\n")
            
            # 读取并显示结果
            with open(local_result, 'r', encoding='utf-8') as f:
                result_content = f.read()
            
            send_output(f"\n{'='*60}\n")
            send_output(f"📋 生成结果:\n")
            send_output(f"{'='*60}\n")
            send_output(result_content)
            send_output(f"\n{'='*60}\n")
            
            socketio.emit('task_completed', {
                'task_id': task_id,
                'result_file': f'wallets_{task_id}.txt'
            })
        else:
            send_output("❌ 下载结果失败\n")
        
        ssh.close()
        send_output(f"\n[{datetime.now().strftime('%H:%M:%S')}] ✨ 任务完成！\n")
        
        # 清理任务
        if task_id in active_tasks:
            del active_tasks[task_id]
        
    except Exception as e:
        send_output(f"\n❌ 任务异常: {str(e)}\n")
        socketio.emit('task_error', {
            'task_id': task_id,
            'error': str(e)
        })
        
        # 清理任务
        if task_id in active_tasks:
            del active_tasks[task_id]


@app.route('/download/<filename>')
def download_result(filename):
    """下载生成的钱包文件"""
    try:
        output_dir = os.path.join(os.path.dirname(__file__), '../output')
        file_path = os.path.join(output_dir, filename)
        
        if os.path.exists(file_path):
            return send_file(
                file_path,
                as_attachment=True,
                download_name=filename
            )
        else:
            return jsonify({'error': '文件不存在'}), 404
            
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@app.route('/api/health')
def health_check():
    """健康检查"""
    return jsonify({
        'status': 'ok',
        'timestamp': datetime.now().isoformat()
    })


if __name__ == '__main__':
    # 创建必要的目录
    os.makedirs('output', exist_ok=True)
    
    # 启动服务器
    print("🚀 BSC靓号生成器 Web管理后端启动中...")
    print("📡 访问地址: http://0.0.0.0:5000")
    print("=" * 60)
    
    socketio.run(app, host='0.0.0.0', port=5000, debug=False, allow_unsafe_werkzeug=True)
