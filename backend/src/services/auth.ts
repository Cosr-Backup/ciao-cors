import { Database } from "@db/sqlite";
import { createHash } from "node:crypto";

export class AuthService {
  constructor(private db: Database) {}

  generateToken(): string {
    return createHash('sha256').update(Math.random().toString()).digest('hex');
  }

  async validateAdmin(username: string, password: string): Promise<boolean> {
    const stmt = this.db.prepare("SELECT value FROM config WHERE key = ?");
    const storedUsername = (stmt.get("admin_username") as { value: string } | undefined)?.value;
    const storedPassword = (stmt.get("admin_password") as { value: string } | undefined)?.value;
    
    return username === storedUsername && password === storedPassword;
  }

  async updateAdminPassword(newPassword: string): Promise<void> {
    this.db.exec("UPDATE config SET value = ? WHERE key = 'admin_password'", [newPassword]);
  }

  async updateAdminUsername(newUsername: string): Promise<void> {
    this.db.exec("UPDATE config SET value = ? WHERE key = 'admin_username'", [newUsername]);
  }
}