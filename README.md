# 🌐 CIAO-CORS

一个功能完备的 CORS 代理服务，专为 Deno Deploy 设计，支持完整的 Web 管理界面。

## ✨ 特性

- 🚀 **零配置启动** - 单文件部署，开箱即用
- 🔒 **安全控制** - IP 黑白名单、API Key 认证、频率限制
- 📊 **实时监控** - 完整的请求日志和统计面板
- 🎨 **现代界面** - 响应式 Web 管理界面
- ⚡ **高性能** - 基于 Deno 的现代 JavaScript 运行时
- 🛡️ **生产就绪** - 完善的错误处理和安全措施

## 🚀 快速开始

### 部署到 Deno Deploy

1. 访问 [dash.deno.com](https://dash.deno.com)
2. 创建新项目
3. 上传 `main.ts` 文件
4. 部署完成！

### 本地运行

```bash
# 安装 Deno (如果还没有安装)
curl -fsSL https://deno.land/install.sh | sh

# 运行服务
deno run --allow-net --allow-env main.ts
```

## 📖 使用说明

### 基本代理用法

将需要请求的 URL 放在代理服务地址后面：

```javascript
// 原始请求（有跨域问题）
fetch('https://api.example.com/data')

// 使用代理（解决跨域）
fetch('https://your-proxy.deno.dev/https://api.example.com/data')
```

### 使用 API Key

```javascript
// 通过请求头
fetch('https://your-proxy.deno.dev/https://api.example.com/data', {
  headers: {
    'X-API-Key': 'your-api-key'
  }
})

// 通过 URL 参数
fetch('https://your-proxy.deno.dev/https://api.example.com/data?key=your-api-key')
```

## 🔧 配置

### 环境变量

可以通过环境变量进行配置：

```bash
# 管理员密码（强烈建议修改）
ADMIN_PASSWORD=your-secure-password

# 允许的来源域名（逗号分隔）
ALLOWED_ORIGINS=*,https://yoursite.com

# 阻止的来源域名（逗号分隔）
BLOCKED_ORIGINS=https://badsite.com

# 每分钟请求限制
RATE_LIMIT_PER_MINUTE=60

# 最大并发请求数
MAX_CONCURRENT=10

# 是否要求 API Key 认证
REQUIRE_AUTH=false

# 完整配置 JSON（可选）
CIAO_CORS_CONFIG={"allowedOrigins":["*"],"requireAuth":false}
```

### Web 管理界面

访问 `/admin` 进入管理界面，可以：

- 📊 查看实时统计数据
- ⚙️ 管理黑白名单和频率限制
- 📝 查看详细的请求日志
- 🔑 创建和管理 API Keys

默认管理员密码：`admin123`（请在生产环境中修改）

## 🛡️ 安全特性

### IP 控制
- **白名单模式**：只允许指定 IP 访问
- **黑名单模式**：阻止指定 IP 访问
- **通配符支持**：支持 IP 段匹配

### 域名控制
- **来源限制**：控制允许的 Referer 域名
- **目标过滤**：可以限制代理的目标域名

### 频率限制
- **每分钟请求数**：限制单个客户端的请求频率
- **并发控制**：限制同时处理的请求数量
- **单源限制**：针对每个 IP 或 API Key 的独立限制

### API Key 认证
- **可选认证**：可以开启 API Key 要求模式
- **密钥管理**：通过管理界面创建和删除 API Key
- **使用统计**：跟踪每个 API Key 的使用情况

## 📊 监控和日志

### 实时统计
- 总请求数和错误率
- 每小时/每天请求量
- 平均响应时间
- 热门目标域名

### 详细日志
- 完整的请求和响应信息
- 客户端 IP 和 User Agent
- 响应时间和状态码
- API Key 使用记录

### 自动清理
- 自动清理 7 天前的日志
- 定期清理过期的频率限制记录
- 内存使用优化

## 🎨 界面预览

### 首页
- 🌐 项目介绍和特性说明
- 📖 详细的使用文档
- 🎯 JavaScript 代码示例

### 管理界面
- 📊 **统计概览** - 实时数据面板
- ⚙️ **配置管理** - 黑白名单和限制设置
- 📝 **请求日志** - 详细的访问记录
- 🔑 **API 密钥** - 密钥创建和管理

## 🔄 API 文档

### 配置管理
```http
GET  /api/config      # 获取当前配置
POST /api/config      # 更新配置
DELETE /api/config    # 重置为默认配置
```

### 日志查询
```http
GET /api/logs?limit=100&offset=0   # 获取请求日志
```

### 统计数据
```http
GET /api/stats        # 获取统计信息
```

### 认证管理
```http
POST /api/auth        # 管理员登录
DELETE /api/auth      # 登出
```

### API Key 管理
```http
GET /api/apikeys      # 获取所有 API Key
POST /api/apikeys     # 创建新 API Key
DELETE /api/apikeys   # 删除 API Key
```

## 🚀 部署指南

### Deno Deploy 部署

1. **创建项目**
   - 访问 [dash.deno.com](https://dash.deno.com)
   - 点击 "New Project"
   - 选择从文件上传

2. **上传文件**
   - 上传 `main.ts` 文件
   - 确保文件名为 `main.ts`

3. **配置环境变量**（可选）
   - 在项目设置中添加环境变量
   - 设置 `ADMIN_PASSWORD` 等配置

4. **部署完成**
   - 自动获得 `https://your-project.deno.dev` 域名
   - 可以绑定自定义域名

### 自托管部署

```bash
# 克隆项目
git clone <repository-url>
cd ciao-cors

# 运行服务
deno run --allow-net --allow-env main.ts

# 或者使用 PM2 等进程管理器
pm2 start "deno run --allow-net --allow-env main.ts" --name ciao-cors
```

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

1. Fork 项目
2. 创建特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 打开 Pull Request

## 📄 许可证

本项目采用 MIT 许可证 - 查看 [LICENSE](LICENSE) 文件了解详情。

## 🙏 致谢

- [Deno](https://deno.land/) - 现代 JavaScript/TypeScript 运行时
- [Deno Deploy](https://deno.com/deploy) - 边缘计算平台

## 📞 支持

如有问题或建议，请：

1. 提交 [GitHub Issue](https://github.com/your-username/ciao-cors/issues)
2. 查看 [文档](https://github.com/your-username/ciao-cors/wiki)
3. 加入讨论 [Discussions](https://github.com/your-username/ciao-cors/discussions)

---

**CIAO-CORS** - 让跨域访问变得简单！ 🚀

### 🚀 核心功能
- **CORS 代理**: 完整的跨域请求代理支持
- **黑白名单**: IP 地址和域名级别的访问控制
- **频率限制**: 每分钟请求数、并发连接数控制
- **API Key 管理**: 支持多个 API Key 的创建和管理
- **请求日志**: 详细的请求记录和统计分析

### 🎯 管理界面
- **门户首页**: 项目介绍和使用说明
- **登录界面**: 安全的管理员认证
- **管理面板**: 直观的配置和监控界面
- **统计报表**: 实时的使用情况统计

### 🛡️ 安全特性
- **访问控制**: 基于 IP 和域名的精确控制
- **频率限制**: 防止滥用的多层限制机制
- **会话管理**: 安全的管理员会话控制
- **API 认证**: 可选的 API Key 验证机制

## 🏗️ 项目结构

```
ciao-cors/
├── main.ts           # 主程序文件（单文件部署）
├── deno.json        # Deno 配置文件
├── README.md        # 项目说明文档
└── LICENSE          # MIT 许可证
```

## 🚀 快速开始

### 本地开发

```bash
# 克隆项目
git clone <your-repo-url>
cd ciao-cors

# 本地运行
deno task dev
# 或者
deno run --allow-net --allow-env --allow-read --allow-write main.ts
```

### Deno Deploy 部署

1. 访问 [dash.deno.com](https://dash.deno.com)
2. 创建新项目
3. 连接你的 GitHub 仓库
4. 选择 `main.ts` 作为入口文件
5. 设置环境变量（可选）：
   - `ADMIN_PASSWORD`: 管理员密码（默认: admin123）
   - `PORT`: 端口号（默认: 8000）

## 📖 使用说明

### 基本代理使用

```javascript
// 代理请求示例
fetch('https://your-cors-proxy.deno.dev/https://api.example.com/data')
  .then(response => response.json())
  .then(data => console.log(data));
```

### API Key 使用

```javascript
// 带 API Key 的请求
fetch('https://your-cors-proxy.deno.dev/https://api.example.com/data', {
  headers: {
    'X-API-Key': 'your-api-key-here'
  }
})
```

### 管理界面

1. 访问 `https://your-cors-proxy.deno.dev/` 查看首页
2. 访问 `https://your-cors-proxy.deno.dev/login` 登录管理界面
3. 登录后访问 `https://your-cors-proxy.deno.dev/admin` 进行配置管理

## ⚙️ 配置选项

### 访问控制
- **allowedOrigins**: 允许的来源域名列表
- **blockedOrigins**: 禁止的来源域名列表
- **allowedIPs**: 允许的 IP 地址列表
- **blockedIPs**: 禁止的 IP 地址列表

### 频率限制
- **requestsPerMinute**: 每分钟最大请求数
- **maxConcurrent**: 最大并发连接数
- **perSourceLimit**: 单一来源的并发限制

### API Key 管理
- **apiKeys**: API Key 配置对象
- **requireAuth**: 是否强制要求 API Key

## 📊 API 接口

### 配置管理
- `GET /api/config` - 获取当前配置
- `POST /api/config` - 更新配置
- `POST /api/config/reset` - 重置为默认配置

### 日志和统计
- `GET /api/logs` - 获取请求日志
- `GET /api/stats` - 获取统计数据
- `DELETE /api/logs` - 清空日志记录

### 认证管理
- `POST /api/auth/login` - 管理员登录
- `POST /api/auth/logout` - 退出登录
- `GET /api/auth/status` - 检查登录状态

### API Key 管理
- `GET /api/keys` - 获取 API Key 列表
- `POST /api/keys` - 创建新的 API Key
- `DELETE /api/keys/:id` - 删除 API Key
- `PUT /api/keys/:id` - 更新 API Key 状态

## 🔧 开发说明

### 项目架构

该项目采用单文件架构，所有功能都在 `main.ts` 中实现，包括：

1. **核心代理模块**: 处理 CORS 代理请求
2. **安全验证模块**: IP、域名、API Key 验证
3. **频率限制模块**: 请求频率和并发控制
4. **日志统计模块**: 请求记录和数据分析
5. **配置管理模块**: 配置的加载、保存、重置
6. **Web 界面模块**: 前端 HTML、CSS、JS 生成
7. **API 接口模块**: RESTful API 实现

### 函数组织

- **请求处理函数**: `handleRequest`, `handleProxyRequest`, `handleAPIRequest`
- **安全验证函数**: `validateIP`, `validateOrigin`, `validateAPIKey`
- **频率限制函数**: `checkRateLimit`, `updateRateLimit`, `cleanupRateLimit`
- **日志统计函数**: `logRequest`, `getStatistics`, `cleanupLogs`
- **配置管理函数**: `loadConfig`, `saveConfig`, `resetConfig`
- **工具函数**: `fixUrl`, `getClientIP`, `generateUniqueId`

## 📝 许可证

MIT License - 详见 [LICENSE](LICENSE) 文件

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

## 📞 支持

如有问题，请创建 [GitHub Issue](https://github.com/your-username/ciao-cors/issues)。