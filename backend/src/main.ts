import { Hono } from "@hono/hono";
import { cors } from "@hono/hono/cors";
import { logger } from "@hono/hono/logger";
import { serveStatic } from "@hono/hono/deno";
import { Database } from "@db/sqlite";
import { load } from "@std/dotenv";
import { join } from "@std/path";

import { ProxyService } from "./services/proxy.ts";
import { ConfigService } from "./services/config.ts";
import { StatsService } from "./services/stats.ts";
import { AuthService } from "./services/auth.ts";
import { apiRoutes } from "./routes/api.ts";

// 加载环境变量
await load({ export: true });

// 初始化数据库
const db = new Database("data/ciao-cors.db");

// 初始化服务
const configService = new ConfigService(db);
const statsService = new StatsService(db);
const authService = new AuthService(db);
const proxyService = new ProxyService(configService, statsService);

// 初始化数据库表
function initDatabase() {
  db.exec(`
    CREATE TABLE IF NOT EXISTS config (
      key TEXT PRIMARY KEY,
      value TEXT
    );
    
    CREATE TABLE IF NOT EXISTS api_keys (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      key TEXT UNIQUE,
      name TEXT,
      enabled BOOLEAN DEFAULT 1,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    );
    
    CREATE TABLE IF NOT EXISTS blacklist (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      type TEXT, -- 'ip' or 'domain'
      value TEXT,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    );
    
    CREATE TABLE IF NOT EXISTS whitelist (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      type TEXT, -- 'ip' or 'domain'
      value TEXT,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    );
    
    CREATE TABLE IF NOT EXISTS stats (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
      ip TEXT,
      domain TEXT,
      status_code INTEGER,
      response_time INTEGER,
      user_agent TEXT,
      api_key TEXT
    );
    
    CREATE TABLE IF NOT EXISTS rate_limits (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      type TEXT, -- 'ip' or 'api_key'
      identifier TEXT,
      requests INTEGER DEFAULT 0,
      window_start DATETIME,
      UNIQUE(type, identifier, window_start)
    );
    
    -- 插入默认配置
    INSERT OR IGNORE INTO config (key, value) VALUES 
      ('admin_username', 'admin'),
      ('admin_password', '$2b$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi'), -- password
      ('cors_origin', '*'),
      ('max_requests_per_minute', '100'),
      ('max_concurrent_requests', '10'),
      ('enable_whitelist', 'false'),
      ('enable_blacklist', 'true');
  `);
}

initDatabase();

// 创建Hono应用
const app = new Hono();

// 中间件
app.use(logger());
app.use(cors({
  origin: "*",
  allowMethods: ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
  allowHeaders: ["Content-Type", "Authorization", "X-API-Key"],
}));

// 健康检查
app.get("/health", (c) => c.json({ status: "ok", timestamp: new Date().toISOString() }));

// API路由
app.route("/api", apiRoutes(configService, statsService, authService));

// 代理路由 - 处理所有代理请求
app.all("/*", async (c) => {
  const url = c.req.path.slice(1); // 移除开头的/
  
  if (!url || url === "favicon.ico" || url === "robots.txt") {
    return c.json({
      code: 0,
      usage: "Host/{URL}",
      source: "https://github.com/your-username/ciao-cors",
      message: "欢迎使用 Ciao-CORS 代理服务"
    });
  }

  return await proxyService.handleRequest(c, url);
});

// 静态文件服务
app.use("/*", serveStatic({
  root: "./static",
  rewriteRequestPath: (path) => path === "/" ? "/index.html" : path,
}));

const port = parseInt(Deno.env.get("PORT") || "8000");
console.log(`🚀 Ciao-CORS 服务启动在 http://localhost:${port}`);

Deno.serve({ port }, app.fetch);