// WebSocket连接
const socket = io();

// 全局变量
let currentTaskId = null;
let currentResultFile = null;
let serverInfo = null;

// 页面加载完成
document.addEventListener('DOMContentLoaded', function() {
    initSocketIO();
    loadSavedConfig();
});

// 初始化WebSocket
function initSocketIO() {
    socket.on('connect', function() {
        addTerminalLine('✅ 已连接到Web服务器', 'success');
    });

    socket.on('disconnect', function() {
        addTerminalLine('❌ 与Web服务器断开连接', 'error');
    });

    socket.on('connection_result', function(data) {
        handleConnectionResult(data);
    });

    socket.on('task_started', function(data) {
        currentTaskId = data.task_id;
        document.getElementById('task-id').textContent = `任务ID: ${data.task_id}`;
        document.getElementById('task-id').style.display = 'inline';
        updateStatus('正在生成中...', 'warning');
        showStopButton();
    });
    
    socket.on('task_stopped', function(data) {
        if (data.task_id === currentTaskId) {
            addTerminalLine(`\n✅ ${data.message}`, 'success');
            updateStatus('任务已停止', 'warning');
            hideStopButton();
            currentTaskId = null;
        }
    });

    socket.on('generation_output', function(data) {
        addTerminalLine(data.output);
        scrollToBottom();
    });

    socket.on('task_completed', function(data) {
        currentResultFile = data.result_file;
        updateStatus('✅ 生成完成！', 'success');
        showDownloadSection();
        addTerminalLine('\n🎉 任务完成！您可以下载结果文件。', 'success');
        hideStopButton();
        currentTaskId = null;
    });

    socket.on('task_error', function(data) {
        updateStatus('❌ 任务失败', 'error');
        addTerminalLine(`\n❌ 错误: ${data.error}`, 'error');
        if (currentTaskId) {
            hideStopButton();
            currentTaskId = null;
        }
    });
}

// 测试连接
function testConnection() {
    const host = document.getElementById('host').value.trim();
    const port = parseInt(document.getElementById('port').value) || 22;
    const username = document.getElementById('username').value.trim() || 'root';
    const password = document.getElementById('password').value;

    if (!host) {
        alert('请输入服务器IP地址！');
        return;
    }

    if (!password) {
        alert('请输入服务器密码！');
        return;
    }

    addTerminalLine('\n🔍 正在测试连接...', 'warning');
    updateStatus('正在连接...', 'warning');

    socket.emit('test_connection', {
        host: host,
        port: port,
        username: username,
        password: password
    });
}

// 处理连接结果
function handleConnectionResult(data) {
    if (data.success) {
        serverInfo = data;
        
        // 显示服务器信息
        document.getElementById('server-info').style.display = 'block';
        document.getElementById('cpu-cores').textContent = `${data.cpu_cores} 核`;
        document.getElementById('memory').textContent = `${data.memory_gb} GB`;
        document.getElementById('python-version').textContent = data.python_version;

        // 设置CPU滑块
        const cpuSlider = document.getElementById('cpu-slider');
        cpuSlider.max = data.cpu_cores;
        cpuSlider.value = Math.max(1, data.cpu_cores - 1);
        cpuSlider.disabled = false;
        updateCPUValue(cpuSlider.value);

        // 启用开始按钮
        document.getElementById('start-btn').disabled = false;

        updateStatus('✅ 连接成功，可以开始生成', 'success');
        addTerminalLine(`✅ 连接成功！`, 'success');
        addTerminalLine(`   CPU: ${data.cpu_cores} 核`, 'success');
        addTerminalLine(`   内存: ${data.memory_gb} GB`, 'success');
        addTerminalLine(`   Python: ${data.python_version}`, 'success');
        addTerminalLine(`   系统: ${data.os_info}\n`, 'success');

        // 保存配置
        saveConfig();
    } else {
        updateStatus('❌ 连接失败', 'error');
        addTerminalLine(`❌ 连接失败: ${data.message}`, 'error');
    }
}

// 开始生成
function startGeneration() {
    const prefix = document.getElementById('prefix').value.trim();
    const suffix = document.getElementById('suffix').value.trim();
    const contains = document.getElementById('contains').value.trim();
    const caseSensitive = document.getElementById('case-sensitive').checked;
    const walletCount = parseInt(document.getElementById('wallet-count').value) || 1;
    const cpuCores = parseInt(document.getElementById('cpu-slider').value);

    // 验证至少有一个条件
    if (!prefix && !suffix && !contains) {
        alert('请至少设置一个条件（前缀、后缀或包含）！');
        return;
    }

    // 确认开始
    const confirmMsg = `确认开始生成？\n\n前缀: ${prefix || '(无)'}\n后缀: ${suffix || '(无)'}\n包含: ${contains || '(无)'}\n数量: ${walletCount} 个\n核心: ${cpuCores} 核`;
    
    if (!confirm(confirmMsg)) {
        return;
    }

    // 隐藏下载区域
    document.getElementById('download-section').style.display = 'none';

    // 发送生成请求
    addTerminalLine('\n' + '='.repeat(60), 'warning');
    addTerminalLine('🚀 开始新的生成任务...', 'warning');
    addTerminalLine('='.repeat(60) + '\n', 'warning');

    socket.emit('start_generation', {
        host: document.getElementById('host').value.trim(),
        port: parseInt(document.getElementById('port').value) || 22,
        username: document.getElementById('username').value.trim() || 'root',
        password: document.getElementById('password').value,
        prefix: prefix,
        suffix: suffix,
        contains: contains,
        case_sensitive: caseSensitive,
        wallet_count: walletCount,
        cpu_cores: cpuCores
    });
}

// 更新CPU值显示
function updateCPUValue(value) {
    document.getElementById('cpu-value').textContent = value;
}

// 添加终端行
function addTerminalLine(text, className = '') {
    const terminal = document.getElementById('terminal');
    const line = document.createElement('div');
    line.className = `terminal-line ${className}`;
    line.textContent = text;
    terminal.appendChild(line);
    scrollToBottom();
}

// 清空终端
function clearTerminal() {
    const terminal = document.getElementById('terminal');
    terminal.innerHTML = '<div class="terminal-line welcome">终端已清空，等待新的输出...</div>';
}

// 滚动到底部
function scrollToBottom() {
    const terminal = document.getElementById('terminal');
    terminal.scrollTop = terminal.scrollHeight;
}

// 更新状态
function updateStatus(text, type = 'info') {
    const statusText = document.getElementById('status-text');
    statusText.textContent = `状态: ${text}`;
    
    // 移除所有类
    statusText.className = '';
    
    // 添加新类
    if (type === 'success') {
        statusText.style.color = '#2ecc71';
    } else if (type === 'error') {
        statusText.style.color = '#e74c3c';
    } else if (type === 'warning') {
        statusText.style.color = '#f39c12';
    } else {
        statusText.style.color = '#3498db';
    }
}

// 显示下载区域
function showDownloadSection() {
    document.getElementById('download-section').style.display = 'block';
}

// 下载结果
function downloadResult() {
    if (currentResultFile) {
        window.location.href = `/download/${currentResultFile}`;
        addTerminalLine(`\n📥 正在下载: ${currentResultFile}`, 'success');
    } else {
        alert('没有可下载的文件！');
    }
}

// 保存配置到localStorage
function saveConfig() {
    const config = {
        host: document.getElementById('host').value,
        port: document.getElementById('port').value,
        username: document.getElementById('username').value
    };
    localStorage.setItem('bsc_config', JSON.stringify(config));
}

// 加载保存的配置
function loadSavedConfig() {
    const saved = localStorage.getItem('bsc_config');
    if (saved) {
        try {
            const config = JSON.parse(saved);
            if (config.host) document.getElementById('host').value = config.host;
            if (config.port) document.getElementById('port').value = config.port;
            if (config.username) document.getElementById('username').value = config.username;
        } catch (e) {
            console.error('加载配置失败:', e);
        }
    }
}

// ========== 停止任务功能 ==========

// 显示停止按钮
function showStopButton() {
    document.getElementById('stop-btn').style.display = 'block';
}

// 隐藏停止按钮
function hideStopButton() {
    document.getElementById('stop-btn').style.display = 'none';
}

// 停止任务
function stopTask() {
    if (!currentTaskId) {
        alert('没有运行中的任务');
        return;
    }
    
    if (!confirm('确定要停止当前任务吗？停止后已生成的结果可能会丢失。')) {
        return;
    }
    
    socket.emit('stop_task', { task_id: currentTaskId });
    addTerminalLine('\n⚠️  正在停止任务...', 'warning');
}
