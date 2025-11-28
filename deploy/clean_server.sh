#!/bin/bash
###############################################################################
# BSC靓号生成器 - 服务器端文件清理脚本
# 功能：清理备份文件、临时文件、测试文件等无用文件
###############################################################################

echo "======================================"
echo "🧹 开始清理服务器无用文件"
echo "======================================"
echo ""

# 切换到项目目录
cd ~/bsc-web-manager || { echo "❌ 项目目录不存在"; exit 1; }

# 统计清理的文件数量
deleted_count=0

echo "📋 正在扫描无用文件..."
echo ""

# =============================================================================
# 1. 清理备份文件
# =============================================================================
echo "1️⃣  清理备份文件 (*.bak, *.bak.*)..."

backup_files=$(find . -name "*.bak" -o -name "*.bak.*" 2>/dev/null | wc -l)
if [ "$backup_files" -gt 0 ]; then
    find . -name "*.bak" -delete 2>/dev/null
    find . -name "*.bak.*" -delete 2>/dev/null
    echo "   ✅ 删除了 $backup_files 个备份文件"
    deleted_count=$((deleted_count + backup_files))
else
    echo "   ✓ 没有备份文件需要清理"
fi

# =============================================================================
# 2. 清理测试文件
# =============================================================================
echo ""
echo "2️⃣  清理测试文件..."

test_count=0

# 测试HTML文件
for file in test_*.html test_*.py; do
    if [ -f "$file" ]; then
        rm -f "$file"
        echo "   - 删除: $file"
        test_count=$((test_count + 1))
    fi
done

if [ "$test_count" -gt 0 ]; then
    echo "   ✅ 删除了 $test_count 个测试文件"
    deleted_count=$((deleted_count + test_count))
else
    echo "   ✓ 没有测试文件需要清理"
fi

# =============================================================================
# 3. 清理过期的部署脚本
# =============================================================================
echo ""
echo "3️⃣  清理过期的部署脚本..."

script_count=0
old_scripts=(
    "deploy/add_features_v2.sh"
    "deploy/add_progress_stop.sh"
    "deploy/add_progress_stop_final.sh"
    "deploy/apply_clean_output.sh"
    "deploy/fix_env.sh"
    "deploy/fix_nginx_config.sh"
    "deploy/fix_nginx_ssl.sh"
    "deploy/quick_fix_nginx.sh"
    "deploy/quick_update.sh"
    "deploy/rollback_to_simple.sh"
    "deploy/rollback_to_stop_version.sh"
    "deploy/update_ansi_support.sh"
    "deploy/功能添加说明.md"
)

for script in "${old_scripts[@]}"; do
    if [ -f "$script" ]; then
        rm -f "$script"
        echo "   - 删除: $script"
        script_count=$((script_count + 1))
    fi
done

if [ "$script_count" -gt 0 ]; then
    echo "   ✅ 删除了 $script_count 个过期脚本"
    deleted_count=$((deleted_count + script_count))
else
    echo "   ✓ 没有过期脚本需要清理"
fi

# =============================================================================
# 4. 清理过期文档
# =============================================================================
echo ""
echo "4️⃣  清理过期文档..."

doc_count=0
old_docs=(
    "DEPLOY_CLEAN_OUTPUT.md"
    "LUCK_FEATURE.md"
    "QUICK_FIX.md"
    "PROJECT_OVERVIEW.md"
    "QUICKSTART.md"
    "USAGE.md"
)

for doc in "${old_docs[@]}"; do
    if [ -f "$doc" ]; then
        rm -f "$doc"
        echo "   - 删除: $doc"
        doc_count=$((doc_count + 1))
    fi
done

if [ "$doc_count" -gt 0 ]; then
    echo "   ✅ 删除了 $doc_count 个过期文档"
    deleted_count=$((deleted_count + doc_count))
else
    echo "   ✓ 没有过期文档需要清理"
fi

# =============================================================================
# 5. 清理Python缓存
# =============================================================================
echo ""
echo "5️⃣  清理Python缓存文件..."

cache_count=$(find . -type d -name "__pycache__" 2>/dev/null | wc -l)
if [ "$cache_count" -gt 0 ]; then
    find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null
    echo "   ✅ 删除了 $cache_count 个缓存目录"
    deleted_count=$((deleted_count + cache_count))
else
    echo "   ✓ 没有Python缓存需要清理"
fi

pyc_count=$(find . -name "*.pyc" -o -name "*.pyo" 2>/dev/null | wc -l)
if [ "$pyc_count" -gt 0 ]; then
    find . -name "*.pyc" -delete 2>/dev/null
    find . -name "*.pyo" -delete 2>/dev/null
    echo "   ✅ 删除了 $pyc_count 个编译文件"
    deleted_count=$((deleted_count + pyc_count))
fi

# =============================================================================
# 6. 清理临时文件
# =============================================================================
echo ""
echo "6️⃣  清理临时文件..."

temp_count=0

# .tmp, .log, .swp等
for ext in tmp log swp; do
    files=$(find . -name "*.$ext" 2>/dev/null | wc -l)
    if [ "$files" -gt 0 ]; then
        find . -name "*.$ext" -delete 2>/dev/null
        temp_count=$((temp_count + files))
    fi
done

if [ "$temp_count" -gt 0 ]; then
    echo "   ✅ 删除了 $temp_count 个临时文件"
    deleted_count=$((deleted_count + temp_count))
else
    echo "   ✓ 没有临时文件需要清理"
fi

# =============================================================================
# 7. 清理旧的输出文件（可选，询问用户）
# =============================================================================
echo ""
echo "7️⃣  检查输出文件..."

if [ -d "output" ]; then
    output_count=$(find output -name "wallets_task_*.txt" 2>/dev/null | wc -l)
    if [ "$output_count" -gt 0 ]; then
        echo "   ℹ️  发现 $output_count 个钱包输出文件"
        echo "   ⚠️  这些文件包含生成的钱包，请手动删除"
        echo "   命令: rm -f output/wallets_task_*.txt"
    else
        echo "   ✓ output目录为空"
    fi
else
    echo "   ✓ output目录不存在"
fi

# =============================================================================
# 8. 清理空目录
# =============================================================================
echo ""
echo "8️⃣  清理空目录..."

empty_count=$(find . -type d -empty 2>/dev/null | grep -v "venv" | grep -v ".git" | wc -l)
if [ "$empty_count" -gt 0 ]; then
    find . -type d -empty 2>/dev/null | grep -v "venv" | grep -v ".git" | xargs rm -rf 2>/dev/null
    echo "   ✅ 删除了 $empty_count 个空目录"
    deleted_count=$((deleted_count + empty_count))
else
    echo "   ✓ 没有空目录需要清理"
fi

# =============================================================================
# 完成
# =============================================================================
echo ""
echo "======================================"
echo "✅ 清理完成！"
echo "======================================"
echo ""
echo "📊 清理统计:"
echo "   总共删除: $deleted_count 个文件/目录"
echo ""
echo "💾 磁盘空间:"
du -sh ~/bsc-web-manager 2>/dev/null | awk '{print "   项目大小: " $1}'
echo ""
echo "📁 当前文件结构:"
tree -L 2 -I 'venv|__pycache__|*.pyc' ~/bsc-web-manager 2>/dev/null || ls -la ~/bsc-web-manager

echo ""
echo "🎉 服务器已清理完毕！"
echo ""

