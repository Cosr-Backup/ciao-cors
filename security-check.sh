#!/bin/bash

# CIAO-CORS 安全配置检查脚本
# 用于验证服务的安全配置和检测潜在的安全问题

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 配置
SERVICE_NAME="ciao-cors"
CONFIG_FILE="/etc/ciao-cors/config.env"
INSTALL_DIR="/opt/ciao-cors"

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

# 检查配置文件安全性
check_config_security() {
    print_separator
    print_status "info" "检查配置文件安全性"
    print_separator

    if [[ ! -f "$CONFIG_FILE" ]]; then
        print_status "error" "配置文件不存在: $CONFIG_FILE"
        return 1
    fi

    # 检查文件权限
    local file_perms=$(stat -c "%a" "$CONFIG_FILE" 2>/dev/null)
    if [[ "$file_perms" == "600" ]]; then
        print_status "success" "配置文件权限正确 (600)"
    elif [[ "$file_perms" == "644" ]]; then
        print_status "warning" "配置文件权限过于宽松 ($file_perms)，建议设置为600"
    else
        print_status "error" "配置文件权限不安全 ($file_perms)，必须设置为600"
    fi

    # 检查文件所有者
    local file_owner=$(stat -c "%U:%G" "$CONFIG_FILE" 2>/dev/null)
    if [[ "$file_owner" == "root:root" ]]; then
        print_status "success" "配置文件所有者正确 (root:root)"
    else
        print_status "warning" "配置文件所有者不是root:root ($file_owner)"
    fi

    # 检查API密钥强度
    local api_key=$(grep "^API_KEY=" "$CONFIG_FILE" | cut -d'=' -f2 2>/dev/null)
    if [[ -n "$api_key" ]]; then
        if [[ ${#api_key} -ge 32 ]]; then
            print_status "success" "API密钥长度充足 (${#api_key} 字符)"
        elif [[ ${#api_key} -ge 16 ]]; then
            print_status "warning" "API密钥长度一般 (${#api_key} 字符)，建议使用32字符以上"
        else
            print_status "error" "API密钥过短 (${#api_key} 字符)，存在严重安全风险"
        fi

        # 检查密钥复杂度
        local has_upper=$(echo "$api_key" | grep -q '[A-Z]' && echo "yes" || echo "no")
        local has_lower=$(echo "$api_key" | grep -q '[a-z]' && echo "yes" || echo "no")
        local has_digit=$(echo "$api_key" | grep -q '[0-9]' && echo "yes" || echo "no")
        local has_special=$(echo "$api_key" | grep -q '[^A-Za-z0-9]' && echo "yes" || echo "no")

        local complexity_score=0
        [[ "$has_upper" == "yes" ]] && ((complexity_score++))
        [[ "$has_lower" == "yes" ]] && ((complexity_score++))
        [[ "$has_digit" == "yes" ]] && ((complexity_score++))
        [[ "$has_special" == "yes" ]] && ((complexity_score++))

        if [[ $complexity_score -ge 3 ]]; then
            print_status "success" "API密钥复杂度良好"
        elif [[ $complexity_score -ge 2 ]]; then
            print_status "warning" "API密钥复杂度一般，建议包含大小写字母、数字和特殊字符"
        else
            print_status "error" "API密钥复杂度不足，存在安全风险"
        fi

        # 检查是否为常见弱密钥
        local weak_keys=("password" "123456" "admin" "test" "demo" "secret" "key")
        for weak_key in "${weak_keys[@]}"; do
            if [[ "$api_key" == *"$weak_key"* ]]; then
                print_status "error" "API密钥包含常见弱密码模式: $weak_key"
                break
            fi
        done
    else
        print_status "error" "未设置API密钥，管理API完全开放，存在严重安全风险"
    fi
    
    # 检查限流配置
    local rate_limit=$(grep "^RATE_LIMIT=" "$CONFIG_FILE" | cut -d'=' -f2 2>/dev/null)
    local concurrent_limit=$(grep "^CONCURRENT_LIMIT=" "$CONFIG_FILE" | cut -d'=' -f2 2>/dev/null)
    local total_concurrent_limit=$(grep "^TOTAL_CONCURRENT_LIMIT=" "$CONFIG_FILE" | cut -d'=' -f2 2>/dev/null)

    if [[ -n "$rate_limit" ]] && [[ "$rate_limit" -gt 0 ]]; then
        if [[ "$rate_limit" -le 5000 ]]; then
            print_status "success" "请求频率限制合理 ($rate_limit/分钟)"
        else
            print_status "warning" "请求频率限制较高 ($rate_limit/分钟)，可能存在滥用风险"
        fi
    else
        print_status "error" "未设置请求频率限制，存在DoS攻击风险"
    fi

    if [[ -n "$concurrent_limit" ]] && [[ "$concurrent_limit" -gt 0 ]]; then
        if [[ "$concurrent_limit" -le 100 ]]; then
            print_status "success" "单IP并发限制合理 ($concurrent_limit)"
        else
            print_status "warning" "单IP并发限制较高 ($concurrent_limit)，可能影响系统稳定性"
        fi
    else
        print_status "error" "未设置单IP并发限制，存在资源耗尽风险"
    fi

    if [[ -n "$total_concurrent_limit" ]] && [[ "$total_concurrent_limit" -gt 0 ]]; then
        if [[ "$total_concurrent_limit" -le 2000 ]]; then
            print_status "success" "总并发限制合理 ($total_concurrent_limit)"
        else
            print_status "warning" "总并发限制较高 ($total_concurrent_limit)，可能影响系统稳定性"
        fi
    else
        print_status "warning" "未设置总并发限制"
    fi

    # 检查访问控制配置
    local blocked_ips=$(grep "^BLOCKED_IPS=" "$CONFIG_FILE" 2>/dev/null)
    local allowed_domains=$(grep "^ALLOWED_DOMAINS=" "$CONFIG_FILE" 2>/dev/null)
    local blocked_domains=$(grep "^BLOCKED_DOMAINS=" "$CONFIG_FILE" 2>/dev/null)
    local allowed_origins=$(grep "^ALLOWED_ORIGINS=" "$CONFIG_FILE" 2>/dev/null)

    local access_control_count=0
    [[ -n "$blocked_ips" ]] && ((access_control_count++))
    [[ -n "$allowed_domains" ]] && ((access_control_count++))
    [[ -n "$blocked_domains" ]] && ((access_control_count++))
    [[ -n "$allowed_origins" ]] && ((access_control_count++))

    if [[ $access_control_count -eq 0 ]]; then
        print_status "warning" "未配置任何访问控制，建议设置域名白名单或IP黑名单"
    elif [[ $access_control_count -ge 2 ]]; then
        print_status "success" "已配置多层访问控制"
    else
        print_status "info" "已配置基础访问控制"
    fi
}

# 检查服务安全性
check_service_security() {
    print_separator
    print_status "info" "检查服务安全性"
    print_separator
    
    # 检查服务是否以root运行
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        local service_user=$(systemctl show "$SERVICE_NAME" --property=User --value)
        if [[ "$service_user" == "root" ]]; then
            print_status "warning" "服务以root用户运行，建议创建专用用户"
        else
            print_status "success" "服务以非root用户运行 ($service_user)"
        fi
    fi
    
    # 检查systemd安全配置
    local service_file="/etc/systemd/system/${SERVICE_NAME}.service"
    if [[ -f "$service_file" ]]; then
        print_status "info" "检查systemd安全配置..."
        
        local security_features=(
            "NoNewPrivileges=true"
            "ProtectSystem=strict"
            "ProtectHome=true"
            "PrivateTmp=true"
            "RestrictSUIDSGID=true"
        )
        
        for feature in "${security_features[@]}"; do
            if grep -q "$feature" "$service_file"; then
                print_status "success" "✓ $feature"
            else
                print_status "warning" "✗ $feature (未启用)"
            fi
        done
    fi
}

# 检查网络安全
check_network_security() {
    print_separator
    print_status "info" "检查网络安全"
    print_separator
    
    local port=$(grep "^PORT=" "$CONFIG_FILE" | cut -d'=' -f2 2>/dev/null)
    
    if [[ -n "$port" ]]; then
        # 检查端口是否只监听本地
        if command -v ss &> /dev/null; then
            local listen_info=$(ss -tuln | grep ":$port ")
            if echo "$listen_info" | grep -q "127.0.0.1:$port"; then
                print_status "info" "服务只监听本地地址"
            elif echo "$listen_info" | grep -q "0.0.0.0:$port"; then
                print_status "warning" "服务监听所有地址，确保防火墙已正确配置"
            fi
        fi
        
        # 检查防火墙状态
        if command -v firewall-cmd &> /dev/null && systemctl is-active --quiet firewalld; then
            if firewall-cmd --query-port="$port/tcp" &> /dev/null; then
                print_status "success" "防火墙已开放端口 $port"
            else
                print_status "warning" "防火墙未开放端口 $port"
            fi
        elif command -v ufw &> /dev/null; then
            if ufw status | grep -q "$port"; then
                print_status "success" "UFW已配置端口 $port"
            else
                print_status "warning" "UFW未配置端口 $port"
            fi
        else
            print_status "warning" "未检测到防火墙配置"
        fi
    fi
}

# 检查文件系统安全
check_filesystem_security() {
    print_separator
    print_status "info" "检查文件系统安全"
    print_separator
    
    # 检查安装目录权限
    if [[ -d "$INSTALL_DIR" ]]; then
        local dir_perms=$(stat -c "%a" "$INSTALL_DIR" 2>/dev/null)
        local dir_owner=$(stat -c "%U" "$INSTALL_DIR" 2>/dev/null)
        
        print_status "info" "安装目录权限: $dir_perms (所有者: $dir_owner)"
        
        if [[ "$dir_perms" =~ ^7[0-5][0-5]$ ]]; then
            print_status "success" "安装目录权限安全"
        else
            print_status "warning" "安装目录权限可能过于宽松"
        fi
    fi
    
    # 检查关键文件权限
    if [[ -f "$INSTALL_DIR/server.ts" ]]; then
        local file_perms=$(stat -c "%a" "$INSTALL_DIR/server.ts" 2>/dev/null)
        if [[ "$file_perms" =~ ^[67][0-5][0-5]$ ]]; then
            print_status "success" "服务文件权限安全"
        else
            print_status "warning" "服务文件权限可能不安全 ($file_perms)"
        fi
    fi
}

# 生成安全建议
generate_security_recommendations() {
    print_separator
    print_status "info" "安全建议"
    print_separator
    
    echo "1. 定期更新系统和Deno运行时"
    echo "2. 使用强密码作为API密钥，定期轮换"
    echo "3. 配置适当的请求频率和并发限制"
    echo "4. 启用日志记录并定期检查异常活动"
    echo "5. 使用HTTPS代理或在反向代理后运行"
    echo "6. 定期备份配置文件"
    echo "7. 监控系统资源使用情况"
    echo "8. 考虑使用专用用户运行服务"
    echo "9. 配置适当的防火墙规则"
    echo "10. 定期检查服务日志中的异常请求"
}

# 主函数
main() {
    echo -e "${BLUE}CIAO-CORS 安全配置检查工具${NC}"
    print_separator
    
    # 检查权限
    if [[ $EUID -ne 0 ]]; then
        print_status "warning" "建议以root权限运行以获得完整的检查结果"
    fi
    
    local issues=0
    
    # 执行各项检查
    if ! check_config_security; then
        issues=$((issues + 1))
    fi
    
    if ! check_service_security; then
        issues=$((issues + 1))
    fi
    
    check_network_security
    check_filesystem_security
    
    # 总结
    print_separator
    if [[ $issues -eq 0 ]]; then
        print_status "success" "安全检查完成，未发现严重问题"
    else
        print_status "warning" "发现 $issues 个需要关注的安全问题"
    fi
    
    generate_security_recommendations
    
    print_separator
    print_status "info" "安全检查完成"
}

# 运行检查
main "$@"
