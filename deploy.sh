#!/bin/bash

# CIAO-CORS 一键部署和管理脚本
# 支持安装、配置、监控、更新、卸载等完整功能
# 版本: 1.1.0
# 作者: bestZwei
# 项目: https://github.com/bestZwei/ciao-cors

# ==================== 全局变量 ====================
SCRIPT_VERSION="1.1.0"
PROJECT_NAME="ciao-cors"
DEFAULT_PORT=3000
INSTALL_DIR="/opt/ciao-cors"
SERVICE_NAME="ciao-cors"
CONFIG_FILE="/etc/ciao-cors/config.env"
LOG_FILE="/var/log/ciao-cors.log"
GITHUB_REPO="https://raw.githubusercontent.com/bestZwei/ciao-cors/main"
SYSTEMD_SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# ==================== 基础功能函数 ====================

# 显示彩色输出
print_status() {
    local type=$1
    local message=$2
    case $type in
        "info")    echo -e "${BLUE}[INFO]${NC} $message" ;;
        "success") echo -e "${GREEN}[SUCCESS]${NC} $message" ;;
        "warning") echo -e "${YELLOW}[WARNING]${NC} $message" ;;
        "error")   echo -e "${RED}[ERROR]${NC} $message" ;;
        "title")   echo -e "${PURPLE}$message${NC}" ;;
        "cyan")    echo -e "${CYAN}$message${NC}" ;;
    esac
}

# 显示分割线
print_separator() {
    echo -e "${CYAN}=====================================================${NC}"
}

# 检查是否为root用户
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_status "error" "此脚本需要root权限运行，请使用 sudo"
        exit 1
    fi
}

# 检查系统要求
check_requirements() {
  print_status "info" "检查系统要求..."
  
  # 检查Linux发行版
  if [[ -f /etc/os-release ]]; then
    source /etc/os-release
    print_status "info" "检测到操作系统: $NAME $VERSION_ID"
  else
    print_status "warning" "未能识别操作系统类型，将尝试继续安装"
  fi
  
  # 检查基本命令
  local required_commands=("curl" "wget" "systemctl" "firewall-cmd")
  for cmd in "${required_commands[@]}"; do
      if ! command -v "$cmd" &> /dev/null; then
          print_status "warning" "命令 $cmd 未找到，尝试安装..."
          case $cmd in
              "curl"|"wget")
                  if command -v yum &> /dev/null; then
                      yum install -y curl wget
                  elif command -v apt &> /dev/null; then
                      apt update && apt install -y curl wget
                  fi
                  ;;
              "firewall-cmd")
                  if command -v yum &> /dev/null; then
                      yum install -y firewalld
                      systemctl enable firewalld
                      systemctl start firewalld
                  elif command -v apt &> /dev/null; then
                      apt install -y firewalld
                      systemctl enable firewalld
                      systemctl start firewalld
                  fi
                  ;;
          esac
      fi
  done
  
  # 检查磁盘空间
  local free_space=$(df -m / | awk 'NR==2 {print $4}')
  if [[ $free_space -lt 100 ]]; then
    print_status "warning" "可用磁盘空间不足 100MB，这可能导致安装问题"
    read -p "是否继续? (y/N): " continue_install
    if [[ ! "$continue_install" =~ ^[Yy]$ ]]; then
      print_status "error" "安装取消"
      exit 1
    fi
  fi
  
  print_status "success" "系统要求检查完成"
}

# 检查Deno安装状态
check_deno_installation() {
    if command -v deno &> /dev/null; then
        local version=$(deno --version | head -n 1 | awk '{print $2}')
        print_status "success" "Deno已安装 (版本: $version)"
        return 0
    else
        print_status "warning" "Deno未安装"
        return 1
    fi
}

# ==================== 安装和配置函数 ====================

# 安装Deno
install_deno() {
  print_status "info" "开始安装Deno..."
  
  # 备份失败处理
  local install_failed=0
  
  # 检查依赖
  local deps=("curl" "unzip")
  for dep in "${deps[@]}"; do
    if ! command -v $dep &> /dev/null; then
      print_status "info" "安装依赖: $dep"
      if command -v apt &> /dev/null; then
        apt update && apt install -y $dep || install_failed=1
      elif command -v yum &> /dev/null; then
        yum install -y $dep || install_failed=1
      fi
      
      if [[ $install_failed -eq 1 ]]; then
        print_status "error" "安装依赖 $dep 失败"
        return 1
      fi
    fi
  done
  
  # 下载并安装Deno
  curl -fsSL https://deno.land/x/install/install.sh | sh
  
  # 添加到PATH
  export DENO_INSTALL="$HOME/.deno"
  export PATH="$DENO_INSTALL/bin:$PATH"
  
  # 创建全局链接
  ln -sf "$HOME/.deno/bin/deno" /usr/local/bin/deno
  
  # 验证安装
  if ! command -v deno &> /dev/null; then
    print_status "error" "Deno安装失败"
    
    # 尝试手动安装
    print_status "info" "尝试手动安装Deno..."
    mkdir -p ~/.deno/bin
    curl -fsSL https://github.com/denoland/deno/releases/latest/download/deno-x86_64-unknown-linux-gnu.zip -o /tmp/deno.zip
    unzip -o /tmp/deno.zip -d ~/.deno/bin
    chmod +x ~/.deno/bin/deno
    ln -sf ~/.deno/bin/deno /usr/local/bin/deno
    
    if ! command -v deno &> /dev/null; then
      print_status "error" "手动安装仍然失败，请参考 https://deno.land/#installation 手动安装"
      return 1
    else
      print_status "success" "手动安装成功"
    fi
  fi
  
  if command -v deno &> /dev/null; then
      local version=$(deno --version | head -n 1 | awk '{print $2}')
      print_status "success" "Deno安装成功 (版本: $version)"
      return 0
  else
      print_status "error" "Deno安装失败"
      return 1
  fi
}

# 下载或更新项目文件
download_project() {
    print_status "info" "下载项目文件..."
    
    # 创建安装目录
    mkdir -p "$INSTALL_DIR"
    cd "$INSTALL_DIR"
    
    # 下载主文件
    if curl -fsSL "$GITHUB_REPO/server.ts" -o server.ts; then
        print_status "success" "项目文件下载成功"
        chmod +x server.ts
        return 0
    else
        print_status "error" "项目文件下载失败"
        return 1
    fi
}

# 创建配置文件
create_config() {
    print_status "info" "创建配置文件..."
    
    # 创建配置目录
    mkdir -p "$(dirname "$CONFIG_FILE")"
    
    # 交互式配置
    echo
    print_status "title" "=== 服务配置 ==="
    
    # 端口配置
    read -p "请输入服务端口 [默认: $DEFAULT_PORT]: " port
    port=${port:-$DEFAULT_PORT}
    
    # 验证端口
    if ! [[ "$port" =~ ^[0-9]+$ ]] || [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
        print_status "error" "无效的端口号"
        return 1
    fi
    
    # 检查端口占用
    if netstat -tuln | grep -q ":$port "; then
        print_status "warning" "端口 $port 已被占用"
        read -p "是否继续使用此端口? (y/N): " continue_port
        if [[ ! "$continue_port" =~ ^[Yy]$ ]]; then
            return 1
        fi
    fi
    
    # API密钥配置
    read -p "是否设置API密钥? (y/N): " set_api_key
    api_key=""
    if [[ "$set_api_key" =~ ^[Yy]$ ]]; then
        read -s -p "请输入API密钥: " api_key
        echo
    fi
    
    # 统计功能
    read -p "是否启用统计功能? (Y/n): " enable_stats
    enable_stats=${enable_stats:-Y}
    if [[ "$enable_stats" =~ ^[Yy]$ ]]; then
        enable_stats="true"
    else
        enable_stats="false"
    fi
    
    # 限流配置
    read -p "请输入请求频率限制 (每分钟) [默认: 60]: " rate_limit
    rate_limit=${rate_limit:-60}
    
    read -p "请输入单IP并发限制 [默认: 10]: " concurrent_limit
    concurrent_limit=${concurrent_limit:-10}
    
    read -p "请输入总并发限制 [默认: 1000]: " total_concurrent_limit
    total_concurrent_limit=${total_concurrent_limit:-1000}
    
    # 安全配置
    echo
    print_status "info" "安全配置 (可选，直接回车跳过)"
    read -p "禁止的IP地址 (逗号分隔): " blocked_ips
    read -p "禁止的域名 (逗号分隔): " blocked_domains
    read -p "允许的域名 (逗号分隔，留空表示允许所有): " allowed_domains
    
    # 生成配置文件
    cat > "$CONFIG_FILE" << EOF
# CIAO-CORS 服务配置
# 生成时间: $(date)

# 基础配置
PORT=$port
ENABLE_STATS=$enable_stats
ENABLE_LOGGING=true

# 限流配置
RATE_LIMIT=$rate_limit
RATE_LIMIT_WINDOW=60000
CONCURRENT_LIMIT=$concurrent_limit
TOTAL_CONCURRENT_LIMIT=$total_concurrent_limit

# 性能配置
MAX_URL_LENGTH=2048
TIMEOUT=30000

EOF
    
    # 添加可选配置
    if [[ -n "$api_key" ]]; then
        echo "API_KEY=$api_key" >> "$CONFIG_FILE"
    fi
    
    if [[ -n "$blocked_ips" ]]; then
        echo "BLOCKED_IPS=[\"$(echo "$blocked_ips" | sed 's/,/","/g')\"]" >> "$CONFIG_FILE"
    fi
    
    if [[ -n "$blocked_domains" ]]; then
        echo "BLOCKED_DOMAINS=[\"$(echo "$blocked_domains" | sed 's/,/","/g')\"]" >> "$CONFIG_FILE"
    fi
    
    if [[ -n "$allowed_domains" ]]; then
        echo "ALLOWED_DOMAINS=[\"$(echo "$allowed_domains" | sed 's/,/","/g')\"]" >> "$CONFIG_FILE"
    fi
    
    chmod 600 "$CONFIG_FILE"
    print_status "success" "配置文件创建成功: $CONFIG_FILE"
    return 0
}

# 配置防火墙
configure_firewall() {
    local port=$1
    print_status "info" "配置防火墙..."
    
    # 检查防火墙状态
    if ! systemctl is-active --quiet firewalld; then
        print_status "warning" "防火墙未运行，尝试启动..."
        systemctl start firewalld
        if [ $? -ne 0 ]; then
            print_status "warning" "无法启动防火墙，跳过防火墙配置"
            return 0
        fi
    fi
    
    # 检查端口是否已开放
    if firewall-cmd --query-port="$port/tcp" &> /dev/null; then
        print_status "info" "端口 $port 已开放"
        return 0
    fi
    
    # 开放端口
    if firewall-cmd --permanent --add-port="$port/tcp" && firewall-cmd --reload; then
        print_status "success" "防火墙端口 $port 配置成功"
        return 0
    else
        print_status "error" "防火墙配置失败"
        return 1
    fi
}

# 创建系统服务
create_systemd_service() {
    print_status "info" "创建系统服务..."
    
    # 读取端口配置
    local port=$(grep "^PORT=" "$CONFIG_FILE" | cut -d'=' -f2)
    
    cat > "$SYSTEMD_SERVICE_FILE" << EOF
[Unit]
Description=CIAO-CORS Proxy Server
After=network.target
Wants=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$INSTALL_DIR
Environment=DENO_INSTALL=/root/.deno
Environment=PATH=/root/.deno/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
EnvironmentFile=$CONFIG_FILE
ExecStart=/usr/local/bin/deno run --allow-net --allow-env server.ts
Restart=always
RestartSec=10
StandardOutput=append:$LOG_FILE
StandardError=append:$LOG_FILE

# 安全配置
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=$INSTALL_DIR
ReadWritePaths=/var/log

[Install]
WantedBy=multi-user.target
EOF
    
    # 重载systemd并启用服务
    systemctl daemon-reload
    systemctl enable "$SERVICE_NAME"
    
    print_status "success" "系统服务创建成功"
    return 0
}

# ==================== 服务管理函数 ====================

# 启动服务
start_service() {
    print_status "info" "启动服务..."
    
    if systemctl start "$SERVICE_NAME"; then
        sleep 3
        if systemctl is-active --quiet "$SERVICE_NAME"; then
            print_status "success" "服务启动成功"
            show_service_info
            return 0
        else
            print_status "error" "服务启动失败"
            view_logs
            return 1
        fi
    else
        print_status "error" "无法启动服务"
        return 1
    fi
}

# 停止服务
stop_service() {
    print_status "info" "停止服务..."
    
    if systemctl stop "$SERVICE_NAME"; then
        print_status "success" "服务已停止"
        return 0
    else
        print_status "error" "停止服务失败"
        return 1
    fi
}

# 重启服务
restart_service() {
    print_status "info" "重启服务..."
    
    if systemctl restart "$SERVICE_NAME"; then
        sleep 3
        if systemctl is-active --quiet "$SERVICE_NAME"; then
            print_status "success" "服务重启成功"
            show_service_info
            return 0
        else
            print_status "error" "服务重启失败"
            view_logs
            return 1
        fi
    else
        print_status "error" "无法重启服务"
        return 1
    fi
}

# 查看服务状态
service_status() {
    print_status "info" "服务状态信息"
    echo
    
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        print_status "success" "服务状态: 运行中"
    else
        print_status "error" "服务状态: 已停止"
    fi
    
    if systemctl is-enabled --quiet "$SERVICE_NAME"; then
        print_status "info" "开机启动: 已启用"
    else
        print_status "warning" "开机启动: 未启用"
    fi
    
    echo
    systemctl status "$SERVICE_NAME" --no-pager -l
}

# 显示服务信息
show_service_info() {
    if [[ -f "$CONFIG_FILE" ]]; then
        local port=$(grep "^PORT=" "$CONFIG_FILE" | cut -d'=' -f2)
        local external_ip=$(curl -s ip.sb 2>/dev/null || echo "unknown")
        
        echo
        print_separator
        print_status "title" "🎉 CIAO-CORS 服务信息"
        print_separator
        print_status "info" "本地访问: http://localhost:$port"
        print_status "info" "外部访问: http://$external_ip:$port"
        print_status "info" "健康检查: http://$external_ip:$port/_api/health"
        print_status "info" "配置文件: $CONFIG_FILE"
        print_status "info" "日志文件: $LOG_FILE"
        print_separator
        echo
    fi
}

# 查看服务日志
view_logs() {
  echo
  print_status "info" "最近的日志信息:"
  echo
  
  # 添加日志过滤选项
  echo "1) 全部日志"
  echo "2) 只显示错误日志"
  echo "3) 按状态码过滤 (例如 404, 500)"
  echo "4) 按IP地址过滤"
  echo "5) 返回"
  
  read -p "请选择 [1-5]: " log_filter
  
  case $log_filter in
    1)
      if [[ -f "$LOG_FILE" ]]; then
        tail -n 100 "$LOG_FILE"
      else
        journalctl -u "$SERVICE_NAME" -n 100 --no-pager
      fi
      ;;
    2)
      if [[ -f "$LOG_FILE" ]]; then
        grep -i "error\|exception\|failed" "$LOG_FILE" | tail -n 50
      else
        journalctl -u "$SERVICE_NAME" --no-pager | grep -i "error\|exception\|failed" | tail -n 50
      fi
      ;;
    3)
      read -p "输入状态码: " status_code
      if [[ -f "$LOG_FILE" ]]; then
        grep -i "($status_code)" "$LOG_FILE" | tail -n 50
      else
        journalctl -u "$SERVICE_NAME" --no-pager | grep -i "($status_code)" | tail -n 50
      fi
      ;;
    4)
      read -p "输入IP地址: " ip_addr
      if [[ -f "$LOG_FILE" ]]; then
        grep -i "$ip_addr" "$LOG_FILE" | tail -n 50
      else
        journalctl -u "$SERVICE_NAME" --no-pager | grep -i "$ip_addr" | tail -n 50
      fi
      ;;
    5) return 0 ;;
    *) print_status "error" "无效选择" ;;
  esac
  
  echo
  read -p "按回车键继续..."
}

# ==================== 配置管理函数 ====================

# 修改配置
modify_config() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        print_status "error" "配置文件不存在"
        return 1
    fi
    
    echo
    print_status "title" "=== 修改配置 ==="
    echo
    
    print_status "info" "当前配置:"
    cat "$CONFIG_FILE"
    echo
    
    print_status "warning" "请选择要修改的配置项:"
    echo "1) 端口号"
    echo "2) API密钥"
    echo "3) 统计功能"
    echo "4) 限流配置"
    echo "5) 安全配置"
    echo "6) 直接编辑配置文件"
    echo "0) 返回主菜单"
    echo
    
    read -p "请选择 [0-6]: " choice
    
    case $choice in
        1) modify_port ;;
        2) modify_api_key ;;
        3) modify_stats ;;
        4) modify_rate_limit ;;
        5) modify_security ;;
        6) edit_config_file ;;
        0) return 0 ;;
        *) print_status "error" "无效选择" ;;
    esac
}

# 修改端口
modify_port() {
    local current_port=$(grep "^PORT=" "$CONFIG_FILE" | cut -d'=' -f2)
    echo
    read -p "当前端口: $current_port, 请输入新端口: " new_port
    
    if [[ "$new_port" =~ ^[0-9]+$ ]] && [ "$new_port" -ge 1 ] && [ "$new_port" -le 65535 ]; then
        sed -i "s/^PORT=.*/PORT=$new_port/" "$CONFIG_FILE"
        print_status "success" "端口已更新为: $new_port"
        
        # 配置防火墙
        configure_firewall "$new_port"
        
        print_status "warning" "请重启服务以应用更改"
    else
        print_status "error" "无效的端口号"
    fi
}

# 修改API密钥
modify_api_key() {
    echo
    read -s -p "请输入新的API密钥 (留空删除): " new_key
    echo
    
    if [[ -n "$new_key" ]]; then
        if grep -q "^API_KEY=" "$CONFIG_FILE"; then
            sed -i "s/^API_KEY=.*/API_KEY=$new_key/" "$CONFIG_FILE"
        else
            echo "API_KEY=$new_key" >> "$CONFIG_FILE"
        fi
        print_status "success" "API密钥已更新"
    else
        sed -i '/^API_KEY=/d' "$CONFIG_FILE"
        print_status "success" "API密钥已删除"
    fi
    
    print_status "warning" "请重启服务以应用更改"
}

# 修改统计功能
modify_stats() {
    local current_stats=$(grep "^ENABLE_STATS=" "$CONFIG_FILE" | cut -d'=' -f2)
    echo
    print_status "info" "当前统计功能: $current_stats"
    read -p "启用统计功能? (y/N): " enable_stats
    
    if [[ "$enable_stats" =~ ^[Yy]$ ]]; then
        sed -i "s/^ENABLE_STATS=.*/ENABLE_STATS=true/" "$CONFIG_FILE"
        print_status "success" "统计功能已启用"
    else
        sed -i "s/^ENABLE_STATS=.*/ENABLE_STATS=false/" "$CONFIG_FILE"
        print_status "success" "统计功能已禁用"
    fi
    
    print_status "warning" "请重启服务以应用更改"
}

# 修改限流配置
modify_rate_limit() {
    echo
    print_status "info" "当前限流配置:"
    grep -E "^(RATE_LIMIT|CONCURRENT_LIMIT|TOTAL_CONCURRENT_LIMIT)=" "$CONFIG_FILE"
    echo
    
    read -p "请输入新的请求频率限制 (每分钟): " rate_limit
    read -p "请输入新的单IP并发限制: " concurrent_limit
    read -p "请输入新的总并发限制: " total_concurrent_limit
    
    if [[ "$rate_limit" =~ ^[0-9]+$ ]]; then
        sed -i "s/^RATE_LIMIT=.*/RATE_LIMIT=$rate_limit/" "$CONFIG_FILE"
    fi
    
    if [[ "$concurrent_limit" =~ ^[0-9]+$ ]]; then
        sed -i "s/^CONCURRENT_LIMIT=.*/CONCURRENT_LIMIT=$concurrent_limit/" "$CONFIG_FILE"
    fi
    
    if [[ "$total_concurrent_limit" =~ ^[0-9]+$ ]]; then
        sed -i "s/^TOTAL_CONCURRENT_LIMIT=.*/TOTAL_CONCURRENT_LIMIT=$total_concurrent_limit/" "$CONFIG_FILE"
    fi
    
    print_status "success" "限流配置已更新"
    print_status "warning" "请重启服务以应用更改"
}

# 修改安全配置
modify_security() {
    echo
    print_status "info" "当前安全配置:"
    grep -E "^(BLOCKED_IPS|BLOCKED_DOMAINS|ALLOWED_DOMAINS)=" "$CONFIG_FILE" 2>/dev/null || print_status "info" "无安全配置"
    echo
    
    read -p "禁止的IP地址 (逗号分隔，留空清除): " blocked_ips
    read -p "禁止的域名 (逗号分隔，留空清除): " blocked_domains
    read -p "允许的域名 (逗号分隔，留空清除): " allowed_domains
    
    # 删除旧配置
    sed -i '/^BLOCKED_IPS=/d' "$CONFIG_FILE"
    sed -i '/^BLOCKED_DOMAINS=/d' "$CONFIG_FILE"
    sed -i '/^ALLOWED_DOMAINS=/d' "$CONFIG_FILE"
    
    # 添加新配置
    if [[ -n "$blocked_ips" ]]; then
        echo "BLOCKED_IPS=[\"$(echo "$blocked_ips" | sed 's/,/","/g')\"]" >> "$CONFIG_FILE"
    fi
    
    if [[ -n "$blocked_domains" ]]; then
        echo "BLOCKED_DOMAINS=[\"$(echo "$blocked_domains" | sed 's/,/","/g')\"]" >> "$CONFIG_FILE"
    fi
    
    if [[ -n "$allowed_domains" ]]; then
        echo "ALLOWED_DOMAINS=[\"$(echo "$allowed_domains" | sed 's/,/","/g')\"]" >> "$CONFIG_FILE"
    fi
    
    print_status "success" "安全配置已更新"
    print_status "warning" "请重启服务以应用更改"
}

# 直接编辑配置文件
edit_config_file() {
    if command -v nano &> /dev/null; then
        nano "$CONFIG_FILE"
    elif command -v vim &> /dev/null; then
        vim "$CONFIG_FILE"
    elif command -v vi &> /dev/null; then
        vi "$CONFIG_FILE"
    else
        print_status "error" "未找到文本编辑器"
        return 1
    fi
    
    print_status "warning" "配置文件已编辑，请重启服务以应用更改"
}

# 显示当前配置
show_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        echo
        print_status "info" "当前配置:"
        print_separator
        cat "$CONFIG_FILE"
        print_separator
    else
        print_status "error" "配置文件不存在"
    fi
    
    echo
    read -p "按回车键继续..."
}

# 备份配置
backup_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        local backup_file="${CONFIG_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
        cp "$CONFIG_FILE" "$backup_file"
        print_status "success" "配置已备份到: $backup_file"
    else
        print_status "error" "配置文件不存在"
    fi
}

# ==================== 监控和维护函数 ====================

# 服务健康检查
health_check() {
    print_status "info" "执行健康检查..."
    
    if [[ ! -f "$CONFIG_FILE" ]]; then
        print_status "error" "配置文件不存在"
        return 1
    fi
    
    local port=$(grep "^PORT=" "$CONFIG_FILE" | cut -d'=' -f2)
    local api_key=$(grep "^API_KEY=" "$CONFIG_FILE" | cut -d'=' -f2 2>/dev/null)
    
    # 检查服务状态
    if ! systemctl is-active --quiet "$SERVICE_NAME"; then
        print_status "error" "服务未运行"
        return 1
    fi
    
    # 检查端口监听
    if ! netstat -tuln | grep -q ":$port "; then
        print_status "error" "端口 $port 未监听"
        return 1
    fi
    
    # 检查API响应
    local health_url="http://localhost:$port/_api/health"
    if [[ -n "$api_key" ]]; then
        health_url="${health_url}?key=$api_key"
    fi
    
    local response=$(curl -s -w "%{http_code}" -o /tmp/health_check.json "$health_url" 2>/dev/null)
    
    if [[ "$response" == "200" ]]; then
        print_status "success" "服务健康检查通过"
        if [[ -f /tmp/health_check.json ]]; then
            echo
            print_status "info" "健康检查响应:"
            cat /tmp/health_check.json | python3 -m json.tool 2>/dev/null || cat /tmp/health_check.json
            rm -f /tmp/health_check.json
        fi
        return 0
    else
        print_status "error" "健康检查失败 (HTTP: $response)"
        return 1
    fi
}

# 性能监控
performance_monitor() {
    print_status "info" "性能监控数据"
    echo
    
    # 系统资源
    print_status "title" "=== 系统资源 ==="
    echo "CPU使用率: $(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1"%"}')"
    echo "内存使用: $(free -h | awk 'NR==2{printf "%.1f%% (%s/%s)\n", $3/$2*100, $3, $2}')"
    echo "磁盘使用: $(df -h / | awk 'NR==2{printf "%s (%s)\n", $5, $4}')"
    
    # 服务进程
    echo
    print_status "title" "=== 服务进程 ==="
    ps aux | grep "[d]eno.*server.ts" | head -5
    
    # 网络连接
    echo
    print_status "title" "=== 网络连接 ==="
    if [[ -f "$CONFIG_FILE" ]]; then
        local port=$(grep "^PORT=" "$CONFIG_FILE" | cut -d'=' -f2)
        netstat -tuln | grep ":$port"
        echo "活动连接数: $(netstat -an | grep ":$port" | grep ESTABLISHED | wc -l)"
    fi
    
    # 日志统计
    echo
    print_status "title" "=== 最近请求统计 ==="
    if [[ -f "$LOG_FILE" ]]; then
        echo "最近1小时请求数: $(grep "$(date -d '1 hour ago' '+%Y-%m-%d %H')" "$LOG_FILE" 2>/dev/null | wc -l)"
        echo "最近24小时请求数: $(grep "$(date -d '1 day ago' '+%Y-%m-%d')" "$LOG_FILE" 2>/dev/null | wc -l)"
    fi
    
    echo
    read -p "按回车键继续..."
}

# 更新服务
update_service() {
  print_status "info" "开始更新服务..."
  
  # 备份当前版本
  if [[ -f "$INSTALL_DIR/server.ts" ]]; then
      cp "$INSTALL_DIR/server.ts" "$INSTALL_DIR/server.ts.backup.$(date +%Y%m%d_%H%M%S)"
      print_status "info" "当前版本已备份"
  fi
  
  # 停止服务
  if systemctl is-active --quiet "$SERVICE_NAME"; then
      print_status "info" "停止服务..."
      systemctl stop "$SERVICE_NAME"
  fi
  
  # 下载新版本
  if download_project; then
      print_status "success" "新版本下载成功"
      
      # 重启服务
      if start_service; then
          print_status "success" "服务更新完成"
      else
          print_status "error" "服务启动失败，尝试恢复备份..."
          
          # 恢复备份
          local backup_file=$(ls -t "$INSTALL_DIR"/server.ts.backup.* 2>/dev/null | head -1)
          if [[ -n "$backup_file" ]]; then
              cp "$backup_file" "$INSTALL_DIR/server.ts"
              start_service
              print_status "warning" "已恢复到之前版本"
          fi
      fi
  else
      print_status "error" "更新失败"
      # 尝试启动原服务
      start_service
  fi
}

# 添加系统优化功能
optimize_system() {
  print_status "info" "系统优化..."
  
  echo
  print_status "warning" "请选择要优化的项目:"
  echo "1) 优化系统限制 (文件描述符、最大连接数)"
  echo "2) 优化内核网络参数"
  echo "3) 创建SWAP空间 (如果内存小于2GB)"
  echo "4) 全部优化"
  echo "0) 返回主菜单"
  echo
  
  read -p "请选择 [0-4]: " choice
  
  case $choice in
    1) optimize_system_limits ;;
    2) optimize_network_params ;;
    3) create_swap ;;
    4)
      optimize_system_limits
      optimize_network_params
      create_swap
      ;;
    0) return 0 ;;
    *) print_status "error" "无效选择" ;;
  esac
}

# 优化系统限制
optimize_system_limits() {
  print_status "info" "优化系统限制..."
  
  # 设置文件描述符限制
  if ! grep -q "* soft nofile 65535" /etc/security/limits.conf; then
    echo "* soft nofile 65535" >> /etc/security/limits.conf
    echo "* hard nofile 65535" >> /etc/security/limits.conf
    print_status "success" "文件描述符限制已优化"
  else
    print_status "info" "文件描述符限制已设置"
  fi
  
  # 设置最大进程数
  if ! grep -q "* soft nproc 65535" /etc/security/limits.conf; then
    echo "* soft nproc 65535" >> /etc/security/limits.conf
    echo "* hard nproc 65535" >> /etc/security/limits.conf
    print_status "success" "最大进程数限制已优化"
  else
    print_status "info" "最大进程数限制已设置"
  fi
  
  print_status "info" "系统限制优化完成，重启后生效"
}

# 优化网络参数
optimize_network_params() {
  print_status "info" "优化网络参数..."
  
  local sysctl_file="/etc/sysctl.d/99-ciao-cors.conf"
  
  cat > "$sysctl_file" << EOF
# CIAO-CORS 网络优化参数
# 增加连接队列
net.core.somaxconn = 32768
net.core.netdev_max_backlog = 32768

# 优化TCP参数
net.ipv4.tcp_max_syn_backlog = 8192
net.ipv4.tcp_max_tw_buckets = 5000
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_keepalive_time = 1200

# 增加端口范围
net.ipv4.ip_local_port_range = 1024 65535
EOF

  sysctl -p "$sysctl_file"
  print_status "success" "网络参数优化完成"
}

# 创建SWAP空间
create_swap() {
  # 检查内存大小和已有SWAP
  local mem_total=$(free -m | awk '/^Mem:/{print $2}')
  local swap_total=$(free -m | awk '/^Swap:/{print $2}')
  
  if [[ $mem_total -ge 2048 ]]; then
    print_status "info" "内存大于2GB (${mem_total}MB)，无需创建SWAP"
    return 0
  fi
  
  if [[ $swap_total -gt 0 ]]; then
    print_status "info" "已存在${swap_total}MB SWAP空间，无需创建"
    return 0
  fi
  
  print_status "info" "创建SWAP空间..."
  
  # 计算SWAP大小 (内存的2倍，最大4GB)
  local swap_size=$((mem_total * 2))
  if [[ $swap_size -gt 4096 ]]; then
    swap_size=4096
  fi
  
  # 创建SWAP文件
  dd if=/dev/zero of=/swapfile bs=1M count=$swap_size
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  
  # 添加到fstab
  if ! grep -q "/swapfile" /etc/fstab; then
    echo "/swapfile swap swap defaults 0 0" >> /etc/fstab
  fi
  
  print_status "success" "创建了${swap_size}MB SWAP空间"
}

# ==================== 卸载函数 ====================

# 完全卸载
uninstall_service() {
    echo
    print_status "warning" "⚠️  即将完全卸载 CIAO-CORS 服务"
    print_status "warning" "这将删除所有相关文件和配置"
    echo
    
    read -p "确定要卸载吗? (输入 'YES' 确认): " confirm
    
    if [[ "$confirm" != "YES" ]]; then
        print_status "info" "取消卸载"
        return 0
    fi
    
    print_status "info" "开始卸载..."
    
    # 停止并禁用服务
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        systemctl stop "$SERVICE_NAME"
    fi
    
    if systemctl is-enabled --quiet "$SERVICE_NAME" 2>/dev/null; then
        systemctl disable "$SERVICE_NAME"
    fi
    
    # 删除服务文件
    if [[ -f "$SYSTEMD_SERVICE_FILE" ]]; then
        rm -f "$SYSTEMD_SERVICE_FILE"
        systemctl daemon-reload
        print_status "info" "系统服务已删除"
    fi
    
    # 删除安装目录
    if [[ -d "$INSTALL_DIR" ]]; then
        rm -rf "$INSTALL_DIR"
        print_status "info" "安装目录已删除"
    fi
    
    # 删除配置文件
    if [[ -f "$CONFIG_FILE" ]]; then
        rm -f "$CONFIG_FILE"
        print_status "info" "配置文件已删除"
    fi
    
    # 删除配置目录（如果为空）
    rmdir "$(dirname "$CONFIG_FILE")" 2>/dev/null
    
    # 删除日志文件
    if [[ -f "$LOG_FILE" ]]; then
        rm -f "$LOG_FILE"
        print_status "info" "日志文件已删除"
    fi
    
    # 关闭防火墙端口（可选）
    if [[ -f "$CONFIG_FILE.backup" ]]; then
        local port=$(grep "^PORT=" "$CONFIG_FILE.backup" | cut -d'=' -f2 2>/dev/null)
        if [[ -n "$port" ]]; then
            read -p "是否关闭防火墙端口 $port? (y/N): " close_port
            if [[ "$close_port" =~ ^[Yy]$ ]]; then
                firewall-cmd --permanent --remove-port="$port/tcp" 2>/dev/null
                firewall-cmd --reload 2>/dev/null
                print_status "info" "防火墙端口已关闭"
            fi
        fi
    fi
    
    print_status "success" "卸载完成"
    
    # 询问是否删除Deno
    echo
    read -p "是否同时卸载Deno? (y/N): " remove_deno
    if [[ "$remove_deno" =~ ^[Yy]$ ]]; then
        rm -rf ~/.deno
        rm -f /usr/local/bin/deno
        print_status "success" "Deno已卸载"
    fi
    
    echo
    print_status "title" "感谢使用 CIAO-CORS！"
    exit 0
}

# ==================== 主菜单和交互 ====================

# 显示主菜单
show_main_menu() {
    clear
    print_separator
    print_status "title" "   🚀 CIAO-CORS 一键部署管理脚本 v$SCRIPT_VERSION"
    print_separator
    echo
    
    # 检查安装状态
    if [[ -f "$SYSTEMD_SERVICE_FILE" ]]; then
        if systemctl is-active --quiet "$SERVICE_NAME"; then
            print_status "success" "服务状态: 运行中 ✅"
        else
            print_status "warning" "服务状态: 已停止 ⏹️"
        fi
        
        if [[ -f "$CONFIG_FILE" ]]; then
            local port=$(grep "^PORT=" "$CONFIG_FILE" | cut -d'=' -f2)
            print_status "info" "服务端口: $port"
        fi
        echo
        
        print_status "cyan" "📋 服务管理"
        echo "  1) 启动服务"
        echo "  2) 停止服务"
        echo "  3) 重启服务"
        echo "  4) 查看状态"
        echo "  5) 查看日志"
        echo
        
        print_status "cyan" "⚙️  配置管理"
        echo "  6) 修改配置"
        echo "  7) 查看配置"
        echo "  8) 备份配置"
        echo
        
        print_status "cyan" "📊 监控维护"
        echo "  9) 健康检查"
        echo " 10) 性能监控"
        echo " 11) 更新服务"
        echo " 12) 系统优化"
        echo
        
        print_status "cyan" "🗑️  其他操作"
        echo " 13) 完全卸载"
        echo "  0) 退出脚本"
        
    else
        print_status "warning" "服务状态: 未安装 ❌"
        echo
        
        print_status "cyan" "📦 安装选项"
        echo "  1) 全新安装"
        echo "  2) 检查系统要求"
        echo "  3) 仅安装Deno"
        echo "  0) 退出脚本"
    fi
    
    echo
    print_separator
}

# 显示安装菜单
show_install_menu() {
    clear
    print_separator
    print_status "title" "   📦 CIAO-CORS 安装向导"
    print_separator
    echo
    
    print_status "info" "安装步骤:"
    echo "  1. 检查系统要求"
    echo "  2. 安装/检查 Deno"
    echo "  3. 下载项目文件"
    echo "  4. 创建配置文件"
    echo "  5. 配置防火墙"
    echo "  6. 创建系统服务"
    echo "  7. 启动服务"
    echo
    
    read -p "确定开始安装? (Y/n): " start_install
    
    if [[ ! "$start_install" =~ ^[Nn]$ ]]; then
        # 执行安装步骤
        check_requirements || return 1
        
        if ! check_deno_installation; then
            install_deno || return 1
        fi
        
        download_project || return 1
        create_config || return 1
        
        local port=$(grep "^PORT=" "$CONFIG_FILE" | cut -d'=' -f2)
        configure_firewall "$port"
        
        create_systemd_service || return 1
        start_service || return 1
        
        print_status "success" "🎉 安装完成！"
        show_service_info
        
        echo
        read -p "按回车键继续..."
    fi
}

# 处理用户输入
handle_user_input() {
  local choice=$1
  
  if [[ -f "$SYSTEMD_SERVICE_FILE" ]]; then
    # 已安装状态的菜单处理
    case $choice in
      1) start_service ;;
      2) stop_service ;;
      3) restart_service ;;
      4) service_status ;;
      5) view_logs ;;
      6) modify_config ;;
      7) show_config ;;
      8) backup_config ;;
      9) health_check ;;
      10) performance_monitor ;;
      11) update_service ;;
      12) optimize_system ;;
      13) uninstall_service ;;
      0) 
          print_status "info" "再见! 👋"
          exit 0 
          ;;
      *)
          print_status "error" "无效选择，请重试"
          sleep 2
          ;;
    esac
  else
    # 未安装状态的菜单处理
    case $choice in
      1) show_install_menu ;;
      2) check_requirements ;;
      3) 
          if ! check_deno_installation; then
              install_deno
          else
              print_status "info" "Deno已安装"
          fi
          ;;
      0)
          print_status "info" "再见! 👋"
          exit 0
          ;;
      *)
          print_status "error" "无效选择，请重试"
          sleep 2
          ;;
    esac
  fi
}

# ==================== 主函数 ====================

# 脚本主入口
main() {
    # 检查root权限
    check_root
    
    # 主循环
    while true; do
        show_main_menu
        echo
        read -p "请选择操作 [0-12]: " choice
        echo
        
        handle_user_input "$choice"
        
        # 如果不是退出或错误选择，等待用户确认
        if [[ "$choice" != "0" && "$choice" =~ ^[0-9]+$ ]]; then
            echo
            read -p "按回车键返回主菜单..."
        fi
    done
}

# 脚本入口点
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
