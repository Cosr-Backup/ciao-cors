import { Database } from "@db/sqlite";

export class ConfigService {
  constructor(private db: Database) {}

  async getConfig(key: string): Promise<string | null> {
    const stmt = this.db.prepare("SELECT value FROM config WHERE key = ?");
    const result = stmt.get(key) as { value: string } | undefined;
    return result?.value || null;
  }

  async setConfig(key: string, value: string): Promise<void> {
    this.db.exec("INSERT OR REPLACE INTO config (key, value) VALUES (?, ?)", [key, value]);
  }

  async getAllConfig(): Promise<Record<string, string>> {
    const stmt = this.db.prepare("SELECT key, value FROM config");
    const results = stmt.all() as Array<{ key: string; value: string }>;
    return results.reduce((acc, row) => {
      acc[row.key] = row.value;
      return acc;
    }, {} as Record<string, string>);
  }

  // 黑名单管理
  async addToBlacklist(type: "ip" | "domain", value: string): Promise<void> {
    this.db.exec("INSERT INTO blacklist (type, value) VALUES (?, ?)", [type, value]);
  }

  async removeFromBlacklist(type: "ip" | "domain", value: string): Promise<void> {
    this.db.exec("DELETE FROM blacklist WHERE type = ? AND value = ?", [type, value]);
  }

  async getBlacklist(type?: "ip" | "domain"): Promise<Array<{ id: number; value: string }>> {
    let query = "SELECT id, value FROM blacklist";
    const params: string[] = [];
    
    if (type) {
      query += " WHERE type = ?";
      params.push(type);
    }
    
    const stmt = this.db.prepare(query);
    return stmt.all(...params) as Array<{ id: number; value: string }>;
  }

  async isBlacklisted(type: "ip" | "domain", value: string): Promise<boolean> {
    const stmt = this.db.prepare("SELECT 1 FROM blacklist WHERE type = ? AND value = ?");
    const result = stmt.get(type, value);
    return !!result;
  }

  // 白名单管理
  async addToWhitelist(type: "ip" | "domain", value: string): Promise<void> {
    this.db.exec("INSERT INTO whitelist (type, value) VALUES (?, ?)", [type, value]);
  }

  async removeFromWhitelist(type: "ip" | "domain", value: string): Promise<void> {
    this.db.exec("DELETE FROM whitelist WHERE type = ? AND value = ?", [type, value]);
  }

  async getWhitelist(type?: "ip" | "domain"): Promise<Array<{ id: number; value: string }>> {
    let query = "SELECT id, value FROM whitelist";
    const params: string[] = [];
    
    if (type) {
      query += " WHERE type = ?";
      params.push(type);
    }
    
    const stmt = this.db.prepare(query);
    return stmt.all(...params) as Array<{ id: number; value: string }>;
  }

  async isWhitelisted(type: "ip" | "domain", value: string): Promise<boolean> {
    const stmt = this.db.prepare("SELECT 1 FROM whitelist WHERE type = ? AND value = ?");
    const result = stmt.get(type, value);
    return !!result;
  }

  // API密钥管理
  async generateApiKey(name: string): Promise<string> {
    const key = "ck_" + Math.random().toString(36).substring(2, 15) + Math.random().toString(36).substring(2, 15);
    this.db.exec("INSERT INTO api_keys (key, name) VALUES (?, ?)", [key, name]);
    return key;
  }

  async revokeApiKey(key: string): Promise<void> {
    this.db.exec("DELETE FROM api_keys WHERE key = ?", [key]);
  }

  async disableApiKey(key: string): Promise<void> {
    this.db.exec("UPDATE api_keys SET enabled = 0 WHERE key = ?", [key]);
  }

  async enableApiKey(key: string): Promise<void> {
    this.db.exec("UPDATE api_keys SET enabled = 1 WHERE key = ?", [key]);
  }

  async getApiKeys(): Promise<Array<{ id: number; key: string; name: string; enabled: boolean; created_at: string }>> {
    const stmt = this.db.prepare("SELECT id, key, name, enabled, created_at FROM api_keys ORDER BY created_at DESC");
    return stmt.all() as Array<{ id: number; key: string; name: string; enabled: boolean; created_at: string }>;
  }

  async isValidApiKey(key: string): Promise<boolean> {
    const stmt = this.db.prepare("SELECT 1 FROM api_keys WHERE key = ? AND enabled = 1");
    const result = stmt.get(key);
    return !!result;
  }

  // 认证相关
  async validateAdmin(username: string, password: string): Promise<boolean> {
    const storedUsername = await this.getConfig("admin_username");
    const storedPassword = await this.getConfig("admin_password");
    
    // 简单密码验证（生产环境应使用bcrypt等）
    return username === storedUsername && password === storedPassword;
  }

  async updateAdminPassword(newPassword: string): Promise<void> {
    await this.setConfig("admin_password", newPassword);
  }
}