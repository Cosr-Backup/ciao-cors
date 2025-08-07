import { Database } from "@db/sqlite";

export class StatsService {
  constructor(private db: Database) {}

  async recordRequest(
    ip: string,
    domain: string,
    statusCode: number,
    responseTime: number,
    userAgent: string,
    apiKey?: string
  ): Promise<void> {
    const stmt = this.db.prepare(`
      INSERT INTO stats (ip, domain, status_code, response_time, user_agent, api_key)
      VALUES (?, ?, ?, ?, ?, ?)
    `);
    stmt.run(ip, domain, statusCode, responseTime, userAgent, apiKey);
  }

  async getRateLimitCount(type: string, identifier: string, windowStart: Date): Promise<number> {
    const stmt = this.db.prepare(`
      SELECT requests FROM rate_limits 
      WHERE type = ? AND identifier = ? AND window_start = ?
    `);
    const result = stmt.get(type, identifier, windowStart.toISOString()) as { requests: number } | undefined;
    return result?.requests || 0;
  }

  async incrementRateLimit(type: string, identifier: string, windowStart: Date): Promise<void> {
    this.db.exec(`
      INSERT OR REPLACE INTO rate_limits (type, identifier, requests, window_start)
      VALUES (?, ?, COALESCE(
        (SELECT requests + 1 FROM rate_limits WHERE type = ? AND identifier = ? AND window_start = ?), 1
      ), ?)
    `, [type, identifier, type, identifier, windowStart.toISOString(), windowStart.toISOString()]);
  }

  async getStats(timeRange: "hour" | "day" | "week" = "day"): Promise<{
    totalRequests: number;
    successfulRequests: number;
    failedRequests: number;
    averageResponseTime: number;
    topDomains: Array<{ domain: string; count: number }>;
    topIPs: Array<{ ip: string; count: number }>;
    statusCodeDistribution: Record<string, number>;
  }> {
    const now = new Date();
    let startTime: Date;

    switch (timeRange) {
      case "hour":
        startTime = new Date(now.getTime() - 60 * 60 * 1000);
        break;
      case "day":
        startTime = new Date(now.getTime() - 24 * 60 * 60 * 1000);
        break;
      case "week":
        startTime = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
        break;
      default:
        startTime = new Date(now.getTime() - 24 * 60 * 60 * 1000);
    }

    // 总请求数
    const totalStmt = this.db.prepare(`
      SELECT COUNT(*) as count FROM stats WHERE timestamp >= ?
    `);
    const totalRequests = (totalStmt.get(startTime.toISOString()) as { count: number }).count;

    // 成功请求数
    const successStmt = this.db.prepare(`
      SELECT COUNT(*) as count FROM stats WHERE timestamp >= ? AND status_code < 400
    `);
    const successfulRequests = (successStmt.get(startTime.toISOString()) as { count: number }).count;

    // 失败请求数
    const failedRequests = totalRequests - successfulRequests;

    // 平均响应时间
    const avgStmt = this.db.prepare(`
      SELECT AVG(response_time) as avg_time FROM stats WHERE timestamp >= ?
    `);
    const averageResponseTime = (avgStmt.get(startTime.toISOString()) as { avg_time: number } || { avg_time: 0 }).avg_time;

    // 热门域名
    const topDomainsStmt = this.db.prepare(`
      SELECT domain, COUNT(*) as count 
      FROM stats 
      WHERE timestamp >= ? 
      GROUP BY domain 
      ORDER BY count DESC 
      LIMIT 10
    `);
    const topDomains = topDomainsStmt.all(startTime.toISOString()) as Array<{ domain: string; count: number }>;

    // 热门IP
    const topIPsStmt = this.db.prepare(`
      SELECT ip, COUNT(*) as count 
      FROM stats 
      WHERE timestamp >= ? 
      GROUP BY ip 
      ORDER BY count DESC 
      LIMIT 10
    `);
    const topIPs = topIPsStmt.all(startTime.toISOString()) as Array<{ ip: string; count: number }>;

    // 状态码分布
    const statusStmt = this.db.prepare(`
      SELECT status_code, COUNT(*) as count 
      FROM stats 
      WHERE timestamp >= ? 
      GROUP BY status_code
    `);
    const statusResults = statusStmt.all(startTime.toISOString()) as Array<{ status_code: number; count: number }>;
    
    const statusCodeDistribution: Record<string, number> = {};
    statusResults.forEach(row => {
      statusCodeDistribution[row.status_code.toString()] = row.count;
    });

    return {
      totalRequests,
      successfulRequests,
      failedRequests,
      averageResponseTime: Math.round(averageResponseTime),
      topDomains,
      topIPs,
      statusCodeDistribution,
    };
  }

  async getRecentRequests(limit: number = 50): Promise<Array<{
    id: number;
    timestamp: string;
    ip: string;
    domain: string;
    status_code: number;
    response_time: number;
    user_agent: string;
    api_key?: string;
  }>> {
    const stmt = this.db.prepare(`
      SELECT id, timestamp, ip, domain, status_code, response_time, user_agent, api_key
      FROM stats
      ORDER BY timestamp DESC
      LIMIT ?
    `);
    return stmt.all(limit) as Array<{
      id: number;
      timestamp: string;
      ip: string;
      domain: string;
      status_code: number;
      response_time: number;
      user_agent: string;
      api_key?: string;
    }>;
  }

  async getUsageByAPIKey(): Promise<Array<{
    api_key: string;
    total_requests: number;
    last_request: string;
  }>> {
    const stmt = this.db.prepare(`
      SELECT 
        COALESCE(api_key, 'anonymous') as api_key,
        COUNT(*) as total_requests,
        MAX(timestamp) as last_request
      FROM stats
      GROUP BY api_key
      ORDER BY total_requests DESC
    `);
    return stmt.all() as Array<{
      api_key: string;
      total_requests: number;
      last_request: string;
    }>;
  }

  async cleanupOldStats(olderThanDays: number = 30): Promise<void> {
    const cutoffDate = new Date();
    cutoffDate.setDate(cutoffDate.getDate() - olderThanDays);
    
    this.db.exec("DELETE FROM stats WHERE timestamp < ?", [cutoffDate.toISOString()]);
    this.db.exec("DELETE FROM rate_limits WHERE window_start < ?", [cutoffDate.toISOString()]);
  }
}