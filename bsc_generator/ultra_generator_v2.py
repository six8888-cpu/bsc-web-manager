#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
BSC靓号生成器 V2 - 运气加持高性能版
支持命令行参数和实时可视化进度条
"""

import os
import sys
import time
import multiprocessing
import argparse
from datetime import datetime
from eth_keys import keys
from eth_utils import to_checksum_address
import secrets


class VanityGenerator:
    """靓号生成器"""
    
    def __init__(self, prefix='', suffix='', contains='', 
                 case_sensitive=False, wallet_count=1, processes=None):
        self.prefix = prefix.lower() if not case_sensitive else prefix
        self.suffix = suffix.lower() if not case_sensitive else suffix
        self.contains = contains.lower() if not case_sensitive else contains
        self.case_sensitive = case_sensitive
        self.wallet_count = wallet_count
        # 使用所有核心以获得最大性能
        self.processes = processes or multiprocessing.cpu_count()
        
        self.found_wallets = []
        self.attempts = multiprocessing.Value('i', 0)
        self.start_time = time.time()
        
        # 预计算匹配长度（用于进度计算）
        self.match_length = len(self.prefix) + len(self.suffix) + len(self.contains)
        
    def generate_wallet(self):
        """生成单个钱包（优化版）"""
        private_key_bytes = secrets.token_bytes(32)
        pk = keys.PrivateKey(private_key_bytes)
        address = pk.public_key.to_checksum_address()
        return private_key_bytes.hex(), address
    
    def check_match(self, address):
        """检查地址是否匹配（超级优化版）"""
        # 直接操作字符串，避免创建新对象
        addr = address[2:] if not self.case_sensitive else address[2:]
        
        # 不区分大小写时转换
        if not self.case_sensitive:
            addr = addr.lower()
        
        # 内联检查，减少函数调用
        # 前缀检查（最快失败）
        if self.prefix:
            if not addr[:len(self.prefix)] == self.prefix:
                return False
        
        # 后缀检查
        if self.suffix:
            suffix_len = len(self.suffix)
            if not addr[-suffix_len:] == self.suffix:
                return False
        
        # 包含检查（使用in操作符，C语言实现，很快）
        if self.contains:
            if self.contains not in addr:
                return False
        
        return True
    
    def worker(self, queue, stop_event):
        """工作进程（超级优化版）"""
        local_attempts = 0
        batch_size = 2000  # 增大批次，进一步减少锁竞争
        
        # 预先缓存函数，减少属性查找
        generate = self.generate_wallet
        check = self.check_match
        is_stopped = stop_event.is_set
        
        while not is_stopped():
            private_key, address = generate()
            local_attempts += 1
            
            if check(address):
                queue.put((private_key, address))
                # 更新最后一批
                with self.attempts.get_lock():
                    self.attempts.value += local_attempts
                return
            
            # 批量更新计数器
            if local_attempts >= batch_size:
                with self.attempts.get_lock():
                    self.attempts.value += batch_size
                local_attempts = 0
    
    def calculate_probability(self):
        """计算理论概率"""
        total_combinations = 1
        
        if self.prefix:
            total_combinations *= 16 ** len(self.prefix)
        if self.suffix:
            total_combinations *= 16 ** len(self.suffix)
        if self.contains:
            total_combinations *= 16 ** len(self.contains)
        
        return total_combinations
    
    def format_number(self, num):
        """格式化数字"""
        if num >= 1e12:
            return f"{num/1e12:.2f}万亿"
        elif num >= 1e8:
            return f"{num/1e8:.2f}亿"
        elif num >= 1e4:
            return f"{num/1e4:.2f}万"
        elif num >= 1e3:
            return f"{num/1e3:.2f}千"
        else:
            return f"{int(num)}"
    
    def get_progress_bar(self, percentage, width=20):
        """生成进度条"""
        filled = int(width * percentage / 100)
        bar = '█' * filled + '░' * (width - filled)
        return bar
    
    
    def format_time(self, seconds):
        """格式化时间"""
        if seconds < 0 or seconds > 3600:
            return "计算中"
        elif seconds < 60:
            return f"{int(seconds)}秒"
        else:
            m = int(seconds // 60)
            s = int(seconds % 60)
            return f"{m}分{s}秒"
    
    def print_config(self):
        """打印配置信息"""
        print("=" * 70)
        print("🚀 BSC靓号生成器 V2 - 高性能运气加持版")
        print("=" * 70)
        
        prefix_val = self.prefix if self.prefix else "(无)"
        suffix_val = self.suffix if self.suffix else "(无)"
        contains_val = self.contains if self.contains else "(无)"
        
        print(f"前缀 (Prefix):     {prefix_val}")
        print(f"后缀 (Suffix):     {suffix_val}")
        print(f"包含 (Contains):   {contains_val}")
        print(f"区分大小写:         {'是' if self.case_sensitive else '否'}")
        print(f"生成数量:          {self.wallet_count} 个")
        print(f"使用核心:          {self.processes} 核")
        
        probability = self.calculate_probability()
        print(f"理论尝试:          {self.format_number(probability)} 次")
        print(f"理论成功率:        {(100/probability):.6f}%")
        print("=" * 70)
        print()
    
    def save_wallet(self, private_key, address, index):
        """保存钱包到文件"""
        output_file = "ultra_vanity_wallets.txt"
        
        if index == 1:
            with open(output_file, 'w', encoding='utf-8') as f:
                f.write("=" * 70 + "\n")
                f.write(f"生成时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
                f.write(f"前缀: {self.prefix if self.prefix else '(无)'}\n")
                f.write(f"后缀: {self.suffix if self.suffix else '(无)'}\n")
                f.write(f"包含: {self.contains if self.contains else '(无)'}\n")
                f.write(f"区分大小写: {'是' if self.case_sensitive else '否'}\n")
                f.write("=" * 70 + "\n\n")
        
        with open(output_file, 'a', encoding='utf-8') as f:
            f.write(f"钱包 #{index}\n")
            f.write(f"地址: {address}\n")
            f.write(f"私钥: 0x{private_key}\n")
            f.write(f"生成时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
            f.write("\n" + "-" * 70 + "\n\n")
    
    def run(self):
        """运行生成任务"""
        self.print_config()
        
        queue = multiprocessing.Queue()
        stop_event = multiprocessing.Event()
        
        found_count = 0
        probability = self.calculate_probability()
        
        print(f"⏰ 开始时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        print(f"🔄 启动 {self.processes} 个进程...")
        print()
        
        while found_count < self.wallet_count:
            # 启动工作进程
            processes = []
            for i in range(self.processes):
                p = multiprocessing.Process(
                    target=self.worker,
                    args=(queue, stop_event)
                )
                p.start()
                processes.append(p)
            
            # 等待结果
            last_attempts = 0
            last_time = time.time()
            
            while True:
                try:
                    # 尝试获取结果（非阻塞）
                    private_key, address = queue.get(timeout=0.5)
                    
                    # 找到一个！
                    found_count += 1
                    self.found_wallets.append((private_key, address))
                    
                    # 保存到文件
                    self.save_wallet(private_key, address, found_count)
                    
                    current_attempts = self.attempts.value
                    elapsed = time.time() - self.start_time
                    
                    print(f"\n")
                    print(f"✅ 找到匹配地址: {address}")
                    print(f"   私钥: 0x{private_key}")
                    print()
                    print(f"🎉 已找到 {found_count}/{self.wallet_count} 个地址")
                    print(f"⏱️  用时: {elapsed:.1f}秒")
                    print(f"🔢 尝试: {self.format_number(current_attempts)} 次")
                    
                    # 运气评价
                    ratio = current_attempts / probability if probability > 0 else 1
                    
                    if ratio < 0.5:
                        luck_msg = f"💎 恭喜！运气爆棚，仅用了理论值的 {ratio*100:.1f}%！"
                    elif ratio < 1.0:
                        luck_msg = f"👍 不错！运气还可以，快于平均速度。"
                    else:
                        luck_msg = f"💪 继续加油！下一个可能会更快。"
                    
                    print(luck_msg)
                    print()
                    
                    # 如果已完成，停止所有进程
                    if found_count >= self.wallet_count:
                        stop_event.set()
                        break
                    
                    # 继续下一轮
                    break
                    
                except:
                    # 超时，显示进度
                    current_attempts = self.attempts.value
                    current_time = time.time()
                    
                    if current_time - last_time >= 1.0:  # 每1秒更新一次（减少开销）
                        elapsed = current_time - self.start_time
                        
                        # 计算速度
                        time_delta = current_time - last_time
                        if time_delta > 0 and current_attempts > last_attempts:
                            instant_speed = (current_attempts - last_attempts) / time_delta
                        else:
                            instant_speed = 0
                        
                        # 只有速度大于0时才显示
                        if instant_speed > 100:  # 只显示有意义的速度
                            # 计算进度百分比
                            progress_pct = min(99.99, (current_attempts / probability * 100)) if probability > 0 else 0
                            
                            # 生成进度条
                            progress_bar = self.get_progress_bar(progress_pct, 20)
                            
                            # 计算预计剩余时间
                            if current_attempts < probability:
                                remaining = probability - current_attempts
                                eta = remaining / instant_speed
                                eta_str = self.format_time(eta)
                            else:
                                eta_str = "随时可能"
                            
                            # 构建输出（简化版，无运气提示）
                            output = (
                                f"\r[{progress_bar}] "
                                f"{progress_pct:5.2f}% | "
                                f"已尝试: {self.format_number(current_attempts):>7s} | "
                                f"速度: {self.format_number(instant_speed):>6s}/s | "
                                f"预计: {eta_str:>8s}"
                            )
                            
                            print(output, end='', flush=True)
                        
                        last_attempts = current_attempts
                        last_time = current_time
            
            # 等待所有进程结束
            for p in processes:
                p.join(timeout=1)
                if p.is_alive():
                    p.terminate()
        
        # 完成
        total_time = time.time() - self.start_time
        total_attempts = self.attempts.value
        avg_speed = total_attempts / total_time if total_time > 0 else 0
        
        print()
        print()
        print("=" * 70)
        print("✨ 全部完成！")
        print("=" * 70)
        print(f"总用时:     {total_time:.1f} 秒 ({total_time/60:.1f} 分钟)")
        print(f"总尝试:     {self.format_number(total_attempts)} 次")
        print(f"平均速度:   {self.format_number(avg_speed)}/秒")
        print(f"生成数量:   {found_count} 个")
        print(f"保存位置:   ultra_vanity_wallets.txt")
        
        # 整体运气评价
        overall_ratio = total_attempts / (probability * self.wallet_count) if probability > 0 else 1
        
        print()
        if overall_ratio < 0.5:
            print("🎊 恭喜！整体运气爆棚，远快于理论预期！")
        elif overall_ratio < 1.0:
            print("👍 不错！整体运气还可以，快于平均水平！")
        elif overall_ratio < 1.5:
            print("😊 正常水平，接近理论预期！")
        else:
            print("💪 耐心点，好运还在后面！")
        
        print("=" * 70)
        print()
        print("⚠️  重要提示:")
        print("   1. 请妥善保管私钥，不要泄露给任何人")
        print("   2. 建议将文件备份到安全的地方")
        print("   3. 首次使用建议先小额测试")
        print()


def main():
    """主函数"""
    parser = argparse.ArgumentParser(description='BSC靓号生成器 V2 - 高性能版')
    parser.add_argument('--prefix', type=str, default='', help='地址前缀')
    parser.add_argument('--suffix', type=str, default='', help='地址后缀')
    parser.add_argument('--contains', type=str, default='', help='地址包含')
    parser.add_argument('--case-sensitive', type=str, default='false', 
                        help='是否区分大小写 (true/false)')
    parser.add_argument('--count', type=int, default=1, help='生成数量')
    parser.add_argument('--processes', type=int, default=None, 
                        help='使用的进程数（默认为CPU核心数-1）')
    
    args = parser.parse_args()
    
    # 验证至少有一个条件
    if not args.prefix and not args.suffix and not args.contains:
        print("❌ 错误: 至少需要设置一个条件（--prefix、--suffix 或 --contains）")
        sys.exit(1)
    
    # 转换case_sensitive
    case_sensitive = args.case_sensitive.lower() == 'true'
    
    # 创建生成器
    generator = VanityGenerator(
        prefix=args.prefix,
        suffix=args.suffix,
        contains=args.contains,
        case_sensitive=case_sensitive,
        wallet_count=args.count,
        processes=args.processes
    )
    
    # 运行
    try:
        generator.run()
    except KeyboardInterrupt:
        print(f"\n\n⚠️  用户中断")
        sys.exit(0)


if __name__ == '__main__':
    # 解决Windows上multiprocessing的问题
    multiprocessing.freeze_support()
    main()
