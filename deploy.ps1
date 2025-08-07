# ===== CIAO-CORS Deployment Script for Windows =====
# A beautiful and comprehensive deployment script for CIAO-CORS
# Features:
# - Interactive menu interface
# - Customizable configuration
# - Service management (install, update, restart, delete)
# - Error handling and dependency checking

# Script Configuration
$DEFAULT_PORT = 8038
$DEFAULT_SERVICE_NAME = "ciao-cors"
$DEFAULT_ADMIN_PASSWORD = "admin123"
$CONFIG_FILE = "$env:USERPROFILE\.ciao-cors-config.json"
$REPO_URL = "https://github.com/bestZwei/ciao-cors"
$MAIN_FILE = "main.ts"
$REPO_DIR = "$env:USERPROFILE\ciao-cors"

# Function to display the beautiful banner
function Show-Banner {
    Clear-Host
    Write-Host "`n`n" -ForegroundColor Blue
    Write-Host "  ______ _____          ____        ______  ____  _____   _____ " -ForegroundColor Blue
    Write-Host " / _____|_   _|   /\   / __ \      / _____|/ __ \|  __ \ / ____|" -ForegroundColor Blue
    Write-Host "| |       | |    /  \ | |  | |    | |     | |  | | |__) | (___  " -ForegroundColor Blue
    Write-Host "| |       | |   / /\ \| |  | |    | |     | |  | |  _  / \___ \ " -ForegroundColor Blue
    Write-Host "| |____  _| |_ / ____ \ |__| |    | |____ | |__| | | \ \ ____) |" -ForegroundColor Blue
    Write-Host " \_____|_____/_/    \_\____/      \______|\____/|_|  \_\_____/ " -ForegroundColor Blue
    Write-Host "`n" -ForegroundColor Cyan
    Write-Host "Comprehensive CORS Proxy with Web Management Interface" -ForegroundColor Cyan
    Write-Host "=================================================" -ForegroundColor Magenta
    Write-Host "`n"
}

# Function to check if Deno is installed
function Check-Deno {
    try {
        $denoVersion = deno --version
        Write-Host "✓ Deno is already installed." -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "Deno is not installed on your system." -ForegroundColor Yellow
        $installDeno = Read-Host "Would you like to install Deno now? (y/n)"
        if ($installDeno -eq "y") {
            Write-Host "Installing Deno..." -ForegroundColor Cyan
            try {
                # Use PowerShell to download and install Deno
                Write-Host "Please visit https://deno.land/#installation to install Deno on Windows." -ForegroundColor Cyan
                Write-Host "Or run the following command in an administrative PowerShell:" -ForegroundColor Cyan
                Write-Host "irm https://deno.land/install.ps1 | iex" -ForegroundColor Yellow
                
                $installNow = Read-Host "Would you like this script to try installing Deno for you? (y/n)"
                if ($installNow -eq "y") {
                    Invoke-RestMethod https://deno.land/install.ps1 | Invoke-Expression
                    Write-Host "Please restart your PowerShell session to use Deno, then run this script again." -ForegroundColor Green
                    exit
                }
                else {
                    Write-Host "After installing Deno, please run this script again." -ForegroundColor Yellow
                    exit
                }
            }
            catch {
                Write-Host "Failed to install Deno. Please install it manually: https://deno.land/#installation" -ForegroundColor Red
                exit
            }
        }
        else {
            Write-Host "Deno is required to run CIAO-CORS. Exiting." -ForegroundColor Red
            exit
        }
        return $false
    }
}

# Function to load existing configuration
function Load-Config {
    if (Test-Path $CONFIG_FILE) {
        $config = Get-Content -Path $CONFIG_FILE | ConvertFrom-Json
        $script:PORT = $config.PORT
        $script:SERVICE_NAME = $config.SERVICE_NAME
        $script:ADMIN_PASSWORD = $config.ADMIN_PASSWORD
        Write-Host "Loaded existing configuration." -ForegroundColor Green
    }
    else {
        $script:PORT = $DEFAULT_PORT
        $script:SERVICE_NAME = $DEFAULT_SERVICE_NAME
        $script:ADMIN_PASSWORD = $DEFAULT_ADMIN_PASSWORD
        Write-Host "No existing configuration found. Using defaults." -ForegroundColor Yellow
    }
}

# Function to save configuration
function Save-Config {
    $config = @{
        PORT = $script:PORT
        SERVICE_NAME = $script:SERVICE_NAME
        ADMIN_PASSWORD = $script:ADMIN_PASSWORD
    }
    $config | ConvertTo-Json | Set-Content -Path $CONFIG_FILE
    Write-Host "Configuration saved to $CONFIG_FILE" -ForegroundColor Green
}

# Function to configure the service
function Configure-Service {
    Show-Banner
    Write-Host "==== CIAO-CORS Configuration ====" -ForegroundColor Cyan
    Write-Host ""
    
    # Load current configuration if it exists
    Load-Config
    
    # Ask for port
    $newPort = Read-Host "Enter port number [$PORT]"
    if ($newPort) { $script:PORT = $newPort }
    
    # Ask for service name
    $newName = Read-Host "Enter service name [$SERVICE_NAME]"
    if ($newName) { $script:SERVICE_NAME = $newName }
    
    # Ask for admin password
    $newPassword = Read-Host "Enter admin password [$ADMIN_PASSWORD]"
    if ($newPassword) { $script:ADMIN_PASSWORD = $newPassword }
    
    # Save the configuration
    Save-Config
    
    Write-Host "`nConfiguration updated successfully!" -ForegroundColor Green
    Write-Host "Press any key to return to the main menu..." -ForegroundColor Yellow
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

# Function to check if service is already running
function Check-Service {
    $process = Get-Process | Where-Object { $_.CommandLine -like "*deno run*$SERVICE_NAME*" -or $_.ProcessName -like "*deno*" -and $_.CommandLine -like "*$MAIN_FILE*" } -ErrorAction SilentlyContinue
    return $null -ne $process
}

# Function to deploy the service
function Deploy-Service {
    Show-Banner
    Write-Host "==== Deploying CIAO-CORS ====" -ForegroundColor Cyan
    Write-Host ""
    
    # Check if Deno is installed
    Check-Deno
    
    # Load configuration
    Load-Config
    
    # Check if service is already running
    if (Check-Service) {
        Write-Host "CIAO-CORS is already running." -ForegroundColor Yellow
        $redeploy = Read-Host "Do you want to stop it and redeploy? (y/n)"
        if ($redeploy -eq "y") {
            Stop-Service
        }
        else {
            Write-Host "Deployment cancelled." -ForegroundColor Yellow
            Write-Host "Press any key to return to the main menu..." -ForegroundColor Yellow
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            return
        }
    }
    
    # Check if we need to clone the repository
    if (-not (Test-Path $REPO_DIR)) {
        Write-Host "Cloning the CIAO-CORS repository..." -ForegroundColor Cyan
        try {
            git clone $REPO_URL $REPO_DIR
        }
        catch {
            Write-Host "Failed to clone repository. Please check your internet connection." -ForegroundColor Red
            Write-Host "Press any key to return to the main menu..." -ForegroundColor Yellow
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            return
        }
    }
    else {
        Write-Host "Repository already exists. Updating..." -ForegroundColor Cyan
        try {
            Set-Location $REPO_DIR
            git pull
        }
        catch {
            Write-Host "Failed to update repository." -ForegroundColor Red
            Write-Host "Press any key to return to the main menu..." -ForegroundColor Yellow
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            return
        }
    }
    
    # Starting the service
    Write-Host "Starting CIAO-CORS on port $PORT..." -ForegroundColor Cyan
    Set-Location $REPO_DIR
    
    # Start as background process
    $env:PORT = $PORT
    $env:ADMIN_PASSWORD = $ADMIN_PASSWORD
    
    # Create a start script
    $startScript = @"
@echo off
set PORT=$PORT
set ADMIN_PASSWORD=$ADMIN_PASSWORD
start "CIAO-CORS" /min deno run --allow-net --allow-env --allow-read $MAIN_FILE
echo Service started! Access at http://localhost:$PORT
"@
    
    $startScript | Set-Content -Path "$REPO_DIR\start-ciao-cors.bat"
    
    # Create a stop script
    $stopScript = @"
@echo off
echo Stopping CIAO-CORS...
taskkill /f /im deno.exe /fi "WINDOWTITLE eq CIAO-CORS"
echo Service stopped!
"@
    
    $stopScript | Set-Content -Path "$REPO_DIR\stop-ciao-cors.bat"
    
    # Start the service
    try {
        Start-Process -FilePath "$REPO_DIR\start-ciao-cors.bat" -WindowStyle Minimized
        Write-Host "CIAO-CORS has been started in the background!" -ForegroundColor Green
        Write-Host "Access the web interface at: http://localhost:$PORT" -ForegroundColor Green
        Write-Host "To stop the service, run: $REPO_DIR\stop-ciao-cors.bat" -ForegroundColor Yellow
    }
    catch {
        Write-Host "Failed to start CIAO-CORS: $_" -ForegroundColor Red
    }
    
    Write-Host "`nPress any key to return to the main menu..." -ForegroundColor Yellow
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

# Function to stop the service
function Stop-Service {
    Show-Banner
    Write-Host "==== Stopping CIAO-CORS ====" -ForegroundColor Cyan
    Write-Host ""
    
    # Load configuration
    Load-Config
    
    # Check if service is running
    if (-not (Check-Service)) {
        Write-Host "CIAO-CORS is not running." -ForegroundColor Yellow
        Write-Host "Press any key to return to the main menu..." -ForegroundColor Yellow
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        return
    }
    
    # Stop the service
    Write-Host "Stopping CIAO-CORS service..." -ForegroundColor Cyan
    
    if (Test-Path "$REPO_DIR\stop-ciao-cors.bat") {
        Start-Process -FilePath "$REPO_DIR\stop-ciao-cors.bat" -Wait
    }
    else {
        # Fallback method
        Get-Process | Where-Object { $_.CommandLine -like "*deno run*$SERVICE_NAME*" -or $_.CommandLine -like "*$MAIN_FILE*" } | ForEach-Object { 
            Write-Host "Stopping process with ID: $($_.Id)" -ForegroundColor Cyan
            Stop-Process -Id $_.Id -Force 
        }
    }
    
    Write-Host "CIAO-CORS service stopped." -ForegroundColor Green
    
    Write-Host "`nPress any key to return to the main menu..." -ForegroundColor Yellow
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

# Function to restart the service
function Restart-CiaoCorsService {
    Show-Banner
    Write-Host "==== Restarting CIAO-CORS ====" -ForegroundColor Cyan
    Write-Host ""
    
    # Load configuration
    Load-Config
    
    # Check if service is running
    if (-not (Check-Service)) {
        Write-Host "CIAO-CORS is not running. Starting it..." -ForegroundColor Yellow
        Deploy-Service
        return
    }
    
    # Restart the service
    Write-Host "Restarting CIAO-CORS service..." -ForegroundColor Cyan
    Stop-Service
    Deploy-Service
    
    Write-Host "`nPress any key to return to the main menu..." -ForegroundColor Yellow
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

# Function to uninstall the service
function Uninstall-Service {
    Show-Banner
    Write-Host "==== Uninstalling CIAO-CORS ====" -ForegroundColor Cyan
    Write-Host ""
    
    # Load configuration
    Load-Config
    
    # Confirm uninstallation
    $confirm = Read-Host "Are you sure you want to uninstall CIAO-CORS? This will remove all configuration. (y/n)"
    if ($confirm -ne "y") {
        Write-Host "Uninstallation cancelled." -ForegroundColor Yellow
        Write-Host "Press any key to return to the main menu..." -ForegroundColor Yellow
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        return
    }
    
    # Stop the service if it's running
    if (Check-Service) {
        Write-Host "Stopping CIAO-CORS service..." -ForegroundColor Cyan
        Stop-Service
    }
    
    # Remove configuration file
    if (Test-Path $CONFIG_FILE) {
        Write-Host "Removing configuration file..." -ForegroundColor Cyan
        Remove-Item $CONFIG_FILE -Force
    }
    
    # Ask if repository should be removed
    $removeRepo = Read-Host "Do you want to remove the CIAO-CORS repository from your system? (y/n)"
    if ($removeRepo -eq "y") {
        Write-Host "Removing CIAO-CORS repository..." -ForegroundColor Cyan
        Remove-Item $REPO_DIR -Recurse -Force -ErrorAction SilentlyContinue
    }
    
    Write-Host "CIAO-CORS has been uninstalled from your system." -ForegroundColor Green
    Write-Host "`nPress any key to return to the main menu..." -ForegroundColor Yellow
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

# Function to view service status
function View-Status {
    Show-Banner
    Write-Host "==== CIAO-CORS Status ====" -ForegroundColor Cyan
    Write-Host ""
    
    # Load configuration
    Load-Config
    
    # Check if service is running
    if (Check-Service) {
        Write-Host "Status: Running" -ForegroundColor Green
        
        $processes = Get-Process | Where-Object { $_.CommandLine -like "*deno run*$SERVICE_NAME*" -or $_.CommandLine -like "*$MAIN_FILE*" } -ErrorAction SilentlyContinue
        
        Write-Host "Service type: Background process" -ForegroundColor Cyan
        Write-Host "Process information:" -ForegroundColor Cyan
        
        foreach ($process in $processes) {
            Write-Host "  PID: $($process.Id)" -ForegroundColor Cyan
            Write-Host "  CPU: $($process.CPU)" -ForegroundColor Cyan
            Write-Host "  Memory: $([math]::Round($process.WorkingSet / 1MB, 2)) MB" -ForegroundColor Cyan
            Write-Host "  Start Time: $($process.StartTime)" -ForegroundColor Cyan
        }
        
        # Try to get the URL
        $ip = (Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias "Ethernet*" | Select-Object -First 1).IPAddress
        if (-not $ip) {
            $ip = (Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias "Wi-Fi*" | Select-Object -First 1).IPAddress
        }
        if (-not $ip) {
            $ip = "localhost"
        }
        
        Write-Host "Access the web interface at: http://$ip`:$PORT" -ForegroundColor Green
        
        # Check if curl is available
        try {
            Write-Host "Testing endpoint..." -ForegroundColor Cyan
            $response = Invoke-WebRequest -Uri "http://localhost:$PORT/" -UseBasicParsing -ErrorAction Stop
            Write-Host "HTTP status code: $($response.StatusCode)" -ForegroundColor Green
        }
        catch {
            Write-Host "Failed to connect to the service: $_" -ForegroundColor Red
        }
    }
    else {
        Write-Host "Status: Not running" -ForegroundColor Red
    }
    
    Write-Host "`nPress any key to return to the main menu..." -ForegroundColor Yellow
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

# Function to update the service
function Update-Service {
    Show-Banner
    Write-Host "==== Updating CIAO-CORS ====" -ForegroundColor Cyan
    Write-Host ""
    
    # Check if repository exists
    if (-not (Test-Path $REPO_DIR)) {
        Write-Host "Repository not found. Please deploy the service first." -ForegroundColor Red
        Write-Host "Press any key to return to the main menu..." -ForegroundColor Yellow
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        return
    }
    
    # Pull latest changes
    Write-Host "Pulling latest changes from repository..." -ForegroundColor Cyan
    try {
        Set-Location $REPO_DIR
        git pull
    }
    catch {
        Write-Host "Failed to update repository. Please check your internet connection." -ForegroundColor Red
        Write-Host "Press any key to return to the main menu..." -ForegroundColor Yellow
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        return
    }
    
    # Ask if service should be restarted
    $restart = Read-Host "Do you want to restart the service to apply the updates? (y/n)"
    if ($restart -eq "y") {
        Restart-CiaoCorsService
    }
    else {
        Write-Host "Updates have been downloaded, but the service was not restarted." -ForegroundColor Yellow
        Write-Host "Changes will take effect after the next restart." -ForegroundColor Yellow
    }
    
    Write-Host "`nPress any key to return to the main menu..." -ForegroundColor Yellow
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

# Main menu function
function Show-MainMenu {
    while ($true) {
        Show-Banner
        Write-Host "==== Main Menu ====" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  1) Deploy CIAO-CORS" -ForegroundColor Blue
        Write-Host "  2) Configure Service" -ForegroundColor Blue
        Write-Host "  3) View Status" -ForegroundColor Blue
        Write-Host "  4) Restart Service" -ForegroundColor Blue
        Write-Host "  5) Stop Service" -ForegroundColor Blue
        Write-Host "  6) Update Service" -ForegroundColor Blue
        Write-Host "  7) Uninstall Service" -ForegroundColor Blue
        Write-Host "  0) Exit" -ForegroundColor Red
        Write-Host ""
        $choice = Read-Host "Please select an option"
        
        switch ($choice) {
            "1" { Deploy-Service }
            "2" { Configure-Service }
            "3" { View-Status }
            "4" { Restart-CiaoCorsService }
            "5" { Stop-Service }
            "6" { Update-Service }
            "7" { Uninstall-Service }
            "0" { 
                Clear-Host
                Write-Host "Thank you for using CIAO-CORS!" -ForegroundColor Green
                Write-Host "Goodbye!" -ForegroundColor Blue
                exit 
            }
            default {
                Write-Host "Invalid option. Please try again." -ForegroundColor Red
                Start-Sleep -Seconds 1
            }
        }
    }
}

# --- Main Script Execution ---
Load-Config
Show-MainMenu
