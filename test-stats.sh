#!/bin/bash

# CIAO-CORS 统计功能测试脚本
# 用于快速测试和验证统计功能是否正常工作

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 配置文件路径
CONFIG_FILE="/etc/ciao-cors/config.env"

# 显示彩色输出
print_status() {
    local type=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    case $type in
        "info")    echo -e "${BLUE}[INFO]${NC} [$timestamp] $message" ;;
        "success") echo -e "${GREEN}[SUCCESS]${NC} [$timestamp] $message" ;;
        "warning") echo -e "${YELLOW}[WARNING]${NC} [$timestamp] $message" ;;
        "error")   echo -e "${RED}[ERROR]${NC} [$timestamp] $message" ;;
    esac
}

# 显示分割线
print_separator() {
    echo -e "${BLUE}=====================================================${NC}"
}

# 主函数
main() {
    clear
    print_separator
    echo -e "${BLUE}🧪 CIAO-CORS 统计功能测试工具 v1.2.0${NC}"
    echo -e "${BLUE}📦 项目地址: https://github.com/bestZwei/ciao-cors${NC}"
    print_separator
    echo
    
    # 检查配置文件
    if [[ ! -f "$CONFIG_FILE" ]]; then
        print_status "error" "配置文件不存在: $CONFIG_FILE"
        print_status "info" "请先运行部署脚本安装服务"
        exit 1
    fi
    
    # 读取配置
    local port=$(grep "^PORT=" "$CONFIG_FILE" | cut -d'=' -f2 2>/dev/null)
    local api_key=$(grep "^API_KEY=" "$CONFIG_FILE" | cut -d'=' -f2 2>/dev/null)
    local enable_stats=$(grep "^ENABLE_STATS=" "$CONFIG_FILE" | cut -d'=' -f2 2>/dev/null)
    
    print_status "info" "当前配置:"
    echo "  端口: ${port:-未设置}"
    echo "  API密钥: $([ -n "$api_key" ] && echo "已设置" || echo "未设置")"
    echo "  统计功能: ${enable_stats:-未设置}"
    echo
    
    # 检查统计功能是否启用
    if [[ "$enable_stats" != "true" ]]; then
        print_status "warning" "统计功能未启用"
        echo "请运行以下命令启用统计功能:"
        echo "  sudo sed -i 's/^ENABLE_STATS=.*/ENABLE_STATS=true/' $CONFIG_FILE"
        echo "  sudo systemctl restart ciao-cors"
        exit 1
    fi
    
    # 检查服务状态
    if ! systemctl is-active --quiet ciao-cors; then
        print_status "error" "CIAO-CORS服务未运行"
        echo "请运行以下命令启动服务:"
        echo "  sudo systemctl start ciao-cors"
        exit 1
    fi
    
    print_status "success" "服务运行正常，开始测试..."
    echo
    
    # 获取初始统计数据
    print_status "info" "获取初始统计数据..."
    local stats_url="http://localhost:$port/_api/stats"
    if [[ -n "$api_key" ]]; then
        stats_url="${stats_url}?key=$api_key"
    fi
    
    local initial_stats=$(curl -s --connect-timeout 5 "$stats_url" 2>/dev/null)
    local initial_requests=0
    
    if [[ $? -eq 0 ]] && [[ -n "$initial_stats" ]]; then
        if command -v jq &> /dev/null; then
            initial_requests=$(echo "$initial_stats" | jq -r '.stats.totalRequests // 0')
        elif command -v python3 &> /dev/null; then
            initial_requests=$(echo "$initial_stats" | python3 -c "import sys,json; data=json.load(sys.stdin); print(data.get('stats',{}).get('totalRequests',0))" 2>/dev/null || echo "0")
        fi
        print_status "success" "初始请求数: $initial_requests"
    else
        print_status "warning" "无法获取初始统计数据，继续测试..."
    fi
    
    # 发送测试请求
    echo
    print_status "info" "发送测试请求..."
    local test_urls=("httpbin.org/get" "httpbin.org/ip" "httpbin.org/user-agent" "httpbin.org/headers")
    local success_count=0
    local total_tests=${#test_urls[@]}
    
    for i in "${!test_urls[@]}"; do
        local url="${test_urls[$i]}"
        print_status "info" "测试 $((i+1))/$total_tests: $url"
        
        local response=$(curl -s -w "%{http_code}" -o /dev/null --connect-timeout 10 --max-time 30 "http://localhost:$port/$url" 2>/dev/null)
        
        if [[ "$response" == "200" ]]; then
            print_status "success" "✅ 请求成功 (HTTP: $response)"
            success_count=$((success_count + 1))
        else
            print_status "warning" "❌ 请求失败 (HTTP: $response)"
        fi
        
        # 短暂延迟
        sleep 1
    done
    
    echo
    print_status "info" "等待统计数据更新..."
    sleep 3
    
    # 获取更新后的统计数据
    print_status "info" "获取更新后的统计数据..."
    local final_stats=$(curl -s --connect-timeout 5 "$stats_url" 2>/dev/null)
    
    if [[ $? -eq 0 ]] && [[ -n "$final_stats" ]]; then
        echo
        print_separator
        print_status "success" "📊 统计数据获取成功！"
        print_separator
        
        if command -v jq &> /dev/null; then
            local final_requests=$(echo "$final_stats" | jq -r '.stats.totalRequests // 0')
            local successful_requests=$(echo "$final_stats" | jq -r '.stats.successfulRequests // 0')
            local failed_requests=$(echo "$final_stats" | jq -r '.stats.failedRequests // 0')
            local avg_response_time=$(echo "$final_stats" | jq -r '.stats.averageResponseTime // 0')
            
            echo "📈 统计摘要:"
            echo "  总请求数: $final_requests (增加: $((final_requests - initial_requests)))"
            echo "  成功请求数: $successful_requests"
            echo "  失败请求数: $failed_requests"
            echo "  平均响应时间: ${avg_response_time}ms"
            echo
            
            echo "🌐 热门域名:"
            echo "$final_stats" | jq -r '.stats.topDomains | to_entries[] | "  \(.key): \(.value) 次"' 2>/dev/null || echo "  无数据"
            
        elif command -v python3 &> /dev/null; then
            local final_requests=$(echo "$final_stats" | python3 -c "import sys,json; data=json.load(sys.stdin); print(data.get('stats',{}).get('totalRequests',0))" 2>/dev/null || echo "0")
            
            echo "📈 统计摘要:"
            echo "  总请求数: $final_requests (增加: $((final_requests - initial_requests)))"
            echo "  成功请求数: $(echo "$final_stats" | python3 -c "import sys,json; data=json.load(sys.stdin); print(data.get('stats',{}).get('successfulRequests',0))" 2>/dev/null || echo "0")"
            echo "  失败请求数: $(echo "$final_stats" | python3 -c "import sys,json; data=json.load(sys.stdin); print(data.get('stats',{}).get('failedRequests',0))" 2>/dev/null || echo "0")"
        else
            echo "📊 原始统计数据:"
            echo "$final_stats"
        fi
        
        print_separator
        
        # 测试结果评估
        if [[ $success_count -eq $total_tests ]]; then
            print_status "success" "🎉 所有测试通过！统计功能工作正常"
        elif [[ $success_count -gt 0 ]]; then
            print_status "warning" "⚠️ 部分测试通过 ($success_count/$total_tests)，统计功能基本正常"
        else
            print_status "error" "❌ 所有测试失败，请检查网络连接和服务配置"
        fi
        
        echo
        print_status "info" "💡 提示:"
        echo "  - 可以通过管理API查看详细统计: $stats_url"
        echo "  - 统计数据会实时更新，反映所有代理请求"
        echo "  - 如需重置统计数据，访问: http://localhost:$port/_api/reset-stats$([ -n "$api_key" ] && echo "?key=$api_key")"
        
    else
        print_status "error" "无法获取统计数据"
        echo
        print_status "info" "可能的原因:"
        echo "  1. API密钥不正确"
        echo "  2. 统计功能未正确启用"
        echo "  3. 服务内部错误"
        echo "  4. 网络连接问题"
        
        echo
        print_status "info" "调试信息:"
        echo "  统计API URL: $stats_url"
        echo "  服务状态: $(systemctl is-active ciao-cors)"
        echo "  端口监听: $(ss -tlnp 2>/dev/null | grep ":$port " | head -1 || echo "未监听")"
    fi
    
    echo
    print_separator
    print_status "info" "测试完成"
    print_separator
}

# 运行主函数
main "$@"
