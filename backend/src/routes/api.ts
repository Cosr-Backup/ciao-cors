import { Hono } from "@hono/hono";
import { ConfigService } from "../services/config.ts";
import { StatsService } from "../services/stats.ts";
import { AuthService } from "../services/auth.ts";

export function apiRoutes(
  configService: ConfigService,
  statsService: StatsService,
  authService: AuthService
) {
  const api = new Hono();

  // 中间件：检查管理员权限
  api.use("/admin/*", async (c, next) => {
    const auth = c.req.header("authorization");
    if (!auth || !auth.startsWith("Basic ")) {
      return c.json({ error: "未授权" }, 401);
    }

    const credentials = atob(auth.split(" ")[1]);
    const [username, password] = credentials.split(":");

    const isValid = await authService.validateAdmin(username, password);
    if (!isValid) {
      return c.json({ error: "用户名或密码错误" }, 401);
    }

    await next();
  });

  // 管理员登录
  api.post("/admin/login", async (c) => {
    const { username, password } = await c.req.json();
    const isValid = await authService.validateAdmin(username, password);
    
    if (isValid) {
      return c.json({ success: true, token: "admin" });
    } else {
      return c.json({ error: "用户名或密码错误" }, 401);
    }
  });

  // 获取系统配置
  api.get("/admin/config", async (c) => {
    const config = await configService.getAllConfig();
    return c.json(config);
  });

  // 更新系统配置
  api.post("/admin/config", async (c) => {
    const updates = await c.req.json();
    
    for (const [key, value] of Object.entries(updates)) {
      await configService.setConfig(key, value as string);
    }
    
    return c.json({ success: true });
  });

  // 获取黑名单
  api.get("/admin/blacklist", async (c) => {
    const type = c.req.query("type") as "ip" | "domain" | undefined;
    const blacklist = await configService.getBlacklist(type);
    return c.json(blacklist);
  });

  // 添加黑名单
  api.post("/admin/blacklist", async (c) => {
    const { type, value } = await c.req.json();
    
    if (!["ip", "domain"].includes(type) || !value) {
      return c.json({ error: "参数错误" }, 400);
    }
    
    await configService.addToBlacklist(type, value);
    return c.json({ success: true });
  });

  // 移除黑名单
  api.delete("/admin/blacklist/:id", async (c) => {
    const id = c.req.param("id");
    await configService.removeFromBlacklist("ip", id); // 简化处理
    return c.json({ success: true });
  });

  // 获取白名单
  api.get("/admin/whitelist", async (c) => {
    const type = c.req.query("type") as "ip" | "domain" | undefined;
    const whitelist = await configService.getWhitelist(type);
    return c.json(whitelist);
  });

  // 添加白名单
  api.post("/admin/whitelist", async (c) => {
    const { type, value } = await c.req.json();
    
    if (!["ip", "domain"].includes(type) || !value) {
      return c.json({ error: "参数错误" }, 400);
    }
    
    await configService.addToWhitelist(type, value);
    return c.json({ success: true });
  });

  // 移除白名单
  api.delete("/admin/whitelist/:id", async (c) => {
    const id = c.req.param("id");
    await configService.removeFromWhitelist("ip", id); // 简化处理
    return c.json({ success: true });
  });

  // 获取API密钥
  api.get("/admin/api-keys", async (c) => {
    const keys = await configService.getApiKeys();
    return c.json(keys);
  });

  // 生成API密钥
  api.post("/admin/api-keys", async (c) => {
    const { name } = await c.req.json();
    
    if (!name) {
      return c.json({ error: "名称不能为空" }, 400);
    }
    
    const key = await configService.generateApiKey(name);
    return c.json({ key, name });
  });

  // 禁用API密钥
  api.post("/admin/api-keys/:key/disable", async (c) => {
    const key = c.req.param("key");
    await configService.disableApiKey(key);
    return c.json({ success: true });
  });

  // 启用API密钥
  api.post("/admin/api-keys/:key/enable", async (c) => {
    const key = c.req.param("key");
    await configService.enableApiKey(key);
    return c.json({ success: true });
  });

  // 撤销API密钥
  api.delete("/admin/api-keys/:key", async (c) => {
    const key = c.req.param("key");
    await configService.revokeApiKey(key);
    return c.json({ success: true });
  });

  // 获取统计数据
  api.get("/admin/stats", async (c) => {
    const timeRange = c.req.query("range") as "hour" | "day" | "week" || "day";
    const stats = await statsService.getStats(timeRange);
    return c.json(stats);
  });

  // 获取最近请求
  api.get("/admin/recent-requests", async (c) => {
    const limit = parseInt(c.req.query("limit") || "50");
    const requests = await statsService.getRecentRequests(limit);
    return c.json(requests);
  });

  // 获取API密钥使用情况
  api.get("/admin/usage-by-key", async (c) => {
    const usage = await statsService.getUsageByAPIKey();
    return c.json(usage);
  });

  // 清理旧数据
  api.post("/admin/cleanup", async (c) => {
    const days = parseInt(c.req.query("days") || "30");
    await statsService.cleanupOldStats(days);
    return c.json({ success: true });
  });

  // 公共API：获取服务状态
  api.get("/status", async (c) => {
    return c.json({
      status: "ok",
      timestamp: new Date().toISOString(),
      version: "1.0.0"
    });
  });

  return api;
}