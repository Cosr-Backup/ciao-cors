# CIAO-CORS

![CIAO-CORS Logo](https://via.placeholder.com/200x80/3498db/ffffff?text=CIAO-CORS)

CIAO-CORS (Comprehensive CORS Proxy with Web Management Interface) is a complete CORS proxy solution with frontend UI, authentication, and advanced management features. It's designed for easy deployment on local servers or platforms like Deno Deploy.

## Features

- 🌐 **Full CORS Proxy**: Eliminates cross-origin issues for API requests
- 🔒 **Security Controls**: IP filtering, origin restrictions, and API key authentication
- 📊 **Monitoring Dashboard**: Track usage statistics and request logs
- ⚙️ **Customizable Settings**: Configure rate limits, blacklists, whitelists, and more
- 🚀 **Easy Deployment**: One-click deployment scripts for various platforms
- 💻 **Web Management Interface**: Administer your proxy through a user-friendly web UI

## Quick Start

### Option 1: One-Click Deployment (Recommended)

#### Linux/macOS

```bash
# Download and run the deployment script
curl -fsSL https://raw.githubusercontent.com/bestZwei/ciao-cors/main/deploy.sh -o deploy.sh
chmod +x deploy.sh
./deploy.sh
```

#### Windows

```powershell
# Download and run the deployment script
Invoke-WebRequest -Uri https://raw.githubusercontent.com/bestZwei/ciao-cors/main/deploy.ps1 -OutFile deploy.ps1
.\deploy.ps1
```

### Option 2: Manual Deployment

1. Ensure [Deno](https://deno.land/) is installed
2. Clone the repository

   ```bash
   git clone https://github.com/bestZwei/ciao-cors.git
   cd ciao-cors
   ```

3. Run the server

   ```bash
   PORT=8038 ADMIN_PASSWORD=your_secure_password deno run --allow-net --allow-env --allow-read main.ts
   ```

4. Access the web interface at [http://localhost:8038](http://localhost:8038)

### Option 3: Deploy to Deno Deploy

1. Fork the repository
2. Log in to [Deno Deploy](https://dash.deno.com/)
3. Create a new project and connect to your GitHub repository
4. Set the entry point to `main.ts`
5. Deploy and enjoy your CORS proxy service!

## Usage Examples

### Basic CORS Proxy

To make a request through the proxy:

```javascript
// Original request (with CORS issues)
fetch('https://api.example.com/data')

// Using CIAO-CORS proxy
fetch('https://your-ciao-cors.deno.dev/https://api.example.com/data')
```

### Using API Keys

For enhanced security, you can create API keys in the admin interface and use them:

```javascript
// Using API key in header
fetch('https://your-ciao-cors.deno.dev/https://api.example.com/data', {
  headers: { 'X-API-Key': 'your-api-key' }
})

// Or as a URL parameter
fetch('https://your-ciao-cors.deno.dev/https://api.example.com/data?key=your-api-key')
```

## Configuration Options

CIAO-CORS offers extensive configuration options through the web interface:

- **Origins Control**: Allow or block specific origins
- **IP Filtering**: Allow or block specific IP addresses
- **Rate Limiting**: Set limits on requests per minute, concurrent requests, etc.
- **Authentication**: Enable/disable API key requirements
- **Monitoring**: View detailed logs and statistics

All configurations can be managed through the admin dashboard at `/admin`

## Architecture

CIAO-CORS is built on Deno, a secure JavaScript/TypeScript runtime, making it lightweight and secure by default. The single-file architecture enables easy deployment on various platforms.

## Development

To contribute to CIAO-CORS:

1. Fork the repository
2. Make your changes
3. Test locally using `deno run --allow-net --allow-env --allow-read main.ts`
4. Submit a pull request

## License

[MIT License](LICENSE)

## Support

If you encounter any issues or have questions, please [open an issue](https://github.com/bestZwei/ciao-cors/issues) on GitHub.

---

Made with ❤️ by [bestZwei](https://github.com/bestZwei)