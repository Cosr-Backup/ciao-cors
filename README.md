# CIAO-CORS

高性能、功能完整的CORS代理服务，支持多种部署方式和丰富的配置选项。专为需要跨域资源访问的Web应用设计，提供了安全、可靠的代理解决方案。

🌐 **在线演示**: [cors.ciao.su](https://cors.ciao.su)

感谢 **[DreamCloud](https://whmcs.as211392.com)** 提供的高防服务器支持，为本项目提供稳定可靠的演示环境。

## 功能特性

### 核心功能
- 🚀 **高性能CORS代理**：支持所有HTTP方法和内容类型，轻松解决跨域问题
- 🔒 **安全防护**：IP/域名黑白名单、恶意URL检测、请求验证
- ⚡ **智能限流**：动态请求频率限制和并发控制，防止资源滥用
- 📊 **实时监控**：详细的请求统计、性能分析和状态监控
- 🎯 **智能缓存**：GET请求响应缓存，大幅提升性能和减少外部请求
- 📝 **完整日志**：支持控制台和Webhook日志，便于追踪和分析
- 🤖 **智能伪装**：优先转发真实User-Agent，自动添加浏览器标准头部，降低被识别为爬虫的风险
- 🔄 **自动重试**：智能重试机制，自动处理网络波动和临时错误，大幅提升请求成功率

### 配置选项
- **黑白名单**：支持IP和域名级别的访问控制，精确管理代理权限
- **频率限制**：可配置的滑动窗口请求限制，自动防御恶意流量
- **并发控制**：单IP和全局并发数限制，确保系统稳定
- **统计监控**：可选的请求统计和性能监控，实时了解系统状态
- **API管理**：内置管理API，支持API密钥保护，安全管理系统

### 部署方式
- **Deno Deploy**：一键部署到全球CDN网络，极速响应全球请求
- **VPS部署**：完整的一键安装和管理脚本，轻松管理自己的实例
- **Docker容器**：支持容器化部署，快速集成到现有基础设施

## 快速开始

### Deno Deploy部署

1. **克隆项目**
   ```bash
   git clone https://github.com/bestZwei/ciao-cors.git
   cd ciao-cors
   ```

2. **创建Deno Deploy项目**
   - 访问 [Deno Deploy](https://dash.deno.com)
   - 创建新项目
   - 选择"从GitHub部署"，选择您的仓库和server.ts文件

3. **配置环境变量**
   - 在Deno Deploy控制台中设置环境变量（可选）
   - 可以配置API_KEY、限流参数、域名黑白名单等

4. **开始使用**
   - 通过 `https://your-project.deno.dev/example.com/api/endpoint` 格式访问
   - 第一个路径段是您要请求的目标域名和路径

### VPS部署

1. **下载部署脚本**
   ```bash
   curl -fsSL https://raw.githubusercontent.com/bestZwei/ciao-cors/main/deploy.sh -o deploy.sh
   chmod +x deploy.sh
   ```

2. **运行安装脚本**
   ```bash
   sudo ./deploy.sh
   ```

3. **按照菜单提示操作**
   - 自动检测和安装Deno
   - 配置服务参数（端口、API密钥等）
   - 设置防火墙规则
   - 创建系统服务

#### 脚本功能特性

- **🔒 安全性**: 脚本锁定机制防止并发执行，完整的权限检查
- **🌐 兼容性**: 支持Ubuntu、Debian、CentOS、RHEL、Fedora等主流发行版
- **🔧 智能安装**: 自动检测系统架构，支持x86_64和ARM64
- **📦 依赖管理**: 自动安装必要依赖，智能包管理器检测
- **🛡️ 防火墙**: 支持firewalld、ufw、iptables多种防火墙
- **📋 备份恢复**: 自动备份配置和文件，支持一键恢复
- **🔄 更新维护**: 内置脚本更新、服务更新、系统优化功能
- **📊 监控诊断**: 健康检查、性能监控、日志分析
- **🎯 用户友好**: 彩色输出、详细提示、错误处理

## 高级配置

### 环境变量

| 变量名 | 默认值 | 说明 |
|--------|--------|------|
| `PORT` | `3000` | 服务监听端口 |
| `RATE_LIMIT` | `2500` | 每个时间窗口的最大请求数 |
| `RATE_LIMIT_WINDOW` | `60000` | 限流时间窗口（毫秒） |
| `CONCURRENT_LIMIT` | `10` | 单IP最大并发数 |
| `TOTAL_CONCURRENT_LIMIT` | `1000` | 全局最大并发数 |
| `MAX_URL_LENGTH` | `2048` | 最大URL长度 |
| `MAX_BODY_SIZE` | `10485760` | 最大请求体大小（字节，默认10MB） |
| `TIMEOUT` | `30000` | 请求超时时间（毫秒） |
| `ENABLE_STATS` | `false` | 是否启用统计功能 |
| `ENABLE_LOGGING` | `true` | 是否启用日志记录 |
| `API_KEY` | - | 管理API密钥（可选） |
| `LOG_WEBHOOK` | - | 日志Webhook URL（可选） |
| `ALLOWED_ORIGINS` | - | 允许的来源域名列表（JSON或逗号分隔） |
| `BLOCKED_IPS` | - | 禁止的IP地址列表（JSON或逗号分隔） |
| `BLOCKED_DOMAINS` | - | 禁止的域名列表（JSON或逗号分隔） |
| `ALLOWED_DOMAINS` | - | 允许的域名列表（JSON或逗号分隔） |
| `REQUIRE_HEADERS` | `true` | 是否强制要求Origin或X-Requested-With头部 |

### 配置示例

**基础配置**
```bash
export PORT=3000
export RATE_LIMIT=100
export ENABLE_STATS=true
export API_KEY=your-secret-key
```

**安全配置**
```bash
export BLOCKED_IPS='["192.168.1.100", "10.0.0.5"]'
export ALLOWED_DOMAINS='["api.example.com", "data.example.org"]'
export BLOCKED_DOMAINS='["malicious.com", "spam.net"]'
export REQUIRE_HEADERS=true  # 强制要求Origin或X-Requested-With头部
```

**性能配置**
```bash
export CONCURRENT_LIMIT=20
export TOTAL_CONCURRENT_LIMIT=2000
export TIMEOUT=60000
export RATE_LIMIT_WINDOW=30000
```

## API参考

### 代理使用

**基本代理格式**
```
https://your-domain.com/{target-url}
```

**使用示例**
```bash
# 代理GET请求（需要添加必需的头部）
curl -H "X-Requested-With: XMLHttpRequest" \
  https://your-domain.com/httpbin.org/get

# 代理POST请求
curl -X POST https://your-domain.com/jsonplaceholder.typicode.com/posts \
  -H "Content-Type: application/json" \
  -H "X-Requested-With: XMLHttpRequest" \
  -d '{"title": "test", "body": "content"}'

# 使用Origin头部（浏览器fetch会自动添加）
curl -H "Origin: https://your-app.com" \
  "https://your-domain.com/api.github.com/users/octocat"
```

**JavaScript fetch示例**
```javascript
// fetch会自动添加Origin头部，无需手动设置
fetch('https://your-domain.com/httpbin.org/get')
  .then(response => response.json())
  .then(data => console.log(data));

// 或者手动添加X-Requested-With头部
fetch('https://your-domain.com/httpbin.org/get', {
  headers: {
    'X-Requested-With': 'XMLHttpRequest'
  }
})
  .then(response => response.json())
  .then(data => console.log(data));
```

### 管理API

需要设置`API_KEY`环境变量才能访问管理API。

**健康检查**
```bash
GET /_api/health?key=your-api-key
```

**查看统计信息**
```bash
GET /_api/stats?key=your-api-key
```

**查看性能数据**
```bash
GET /_api/performance?key=your-api-key
```

**查看配置信息**
```bash
GET /_api/config?key=your-api-key
```

**查看版本信息**
```bash
GET /_api/version?key=your-api-key
```

**重置统计数据**
```bash
GET /_api/reset-stats?key=your-api-key
```

**清理缓存**
```bash
GET /_api/clear-cache?key=your-api-key
```

**热重载配置**
```bash
GET /_api/reload-config?key=your-api-key
```

**使用Bearer Token**
```bash
curl -H "Authorization: Bearer your-api-key" \
  https://your-domain.com/_api/stats
```

## 安全最佳实践

### 🔐 基础安全配置

1. **强制设置API密钥**
   - 使用至少32位的复杂随机密钥
   - 包含大小写字母、数字和特殊字符
   - 定期轮换API密钥（建议每3-6个月）
   - 示例生成强密钥：`openssl rand -base64 32`

2. **配置严格的访问控制**
   - 使用域名白名单限制可代理的目标
   - 配置IP黑名单阻止恶意来源
   - 设置来源白名单控制CORS访问
   - 避免使用通配符（*）除非必要

3. **实施多层限流保护**
   - 请求频率限制：防止单IP过度请求
   - 并发连接限制：防止资源耗尽
   - 请求体大小限制：防止大文件攻击
   - 根据服务器性能调整参数

### 🛡️ 系统安全加固

4. **服务运行安全**
   - 使用专用非特权用户运行服务
   - 启用systemd安全特性（已内置）
   - 配置适当的文件权限（600用于配置文件）
   - 定期检查服务运行状态

5. **网络安全配置**
   - 配置防火墙只开放必要端口
   - 使用HTTPS反向代理（推荐nginx/Apache）
   - 考虑使用VPN或内网部署
   - 监控异常网络连接

6. **日志和监控**
   - 启用详细日志记录
   - 配置日志轮转防止磁盘满
   - 设置异常告警（可用Webhook）
   - 定期分析访问模式

### 🔄 维护和更新

7. **定期安全维护**
   - 及时更新系统和Deno运行时
   - 使用管理脚本检查服务状态
   - 定期备份配置文件
   - 运行安全检查脚本

8. **安全检查工具**
   ```bash
   # 运行安全配置检查
   curl -fsSL https://raw.githubusercontent.com/bestZwei/ciao-cors/main/security-check.sh | sudo bash

   # 或下载后运行
   wget https://raw.githubusercontent.com/bestZwei/ciao-cors/main/security-check.sh
   chmod +x security-check.sh
   sudo ./security-check.sh
   ```

### ⚠️ 安全警告

- **永远不要**在生产环境中禁用所有安全限制
- **永远不要**使用弱密码或默认密钥
- **永远不要**允许代理访问内网地址（已内置保护）
- **永远不要**忽略异常的流量模式
- **定期检查**是否有未授权的配置更改

## 性能优化

### 推荐配置
- **小型站点**：并发限制10，频率限制60/分钟
- **中型站点**：并发限制50，频率限制300/分钟
- **大型站点**：并发限制100，频率限制1000/分钟

### 优化技巧
1. **增加缓存时间**
   - 对于不经常变化的内容，可以延长缓存TTL
   - 添加自定义缓存控制头

2. **调整并发限制**
   - 对于强CPU服务器，可以增加并发限制
   - 监控系统负载，避免过载

3. **使用VPS部署脚本的系统优化功能**
   - 优化系统限制（文件描述符、连接数）
   - 调整网络参数提高吞吐量
   - 添加SWAP空间（低内存服务器）

### 监控指标
- 平均响应时间（目标：<500ms）
- 错误率（目标：<1%）
- 并发连接数
- 缓存命中率（目标：>70%）

## 故障排除

### 部署脚本问题

**Q: 脚本提示"网络连接失败"**
```bash
# 检查网络连接
ping github.com
ping deno.land

# 检查DNS设置
cat /etc/resolv.conf

# 临时使用其他DNS
echo "nameserver 8.8.8.8" > /etc/resolv.conf
```

**Q: 健康检查显示"端口未监听"但服务在运行**
```bash
# 安装网络工具
sudo apt install net-tools iproute2 lsof  # Ubuntu/Debian
sudo yum install net-tools iproute lsof   # CentOS/RHEL

# 手动检查端口
sudo ss -tuln | grep :3000
sudo netstat -tuln | grep :3000
sudo lsof -i :3000

# 检查服务日志
sudo journalctl -u ciao-cors -f
```

**Q: 性能监控显示"netstat: command not found"**
```bash
# 现代Linux系统推荐使用ss命令
sudo apt install iproute2  # Ubuntu/Debian
sudo yum install iproute   # CentOS/RHEL

# 或安装传统的net-tools
sudo apt install net-tools  # Ubuntu/Debian
sudo yum install net-tools  # CentOS/RHEL
```

**Q: Deno安装失败**
```bash
# 手动安装Deno
curl -fsSL https://deno.land/x/install/install.sh | sh
export PATH="$HOME/.deno/bin:$PATH"
sudo ln -sf $HOME/.deno/bin/deno /usr/local/bin/deno

# 验证安装
deno --version
```

**Q: 防火墙配置失败**
```bash
# 检查防火墙状态
sudo systemctl status firewalld
sudo systemctl status ufw

# 手动开放端口
sudo firewall-cmd --permanent --add-port=3000/tcp
sudo firewall-cmd --reload

# 或使用ufw
sudo ufw allow 3000/tcp
```

**Q: 服务创建失败**
```bash
# 检查systemd
sudo systemctl --version

# 手动重载systemd
sudo systemctl daemon-reload

# 检查服务文件
sudo systemctl cat ciao-cors
```

### 服务运行问题

**Q: 服务启动失败，提示端口被占用**
```bash
# 检查端口占用
sudo netstat -tlnp | grep :3000
sudo lsof -i :3000

# 或使用其他端口
sudo ./deploy.sh  # 选择修改配置 -> 端口号
```

**Q: 请求被拒绝，提示Rate limit exceeded**
```bash
# 调整限流配置
export RATE_LIMIT=200
export RATE_LIMIT_WINDOW=60000
```

**Q: 代理请求超时**
```bash
# 增加超时时间
export TIMEOUT=60000
```

**Q: 统计数据不显示**
```bash
# 检查统计功能是否启用
curl http://localhost:3000/_api/config?key=your-api-key

# 启用统计功能
export ENABLE_STATS=true

# 或修改配置文件
sudo sed -i 's/^ENABLE_STATS=.*/ENABLE_STATS=true/' /etc/ciao-cors/config.env
sudo systemctl restart ciao-cors

# 测试统计功能
curl https://raw.githubusercontent.com/bestZwei/ciao-cors/main/test-stats.sh | bash
```

**Q: 客户端收到CORS错误**
```bash
# 检查允许的来源设置
export ALLOWED_ORIGINS='["*"]'
# 或者指定特定域名
export ALLOWED_ORIGINS='["https://your-app.com"]'
```

**Q: 收到"Missing required request header"错误**
```bash
# 这是新的安全功能，需要添加必需的头部
# 方法1：在请求中添加X-Requested-With头部
curl -H "X-Requested-With: XMLHttpRequest" https://your-domain.com/target-url

# 方法2：在请求中添加Origin头部
curl -H "Origin: https://your-app.com" https://your-domain.com/target-url

# 方法3：如果需要禁用此功能（不推荐）
export REQUIRE_HEADERS=false
sudo systemctl restart ciao-cors
```

### 快速诊断

**使用诊断脚本**
```bash
# 下载诊断脚本
curl -fsSL https://raw.githubusercontent.com/bestZwei/ciao-cors/main/diagnose.sh -o diagnose.sh
chmod +x diagnose.sh

# 运行诊断
sudo ./diagnose.sh
```

诊断脚本会自动检查：
- 系统状态和资源
- 服务运行状态
- 配置文件有效性
- 网络连接和端口监听
- 错误日志分析
- 提供自动修复建议

### 调试技巧

**查看实时日志**
```bash
# systemd服务日志
sudo journalctl -f -u ciao-cors

# 或者直接运行
deno run --allow-net --allow-env server.ts
```

**API调试**
```bash
# 健康检查
curl http://localhost:3000/_api/health

# 测试代理
curl http://localhost:3000/httpbin.org/ip

# 性能数据
curl -H "Authorization: Bearer your-api-key" \
  http://localhost:3000/_api/performance
```

## 技术架构

CIAO-CORS 采用现代化的架构设计，确保高性能和可靠性：

- **运行时环境**：使用Deno运行时，获得原生TypeScript支持和安全沙箱
- **无依赖设计**：不依赖外部npm包，减少安全风险和部署复杂性
- **内存优化**：智能缓存管理和资源清理，避免内存泄漏
- **并发控制**：多级限流策略，确保系统稳定性
- **安全增强**：全面的请求验证和过滤，防止恶意请求

## 许可证

MIT License - 详见 [LICENSE](LICENSE) 文件

## 贡献指南

欢迎提交Issue和Pull Request！

1. Fork本项目
2. 创建功能分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 开启Pull Request

### 开发环境设置

```bash
# 安装Deno
curl -fsSL https://deno.land/x/install/install.sh | sh

# 本地运行
deno run --allow-net --allow-env server.ts

# 类型检查
deno check server.ts

# 代码格式化
deno fmt server.ts

# 代码lint
deno lint server.ts
```

## 支持

如果这个项目对你有帮助，请给个⭐️！

### 联系方式

- GitHub Issues: [https://github.com/bestZwei/ciao-cors/issues](https://github.com/bestZwei/ciao-cors/issues)
- Email: [post@zwei.de.eu.org](mailto:post@zwei.de.eu.org)

---

Made with ❤️ by [bestZwei](https://github.com/bestZwei)