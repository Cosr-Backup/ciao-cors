#!/bin/bash

# CIAO-CORS 服务诊断脚本
# 用于快速诊断和修复常见问题

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 配置
SERVICE_NAME="ciao-cors"
CONFIG_FILE="/etc/ciao-cors/config.env"
LOG_FILE="/var/log/ciao-cors.log"

print_status() {
    local type=$1
    local message=$2
    case $type in
        "info")    echo -e "${BLUE}[INFO]${NC} $message" ;;
        "success") echo -e "${GREEN}[SUCCESS]${NC} $message" ;;
        "warning") echo -e "${YELLOW}[WARNING]${NC} $message" ;;
        "error")   echo -e "${RED}[ERROR]${NC} $message" ;;
    esac
}

print_separator() {
    echo -e "${BLUE}================================================${NC}"
}

# 检查系统状态
check_system() {
    print_separator
    print_status "info" "系统状态检查"
    print_separator
    
    # 检查操作系统
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        print_status "info" "操作系统: $NAME $VERSION_ID"
    fi
    
    # 检查系统资源
    print_status "info" "系统资源:"
    echo "  CPU: $(nproc) 核心"
    echo "  内存: $(free -h | awk '/^Mem:/{print $2}')"
    echo "  磁盘: $(df -h / | awk 'NR==2{print $4}') 可用"
    
    # 检查网络工具
    print_status "info" "网络工具:"
    for tool in ss netstat lsof curl; do
        if command -v $tool &> /dev/null; then
            echo "  ✓ $tool"
        else
            echo "  ✗ $tool (缺失)"
        fi
    done
}

# 检查服务状态
check_service() {
    print_separator
    print_status "info" "服务状态检查"
    print_separator
    
    # 检查服务是否存在
    if ! systemctl list-unit-files | grep -q "^$SERVICE_NAME.service"; then
        print_status "error" "服务未安装"
        return 1
    fi
    
    # 检查服务状态
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        print_status "success" "服务正在运行"
    else
        print_status "error" "服务未运行"
        print_status "info" "服务状态:"
        systemctl status "$SERVICE_NAME" --no-pager -l
        return 1
    fi
    
    # 检查服务启动时间
    local start_time=$(systemctl show "$SERVICE_NAME" --property=ActiveEnterTimestamp --value)
    print_status "info" "服务启动时间: $start_time"
    
    return 0
}

# 检查配置
check_config() {
    print_separator
    print_status "info" "配置检查"
    print_separator
    
    if [[ ! -f "$CONFIG_FILE" ]]; then
        print_status "error" "配置文件不存在: $CONFIG_FILE"
        return 1
    fi
    
    print_status "success" "配置文件存在"
    
    # 检查关键配置
    local port=$(grep "^PORT=" "$CONFIG_FILE" | cut -d'=' -f2 2>/dev/null)
    local api_key=$(grep "^API_KEY=" "$CONFIG_FILE" | cut -d'=' -f2 2>/dev/null)
    local stats=$(grep "^ENABLE_STATS=" "$CONFIG_FILE" | cut -d'=' -f2 2>/dev/null)
    
    print_status "info" "配置信息:"
    echo "  端口: ${port:-未设置}"
    echo "  API密钥: ${api_key:+已设置}"
    echo "  统计功能: ${stats:-未设置}"
    
    # 验证端口
    if [[ -n "$port" ]]; then
        if [[ "$port" =~ ^[0-9]+$ ]] && [ "$port" -ge 1 ] && [ "$port" -le 65535 ]; then
            print_status "success" "端口配置有效"
        else
            print_status "error" "端口配置无效: $port"
            return 1
        fi
    else
        print_status "error" "端口未配置"
        return 1
    fi
    
    return 0
}

# 检查网络
check_network() {
    print_separator
    print_status "info" "网络检查"
    print_separator
    
    local port=$(grep "^PORT=" "$CONFIG_FILE" | cut -d'=' -f2 2>/dev/null)
    
    if [[ -z "$port" ]]; then
        print_status "error" "无法获取端口配置"
        return 1
    fi
    
    # 检查端口监听
    local listening=false
    if command -v ss &> /dev/null; then
        if ss -tuln | grep -q ":$port "; then
            listening=true
            print_status "success" "端口 $port 正在监听"
            ss -tuln | grep ":$port"
        fi
    elif command -v netstat &> /dev/null; then
        if netstat -tuln | grep -q ":$port "; then
            listening=true
            print_status "success" "端口 $port 正在监听"
            netstat -tuln | grep ":$port"
        fi
    fi
    
    if [[ "$listening" != "true" ]]; then
        print_status "error" "端口 $port 未监听"
        return 1
    fi
    
    # 检查API响应
    print_status "info" "测试API响应..."
    local response=$(curl -s -w "%{http_code}" -o /dev/null --connect-timeout 5 "http://localhost:$port/health" 2>/dev/null)
    
    if [[ "$response" == "200" ]]; then
        print_status "success" "API响应正常"
    else
        print_status "error" "API响应异常 (HTTP: $response)"
        return 1
    fi
    
    return 0
}

# 检查日志
check_logs() {
    print_separator
    print_status "info" "日志检查"
    print_separator
    
    if [[ -f "$LOG_FILE" ]]; then
        print_status "info" "最近的错误日志:"
        grep -i "error\|exception\|failed" "$LOG_FILE" | tail -5
    else
        print_status "info" "系统日志中的错误:"
        journalctl -u "$SERVICE_NAME" --no-pager | grep -i "error\|exception\|failed" | tail -5
    fi
}

# 自动修复
auto_fix() {
    print_separator
    print_status "info" "尝试自动修复"
    print_separator
    
    # 重启服务
    print_status "info" "重启服务..."
    if systemctl restart "$SERVICE_NAME"; then
        print_status "success" "服务重启成功"
        sleep 3
        
        # 再次检查
        if systemctl is-active --quiet "$SERVICE_NAME"; then
            print_status "success" "服务运行正常"
            return 0
        else
            print_status "error" "服务重启后仍未运行"
            return 1
        fi
    else
        print_status "error" "服务重启失败"
        return 1
    fi
}

# 主函数
main() {
    echo -e "${BLUE}CIAO-CORS 服务诊断工具${NC}"
    print_separator
    
    local issues=0
    
    # 执行检查
    check_system
    
    if ! check_service; then
        issues=$((issues + 1))
    fi
    
    if ! check_config; then
        issues=$((issues + 1))
    fi
    
    if ! check_network; then
        issues=$((issues + 1))
    fi
    
    check_logs
    
    # 总结
    print_separator
    if [[ $issues -eq 0 ]]; then
        print_status "success" "所有检查通过，服务运行正常"
    else
        print_status "warning" "发现 $issues 个问题"
        
        read -p "是否尝试自动修复? (y/N): " auto_fix_choice
        if [[ "$auto_fix_choice" =~ ^[Yy]$ ]]; then
            auto_fix
        fi
    fi
    
    print_separator
    print_status "info" "诊断完成"
}

# 检查权限
if [[ $EUID -ne 0 ]]; then
    print_status "error" "此脚本需要root权限运行，请使用 sudo"
    exit 1
fi

# 运行诊断
main "$@"
