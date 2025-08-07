# Ciao-CORS - 功能强大的CORS代理服务

一个现代化的、支持自部署的 CORS 代理服务，为您提供稳定、可控的跨域解决方案。

## 🎯 三个核心问题解答

### 1. 公共免费CORS代理服务
- **cors.eu.org** - 由netnr提供的Cloudflare Workers服务，但已限制大量请求
- **seep.eu.org** - 2024年1月后推荐的无限制代理服务
- **注意**：公共免费服务通常有请求限制，建议生产环境使用自部署方案

### 2. 现成开源项目
- **netnr/workers** - <https://github.com/netnr/workers> - Cloudflare Workers实现
- **cors-anywhere** - Node.js实现的流行CORS代理
- **cors-server** - 基于Express的轻量级解决方案

### 3. Deno+Docker实现复杂度
**不复杂**！使用Deno和TypeScript实现CORS代理非常简单：
- Deno原生支持HTTP服务器和fetch API
- 单文件即可实现核心功能
- Docker部署仅需几行配置
- 本项目提供了完整实现参考

## 🚀 项目特性

- **核心代理**：稳定高效地将 HTTP/HTTPS 请求代理转发，并自动注入必要的 CORS 头部
- **管理后台**：美观易用的前端界面，轻松管理所有配置
- **安全控制**：
  - IP/域名黑白名单
  - API Key 管理
  - 请求频率限制
  - 并发连接数限制
- **统计监控**：实时查看代理服务的使用情况和流量分析
- **Docker一键部署**：使用 `docker-compose` 轻松部署
- **CI/CD自动化**：GitHub Actions自动构建发布

## 🛠️ 技术栈

- **后端**: Deno, Hono, TypeScript, SQLite
- **前端**: React, Vite, TypeScript, Mantine UI
- **部署**: Docker, Docker Compose, Nginx
- **CI/CD**: GitHub Actions

## 📦 快速开始

```bash
# 克隆项目
git clone https://github.com/your-username/ciao-cors.git
cd ciao-cors

# 配置环境
cp .env.example .env
# 编辑 .env 文件设置管理员密码

# 启动服务
docker-compose up -d

# 访问服务
# 门户: http://localhost:8080
# 后台: http://localhost:8080/dashboard
```

## 📁 项目结构

```
ciao-cors/
├── backend/          # Deno后端服务
├── frontend/         # React前端应用
├── nginx/           # Nginx配置
├── docker-compose.yml
├── .github/workflows/ # CI/CD工作流
└── docs/            # 项目文档
```

## 🔧 开发指南

### 本地开发
```bash
# 启动后端
cd backend && deno task dev

# 启动前端
cd frontend && npm run dev
```

### Docker开发
```bash
# 构建镜像
docker-compose build

# 启动开发环境
docker-compose -f docker-compose.dev.yml up
```

## 🚢 生产部署

1. 配置 `.env` 文件
2. 运行 `docker-compose up -d`
3. 配置反向代理（可选）
4. 访问管理后台完成初始设置

## 📊 管理功能

- **代理配置**: 自定义CORS头、超时设置
- **访问控制**: IP白名单/黑名单、API密钥管理
- **速率限制**: 按IP或API Key限制请求频率
- **监控面板**: 实时流量、错误率、响应时间统计
- **日志管理**: 访问日志查询和导出

## 🤝 贡献

欢迎提交Issue和Pull Request！

## 📄 许可证

MIT License - 详见 [LICENSE](LICENSE) 文件
