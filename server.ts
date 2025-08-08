/**
 * CIAO-CORS - 高性能CORS代理服务
 * 支持环境变量配置、请求限制、黑白名单、统计等功能
 */

// ==================== 配置管理模块 ====================
interface Config {
  port: number;
  allowedOrigins: string[];
  blockedIPs: string[];
  blockedDomains: string[];
  allowedDomains: string[];
  rateLimit: number;
  rateLimitWindow: number;
  concurrentLimit: number;
  totalConcurrentLimit: number;
  apiKey?: string;
  enableStats: boolean;
  enableLogging: boolean;
  logWebhook?: string;
  maxUrlLength: number;
  timeout: number;
}

/**
 * 加载和解析环境变量配置
 * 支持JSON格式的复杂配置和简单的字符串配置
 */
function loadConfig(): Config {
  const parseArray = (str?: string): string[] => {
    if (!str) return [];
    try {
      return JSON.parse(str);
    } catch {
      return str.split(',').map(s => s.trim()).filter(Boolean);
    }
  };

  return {
    port: parseInt(Deno.env.get('PORT') || '3000'),
    allowedOrigins: parseArray(Deno.env.get('ALLOWED_ORIGINS')),
    blockedIPs: parseArray(Deno.env.get('BLOCKED_IPS')),
    blockedDomains: parseArray(Deno.env.get('BLOCKED_DOMAINS')),
    allowedDomains: parseArray(Deno.env.get('ALLOWED_DOMAINS')),
    rateLimit: parseInt(Deno.env.get('RATE_LIMIT') || '60'),
    rateLimitWindow: parseInt(Deno.env.get('RATE_LIMIT_WINDOW') || '60000'),
    concurrentLimit: parseInt(Deno.env.get('CONCURRENT_LIMIT') || '10'),
    totalConcurrentLimit: parseInt(Deno.env.get('TOTAL_CONCURRENT_LIMIT') || '1000'),
    apiKey: Deno.env.get('API_KEY'),
    enableStats: Deno.env.get('ENABLE_STATS') === 'true',
    enableLogging: Deno.env.get('ENABLE_LOGGING') !== 'false',
    logWebhook: Deno.env.get('LOG_WEBHOOK'),
    maxUrlLength: parseInt(Deno.env.get('MAX_URL_LENGTH') || '2048'),
    timeout: parseInt(Deno.env.get('TIMEOUT') || '30000')
  };
}

// ==================== 限制和安全模块 ====================
class RateLimiter {
  private requests: Map<string, number[]> = new Map();
  private windowMs: number;
  private maxRequests: number;

  constructor(windowMs: number, maxRequests: number) {
    this.windowMs = windowMs;
    this.maxRequests = maxRequests;
    
    // 定期清理过期记录
    setInterval(() => this.cleanup(), Math.min(windowMs, 60000));
  }

  checkLimit(ip: string): boolean {
    const now = Date.now();
    const requests = this.requests.get(ip) || [];
    
    // 移除过期的请求记录
    const validRequests = requests.filter(time => now - time < this.windowMs);
    
    if (validRequests.length >= this.maxRequests) {
      return false;
    }
    
    validRequests.push(now);
    this.requests.set(ip, validRequests);
    return true;
  }

  cleanup(): void {
    const now = Date.now();
    for (const [ip, requests] of this.requests.entries()) {
      const validRequests = requests.filter(time => now - time < this.windowMs);
      if (validRequests.length === 0) {
        this.requests.delete(ip);
      } else {
        this.requests.set(ip, validRequests);
      }
    }
  }

  getStats(): { totalIPs: number; totalRequests: number } {
    return {
      totalIPs: this.requests.size,
      totalRequests: Array.from(this.requests.values()).reduce((sum, reqs) => sum + reqs.length, 0)
    };
  }
}

class ConcurrencyLimiter {
  private perIpCount: Map<string, number> = new Map();
  private totalCount = 0;
  private perIpLimit: number;
  private totalLimit: number;

  constructor(perIpLimit: number, totalLimit: number) {
    this.perIpLimit = perIpLimit;
    this.totalLimit = totalLimit;
  }

  acquire(ip: string): boolean {
    const currentPerIp = this.perIpCount.get(ip) || 0;
    
    if (currentPerIp >= this.perIpLimit || this.totalCount >= this.totalLimit) {
      return false;
    }
    
    this.perIpCount.set(ip, currentPerIp + 1);
    this.totalCount++;
    return true;
  }

  release(ip: string): void {
    const currentPerIp = this.perIpCount.get(ip) || 0;
    if (currentPerIp > 0) {
      this.perIpCount.set(ip, currentPerIp - 1);
      this.totalCount = Math.max(0, this.totalCount - 1);
      
      if (this.perIpCount.get(ip) === 0) {
        this.perIpCount.delete(ip);
      }
    }
  }

  getStats(): { perIpCount: Map<string, number>; totalCount: number } {
    return {
      perIpCount: new Map(this.perIpCount),
      totalCount: this.totalCount
    };
  }
}

/**
 * 安全检查：验证目标URL和请求来源
 */
function validateRequest(url: string, ip: string, config: Config, origin?: string | null): { valid: boolean; reason?: string } {
  // 检查IP黑名单
  if (config.blockedIPs.length > 0 && config.blockedIPs.includes(ip)) {
    return { valid: false, reason: 'IP blocked' };
  }

  // 检查URL长度
  if (url.length > config.maxUrlLength) {
    return { valid: false, reason: 'URL too long' };
  }

  // 解析目标域名
  let targetDomain: string;
  try {
    const targetUrl = new URL(fixUrl(url));
    targetDomain = targetUrl.hostname.toLowerCase();
  } catch {
    return { valid: false, reason: 'Invalid URL' };
  }

  // 检查域名黑名单
  if (config.blockedDomains.length > 0) {
    const isBlocked = config.blockedDomains.some(blocked => 
      targetDomain === blocked || targetDomain.endsWith('.' + blocked)
    );
    if (isBlocked) {
      return { valid: false, reason: 'Domain blocked' };
    }
  }

  // 检查域名白名单
  if (config.allowedDomains.length > 0) {
    const isAllowed = config.allowedDomains.some(allowed => 
      targetDomain === allowed || targetDomain.endsWith('.' + allowed)
    );
    if (!isAllowed) {
      return { valid: false, reason: 'Domain not allowed' };
    }
  }

  // 检查来源白名单
  if (config.allowedOrigins.length > 0 && origin) {
    if (!config.allowedOrigins.includes('*') && !config.allowedOrigins.includes(origin)) {
      return { valid: false, reason: 'Origin not allowed' };
    }
  }

  // 检查恶意URL模式
  const maliciousPatterns = [
    /javascript:/i,
    /data:/i,
    /vbscript:/i,
    /file:/i,
    /ftp:/i
  ];
  
  if (maliciousPatterns.some(pattern => pattern.test(url))) {
    return { valid: false, reason: 'Malicious URL pattern' };
  }

  return { valid: true };
}

// ==================== 请求处理模块 ====================
/**
 * 修复和标准化URL格式
 */
function fixUrl(url: string): string {
  if (url.includes("://")) {
    return url;
  } else if (url.includes(':/')) {
    return url.replace(':/', '://');
  } else {
    // 默认使用HTTPS协议，更安全
    return "https://" + url;
  }
}

/**
 * 构建代理请求的headers
 */
function buildProxyHeaders(originalHeaders: Headers): Record<string, string> {
  const proxyHeaders: Record<string, string> = {};
  const dropHeaders = [
    'content-length', 'host', 'connection', 'keep-alive',
    'proxy-authenticate', 'proxy-authorization', 'te', 'trailers',
    'transfer-encoding', 'upgrade', 'cf-connecting-ip', 'cf-ray',
    'cf-visitor', 'cf-ipcountry'
  ];

  for (const [key, value] of originalHeaders.entries()) {
    const lowerKey = key.toLowerCase();
    if (!dropHeaders.includes(lowerKey)) {
      proxyHeaders[key] = value;
    }
  }

  // 添加代理相关headers
  proxyHeaders['User-Agent'] = proxyHeaders['User-Agent'] || 'CIAO-CORS/1.0';
  
  return proxyHeaders;
}

/**
 * 处理请求body，支持各种content-type
 */
async function processRequestBody(request: Request): Promise<any> {
  if (!['POST', 'PUT', 'PATCH', 'DELETE'].includes(request.method)) {
    return undefined;
  }

  const contentType = request.headers.get('content-type')?.toLowerCase() || '';

  try {
    if (contentType.includes('application/json')) {
      return JSON.stringify(await request.json());
    } else if (contentType.includes('application/x-www-form-urlencoded') || 
               contentType.includes('multipart/form-data')) {
      return await request.formData();
    } else if (contentType.includes('text/')) {
      return await request.text();
    } else {
      return await request.arrayBuffer();
    }
  } catch {
    return await request.arrayBuffer();
  }
}

/**
 * 执行代理请求
 */
async function performProxy(request: Request, targetUrl: string, config: Config): Promise<Response> {
  const headers = buildProxyHeaders(request.headers);
  const body = await processRequestBody(request);

  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), config.timeout);

  try {
    const response = await fetch(targetUrl, {
      method: request.method,
      headers,
      body,
      signal: controller.signal,
      redirect: 'follow',
      // 增加缓存控制
      cache: request.headers.get('cache-control')?.includes('no-cache') ? 'no-cache' : 'default'
    });

    clearTimeout(timeoutId);
    return response;
  } catch (error) {
    clearTimeout(timeoutId);
    
    if (error instanceof Error && error.name === 'AbortError') {
      throw new Error('Request timeout');
    }
    throw error;
  }
}

// ==================== 统计和日志模块 ====================
interface RequestStats {
  totalRequests: number;
  successfulRequests: number;
  failedRequests: number;
  topDomains: Map<string, number>;
  topIPs: Map<string, number>;
  statusCodes: Map<number, number>;
  averageResponseTime: number;
  startTime: number;
}

class StatsCollector {
  private stats: RequestStats;
  private responseTimes: number[] = [];
  // 添加存储周期性统计的数组
  private hourlyStats: { timestamp: number; requests: number }[] = [];

  constructor() {
    this.stats = {
      totalRequests: 0,
      successfulRequests: 0,
      failedRequests: 0,
      topDomains: new Map(),
      topIPs: new Map(),
      statusCodes: new Map(),
      averageResponseTime: 0,
      startTime: Date.now()
    };
    
    // 每小时记录一次统计数据
    setInterval(() => this.recordHourlyStat(), 3600000);
  }

  recordRequest(ip: string, domain: string, statusCode: number, responseTime: number, success: boolean): void {
    this.stats.totalRequests++;
    
    if (success) {
      this.stats.successfulRequests++;
    } else {
      this.stats.failedRequests++;
    }

    // 记录域名统计
    const domainCount = this.stats.topDomains.get(domain) || 0;
    this.stats.topDomains.set(domain, domainCount + 1);

    // 记录IP统计
    const ipCount = this.stats.topIPs.get(ip) || 0;
    this.stats.topIPs.set(ip, ipCount + 1);

    // 记录状态码统计
    const statusCount = this.stats.statusCodes.get(statusCode) || 0;
    this.stats.statusCodes.set(statusCode, statusCount + 1);

    // 记录响应时间
    this.responseTimes.push(responseTime);
    if (this.responseTimes.length > 1000) {
      this.responseTimes.shift();
    }
    this.stats.averageResponseTime = this.responseTimes.reduce((a, b) => a + b, 0) / this.responseTimes.length;
  }

  // 记录每小时统计数据
  private recordHourlyStat(): void {
    this.hourlyStats.push({
      timestamp: Date.now(),
      requests: this.stats.totalRequests
    });
    
    // 保留最近24小时的数据
    if (this.hourlyStats.length > 24) {
      this.hourlyStats.shift();
    }
  }

  getStats(): RequestStats & { hourlyStats?: { timestamp: number; requests: number }[] } {
    const result = {
      ...this.stats,
      topDomains: new Map(Array.from(this.stats.topDomains.entries())
        .sort((a, b) => b[1] - a[1]).slice(0, 10)),
      topIPs: new Map(Array.from(this.stats.topIPs.entries())
        .sort((a, b) => b[1] - a[1]).slice(0, 10)),
      hourlyStats: this.hourlyStats
    };
    return result;
  }

  reset(): void {
    this.stats = {
      totalRequests: 0,
      successfulRequests: 0,
      failedRequests: 0,
      topDomains: new Map(),
      topIPs: new Map(),
      statusCodes: new Map(),
      averageResponseTime: 0,
      startTime: Date.now()
    };
    this.responseTimes = [];
    // 保留历史统计数据
    // this.hourlyStats = [];
  }
}

class Logger {
  private enableConsole: boolean;
  private webhookUrl?: string;
  // 添加日志缓冲区，减少I/O操作
  private logBuffer: string[] = [];
  private bufferSize = 10;
  private bufferTimer: number | null = null;

  constructor(enableConsole: boolean, webhookUrl?: string) {
    this.enableConsole = enableConsole;
    this.webhookUrl = webhookUrl;
    
    // 定期刷新日志缓冲区
    if (this.webhookUrl) {
      this.bufferTimer = setInterval(() => this.flushLogBuffer(), 30000) as unknown as number;
    }
  }

  logRequest(request: Request, response: Response, proxyUrl?: string, responseTime?: number): void {
    if (!this.enableConsole && !this.webhookUrl) return;

    const logData = {
      timestamp: new Date().toISOString(),
      method: request.method,
      url: new URL(request.url).pathname,
      proxyUrl,
      statusCode: response.status,
      responseTime,
      userAgent: request.headers.get('user-agent'),
      referer: request.headers.get('referer'),
      ip: this.getClientIP(request)
    };

    if (this.enableConsole) {
      console.log(`[${logData.timestamp}] ${logData.method} ${logData.url} -> ${logData.proxyUrl} (${logData.statusCode}) ${logData.responseTime}ms`);
    }

    if (this.webhookUrl) {
      // 将日志添加到缓冲区
      this.logBuffer.push(JSON.stringify(logData));
      
      // 如果缓冲区已满，立即发送
      if (this.logBuffer.length >= this.bufferSize) {
        this.flushLogBuffer();
      }
    }
  }

  logError(error: Error, context?: any): void {
    if (!this.enableConsole && !this.webhookUrl) return;

    const logData = {
      timestamp: new Date().toISOString(),
      level: 'ERROR',
      message: error.message,
      stack: error.stack,
      context
    };

    if (this.enableConsole) {
      console.error(`[${logData.timestamp}] ERROR: ${error.message}`, context);
    }

    if (this.webhookUrl) {
      fetch(this.webhookUrl, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(logData)
      }).catch(() => {});
    }
  }

  // 批量发送日志到webhook
  private flushLogBuffer(): void {
    if (this.webhookUrl && this.logBuffer.length > 0) {
      const logs = this.logBuffer;
      this.logBuffer = [];
      
      fetch(this.webhookUrl, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ logs })
      }).catch(() => {});
    }
  }

  // 清理资源
  cleanup(): void {
    if (this.bufferTimer !== null) {
      clearInterval(this.bufferTimer);
      this.bufferTimer = null;
      this.flushLogBuffer();
    }
  }

  private getClientIP(request: Request): string {
    return request.headers.get('cf-connecting-ip') ||
           request.headers.get('x-forwarded-for')?.split(',')[0]?.trim() ||
           request.headers.get('x-real-ip') ||
           'unknown';
  }
}

// ==================== 主服务模块 ====================
class CiaoCorsServer {
  private config: Config;
  private rateLimiter: RateLimiter;
  private concurrencyLimiter: ConcurrencyLimiter;
  private statsCollector: StatsCollector;
  private logger: Logger;
  // 添加简单缓存
  private responseCache: Map<string, { response: Response, timestamp: number }> = new Map();
  private cacheTTL = 60000; // 1分钟缓存
  
  constructor() {
    this.config = loadConfig();
    this.rateLimiter = new RateLimiter(this.config.rateLimitWindow, this.config.rateLimit);
    this.concurrencyLimiter = new ConcurrencyLimiter(this.config.concurrentLimit, this.config.totalConcurrentLimit);
    this.statsCollector = new StatsCollector();
    this.logger = new Logger(this.config.enableLogging, this.config.logWebhook);
    
    // 定期清理缓存
    setInterval(() => this.cleanupCache(), 30000);
  }

  async handleRequest(request: Request): Promise<Response> {
    const startTime = Date.now();
    const clientIP = this.getClientIP(request);
    const origin = request.headers.get('origin');
    
    try {
      // 处理OPTIONS预检请求
      if (request.method === 'OPTIONS') {
        return this.handlePreflight(request);
      }

      // 解析目标URL
      const url = new URL(request.url);
      let targetPath = decodeURIComponent(url.pathname.substring(1));
      
      // 处理管理API
      if (targetPath.startsWith('_api/')) {
        return this.handleManagementApi(request, targetPath);
      }

      // 验证基本URL格式
      if (targetPath.length < 3 || !targetPath.includes('.') || 
          targetPath === 'favicon.ico' || targetPath === 'robots.txt') {
        return this.createErrorResponse(400, 'Invalid URL format', {
          usage: 'https://your-domain.com/{target-url}',
          example: 'https://your-domain.com/httpbin.org/get'
        });
      }

      // 检查请求频率限制
      if (!this.rateLimiter.checkLimit(clientIP)) {
        return this.createErrorResponse(429, 'Rate limit exceeded', {
          retryAfter: Math.ceil(this.config.rateLimitWindow / 1000)
        });
      }

      // 检查并发限制
      if (!this.concurrencyLimiter.acquire(clientIP)) {
        return this.createErrorResponse(503, 'Concurrency limit exceeded', {
          retryAfter: 5
        });
      }

      let response: Response;
      let success = false;
      
      try {
        // 安全验证
        const validation = validateRequest(targetPath, clientIP, this.config, origin || undefined);
        if (!validation.valid) {
          return this.createErrorResponse(403, validation.reason || 'Request blocked');
        }

        // 执行代理请求
        const targetUrl = fixUrl(targetPath);
        
        // 检查GET请求的缓存
        const cacheKey = `${request.method}:${targetUrl}`;
        const cachedResponse = request.method === 'GET' ? this.responseCache.get(cacheKey) : undefined;
        
        if (cachedResponse && (Date.now() - cachedResponse.timestamp < this.cacheTTL)) {
          // 返回缓存的响应副本
          const cachedBody = await cachedResponse.response.clone().arrayBuffer();
          const cachedHeaders = new Headers(cachedResponse.response.headers);
          
          response = new Response(cachedBody, {
            status: cachedResponse.response.status,
            statusText: cachedResponse.response.statusText,
            headers: this.buildCorsHeaders(cachedHeaders, origin || undefined)
          });
          
          success = response.status < 400;
        } else {
          // 执行新请求
          const proxyResponse = await performProxy(request, targetUrl, this.config);
          
          // 构建响应
          response = new Response(proxyResponse.body, {
            status: proxyResponse.status,
            statusText: proxyResponse.statusText,
            headers: this.buildCorsHeaders(proxyResponse.headers, origin || undefined)
          });
          
          success = proxyResponse.status < 400;
          
          // 缓存GET请求的成功响应
          if (request.method === 'GET' && success) {
            this.responseCache.set(cacheKey, {
              response: response.clone(),
              timestamp: Date.now()
            });
          }
        }
        
        // 记录统计
        if (this.config.enableStats) {
          const domain = new URL(targetUrl).hostname;
          const responseTime = Date.now() - startTime;
          this.statsCollector.recordRequest(clientIP, domain, response.status, responseTime, success);
        }

        // 记录日志
        this.logger.logRequest(request, response, targetUrl, Date.now() - startTime);
        
        return response;
        
      } finally {
        this.concurrencyLimiter.release(clientIP);
      }

    } catch (error) {
      this.logger.logError(error as Error, { url: request.url, ip: clientIP });
      
      if (this.config.enableStats) {
        this.statsCollector.recordRequest(clientIP, 'error', 500, Date.now() - startTime, false);
      }
      
      return this.createErrorResponse(500, 'Proxy error', { 
        message: error instanceof Error ? error.message : 'Unknown error' 
      });
    }
  }

  // 清理过期缓存
  private cleanupCache(): void {
    const now = Date.now();
    for (const [key, cached] of this.responseCache.entries()) {
      if (now - cached.timestamp > this.cacheTTL) {
        this.responseCache.delete(key);
      }
    }
  }

  handlePreflight(request: Request): Response {
    const origin = request.headers.get('origin');
    const headers = this.buildCorsHeaders(new Headers(), origin || undefined);
    
    // 添加请求的自定义头
    const requestHeaders = request.headers.get('access-control-request-headers');
    if (requestHeaders) {
      headers.set('Access-Control-Allow-Headers', 
        `${headers.get('Access-Control-Allow-Headers')}, ${requestHeaders}`);
    }
    
    return new Response(null, {
      status: 204,
      headers
    });
  }

  handleManagementApi(request: Request, path: string): Response {
    // API密钥验证
    if (this.config.apiKey) {
      const authHeader = request.headers.get('authorization');
      const providedKey = authHeader?.replace('Bearer ', '') || 
                         new URL(request.url).searchParams.get('key');
      
      if (providedKey !== this.config.apiKey) {
        return this.createErrorResponse(401, 'Invalid API key');
      }
    }

    const apiPath = path.substring(5); // 移除 '_api/' 前缀

    switch (apiPath) {
      case 'stats':
        if (!this.config.enableStats) {
          return this.createErrorResponse(404, 'Stats disabled');
        }
        const stats = this.statsCollector.getStats();
        const rateLimiterStats = this.rateLimiter.getStats();
        const concurrencyStats = this.concurrencyLimiter.getStats();
        
        return new Response(JSON.stringify({
          stats: {
            ...stats,
            topDomains: Object.fromEntries(stats.topDomains),
            topIPs: Object.fromEntries(stats.topIPs),
            statusCodes: Object.fromEntries(stats.statusCodes),
            hourlyStats: stats.hourlyStats
          },
          rateLimiter: rateLimiterStats,
          concurrency: {
            totalCount: concurrencyStats.totalCount,
            activeIPs: concurrencyStats.perIpCount.size
          },
          cache: {
            size: this.responseCache.size
          },
          uptime: Date.now() - stats.startTime,
          version: '1.1.0'
        }, null, 2), {
          headers: { 'Content-Type': 'application/json' }
        });

      case 'health':
        return new Response(JSON.stringify({
          status: 'healthy',
          timestamp: new Date().toISOString(),
          version: '1.1.0',
          memory: Deno.memoryUsage ? {
            rss: Deno.memoryUsage().rss,
            heapTotal: Deno.memoryUsage().heapTotal,
            heapUsed: Deno.memoryUsage().heapUsed
          } : undefined
        }), {
          headers: { 'Content-Type': 'application/json' }
        });

      case 'config':
        // 返回脱敏的配置信息
        const safeConfig = { ...this.config };
        if (safeConfig.apiKey) safeConfig.apiKey = '***';
        if (safeConfig.logWebhook) safeConfig.logWebhook = '***';
        
        return new Response(JSON.stringify(safeConfig, null, 2), {
          headers: { 'Content-Type': 'application/json' }
        });

      case 'reset-stats':
        if (!this.config.enableStats) {
          return this.createErrorResponse(404, 'Stats disabled');
        }
        this.statsCollector.reset();
        return new Response(JSON.stringify({
          success: true,
          message: 'Statistics reset successfully'
        }), {
          headers: { 'Content-Type': 'application/json' }
        });

      case 'clear-cache':
        const cacheSize = this.responseCache.size;
        this.responseCache.clear();
        return new Response(JSON.stringify({
          success: true,
          message: `Cache cleared successfully (${cacheSize} entries)`
        }), {
          headers: { 'Content-Type': 'application/json' }
        });

      default:
        return this.createErrorResponse(404, 'API endpoint not found');
    }
  }

  private buildCorsHeaders(originalHeaders: Headers, origin?: string): Headers {
    const headers = new Headers();

    // 复制原始响应头（除了一些需要过滤的）
    const skipHeaders = ['access-control-allow-origin', 'access-control-allow-methods', 
                        'access-control-allow-headers', 'access-control-expose-headers'];
    
    for (const [key, value] of originalHeaders.entries()) {
      if (!skipHeaders.includes(key.toLowerCase())) {
        headers.set(key, value);
      }
    }

    // 设置CORS头
    if (this.config.allowedOrigins.length > 0) {
      if (this.config.allowedOrigins.includes('*')) {
        headers.set('Access-Control-Allow-Origin', '*');
      } else if (origin && this.config.allowedOrigins.includes(origin)) {
        headers.set('Access-Control-Allow-Origin', origin);
        headers.set('Vary', 'Origin');
      }
    } else {
      headers.set('Access-Control-Allow-Origin', '*');
    }

    headers.set('Access-Control-Allow-Methods', 'GET, POST, PUT, PATCH, DELETE, OPTIONS');
    headers.set('Access-Control-Allow-Headers', 
      'Accept, Authorization, Cache-Control, Content-Type, DNT, If-Modified-Since, Keep-Alive, Origin, User-Agent, X-Requested-With, Token, x-access-token');
    headers.set('Access-Control-Expose-Headers', '*');
    headers.set('Access-Control-Max-Age', '86400');

    return headers;
  }

  createErrorResponse(code: number, message: string, details?: any): Response {
    const body = {
      error: true,
      code,
      message,
      timestamp: new Date().toISOString(),
      ...details
    };

    return new Response(JSON.stringify(body, null, 2), {
      status: code,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
        ...(details?.retryAfter ? { 'Retry-After': String(details.retryAfter) } : {})
      }
    });
  }

  private getClientIP(request: Request): string {
    return request.headers.get('cf-connecting-ip') ||
           request.headers.get('x-forwarded-for')?.split(',')[0]?.trim() ||
           request.headers.get('x-real-ip') ||
           'unknown';
  }
  
  // 清理资源
  cleanup(): void {
    this.logger.cleanup();
    this.responseCache.clear();
  }
}

// ==================== 服务启动模块 ====================
/**
 * 主函数：启动服务
 * 支持Deno Deploy和本地运行
 */
async function main() {
  const config = loadConfig();
  const server = new CiaoCorsServer();

  console.log(`
====================================================
  🚀 CIAO-CORS Server v1.1.0
====================================================
  📌 Port: ${config.port}
  📊 Stats: ${config.enableStats ? 'enabled' : 'disabled'}
  📝 Logging: ${config.enableLogging ? 'enabled' : 'disabled'}
  ⏱️ Rate limit: ${config.rateLimit} requests per ${config.rateLimitWindow / 1000}s
  🔄 Concurrent limit: ${config.concurrentLimit} per IP, ${config.totalConcurrentLimit} total
  🔒 API key: ${config.apiKey ? 'configured' : 'not set'}
====================================================
  `);
  
  if (config.allowedDomains.length > 0) {
    console.log(`🔒 Domain whitelist: ${config.allowedDomains.length} domains`);
  }
  if (config.blockedDomains.length > 0) {
    console.log(`🚫 Domain blacklist: ${config.blockedDomains.length} domains`);
  }

  // 捕获退出信号
  const handleShutdown = () => {
    console.log("💤 Shutting down gracefully...");
    server.cleanup();
    Deno.exit(0);
  };

  // 处理退出信号
  if (Deno.addSignalListener) {
    try {
      Deno.addSignalListener("SIGINT", handleShutdown);
      Deno.addSignalListener("SIGTERM", handleShutdown);
    } catch (e) {
      console.warn("无法注册信号处理程序:", e);
    }
  }

  const handler = (request: Request) => server.handleRequest(request);

  // 启动HTTP服务器
  try {
    await Deno.serve({ port: config.port }, handler);
  } catch (error) {
    console.error('Failed to start server:', error);
    Deno.exit(1);
  }
}

/**
 * Deno Deploy兼容的默认导出
 */
export default {
  async fetch(request: Request, env: any, ctx: any): Promise<Response> {
    // 为Deno Deploy环境设置环境变量
    if (env) {
      for (const [key, value] of Object.entries(env)) {
        try {
          Deno.env.set(key, String(value));
        } catch {
          // Deno Deploy可能不支持设置环境变量，忽略错误
        }
      }
    }

    const server = new CiaoCorsServer();
    
    // 如果提供了ctx，注册请求完成后的清理函数
    if (ctx && typeof ctx.waitUntil === 'function') {
      ctx.waitUntil(async () => {
        // 延迟一段时间再清理，确保请求处理完毕
        await new Promise(r => setTimeout(r, 100));
        server.cleanup();
      });
    }
    
    return server.handleRequest(request);
  }
};

// 如果直接运行，启动服务
if (import.meta.main) {
  main();
}
