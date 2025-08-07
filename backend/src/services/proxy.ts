import { Context } from "@hono/hono";
import { ConfigService } from "./config.ts";
import { StatsService } from "./stats.ts";

export class ProxyService {
  constructor(
    private configService: ConfigService,
    private statsService: StatsService
  ) {}

  async handleRequest(c: Context, targetUrl: string) {
    const startTime = Date.now();
    const clientIP = c.req.header("x-forwarded-for") || c.req.header("x-real-ip") || "unknown";
    const userAgent = c.req.header("user-agent") || "";
    const apiKey = c.req.header("x-api-key") || c.req.query("api_key");

    try {
      // 解码URL
      const decodedUrl = decodeURIComponent(targetUrl);
      
      // 验证URL格式
      if (!this.isValidUrl(decodedUrl)) {
        return c.json({ error: "无效的URL格式" }, 400);
      }

      const url = new URL(decodedUrl);

      // 安全检查
      const securityCheck = await this.performSecurityCheck(clientIP, url.hostname, apiKey);
      if (!securityCheck.allowed) {
        await this.statsService.recordRequest(clientIP, url.hostname, 403, Date.now() - startTime, userAgent, apiKey);
        return c.json({ error: securityCheck.reason }, 403);
      }

      // 速率限制检查
      const rateLimitCheck = await this.checkRateLimit(clientIP, apiKey);
      if (!rateLimitCheck.allowed) {
        await this.statsService.recordRequest(clientIP, url.hostname, 429, Date.now() - startTime, userAgent, apiKey);
        return c.json({ error: "请求频率过高，请稍后再试" }, 429);
      }

      // 构建请求
      const requestHeaders = new Headers(c.req.header());
      
      // 移除不需要的头部
      const headersToRemove = ["host", "origin", "referer"];
      headersToRemove.forEach(header => requestHeaders.delete(header));

      // 添加API Key到头部（如果存在）
      if (apiKey) {
        requestHeaders.set("x-api-key", apiKey);
      }

      // 构建请求选项
      const requestOptions: RequestInit = {
        method: c.req.method,
        headers: requestHeaders,
      };

      // 处理请求体
      if (["POST", "PUT", "PATCH", "DELETE"].includes(c.req.method)) {
        const contentType = c.req.header("content-type") || "";
        
        if (contentType.includes("application/json")) {
          requestOptions.body = JSON.stringify(await c.req.json());
        } else if (contentType.includes("application/x-www-form-urlencoded")) {
          requestOptions.body = await c.req.text();
        } else if (contentType.includes("multipart/form-data")) {
          requestOptions.body = await c.req.formData();
        } else {
          requestOptions.body = await c.req.arrayBuffer();
        }
      }

      // 发送请求
      const response = await fetch(url.toString(), requestOptions);
      
      // 记录统计
      await this.statsService.recordRequest(
        clientIP,
        url.hostname,
        response.status,
        Date.now() - startTime,
        userAgent,
        apiKey
      );

      // 构建响应
      const responseHeaders = new Headers(response.headers);
      
      // 添加CORS头部
      responseHeaders.set("access-control-allow-origin", "*");
      responseHeaders.set("access-control-allow-methods", "GET, POST, PUT, PATCH, DELETE, OPTIONS");
      responseHeaders.set("access-control-allow-headers", "Content-Type, Authorization, X-API-Key");
      
      // 移除可能影响的内容
      responseHeaders.delete("content-security-policy");
      responseHeaders.delete("x-frame-options");

      return new Response(response.body, {
        status: response.status,
        statusText: response.statusText,
        headers: responseHeaders,
      });

    } catch (error) {
      console.error("代理请求失败:", error);
      await this.statsService.recordRequest(clientIP, targetUrl, 500, Date.now() - startTime, userAgent, apiKey);
      return c.json({ error: "代理请求失败" }, 500);
    }
  }

  private isValidUrl(url: string): boolean {
    try {
      new URL(url);
      return true;
    } catch {
      return false;
    }
  }

  private async performSecurityCheck(clientIP: string, hostname: string, apiKey?: string): Promise<{ allowed: boolean; reason?: string }> {
    // 检查黑名单
    const isBlacklisted = await this.configService.isBlacklisted("ip", clientIP) ||
                         await this.configService.isBlacklisted("domain", hostname);
    
    if (isBlacklisted) {
      return { allowed: false, reason: "IP或域名已被加入黑名单" };
    }

    // 检查白名单
    const whitelistEnabled = await this.configService.getConfig("enable_whitelist") === "true";
    if (whitelistEnabled) {
      const isWhitelisted = await this.configService.isWhitelisted("ip", clientIP) ||
                           await this.configService.isWhitelisted("domain", hostname);
      
      if (!isWhitelisted) {
        return { allowed: false, reason: "IP或域名不在白名单中" };
      }
    }

    // 检查API Key
    if (apiKey) {
      const isValidKey = await this.configService.isValidApiKey(apiKey);
      if (!isValidKey) {
        return { allowed: false, reason: "无效的API密钥" };
      }
    }

    return { allowed: true };
  }

  private async checkRateLimit(clientIP: string, apiKey?: string): Promise<{ allowed: boolean }> {
    const maxRequestsPerMinute = parseInt(await this.configService.getConfig("max_requests_per_minute") || "100");
    const windowStart = new Date();
    windowStart.setSeconds(0, 0);

    const identifier = apiKey || clientIP;
    const type = apiKey ? "api_key" : "ip";

    const currentCount = await this.statsService.getRateLimitCount(type, identifier, windowStart);
    
    if (currentCount >= maxRequestsPerMinute) {
      return { allowed: false };
    }

    await this.statsService.incrementRateLimit(type, identifier, windowStart);
    return { allowed: true };
  }
}