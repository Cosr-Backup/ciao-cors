/**
 * CIAO-CORS - Comprehensive CORS Proxy with Web Management Interface
 * A complete CORS proxy solution with frontend UI, authentication, and advanced management features
 * Designed for deployment on Deno Deploy (dash.deno.com)
 */

// @ts-ignore: Deno global is available in Deno runtime
declare const Deno: any;

// ===== 类型定义 =====
interface ProxyConfig {
  allowedOrigins: string[];
  blockedOrigins: string[];
  allowedIPs: string[];
  blockedIPs: string[];
  rateLimit: {
    requestsPerMinute: number;
    maxConcurrent: number;
    perSourceLimit: number;
  };
  apiKeys: { [key: string]: { name: string; active: boolean; created: string } };
  requireAuth: boolean;
}

interface RequestLog {
  id: string;
  timestamp: string;
  method: string;
  url: string;
  proxyUrl: string;
  clientIP: string;
  userAgent: string;
  statusCode: number;
  responseTime: number;
  apiKey?: string;
}

interface UserSession {
  authenticated: boolean;
  loginTime: string;
  ip: string;
}

// ===== 全局配置和状态 =====
const DEFAULT_CONFIG: ProxyConfig = {
  allowedOrigins: ["*"],
  blockedOrigins: [],
  allowedIPs: [],
  blockedIPs: [],
  rateLimit: {
    requestsPerMinute: 99999,
    maxConcurrent: 99999,
    perSourceLimit: 99999
  },
  apiKeys: {},
  requireAuth: false
};

let config: ProxyConfig = { ...DEFAULT_CONFIG };
const requestLogs: RequestLog[] = [];
const rateLimitMap = new Map<string, { count: number; lastReset: number; concurrent: number }>();
const sessionMap = new Map<string, UserSession>();

// 管理员密码 (生产环境应使用环境变量)
const ADMIN_PASSWORD = Deno.env.get("ADMIN_PASSWORD") || "admin123";

// ===== 核心代理功能 =====

/**
 * 主要的 fetch 处理函数
 * 处理所有传入的请求，包括代理请求和管理界面请求
 */
async function handleRequest(request: Request): Promise<Response> {
  const url = new URL(request.url);
  const pathname = url.pathname;
  const clientIP = getClientIP(request);
  
  // 预检请求直接返回
  if (request.method === "OPTIONS") {
    return new Response(null, {
      status: 200,
      headers: createCORSHeaders(request)
    });
  }
  
  // 路由分发
  if (pathname.startsWith("/api/")) {
    return handleAPIRequest(request);
  } else if (pathname.startsWith("/admin")) {
    return handleAdminInterface(request);
  } else if (pathname === "/" || pathname === "/index.html") {
    return handleHomePage(request);
  } else if (pathname === "/login") {
    return handleLoginPage(request);
  } else if (pathname === "/favicon.ico" || pathname === "/robots.txt") {
    return new Response("Not Found", { status: 404 });
  } else {
    return handleProxyRequest(request);
  }
}

/**
 * 处理 CORS 代理请求
 * 核心代理逻辑，支持黑白名单、频率限制等
 */
async function handleProxyRequest(request: Request): Promise<Response> {
  const startTime = Date.now();
  const url = new URL(request.url);
  const clientIP = getClientIP(request);
  const userAgent = request.headers.get("user-agent") || "";
  const origin = request.headers.get("origin") || "";
  const apiKey = request.headers.get("x-api-key") || url.searchParams.get("key") || "";
  
  try {
    // 提取目标URL
    let targetUrl = url.pathname.substring(1); // 去掉开头的 /
    targetUrl = decodeURIComponent(targetUrl);
    
    // 检查URL有效性
    if (!targetUrl || targetUrl.length < 3 || !targetUrl.includes('.')) {
      return createErrorResponse(400, "Invalid target URL", {
        usage: "https://your-proxy.com/{target-url}",
        example: "https://your-proxy.com/https://api.example.com/data"
      });
    }
    
    targetUrl = fixUrl(targetUrl);
    
    // 安全验证
    if (config.requireAuth && !validateAPIKey(apiKey)) {
      return createErrorResponse(401, "Valid API key required");
    }
    
    if (!validateIP(clientIP)) {
      return createErrorResponse(403, "IP address not allowed");
    }
    
    if (!validateOrigin(origin)) {
      return createErrorResponse(403, "Origin not allowed");
    }
    
    // 频率限制检查
    const clientKey = apiKey || clientIP;
    const rateLimitResult = checkRateLimit(clientKey);
    if (!rateLimitResult.allowed) {
      return createErrorResponse(429, "Rate limit exceeded", { reason: rateLimitResult.reason });
    }
    
    // 更新频率限制计数
    updateRateLimit(clientKey);
    
    // 构建代理请求
    const proxyHeaders = new Headers();
    const skipHeaders = ['host', 'content-length', 'cf-connecting-ip', 'x-forwarded-for', 'x-real-ip'];
    
    for (const [key, value] of request.headers) {
      if (!skipHeaders.includes(key.toLowerCase()) && !key.startsWith('cf-')) {
        proxyHeaders.set(key, value);
      }
    }
    
    // 添加标识头部
    proxyHeaders.set('User-Agent', userAgent || 'CIAO-CORS-Proxy/1.0');
    
    const proxyOptions: RequestInit = {
      method: request.method,
      headers: proxyHeaders,
    };
    
    // 处理请求体
    if (["POST", "PUT", "PATCH", "DELETE"].includes(request.method)) {
      proxyOptions.body = request.body;
    }
    
    // 发起代理请求
    const response = await fetch(targetUrl, proxyOptions);
    
    // 创建响应头
    const responseHeaders = createCORSHeaders(request);
    
    // 复制响应头（排除一些不需要的）
    const skipResponseHeaders = ['content-encoding', 'content-length', 'transfer-encoding'];
    for (const [key, value] of response.headers) {
      if (!skipResponseHeaders.includes(key.toLowerCase())) {
        responseHeaders.set(key, value);
      }
    }
    
    const proxyResponse = new Response(response.body, {
      status: response.status,
      statusText: response.statusText,
      headers: responseHeaders
    });
    
    // 记录日志
    const responseTime = Date.now() - startTime;
    logRequest(request, proxyResponse, targetUrl, responseTime);
    
    // 更新频率限制（减少并发计数）
    updateRateLimit(clientKey, false);
    
    return proxyResponse;
    
  } catch (error) {
    console.error("Proxy error:", error);
    const responseTime = Date.now() - startTime;
    const errorResponse = createErrorResponse(502, "Proxy request failed", error.message);
    logRequest(request, errorResponse, undefined, responseTime);
    updateRateLimit(clientIP, false);
    return errorResponse;
  }
}

/**
 * 处理 API 请求
 * 管理配置、统计数据等的 RESTful API
 */
async function handleAPIRequest(request: Request): Promise<Response> {
  const url = new URL(request.url);
  const pathname = url.pathname;
  const method = request.method;
  
  // Auth endpoint should be accessible without session
  if (pathname === "/api/auth") {
    if (method === "POST") {
      try {
        const { password } = await request.json();
        if (password === ADMIN_PASSWORD) {
          const sessionId = generateUniqueId();
          const clientIP = getClientIP(request);
          sessionMap.set(sessionId, {
            authenticated: true,
            loginTime: new Date().toISOString(),
            ip: clientIP
          });
          console.log(`Login successful: Created session ${sessionId} for IP ${clientIP}`);
          return new Response(JSON.stringify({ success: true, sessionId }), {
            headers: { 
              "Content-Type": "application/json",
              "Set-Cookie": `session=${sessionId}; Path=/; HttpOnly; SameSite=Lax; Max-Age=86400`,
              ...Object.fromEntries(createCORSHeaders(request))
            }
          });
        } else {
          console.log(`Login failed: Invalid password attempt from ${getClientIP(request)}`);
          return createErrorResponse(401, "Invalid password");
        }
      } catch (error) {
        console.error("Login error:", error);
        return createErrorResponse(400, "Invalid request format", error.message);
      }
    } else if (method === "DELETE") {
      const sessionId = getCookieValue(request, "session");
      if (sessionId) {
        sessionMap.delete(sessionId);
      }
      return new Response(JSON.stringify({ success: true, message: "Logged out" }), {
        headers: { 
          "Content-Type": "application/json",
          "Set-Cookie": "session=; Path=/; HttpOnly; SameSite=Lax; Max-Age=0",
          ...Object.fromEntries(createCORSHeaders(request))
        }
      });
    }
  }
  
  // Session check endpoint - accessible without full auth
  if (pathname === "/api/session" && method === "GET") {
    const sessionValid = validateSession(request);
    return new Response(JSON.stringify({ 
      authenticated: sessionValid,
      timestamp: new Date().toISOString()
    }), {
      headers: { 
        "Content-Type": "application/json",
        ...Object.fromEntries(createCORSHeaders(request))
      }
    });
  }
  
  // All other API endpoints require authentication
  if (!validateSession(request)) {
    console.log(`Unauthorized API access attempt to ${pathname} from ${getClientIP(request)}`);
    return createErrorResponse(401, "Authentication required");
  }
  
  try {
    // 路由处理
    if (pathname === "/api/config") {
      if (method === "GET") {
        return new Response(JSON.stringify(config), {
          headers: { "Content-Type": "application/json", ...Object.fromEntries(createCORSHeaders(request)) }
        });
      } else if (method === "POST") {
        const newConfig = await request.json();
        config = { ...config, ...newConfig };
        return new Response(JSON.stringify({ success: true, config }), {
          headers: { "Content-Type": "application/json", ...Object.fromEntries(createCORSHeaders(request)) }
        });
      } else if (method === "DELETE") {
        config = { ...DEFAULT_CONFIG };
        return new Response(JSON.stringify({ success: true, message: "Config reset" }), {
          headers: { "Content-Type": "application/json", ...Object.fromEntries(createCORSHeaders(request)) }
        });
      }
    } else if (pathname === "/api/logs") {
      const limit = parseInt(url.searchParams.get("limit") || "100");
      const offset = parseInt(url.searchParams.get("offset") || "0");
      const logs = requestLogs.slice(offset, offset + limit);
      return new Response(JSON.stringify({ logs, total: requestLogs.length }), {
        headers: { "Content-Type": "application/json", ...Object.fromEntries(createCORSHeaders(request)) }
      });
    } else if (pathname === "/api/stats") {
      const stats = getStatistics();
      return new Response(JSON.stringify(stats), {
        headers: { "Content-Type": "application/json", ...Object.fromEntries(createCORSHeaders(request)) }
      });
    } else if (pathname === "/api/apikeys") {
      if (method === "POST") {
        const { name } = await request.json();
        const apiKey = generateUniqueId();
        config.apiKeys[apiKey] = {
          name: name || "Unnamed Key",
          active: true,
          created: new Date().toISOString()
        };
        return new Response(JSON.stringify({ success: true, apiKey, name }), {
          headers: { "Content-Type": "application/json", ...Object.fromEntries(createCORSHeaders(request)) }
        });
      } else if (method === "DELETE") {
        const { apiKey } = await request.json();
        delete config.apiKeys[apiKey];
        return new Response(JSON.stringify({ success: true, message: "API key deleted" }), {
          headers: { "Content-Type": "application/json", ...Object.fromEntries(createCORSHeaders(request)) }
        });
      } else if (method === "GET") {
        return new Response(JSON.stringify(config.apiKeys), {
          headers: { "Content-Type": "application/json", ...Object.fromEntries(createCORSHeaders(request)) }
        });
      }
    }
    
    return createErrorResponse(404, "API endpoint not found");
    
  } catch (error) {
    console.error("API error:", error);
    return createErrorResponse(500, "API request failed", error.message);
  }
}

/**
 * 处理管理界面请求
 * 返回管理界面的 HTML、CSS、JS
 */
async function handleAdminInterface(request: Request): Promise<Response> {
  // 需要验证登录状态
  if (!validateSession(request)) {
    return new Response("Unauthorized", { 
      status: 302, 
      headers: { "Location": "/login" } 
    });
  }
  
  const adminHTML = `<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>CIAO-CORS - 管理界面</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', system-ui, sans-serif; background: #f5f7fa; color: #2c3e50; }
        .container { max-width: 1200px; margin: 0 auto; padding: 20px; }
        .header { background: white; padding: 20px; border-radius: 8px; margin-bottom: 20px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .header h1 { color: #2c3e50; margin-bottom: 10px; }
        .nav { display: flex; gap: 20px; margin-top: 20px; }
        .nav button { padding: 10px 20px; border: none; border-radius: 4px; cursor: pointer; background: #3498db; color: white; }
        .nav button.active { background: #2980b9; }
        .nav button:hover { background: #2980b9; }
        .section { background: white; padding: 20px; border-radius: 8px; margin-bottom: 20px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); display: none; }
        .section.active { display: block; }
        .stats-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 20px; margin-bottom: 20px; }
        .stat-card { background: #ecf0f1; padding: 15px; border-radius: 4px; text-align: center; }
        .stat-number { font-size: 24px; font-weight: bold; color: #2980b9; }
        .form-group { margin-bottom: 15px; }
        .form-group label { display: block; margin-bottom: 5px; font-weight: 500; }
        .form-group input, .form-group textarea { width: 100%; padding: 8px; border: 1px solid #ddd; border-radius: 4px; }
        .btn { padding: 10px 20px; border: none; border-radius: 4px; cursor: pointer; margin-right: 10px; }
        .btn-primary { background: #3498db; color: white; }
        .btn-danger { background: #e74c3c; color: white; }
        .btn-success { background: #27ae60; color: white; }
        .table { width: 100%; border-collapse: collapse; margin-top: 10px; }
        .table th, .table td { padding: 10px; border: 1px solid #ddd; text-align: left; }
        .table th { background: #f8f9fa; }
        .logout { float: right; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🌐 CIAO-CORS 管理界面</h1>
            <p>全功能 CORS 代理服务管理控制台</p>
            <button class="btn btn-danger logout" onclick="logout()">退出登录</button>
            <div class="nav">
                <button class="nav-btn active" onclick="showSection('stats')">统计概览</button>
                <button class="nav-btn" onclick="showSection('config')">配置管理</button>
                <button class="nav-btn" onclick="showSection('logs')">请求日志</button>
                <button class="nav-btn" onclick="showSection('apikeys')">API密钥</button>
            </div>
        </div>

        <div id="stats" class="section active">
            <h2>📊 统计概览</h2>
            <div class="stats-grid" id="statsGrid">
                <div class="stat-card">
                    <div class="stat-number" id="totalRequests">-</div>
                    <div>总请求数</div>
                </div>
                <div class="stat-card">
                    <div class="stat-number" id="hourlyRequests">-</div>
                    <div>每小时请求</div>
                </div>
                <div class="stat-card">
                    <div class="stat-number" id="errorRate">-</div>
                    <div>错误率</div>
                </div>
                <div class="stat-card">
                    <div class="stat-number" id="avgResponseTime">-</div>
                    <div>平均响应时间(ms)</div>
                </div>
            </div>
        </div>

        <div id="config" class="section">
            <h2>⚙️ 配置管理</h2>
            <div class="form-group">
                <label>允许的来源域名（每行一个）</label>
                <textarea id="allowedOrigins" rows="3" placeholder="*\nhttps://example.com"></textarea>
            </div>
            <div class="form-group">
                <label>阻止的来源域名（每行一个）</label>
                <textarea id="blockedOrigins" rows="3"></textarea>
            </div>
            <div class="form-group">
                <label>每分钟请求限制</label>
                <input type="number" id="requestsPerMinute" placeholder="60">
            </div>
            <div class="form-group">
                <label>最大并发请求数</label>
                <input type="number" id="maxConcurrent" placeholder="10">
            </div>
            <div class="form-group">
                <label>
                    <input type="checkbox" id="requireAuth"> 要求API密钥认证
                </label>
            </div>
            <button class="btn btn-primary" onclick="saveConfig()">保存配置</button>
            <button class="btn btn-danger" onclick="resetConfig()">重置为默认</button>
        </div>

        <div id="logs" class="section">
            <h2>📝 请求日志</h2>
            <button class="btn btn-primary" onclick="refreshLogs()">刷新日志</button>
            <table class="table">
                <thead>
                    <tr>
                        <th>时间</th>
                        <th>方法</th>
                        <th>目标URL</th>
                        <th>客户端IP</th>
                        <th>状态码</th>
                        <th>响应时间</th>
                    </tr>
                </thead>
                <tbody id="logsTable">
                </tbody>
            </table>
        </div>

        <div id="apikeys" class="section">
            <h2>🔑 API密钥管理</h2>
            <div class="form-group">
                <label>密钥名称</label>
                <input type="text" id="newKeyName" placeholder="输入密钥名称">
                <button class="btn btn-success" onclick="createAPIKey()">创建新密钥</button>
            </div>
            <table class="table">
                <thead>
                    <tr>
                        <th>密钥名称</th>
                        <th>密钥</th>
                        <th>创建时间</th>
                        <th>状态</th>
                        <th>操作</th>
                    </tr>
                </thead>
                <tbody id="apiKeysTable">
                </tbody>
            </table>
        </div>
    </div>

    <script>
        function showSection(sectionId) {
            document.querySelectorAll('.section').forEach(s => s.classList.remove('active'));
            document.querySelectorAll('.nav-btn').forEach(b => b.classList.remove('active'));
            document.getElementById(sectionId).classList.add('active');
            event.target.classList.add('active');
            if (sectionId === 'stats') loadStats();
            if (sectionId === 'config') loadConfig();
            if (sectionId === 'logs') refreshLogs();
            if (sectionId === 'apikeys') loadAPIKeys();
        }

        async function loadStats() {
            try {
                const response = await fetch('/api/stats');
                const stats = await response.json();
                document.getElementById('totalRequests').textContent = stats.total.requests;
                document.getElementById('hourlyRequests').textContent = stats.hourly.requests;
                document.getElementById('errorRate').textContent = 
                    stats.total.requests > 0 ? Math.round(stats.total.errors / stats.total.requests * 100) + '%' : '0%';
                document.getElementById('avgResponseTime').textContent = stats.total.avgResponseTime;
            } catch (e) {
                console.error('Failed to load stats:', e);
            }
        }

        async function loadConfig() {
            try {
                const response = await fetch('/api/config');
                const config = await response.json();
                document.getElementById('allowedOrigins').value = config.allowedOrigins.join('\\n');
                document.getElementById('blockedOrigins').value = config.blockedOrigins.join('\\n');
                document.getElementById('requestsPerMinute').value = config.rateLimit.requestsPerMinute;
                document.getElementById('maxConcurrent').value = config.rateLimit.maxConcurrent;
                document.getElementById('requireAuth').checked = config.requireAuth;
            } catch (e) {
                console.error('Failed to load config:', e);
            }
        }

        async function saveConfig() {
            const newConfig = {
                allowedOrigins: document.getElementById('allowedOrigins').value.split('\\n').filter(x => x.trim()),
                blockedOrigins: document.getElementById('blockedOrigins').value.split('\\n').filter(x => x.trim()),
                rateLimit: {
                    requestsPerMinute: parseInt(document.getElementById('requestsPerMinute').value) || 60,
                    maxConcurrent: parseInt(document.getElementById('maxConcurrent').value) || 10
                },
                requireAuth: document.getElementById('requireAuth').checked
            };
            
            try {
                const response = await fetch('/api/config', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify(newConfig)
                });
                if (response.ok) {
                    alert('配置保存成功！');
                } else {
                    alert('配置保存失败！');
                }
            } catch (e) {
                alert('配置保存失败：' + e.message);
            }
        }

        async function resetConfig() {
            if (confirm('确定要重置配置为默认值吗？')) {
                try {
                    const response = await fetch('/api/config', { method: 'DELETE' });
                    if (response.ok) {
                        alert('配置已重置！');
                        loadConfig();
                    }
                } catch (e) {
                    alert('重置失败：' + e.message);
                }
            }
        }

        async function refreshLogs() {
            try {
                const response = await fetch('/api/logs?limit=50');
                const data = await response.json();
                const tbody = document.getElementById('logsTable');
                tbody.innerHTML = data.logs.map(log => \`
                    <tr>
                        <td>\${new Date(log.timestamp).toLocaleString()}</td>
                        <td>\${log.method}</td>
                        <td>\${log.proxyUrl || '-'}</td>
                        <td>\${log.clientIP}</td>
                        <td style="color: \${log.statusCode >= 400 ? '#e74c3c' : '#27ae60'}">\${log.statusCode}</td>
                        <td>\${log.responseTime}ms</td>
                    </tr>
                \`).join('');
            } catch (e) {
                console.error('Failed to load logs:', e);
            }
        }

        async function loadAPIKeys() {
            try {
                const response = await fetch('/api/apikeys');
                const apiKeys = await response.json();
                const tbody = document.getElementById('apiKeysTable');
                tbody.innerHTML = Object.entries(apiKeys).map(([key, info]) => \`
                    <tr>
                        <td>\${info.name}</td>
                        <td><code>\${key}</code></td>
                        <td>\${new Date(info.created).toLocaleString()}</td>
                        <td>\${info.active ? '✅ 活跃' : '❌ 禁用'}</td>
                        <td><button class="btn btn-danger" onclick="deleteAPIKey('\${key}')">删除</button></td>
                    </tr>
                \`).join('');
            } catch (e) {
                console.error('Failed to load API keys:', e);
            }
        }

        async function createAPIKey() {
            const name = document.getElementById('newKeyName').value.trim();
            if (!name) {
                alert('请输入密钥名称');
                return;
            }
            
            try {
                const response = await fetch('/api/apikeys', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ name })
                });
                const result = await response.json();
                if (response.ok) {
                    alert(\`API密钥创建成功！\\n密钥：\${result.apiKey}\`);
                    document.getElementById('newKeyName').value = '';
                    loadAPIKeys();
                } else {
                    alert('创建失败：' + result.message);
                }
            } catch (e) {
                alert('创建失败：' + e.message);
            }
        }

        async function deleteAPIKey(apiKey) {
            if (confirm('确定要删除这个API密钥吗？')) {
                try {
                    const response = await fetch('/api/apikeys', {
                        method: 'DELETE',
                        headers: { 'Content-Type': 'application/json' },
                        body: JSON.stringify({ apiKey })
                    });
                    if (response.ok) {
                        alert('API密钥已删除！');
                        loadAPIKeys();
                    }
                } catch (e) {
                    alert('删除失败：' + e.message);
                }
            }
        }

        async function logout() {
            try {
                await fetch('/api/auth', { method: 'DELETE' });
                window.location.href = '/login';
            } catch (e) {
                console.error('Logout failed:', e);
            }
        }

        // 初始化
        loadStats();
        setInterval(loadStats, 30000); // 每30秒刷新统计
    </script>
</body>
</html>`;

  return new Response(adminHTML, {
    headers: { 
      "Content-Type": "text/html; charset=utf-8",
      ...Object.fromEntries(createCORSHeaders(request))
    }
  });
}

/**
 * 处理首页请求
 * 返回项目介绍和使用说明页面
 */
async function handleHomePage(request: Request): Promise<Response> {
  const homeHTML = `<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>CIAO-CORS - 免费CORS代理服务</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { 
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', system-ui, sans-serif; 
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white; min-height: 100vh; 
        }
        .container { max-width: 1000px; margin: 0 auto; padding: 40px 20px; }
        .header { text-align: center; margin-bottom: 60px; }
        .header h1 { font-size: 3em; margin-bottom: 20px; text-shadow: 2px 2px 4px rgba(0,0,0,0.3); }
        .header p { font-size: 1.2em; opacity: 0.9; }
        .features { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 30px; margin-bottom: 60px; }
        .feature { background: rgba(255,255,255,0.1); padding: 30px; border-radius: 10px; backdrop-filter: blur(10px); }
        .feature h3 { margin-bottom: 15px; font-size: 1.3em; }
        .usage { background: rgba(255,255,255,0.1); padding: 40px; border-radius: 10px; margin-bottom: 40px; backdrop-filter: blur(10px); }
        .usage h2 { margin-bottom: 20px; }
        .code { background: rgba(0,0,0,0.3); padding: 15px; border-radius: 5px; font-family: 'Courier New', monospace; margin: 10px 0; overflow-x: auto; }
        .admin-btn { 
            display: inline-block; background: #27ae60; color: white; padding: 15px 30px; 
            border-radius: 5px; text-decoration: none; font-weight: bold; margin-top: 20px;
            transition: background 0.3s;
        }
        .admin-btn:hover { background: #229954; }
        .footer { text-align: center; margin-top: 60px; opacity: 0.8; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🌐 CIAO-CORS</h1>
            <p>免费、快速、安全的 CORS 代理服务</p>
            <p>解决跨域问题，让API调用变得简单</p>
        </div>

        <div class="features">
            <div class="feature">
                <h3>🚀 快速简单</h3>
                <p>只需在URL前添加代理地址，即可解决跨域问题。无需注册，立即使用。</p>
            </div>
            <div class="feature">
                <h3>🔒 安全可靠</h3>
                <p>支持IP白名单、API密钥认证、频率限制等安全措施，保护您的服务。</p>
            </div>
            <div class="feature">
                <h3>📊 监控统计</h3>
                <p>完整的请求日志和统计数据，让您了解服务使用情况。</p>
            </div>
            <div class="feature">
                <h3>⚙️ 灵活配置</h3>
                <p>支持黑白名单、频率限制、并发控制等多种配置选项。</p>
            </div>
        </div>

        <div class="usage">
            <h2>📖 使用说明</h2>
            <h3>基本用法</h3>
            <p>在您要请求的URL前面加上代理地址：</p>
            <div class="code">
                https://your-proxy.deno.dev/https://api.example.com/data
            </div>
            
            <h3>JavaScript 示例</h3>
            <div class="code">
// 原始请求（会有跨域问题）
fetch('https://api.example.com/data')

// 使用代理（解决跨域）
fetch('https://your-proxy.deno.dev/https://api.example.com/data')
            </div>

            <h3>使用 API Key（可选）</h3>
            <div class="code">
// 通过请求头
fetch('https://your-proxy.deno.dev/https://api.example.com/data', {
  headers: { 'X-API-Key': 'your-api-key' }
})

// 通过URL参数
fetch('https://your-proxy.deno.dev/https://api.example.com/data?key=your-api-key')
            </div>
        </div>

        <div style="text-align: center;">
            <a href="/admin" class="admin-btn">🔧 管理界面</a>
        </div>

        <div class="footer">
            <p>CIAO-CORS © 2025 | 基于 Deno Deploy 构建</p>
            <p>开源项目，欢迎贡献代码</p>
        </div>
    </div>
</body>
</html>`;

  return new Response(homeHTML, {
    headers: { 
      "Content-Type": "text/html; charset=utf-8",
      ...Object.fromEntries(createCORSHeaders(request))
    }
  });
}

/**
 * 处理登录页面请求
 * 返回登录界面和处理登录验证
 */
async function handleLoginPage(request: Request): Promise<Response> {
  const loginHTML = `<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>CIAO-CORS - 管理员登录</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { 
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', system-ui, sans-serif; 
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            display: flex; align-items: center; justify-content: center; min-height: 100vh;
        }
        .login-container { 
            background: rgba(255,255,255,0.1); padding: 40px; border-radius: 10px; 
            backdrop-filter: blur(10px); box-shadow: 0 8px 32px rgba(0,0,0,0.3);
            width: 100%; max-width: 400px;
        }
        .login-header { text-align: center; margin-bottom: 30px; color: white; }
        .login-header h1 { margin-bottom: 10px; }
        .form-group { margin-bottom: 20px; }
        .form-group label { display: block; margin-bottom: 8px; color: white; font-weight: 500; }
        .form-group input { 
            width: 100%; padding: 12px; border: none; border-radius: 5px; 
            background: rgba(255,255,255,0.9); font-size: 16px;
        }
        .btn { 
            width: 100%; padding: 12px; border: none; border-radius: 5px; 
            background: #27ae60; color: white; font-size: 16px; font-weight: bold;
            cursor: pointer; transition: background 0.3s;
        }
        .btn:hover { background: #229954; }
        .back-link { 
            display: block; text-align: center; margin-top: 20px; 
            color: rgba(255,255,255,0.8); text-decoration: none;
        }
        .back-link:hover { color: white; }
        .error { 
            background: rgba(231,76,60,0.8); color: white; padding: 10px; 
            border-radius: 5px; margin-bottom: 20px; display: none;
        }
        .success {
            background: rgba(39,174,96,0.8); color: white; padding: 10px;
            border-radius: 5px; margin-bottom: 20px; display: none;
        }
    </style>
</head>
<body>
    <div class="login-container">
        <div class="login-header">
            <h1>🔐 管理员登录</h1>
            <p>输入管理员密码访问管理界面</p>
        </div>
        
        <div id="error" class="error"></div>
        <div id="success" class="success"></div>
        
        <form id="loginForm" onsubmit="handleLogin(event)">
            <div class="form-group">
                <label for="password">管理员密码</label>
                <input type="password" id="password" name="password" required placeholder="请输入管理员密码">
            </div>
            <button type="submit" class="btn">登录</button>
        </form>
        
        <a href="/" class="back-link">← 返回首页</a>
    </div>

    <script>
        async function handleLogin(event) {
            event.preventDefault();
            
            const password = document.getElementById('password').value;
            const errorDiv = document.getElementById('error');
            const successDiv = document.getElementById('success');
            
            try {
                errorDiv.style.display = 'none';
                successDiv.style.display = 'none';
                
                const response = await fetch('/api/auth', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ password })
                });
                
                const result = await response.json();
                
                if (response.ok && result.success) {
                    successDiv.textContent = '登录成功，正在跳转...';
                    successDiv.style.display = 'block';
                    setTimeout(() => {
                        window.location.href = '/admin';
                    }, 1000);
                } else {
                    errorDiv.textContent = '密码错误，请重试';
                    errorDiv.style.display = 'block';
                    document.getElementById('password').value = '';
                }
            } catch (error) {
                errorDiv.textContent = '登录失败：' + error.message;
                errorDiv.style.display = 'block';
            }
        }
        
        // 检查会话状态
        async function checkSession() {
            try {
                const response = await fetch('/api/session');
                if (response.ok) {
                    const result = await response.json();
                    if (result.authenticated) {
                        window.location.href = '/admin';
                    }
                }
            } catch (e) {
                console.log('Session check failed, staying on login page');
            }
        }
        
        // 页面加载时检查会话
        checkSession();
    </script>
</body>
</html>`;

  return new Response(loginHTML, {
    headers: { 
      "Content-Type": "text/html; charset=utf-8",
      ...Object.fromEntries(createCORSHeaders(request))
    }
  });
}

// ===== 安全和验证模块 =====

/**
 * IP 地址验证
 * 检查 IP 是否在黑白名单中
 */
function validateIP(ip: string): boolean {
  // 如果有阻止列表，检查是否在其中
  if (config.blockedIPs.length > 0) {
    for (const blockedIP of config.blockedIPs) {
      if (ip === blockedIP || ip.startsWith(blockedIP.replace('*', ''))) {
        return false;
      }
    }
  }
  
  // 如果有允许列表，检查是否在其中
  if (config.allowedIPs.length > 0) {
    for (const allowedIP of config.allowedIPs) {
      if (allowedIP === "*" || ip === allowedIP || ip.startsWith(allowedIP.replace('*', ''))) {
        return true;
      }
    }
    return false; // 有白名单但不在其中
  }
  
  return true; // 没有限制则允许
}

/**
 * 域名/来源验证
 * 检查请求来源是否允许
 */
function validateOrigin(origin: string): boolean {
  if (!origin) return true; // 没有origin头部
  
  // 检查阻止列表
  if (config.blockedOrigins.length > 0) {
    for (const blockedOrigin of config.blockedOrigins) {
      if (origin.includes(blockedOrigin) || blockedOrigin === "*") {
        return false;
      }
    }
  }
  
  // 检查允许列表
  if (config.allowedOrigins.length > 0) {
    for (const allowedOrigin of config.allowedOrigins) {
      if (allowedOrigin === "*" || origin.includes(allowedOrigin)) {
        return true;
      }
    }
    return false; // 有白名单但不在其中
  }
  
  return true; // 没有限制则允许
}

/**
 * API Key 验证
 * 检查请求的 API Key 是否有效
 */
function validateAPIKey(apiKey: string): boolean {
  if (!apiKey) return false;
  const keyInfo = config.apiKeys[apiKey];
  return keyInfo && keyInfo.active;
}

/**
 * 用户会话验证
 * 检查管理界面的登录状态
 */
function validateSession(request: Request): boolean {
  const sessionId = getCookieValue(request, "session");
  if (!sessionId) {
    console.log("No session cookie found");
    return false;
  }
  
  const session = sessionMap.get(sessionId);
  if (!session || !session.authenticated) {
    console.log(`Invalid session: ${sessionId}`);
    return false;
  }
  
  // 检查会话是否过期（24小时）
  const loginTime = new Date(session.loginTime);
  const now = new Date();
  const hoursDiff = (now.getTime() - loginTime.getTime()) / (1000 * 60 * 60);
  
  if (hoursDiff > 24) {
    console.log(`Session expired: ${sessionId}`);
    sessionMap.delete(sessionId);
    return false;
  }
  
  return true;
}

// ===== 频率限制模块 =====

/**
 * 检查频率限制
 * 实现每分钟请求数和并发限制
 */
function checkRateLimit(clientKey: string): { allowed: boolean; reason?: string } {
  const now = Date.now();
  const oneMinute = 60 * 1000;
  
  let rateData = rateLimitMap.get(clientKey);
  if (!rateData) {
    rateData = { count: 0, lastReset: now, concurrent: 0 };
    rateLimitMap.set(clientKey, rateData);
  }
  
  // 重置计数器（每分钟）
  if (now - rateData.lastReset > oneMinute) {
    rateData.count = 0;
    rateData.lastReset = now;
  }
  
  // 检查每分钟请求限制
  if (rateData.count >= config.rateLimit.requestsPerMinute) {
    return { allowed: false, reason: "Requests per minute exceeded" };
  }
  
  // 检查并发限制
  if (rateData.concurrent >= config.rateLimit.maxConcurrent) {
    return { allowed: false, reason: "Concurrent requests exceeded" };
  }
  
  return { allowed: true };
}

/**
 * 更新频率限制计数器
 * 记录新的请求
 */
function updateRateLimit(clientKey: string, increment: boolean = true): void {
  let rateData = rateLimitMap.get(clientKey);
  if (!rateData) {
    rateData = { count: 0, lastReset: Date.now(), concurrent: 0 };
    rateLimitMap.set(clientKey, rateData);
  }
  
  if (increment) {
    rateData.count++;
    rateData.concurrent++;
  } else {
    rateData.concurrent = Math.max(0, rateData.concurrent - 1);
  }
}

/**
 * 清理过期的频率限制记录
 * 定期清理以节省内存
 */
function cleanupRateLimit(): void {
  const now = Date.now();
  const fiveMinutes = 5 * 60 * 1000;
  
  for (const [key, data] of rateLimitMap.entries()) {
    if (now - data.lastReset > fiveMinutes && data.concurrent === 0) {
      rateLimitMap.delete(key);
    }
  }
}

// ===== 日志和统计模块 =====

/**
 * 记录请求日志
 * 保存请求详情用于统计和监控
 */
function logRequest(request: Request, response: Response, proxyUrl?: string, responseTime?: number): void {
  const url = new URL(request.url);
  const clientIP = getClientIP(request);
  const userAgent = request.headers.get("user-agent") || "";
  const apiKey = request.headers.get("x-api-key") || url.searchParams.get("key") || undefined;
  
  const log: RequestLog = {
    id: generateUniqueId(),
    timestamp: new Date().toISOString(),
    method: request.method,
    url: request.url,
    proxyUrl: proxyUrl || "",
    clientIP,
    userAgent,
    statusCode: response.status,
    responseTime: responseTime || 0,
    apiKey
  };
  
  requestLogs.unshift(log); // 最新的在前面
  
  // 限制日志数量，避免内存过多占用
  if (requestLogs.length > 10000) {
    requestLogs.splice(5000); // 保留最新的5000条
  }
}

/**
 * 获取统计数据
 * 计算各种统计指标
 */
function getStatistics(): any {
  const now = Date.now();
  const oneHour = 60 * 60 * 1000;
  const oneDay = 24 * oneHour;
  
  const hourlyLogs = requestLogs.filter(log => 
    now - new Date(log.timestamp).getTime() < oneHour
  );
  const dailyLogs = requestLogs.filter(log => 
    now - new Date(log.timestamp).getTime() < oneDay
  );
  
  // 统计状态码
  const statusCodes = requestLogs.reduce((acc, log) => {
    acc[log.statusCode] = (acc[log.statusCode] || 0) + 1;
    return acc;
  }, {} as Record<number, number>);
  
  // 统计顶级域名
  const topDomains = requestLogs
    .filter(log => log.proxyUrl)
    .reduce((acc, log) => {
      try {
        const domain = new URL(log.proxyUrl).hostname;
        acc[domain] = (acc[domain] || 0) + 1;
      } catch (e) {
        // 忽略无效URL
      }
      return acc;
    }, {} as Record<string, number>);
  
  // 平均响应时间
  const avgResponseTime = requestLogs.length > 0 
    ? requestLogs.reduce((sum, log) => sum + log.responseTime, 0) / requestLogs.length 
    : 0;
  
  return {
    total: {
      requests: requestLogs.length,
      errors: requestLogs.filter(log => log.statusCode >= 400).length,
      avgResponseTime: Math.round(avgResponseTime)
    },
    hourly: {
      requests: hourlyLogs.length,
      errors: hourlyLogs.filter(log => log.statusCode >= 400).length
    },
    daily: {
      requests: dailyLogs.length,
      errors: dailyLogs.filter(log => log.statusCode >= 400).length
    },
    statusCodes,
    topDomains: Object.entries(topDomains)
      .sort(([,a], [,b]) => b - a)
      .slice(0, 10)
      .reduce((acc, [domain, count]) => {
        acc[domain] = count;
        return acc;
      }, {} as Record<string, number>),
    rateLimit: {
      activeClients: rateLimitMap.size,
      totalConcurrent: Array.from(rateLimitMap.values())
        .reduce((sum, data) => sum + data.concurrent, 0)
    },
    apiKeys: {
      total: Object.keys(config.apiKeys).length,
      active: Object.values(config.apiKeys).filter(key => key.active).length
    }
  };
}

/**
 * 清理旧日志
 * 防止日志占用过多内存
 */
function cleanupLogs(): void {
  const now = Date.now();
  const sevenDays = 7 * 24 * 60 * 60 * 1000;
  
  // 删除7天前的日志
  const cutoffTime = now - sevenDays;
  const originalLength = requestLogs.length;
  
  for (let i = requestLogs.length - 1; i >= 0; i--) {
    if (new Date(requestLogs[i].timestamp).getTime() < cutoffTime) {
      requestLogs.splice(i, 1);
    }
  }
  
  if (originalLength !== requestLogs.length) {
    console.log(`Cleaned up ${originalLength - requestLogs.length} old log entries`);
  }
}

// ===== 配置管理模块 =====

/**
 * 加载配置
 * 从环境变量或文件加载配置
 */
function loadConfig(): void {
  try {
    // 从环境变量加载配置
    const envConfig = Deno.env.get("CIAO_CORS_CONFIG");
    if (envConfig) {
      const parsedConfig = JSON.parse(envConfig);
      config = { ...DEFAULT_CONFIG, ...parsedConfig };
      console.log("✅ Configuration loaded from environment");
    } else {
      console.log("ℹ️ Using default configuration");
    }
    
    // 加载其他环境变量
    if (Deno.env.get("ALLOWED_ORIGINS")) {
      config.allowedOrigins = Deno.env.get("ALLOWED_ORIGINS")!.split(',').map(s => s.trim());
    }
    if (Deno.env.get("BLOCKED_ORIGINS")) {
      config.blockedOrigins = Deno.env.get("BLOCKED_ORIGINS")!.split(',').map(s => s.trim());
    }
    if (Deno.env.get("RATE_LIMIT_PER_MINUTE")) {
      config.rateLimit.requestsPerMinute = parseInt(Deno.env.get("RATE_LIMIT_PER_MINUTE")!);
    }
    if (Deno.env.get("MAX_CONCURRENT")) {
      config.rateLimit.maxConcurrent = parseInt(Deno.env.get("MAX_CONCURRENT")!);
    }
    if (Deno.env.get("REQUIRE_AUTH")) {
      config.requireAuth = Deno.env.get("REQUIRE_AUTH")!.toLowerCase() === 'true';
    }
    
  } catch (error) {
    console.error("⚠️ Error loading configuration:", error);
    console.log("ℹ️ Using default configuration");
  }
}

/**
 * 保存配置
 * 将配置保存到持久化存储
 */
function saveConfig(): void {
  try {
    // 在 Deno Deploy 环境中，配置只保存在内存中
    // 如果需要持久化，可以集成外部存储服务
    console.log("ℹ️ Configuration saved to memory (restart will reset to default)");
  } catch (error) {
    console.error("⚠️ Error saving configuration:", error);
  }
}

/**
 * 重置配置为默认值
 */
function resetConfig(): void {
  config = { ...DEFAULT_CONFIG };
  console.log("🔄 Configuration reset to default values");
}

// ===== 工具函数 =====

/**
 * 修复 URL 格式
 * 确保 URL 包含正确的协议
 */
function fixUrl(url: string): string {
  if (url.includes("://")) {
    return url;
  } else if (url.includes(':/')) {
    return url.replace(':/', '://');
  } else {
    return "http://" + url;
  }
}

/**
 * 获取客户端 IP 地址
 * 考虑代理和 CDN 的情况
 */
function getClientIP(request: Request): string {
  const cfConnectingIP = request.headers.get("cf-connecting-ip");
  const xForwardedFor = request.headers.get("x-forwarded-for");
  const xRealIP = request.headers.get("x-real-ip");
  
  if (cfConnectingIP) return cfConnectingIP;
  if (xForwardedFor) return xForwardedFor.split(',')[0].trim();
  if (xRealIP) return xRealIP;
  
  return "127.0.0.1";
}

/**
 * 获取Cookie值
 * 从请求头中解析Cookie
 */
function getCookieValue(request: Request, name: string): string | null {
  const cookieHeader = request.headers.get("cookie");
  if (!cookieHeader) return null;
  
  const cookies = cookieHeader.split(';');
  for (const cookie of cookies) {
    const [key, value] = cookie.trim().split('=');
    if (key === name && value) {
      return value;
    }
  }
  return null;
}

/**
 * 生成唯一 ID
 * 用于生成 API Key 和日志 ID
 */
function generateUniqueId(): string {
  return crypto.randomUUID();
}

/**
 * 创建 CORS 响应头
 * 标准的 CORS 头部设置
 */
function createCORSHeaders(request: Request): Headers {
  const headers = new Headers({
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "GET, POST, PUT, PATCH, DELETE, OPTIONS",
    "Access-Control-Allow-Headers": "Accept, Authorization, Cache-Control, Content-Type, DNT, If-Modified-Since, Keep-Alive, Origin, User-Agent, X-Requested-With, Token, x-access-token, X-API-Key"
  });
  
  const requestHeaders = request.headers.get('Access-Control-Request-Headers');
  if (requestHeaders) {
    headers.set('Access-Control-Allow-Headers', requestHeaders);
  }
  
  return headers;
}

// ===== 错误处理 =====

/**
 * 创建错误响应
 * 标准化的错误响应格式
 */
function createErrorResponse(code: number, message: string, details?: any): Response {
  const body = JSON.stringify({
    code,
    message,
    details,
    timestamp: new Date().toISOString()
  });
  
  return new Response(body, {
    status: code >= 400 && code < 500 ? code : 500,
    headers: {
      "Content-Type": "application/json",
      ...Object.fromEntries(createCORSHeaders(new Request("http://localhost")).entries())
    }
  });
}

// ===== 定时任务 =====

/**
 * 启动定时清理任务
 * 定期清理日志和频率限制记录
 */
function startCleanupTasks(): void {
  // 每分钟清理一次过期的频率限制记录
  setInterval(() => {
    cleanupRateLimit();
  }, 60000);
  
  // 每小时清理一次旧日志
  setInterval(() => {
    cleanupLogs();
  }, 3600000);
  
  console.log("🧹 Cleanup tasks started");
}

// ===== 应用启动 =====

/**
 * 初始化应用
 * 加载配置，启动定时任务等
 */
function initializeApp(): void {
  console.log("🚀 Starting CIAO-CORS Proxy Server...");
  loadConfig();
  startCleanupTasks();
  
  // 预设一个管理员密码用于演示
  console.log(`ℹ️ Admin password is set to: ${ADMIN_PASSWORD}`);
  if (ADMIN_PASSWORD === "admin123") {
    console.log("⚠️ WARNING: Using default admin password! Change this in production!");
  }
  
  console.log("✅ CIAO-CORS Proxy Server is ready!");
}

// ===== Deno Deploy 入口点 =====
export default {
  async fetch(request: Request, env: any, ctx: any): Promise<Response> {
    try {
      return await handleRequest(request);
    } catch (error) {
      console.error("Error handling request:", error);
      return createErrorResponse(500, "Internal Server Error", error.message);
    }
  }
};

// 如果直接运行（非 Deno Deploy 环境）
// @ts-ignore: import.meta.main is available in Deno
if (import.meta.main) {
  initializeApp();
  
  const port = parseInt(Deno.env.get("PORT") || "8000");
  console.log(`🌐 Server running on http://localhost:${port}`);
  
  Deno.serve({ port }, (request) => {
    return handleRequest(request);
  });
}