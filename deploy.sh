#!/usr/bin/env bash

# ===== CIAO-CORS Deployment Script =====
# A beautiful and comprehensive deployment script for CIAO-CORS
# Features:
# - Interactive menu interface
# - Customizable configuration
# - Service management (install, update, restart, delete)
# - Error handling and dependency checking
# - Support for multiple platforms

# Terminal colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Default configuration
DEFAULT_PORT=8038
DEFAULT_SERVICE_NAME="ciao-cors"
DEFAULT_ADMIN_PASSWORD="admin123"
CONFIG_FILE="$HOME/.ciao-cors-config"
REPO_URL="https://github.com/bestZwei/ciao-cors"
MAIN_FILE="main.ts"
SCRIPT_PATH=$(realpath "$0")
ALIAS_NAME="ciaocors"
SCRIPT_VERSION="1.0"
SCRIPT_UPDATE_DATE=$(date -r "$SCRIPT_PATH" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || stat -f "%Sm" "$SCRIPT_PATH" 2>/dev/null || echo "Unknown")

# Function to display the beautiful banner
show_banner() {
    clear
    echo -e "${BLUE}"
    echo '  ██████╗██╗ █████╗  ██████╗       ██████╗ ██████╗ ██████╗ ███████╗'
    echo ' ██╔════╝██║██╔══██╗██╔═══██╗     ██╔════╝██╔═══██╗██╔══██╗██╔════╝'
    echo ' ██║     ██║███████║██║   ██║     ██║     ██║   ██║██████╔╝███████╗'
    echo ' ██║     ██║██╔══██║██║   ██║     ██║     ██║   ██║██╔══██╗╚════██║'
    echo ' ╚██████╗██║██║  ██║╚██████╔╝     ╚██████╗╚██████╔╝██║  ██║███████║'
    echo '  ╚═════╝╚═╝╚═╝  ╚═╝ ╚═════╝       ╚═════╝ ╚═════╝ ╚═╝  ╚═╝╚══════╝'
    echo -e "${NC}"
    echo -e "${CYAN}Comprehensive CORS Proxy with Web Management Interface${NC}"
    echo -e "${PURPLE}═══════════════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}Script Version: ${SCRIPT_VERSION} | Last Updated: ${SCRIPT_UPDATE_DATE}${NC}"
    echo ""
}

# Function to get valid yes/no input
get_yes_no_input() {
    local prompt="$1"
    local response=""
    
    while true; do
        read -p "$prompt" response
        case "$response" in
            [Yy]* ) return 0 ;;
            [Nn]* ) return 1 ;;
            * ) echo -e "${YELLOW}Please answer yes (y) or no (n).${NC}" ;;
        esac
    done
}

# Function to check if port is available
check_port_available() {
    local port=$1
    if command -v netstat &> /dev/null; then
        if netstat -tuln | grep -q ":$port "; then
            return 1
        fi
    elif command -v lsof &> /dev/null; then
        if lsof -i ":$port" &> /dev/null; then
            return 1
        fi
    elif command -v ss &> /dev/null; then
        if ss -tuln | grep -q ":$port "; then
            return 1
        fi
    fi
    return 0
}

# Function to check firewall status and port
check_firewall() {
    local port=$1
    echo -e "${CYAN}Checking firewall status...${NC}"
    
    # Check firewall status on different systems
    if command -v ufw &> /dev/null; then
        # Ubuntu/Debian with UFW
        if ufw status | grep -q "Status: active"; then
            echo -e "${YELLOW}Firewall (UFW) is active.${NC}"
            if ! ufw status | grep -q "$port/tcp"; then
                echo -e "${YELLOW}Port $port is not explicitly allowed in the firewall.${NC}"
                if get_yes_no_input "Would you like to allow port $port through the firewall? (y/n): "; then
                    sudo ufw allow $port/tcp
                    echo -e "${GREEN}Port $port has been allowed through the firewall.${NC}"
                else
                    echo -e "${YELLOW}Port $port remains closed. This may affect access to CIAO-CORS.${NC}"
                fi
            else
                echo -e "${GREEN}Port $port is already allowed in the firewall.${NC}"
            fi
        else
            echo -e "${GREEN}Firewall (UFW) is not active. No port configuration needed.${NC}"
        fi
    elif command -v firewall-cmd &> /dev/null; then
        # CentOS/RHEL/Fedora with firewalld
        if systemctl is-active --quiet firewalld; then
            echo -e "${YELLOW}Firewall (firewalld) is active.${NC}"
            if ! firewall-cmd --list-ports | grep -q "$port/tcp"; then
                echo -e "${YELLOW}Port $port is not explicitly allowed in the firewall.${NC}"
                if get_yes_no_input "Would you like to allow port $port through the firewall? (y/n): "; then
                    sudo firewall-cmd --add-port=$port/tcp --permanent
                    sudo firewall-cmd --reload
                    echo -e "${GREEN}Port $port has been allowed through the firewall.${NC}"
                else
                    echo -e "${YELLOW}Port $port remains closed. This may affect access to CIAO-CORS.${NC}"
                fi
            else
                echo -e "${GREEN}Port $port is already allowed in the firewall.${NC}"
            fi
        else
            echo -e "${GREEN}Firewall (firewalld) is not active. No port configuration needed.${NC}"
        fi
    elif command -v iptables &> /dev/null; then
        # Generic Linux with iptables
        if iptables -L INPUT | grep -q "Chain INPUT (policy DROP)"; then
            echo -e "${YELLOW}Firewall (iptables) appears to be active with default DROP policy.${NC}"
            if ! iptables -L INPUT -n | grep -q "tcp dpt:$port"; then
                echo -e "${YELLOW}Port $port is not explicitly allowed in the firewall.${NC}"
                if get_yes_no_input "Would you like to allow port $port through the firewall? (y/n): "; then
                    sudo iptables -A INPUT -p tcp --dport $port -j ACCEPT
                    echo -e "${GREEN}Port $port has been temporarily allowed. Note: This change may not persist after reboot.${NC}"
                    echo -e "${YELLOW}To make this change permanent, you may need to save your iptables rules.${NC}"
                else
                    echo -e "${YELLOW}Port $port remains closed. This may affect access to CIAO-CORS.${NC}"
                fi
            else
                echo -e "${GREEN}Port $port appears to be already allowed in the firewall.${NC}"
            fi
        else
            echo -e "${GREEN}Firewall (iptables) doesn't appear to be blocking connections. No port configuration needed.${NC}"
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        echo -e "${BLUE}macOS detected. The built-in firewall is typically configured through System Preferences.${NC}"
        echo -e "${YELLOW}Please ensure that your macOS firewall allows incoming connections to port $port if needed.${NC}"
    else
        echo -e "${BLUE}Could not determine firewall status. Please manually verify firewall settings if needed.${NC}"
    fi
}

# Function to check system resources
check_system_resources() {
    echo -e "${CYAN}Checking system resources...${NC}"
    
    # Check disk space
    local free_space=$(df -h . | awk 'NR==2 {print $4}')
    echo -e "${BLUE}Available disk space: $free_space${NC}"
    
    # Check memory
    if command -v free &> /dev/null; then
        local free_memory=$(free -h | awk '/^Mem:/ {print $7}')
        echo -e "${BLUE}Available memory: $free_memory${NC}"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        local free_memory=$(vm_stat | perl -ne '/page size of (\d+)/ and $size=$1; /Pages free: (\d+)/ and printf("%.2f GB\n", $1 * $size / 1048576 / 1024)')
        echo -e "${BLUE}Available memory (approx.): $free_memory${NC}"
    fi
    
    # Check CPU
    local cpu_cores=$(grep -c processor /proc/cpuinfo 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo "Unknown")
    echo -e "${BLUE}CPU cores: $cpu_cores${NC}"
    
    # Check for minimum requirements
    if df -k . | awk 'NR==2 {exit ($4 < 100000)}'; then
        echo -e "${RED}Warning: Less than 100MB of free disk space available. This may cause issues.${NC}"
    fi
    
    echo -e "${GREEN}System resource check completed.${NC}"
}

# Function to create command shortcut
create_command_shortcut() {
    local shell_rc=""
    local shortcut_exists=false
    
    # Determine which shell config file to use
    if [[ -n "$ZSH_VERSION" ]]; then
        shell_rc="$HOME/.zshrc"
    elif [[ -n "$BASH_VERSION" ]]; then
        if [[ "$OSTYPE" == "darwin"* ]]; then
            shell_rc="$HOME/.bash_profile"
            [[ ! -f "$shell_rc" ]] && shell_rc="$HOME/.profile"
        else
            shell_rc="$HOME/.bashrc"
        fi
    else
        shell_rc="$HOME/.profile"
    fi
    
    # Check if the alias already exists
    if grep -q "alias $ALIAS_NAME=" "$shell_rc" 2>/dev/null; then
        shortcut_exists=true
    fi
    
    # Ask to create the shortcut if it doesn't exist
    if ! $shortcut_exists; then
        echo -e "${CYAN}Would you like to create a command shortcut so you can run this script by typing '${ALIAS_NAME}'?${NC}"
        if get_yes_no_input "Create command shortcut? (y/n): "; then
            echo "alias $ALIAS_NAME='$SCRIPT_PATH'" >> "$shell_rc"
            echo -e "${GREEN}Command shortcut created! You can now run this script by typing '${ALIAS_NAME}'.${NC}"
            echo -e "${YELLOW}Note: You need to restart your terminal or run 'source $shell_rc' for the shortcut to take effect.${NC}"
        else
            echo -e "${BLUE}No command shortcut created. You can still run this script using its full path.${NC}"
        fi
    else
        echo -e "${GREEN}Command shortcut '${ALIAS_NAME}' already exists in $shell_rc.${NC}"
    fi
}

# Function to backup configuration
backup_config() {
    if [ -f "$CONFIG_FILE" ]; then
        local backup_file="${CONFIG_FILE}.backup.$(date +%Y%m%d%H%M%S)"
        cp "$CONFIG_FILE" "$backup_file"
        echo -e "${GREEN}Configuration backed up to: $backup_file${NC}"
    fi
}

# Function to check if Deno is installed
check_deno() {
    if ! command -v deno &> /dev/null; then
        echo -e "${YELLOW}Deno is not installed on your system.${NC}"
        
        while true; do
            if get_yes_no_input "Would you like to install Deno now? (y/n): "; then
                echo -e "${CYAN}Installing Deno...${NC}"
                if [[ "$OSTYPE" == "darwin"* ]] || [[ "$OSTYPE" == "linux-gnu"* ]]; then
                    curl -fsSL https://deno.land/x/install/install.sh | sh
                    echo -e "${GREEN}Please restart your terminal or run 'source ~/.bashrc' (or equivalent) to use Deno.${NC}"
                    echo -e "${YELLOW}After restarting your terminal, please run this script again.${NC}"
                    exit 0
                elif [[ "$OSTYPE" == "msys"* ]] || [[ "$OSTYPE" == "win32" ]]; then
                    echo -e "${CYAN}Please visit https://deno.land/#installation to install Deno on Windows.${NC}"
                    echo -e "${YELLOW}After installing Deno, please run this script again.${NC}"
                    exit 0
                else
                    echo -e "${RED}Unsupported operating system. Please install Deno manually: https://deno.land/#installation${NC}"
                    exit 1
                fi
                break
            else
                echo -e "${RED}Deno is required to run CIAO-CORS.${NC}"
                if get_yes_no_input "Are you sure you want to exit without installing Deno? (y/n): "; then
                    echo -e "${YELLOW}Installation cancelled. Exiting.${NC}"
                    exit 1
                fi
                # If they don't confirm exit, loop back to the original question
            fi
        done
    else
        echo -e "${GREEN}✓ Deno is already installed.${NC}"
    fi
}

# Function to load existing configuration
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
        echo -e "${GREEN}Loaded existing configuration.${NC}"
    else
        PORT=$DEFAULT_PORT
        SERVICE_NAME=$DEFAULT_SERVICE_NAME
        ADMIN_PASSWORD=$DEFAULT_ADMIN_PASSWORD
        echo -e "${YELLOW}No existing configuration found. Using defaults.${NC}"
    fi
}

# Function to save configuration
save_config() {
    # Backup existing config
    backup_config
    
    echo "PORT=$PORT" > "$CONFIG_FILE"
    echo "SERVICE_NAME=$SERVICE_NAME" >> "$CONFIG_FILE"
    echo "ADMIN_PASSWORD=$ADMIN_PASSWORD" >> "$CONFIG_FILE"
    echo -e "${GREEN}Configuration saved to $CONFIG_FILE${NC}"
    
    # Check if service is running and ask about restart for configuration changes
    if check_service; then
        echo -e "${YELLOW}The service is currently running.${NC}"
        echo -e "${CYAN}Configuration changes (especially port and service name) require a restart to take effect.${NC}"
        echo -e "${BLUE}Password changes will be applied automatically on the next request.${NC}"
        
        if get_yes_no_input "Would you like to restart the service now to apply all changes? (y/n): "; then
            restart_service
        else
            echo -e "${YELLOW}Configuration saved. Some changes will take effect after the next restart.${NC}"
        fi
    fi
    
    # If systemd service exists, update it
    if [[ "$OSTYPE" == "linux-gnu"* ]] && systemctl list-unit-files | grep -q "$SERVICE_NAME.service"; then
        echo -e "${CYAN}Updating systemd service with new configuration...${NC}"
        
        # Create updated service file
        cat > /tmp/ciao-cors.service << EOF
[Unit]
Description=CIAO-CORS Proxy Service
After=network.target

[Service]
Environment="PORT=$PORT"
Environment="ADMIN_PASSWORD=$ADMIN_PASSWORD"
ExecStart=$(which deno) run --allow-net --allow-env --allow-read $HOME/ciao-cors/$MAIN_FILE
Restart=on-failure
User=$(whoami)
WorkingDirectory=$HOME/ciao-cors

[Install]
WantedBy=multi-user.target
EOF
        
        # Install updated service file
        if sudo mv /tmp/ciao-cors.service /etc/systemd/system/$SERVICE_NAME.service; then
            sudo systemctl daemon-reload
            echo -e "${GREEN}Systemd service updated successfully.${NC}"
        else
            echo -e "${RED}Failed to update systemd service file.${NC}"
        fi
    fi
    
    # Update start script if it exists
    local repo_dir="$HOME/ciao-cors"
    if [ -f "$repo_dir/start-ciao-cors.sh" ]; then
        echo "#!/bin/bash
cd \"$repo_dir\"
export PORT=$PORT
export ADMIN_PASSWORD=$ADMIN_PASSWORD
nohup deno run --allow-net --allow-env --allow-read $MAIN_FILE > ciao-cors.log 2>&1 &
echo \$! > ciao-cors.pid
echo \"CIAO-CORS started with PID: \$(cat ciao-cors.pid)\"" > "$repo_dir/start-ciao-cors.sh"
        chmod +x "$repo_dir/start-ciao-cors.sh"
        echo -e "${GREEN}Start script updated with new configuration.${NC}"
    fi
}

# Function to configure the service
configure_service() {
    show_banner
    echo -e "${CYAN}==== CIAO-CORS Configuration ====${NC}"
    echo ""
    
    # Load current configuration if it exists
    load_config
    
    local old_port="$PORT"
    local old_service_name="$SERVICE_NAME"
    local old_admin_password="$ADMIN_PASSWORD"
    local config_changed=false
    
    # Ask for port
    while true; do
        read -p "Enter port number [$PORT]: " new_port
        new_port=${new_port:-$PORT}
        
        # Validate port number
        if ! [[ "$new_port" =~ ^[0-9]+$ ]] || [ "$new_port" -lt 1 ] || [ "$new_port" -gt 65535 ]; then
            echo -e "${RED}Invalid port number. Please enter a number between 1 and 65535.${NC}"
            continue
        fi
        
        # Check if port is available
        if ! check_port_available "$new_port"; then
            echo -e "${YELLOW}Port $new_port is already in use.${NC}"
            if get_yes_no_input "Would you like to choose a different port? (y/n): "; then
                continue
            fi
        fi
        
        PORT=$new_port
        break
    done
    
    # Ask for service name
    while true; do
        read -p "Enter service name [$SERVICE_NAME]: " new_name
        new_name=${new_name:-$SERVICE_NAME}
        
        # Validate service name (alphanumeric and hyphens only)
        if ! [[ "$new_name" =~ ^[a-zA-Z0-9-]+$ ]]; then
            echo -e "${RED}Invalid service name. Please use only letters, numbers, and hyphens.${NC}"
            continue
        fi
        
        SERVICE_NAME=$new_name
        break
    done
    
    # Ask for admin password
    while true; do
        read -p "Enter admin password [$ADMIN_PASSWORD]: " new_password
        new_password=${new_password:-$ADMIN_PASSWORD}
        
        # Validate password (not empty and minimum length)
        if [ -z "$new_password" ]; then
            echo -e "${RED}Password cannot be empty.${NC}"
            continue
        fi
        
        if [ ${#new_password} -lt 6 ]; then
            echo -e "${YELLOW}Warning: Short passwords are insecure.${NC}"
            if get_yes_no_input "Use this password anyway? (y/n): "; then
                ADMIN_PASSWORD=$new_password
                break
            fi
            continue
        fi
        
        ADMIN_PASSWORD=$new_password
        break
    done
    
    # Check if configuration actually changed
    if [ "$old_port" != "$PORT" ] || [ "$old_service_name" != "$SERVICE_NAME" ] || [ "$old_admin_password" != "$ADMIN_PASSWORD" ]; then
        config_changed=true
    fi
    
    # Check firewall for the selected port
    check_firewall "$PORT"
    
    # Save the configuration if changed
    if $config_changed; then
        save_config
        echo -e "${GREEN}Configuration updated successfully!${NC}"
    else
        echo -e "${BLUE}No changes were made to the configuration.${NC}"
    fi
    
    echo -e "${YELLOW}Press any key to return to the main menu...${NC}"
    read -n 1
}

# Function to check if service is already running
check_service() {
    if pgrep -f "deno run.*$SERVICE_NAME" > /dev/null; then
        return 0 # Service is running
    else
        return 1 # Service is not running
    fi
}

# Function to deploy the service
deploy_service() {
    show_banner
    echo -e "${CYAN}==== Deploying CIAO-CORS ====${NC}"
    echo ""
    
    # Check if Deno is installed
    check_deno
    
    # Load configuration
    load_config
    
    # Check system resources
    check_system_resources
    
    # Check if port is available
    if ! check_port_available "$PORT"; then
        echo -e "${YELLOW}Port $PORT is already in use.${NC}"
        if get_yes_no_input "Would you like to configure a different port? (y/n): "; then
            configure_service
        fi
    fi
    
    # Check if service is already running
    if check_service; then
        echo -e "${YELLOW}CIAO-CORS is already running.${NC}"
        if get_yes_no_input "Do you want to stop it and redeploy? (y/n): "; then
            stop_service
        else
            echo -e "${YELLOW}Deployment cancelled.${NC}"
            echo -e "${YELLOW}Press any key to return to the main menu...${NC}"
            read -n 1
            return
        fi
    fi
    
    # Check firewall for the selected port
    check_firewall "$PORT"
    
    # Check if we need to clone the repository
    local repo_dir="$HOME/ciao-cors"
    if [ ! -d "$repo_dir" ]; then
        echo -e "${CYAN}Cloning the CIAO-CORS repository...${NC}"
        
        # Check if git is installed
        if ! command -v git &> /dev/null; then
            echo -e "${RED}Git is not installed. Please install git to continue.${NC}"
            echo -e "${YELLOW}Press any key to return to the main menu...${NC}"
            read -n 1
            return
        fi
        
        git clone $REPO_URL "$repo_dir" || { 
            echo -e "${RED}Failed to clone repository. Please check your internet connection.${NC}"; 
            echo -e "${YELLOW}Press any key to return to the main menu...${NC}"
            read -n 1
            return
        }
    else
        echo -e "${CYAN}Repository already exists. Updating...${NC}"
        cd "$repo_dir" && git pull || {
            echo -e "${RED}Failed to update repository.${NC}"
            if get_yes_no_input "Would you like to continue with the existing version? (y/n): "; then
                echo -e "${YELLOW}Continuing with existing version...${NC}"
            else
                echo -e "${YELLOW}Deployment cancelled.${NC}"
                echo -e "${YELLOW}Press any key to return to the main menu...${NC}"
                read -n 1
                return
            fi
        }
    fi
    
    # Starting the service
    echo -e "${CYAN}Starting CIAO-CORS on port $PORT...${NC}"
    cd "$repo_dir"
    
    # Create systemd service file if it's a Linux system
    if [[ "$OSTYPE" == "linux-gnu"* ]] && command -v systemctl &> /dev/null; then
        echo -e "${CYAN}Creating systemd service...${NC}"
        
        # Create service file
        cat > /tmp/ciao-cors.service << EOF
[Unit]
Description=CIAO-CORS Proxy Service
After=network.target

[Service]
Environment="PORT=$PORT"
Environment="ADMIN_PASSWORD=$ADMIN_PASSWORD"
ExecStart=$(which deno) run --allow-net --allow-env --allow-read $repo_dir/$MAIN_FILE
Restart=on-failure
User=$(whoami)
WorkingDirectory=$repo_dir

[Install]
WantedBy=multi-user.target
EOF
        
        # Check if sudo is available
        if ! command -v sudo &> /dev/null; then
            echo -e "${RED}Sudo is not available. Cannot install systemd service.${NC}"
            echo -e "${YELLOW}Falling back to background process deployment...${NC}"
        else
            # Install service file
            sudo mv /tmp/ciao-cors.service /etc/systemd/system/$SERVICE_NAME.service || {
                echo -e "${RED}Failed to create systemd service. Falling back to background process.${NC}"
                echo -e "${YELLOW}Continuing with background process deployment...${NC}"
                systemd_failed=true
            }
            
            if [ -z "$systemd_failed" ]; then
                sudo systemctl daemon-reload
                sudo systemctl enable $SERVICE_NAME
                sudo systemctl start $SERVICE_NAME
                
                if systemctl is-active --quiet $SERVICE_NAME; then
                    echo -e "${GREEN}CIAO-CORS has been deployed as a systemd service!${NC}"
                    echo -e "${GREEN}Service name: $SERVICE_NAME${NC}"
                    echo -e "${GREEN}Service status: $(systemctl is-active $SERVICE_NAME)${NC}"
                    echo -e "${GREEN}Access the web interface at: http://localhost:$PORT${NC}"
                    
                    # Try to get the local IP address
                    local ip=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "localhost")
                    if [ "$ip" != "localhost" ]; then
                        echo -e "${GREEN}Access from other devices on your network: http://$ip:$PORT${NC}"
                    fi
                else
                    echo -e "${RED}Failed to start systemd service. Falling back to background process.${NC}"
                    systemd_failed=true
                fi
            fi
        fi
    else
        # If not using systemd or systemd failed
        systemd_failed=true
    fi
    
    # Start as background process if systemd not available or failed
    if [ -n "$systemd_failed" ]; then
        echo -e "${CYAN}Starting as a background process...${NC}"
        
        # Set environment variables
        export PORT=$PORT
        export ADMIN_PASSWORD=$ADMIN_PASSWORD
        
        # Start the process in the background
        nohup deno run --allow-net --allow-env --allow-read $MAIN_FILE > ciao-cors.log 2>&1 &
        local pid=$!
        echo $pid > ciao-cors.pid
        
        # Check if process is still running after a short delay
        sleep 2
        if ps -p $pid > /dev/null; then
            echo -e "${GREEN}CIAO-CORS has been started in the background!${NC}"
            echo -e "${GREEN}PID: $pid${NC}"
            echo -e "${GREEN}Access the web interface at: http://localhost:$PORT${NC}"
            
            # Try to get the local IP address
            local ip=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "localhost")
            if [ "$ip" != "localhost" ]; then
                echo -e "${GREEN}Access from other devices on your network: http://$ip:$PORT${NC}"
            fi
            
            echo -e "${YELLOW}Logs are being written to: $repo_dir/ciao-cors.log${NC}"
            
            # Create start/stop scripts for convenience
            echo "#!/bin/bash
cd \"$repo_dir\"
export PORT=$PORT
export ADMIN_PASSWORD=$ADMIN_PASSWORD
nohup deno run --allow-net --allow-env --allow-read $MAIN_FILE > ciao-cors.log 2>&1 &
echo \$! > ciao-cors.pid
echo \"CIAO-CORS started with PID: \$(cat ciao-cors.pid)\"" > "$repo_dir/start-ciao-cors.sh"
            
            echo "#!/bin/bash
cd \"$repo_dir\"
if [ -f ciao-cors.pid ]; then
    kill \$(cat ciao-cors.pid) 2>/dev/null
    rm ciao-cors.pid
    echo \"CIAO-CORS stopped\"
else
    echo \"PID file not found, trying to find and kill the process...\"
    pkill -f \"deno run.*$SERVICE_NAME\"
    echo \"Sent kill signal to CIAO-CORS processes\"
fi" > "$repo_dir/stop-ciao-cors.sh"
            
            chmod +x "$repo_dir/start-ciao-cors.sh" "$repo_dir/stop-ciao-cors.sh"
            echo -e "${BLUE}Created start/stop scripts:${NC}"
            echo -e "${BLUE}- To start: $repo_dir/start-ciao-cors.sh${NC}"
            echo -e "${BLUE}- To stop: $repo_dir/stop-ciao-cors.sh${NC}"
        else
            echo -e "${RED}Failed to start CIAO-CORS as a background process.${NC}"
            echo -e "${YELLOW}Check the log file for errors: $repo_dir/ciao-cors.log${NC}"
        fi
    fi
    
    # Offer to create command shortcut
    create_command_shortcut
    
    echo ""
    echo -e "${YELLOW}Press any key to return to the main menu...${NC}"
    read -n 1
}

# Function to stop the service
stop_service() {
    show_banner
    echo -e "${CYAN}==== Stopping CIAO-CORS ====${NC}"
    echo ""
    
    # Load configuration
    load_config
    
    # Check if service is running
    if ! check_service; then
        echo -e "${YELLOW}CIAO-CORS is not running.${NC}"
        echo -e "${YELLOW}Press any key to return to the main menu...${NC}"
        read -n 1
        return
    fi
    
    # Stop the service
    if [[ "$OSTYPE" == "linux-gnu"* ]] && systemctl list-unit-files | grep -q "$SERVICE_NAME.service"; then
        echo -e "${CYAN}Stopping systemd service...${NC}"
        sudo systemctl stop $SERVICE_NAME
        echo -e "${GREEN}CIAO-CORS service stopped.${NC}"
    else
        echo -e "${CYAN}Stopping background process...${NC}"
        local repo_dir="$HOME/ciao-cors"
        if [ -f "$repo_dir/ciao-cors.pid" ]; then
            kill $(cat "$repo_dir/ciao-cors.pid")
            rm "$repo_dir/ciao-cors.pid"
            echo -e "${GREEN}CIAO-CORS process stopped.${NC}"
        else
            echo -e "${YELLOW}PID file not found. Trying to find and kill the process...${NC}"
            pkill -f "deno run.*$SERVICE_NAME"
            echo -e "${GREEN}Sent kill signal to all CIAO-CORS processes.${NC}"
        fi
    fi
    
    echo ""
    echo -e "${YELLOW}Press any key to return to the main menu...${NC}"
    read -n 1
}

# Function to restart the service
restart_service() {
    show_banner
    echo -e "${CYAN}==== Restarting CIAO-CORS ====${NC}"
    echo ""
    
    # Load configuration
    load_config
    
    # Check if service is running
    if ! check_service; then
        echo -e "${YELLOW}CIAO-CORS is not running. Starting it...${NC}"
        deploy_service
        return
    fi
    
    # Restart the service
    if [[ "$OSTYPE" == "linux-gnu"* ]] && systemctl list-unit-files | grep -q "$SERVICE_NAME.service"; then
        echo -e "${CYAN}Restarting systemd service...${NC}"
        sudo systemctl restart $SERVICE_NAME
        echo -e "${GREEN}CIAO-CORS service restarted.${NC}"
    else
        echo -e "${CYAN}Restarting background process...${NC}"
        stop_service
        deploy_service
    fi
    
    echo ""
    echo -e "${YELLOW}Press any key to return to the main menu...${NC}"
    read -n 1
}

# Function to uninstall the service
uninstall_service() {
    show_banner
    echo -e "${CYAN}==== Uninstalling CIAO-CORS ====${NC}"
    echo ""
    
    # Load configuration
    load_config
    
    # Confirm uninstallation
    read -p "Are you sure you want to uninstall CIAO-CORS? This will remove all configuration. (y/n): " confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Uninstallation cancelled.${NC}"
        echo -e "${YELLOW}Press any key to return to the main menu...${NC}"
        read -n 1
        return
    fi
    
    # Stop the service if it's running
    if check_service; then
        echo -e "${CYAN}Stopping CIAO-CORS service...${NC}"
        stop_service
    fi
    
    # Remove systemd service if it exists
    if [[ "$OSTYPE" == "linux-gnu"* ]] && systemctl list-unit-files | grep -q "$SERVICE_NAME.service"; then
        echo -e "${CYAN}Removing systemd service...${NC}"
        sudo systemctl disable $SERVICE_NAME
        sudo rm /etc/systemd/system/$SERVICE_NAME.service
        sudo systemctl daemon-reload
    fi
    
    # Remove configuration file
    if [ -f "$CONFIG_FILE" ]; then
        echo -e "${CYAN}Removing configuration file...${NC}"
        rm "$CONFIG_FILE"
    fi
    
    # Ask if repository should be removed
    read -p "Do you want to remove the CIAO-CORS repository from your system? (y/n): " remove_repo
    if [[ $remove_repo =~ ^[Yy]$ ]]; then
        echo -e "${CYAN}Removing CIAO-CORS repository...${NC}"
        rm -rf "$HOME/ciao-cors"
    fi
    
    echo -e "${GREEN}CIAO-CORS has been uninstalled from your system.${NC}"
    echo ""
    echo -e "${YELLOW}Press any key to return to the main menu...${NC}"
    read -n 1
}

# Function to view service status
view_status() {
    show_banner
    echo -e "${CYAN}==== CIAO-CORS Status ====${NC}"
    echo ""
    
    # Load configuration
    load_config
    
    # Check if service is running
    if check_service; then
        echo -e "${GREEN}Status: Running${NC}"
        
        # Get more details based on system type
        if [[ "$OSTYPE" == "linux-gnu"* ]] && systemctl list-unit-files | grep -q "$SERVICE_NAME.service"; then
            echo -e "${CYAN}Service type: systemd${NC}"
            echo -e "${CYAN}Service name: $SERVICE_NAME${NC}"
            echo -e "${CYAN}Service status:${NC}"
            systemctl status $SERVICE_NAME --no-pager
        else
            echo -e "${CYAN}Service type: background process${NC}"
            local pid=$(pgrep -f "deno run.*$SERVICE_NAME")
            echo -e "${CYAN}PID: $pid${NC}"
            echo -e "${CYAN}Process info:${NC}"
            ps -p $pid -o pid,ppid,cmd,%cpu,%mem,etime
        fi
        
        # Try to get the URL
        local ip=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "localhost")
        echo -e "${GREEN}Access the web interface at: http://$ip:$PORT${NC}"
        
        # Check if curl is installed to test the endpoint
        if command -v curl &> /dev/null; then
            echo -e "${CYAN}Testing endpoint...${NC}"
            curl -s -o /dev/null -w "HTTP status code: %{http_code}\n" http://localhost:$PORT/ || echo -e "${RED}Failed to connect to the service.${NC}"
        fi
    else
        echo -e "${RED}Status: Not running${NC}"
    fi
    
    echo ""
    echo -e "${YELLOW}Press any key to return to the main menu...${NC}"
    read -n 1
}

# Function to view logs
view_logs() {
    show_banner
    echo -e "${CYAN}==== CIAO-CORS Logs ====${NC}"
    echo ""
    
    # Load configuration
    load_config
    
    local repo_dir="$HOME/ciao-cors"
    local log_file="$repo_dir/ciao-cors.log"
    
    # Check if service is running through systemd
    if [[ "$OSTYPE" == "linux-gnu"* ]] && systemctl list-unit_files | grep -q "$SERVICE_NAME.service"; then
        echo -e "${CYAN}Viewing systemd journal logs for $SERVICE_NAME:${NC}"
        sudo journalctl -u $SERVICE_NAME -n 100 --no-pager
    elif [ -f "$log_file" ]; then
        # View the log file
        echo -e "${CYAN}Viewing log file: $log_file${NC}"
        tail -n 100 "$log_file"
    else
        echo -e "${RED}No log file found at $log_file${NC}"
        echo -e "${YELLOW}The service may not be running or logs are directed elsewhere.${NC}"
    fi
    
    echo ""
    echo -e "${YELLOW}Press any key to return to the main menu...${NC}"
    read -n 1
}

# Function to update the service
update_service() {
    show_banner
    echo -e "${CYAN}==== Updating CIAO-CORS ====${NC}"
    echo ""
    
    # Pull latest changes
    echo -e "${CYAN}Pulling latest changes from repository...${NC}"
    cd "$HOME/ciao-cors" && git pull || {
        echo -e "${RED}Failed to update repository. Please check your internet connection.${NC}"
        echo -e "${YELLOW}Press any key to return to the main menu...${NC}"
        read -n 1
        return
    }
    
    # Ask if service should be restarted
    read -p "Do you want to restart the service to apply the updates? (y/n): " restart
    if [[ $restart =~ ^[Yy]$ ]]; then
        restart_service
    else
        echo -e "${YELLOW}Updates have been downloaded, but the service was not restarted.${NC}"
        echo -e "${YELLOW}Changes will take effect after the next restart.${NC}"
    fi
    
    echo ""
    echo -e "${YELLOW}Press any key to return to the main menu...${NC}"
    read -n 1
}

# Main menu function
main_menu() {
    while true; do
        show_banner
        echo -e "${CYAN}==== Main Menu ====${NC}"
        echo ""
        echo -e "  ${BLUE}1)${NC} Deploy CIAO-CORS"
        echo -e "  ${BLUE}2)${NC} Configure Service"
        echo -e "  ${BLUE}3)${NC} View Status"
        echo -e "  ${BLUE}4)${NC} View Logs"
        echo -e "  ${BLUE}5)${NC} Restart Service"
        echo -e "  ${BLUE}6)${NC} Stop Service"
        echo -e "  ${BLUE}7)${NC} Update Service"
        echo -e "  ${BLUE}8)${NC} Uninstall Service"
        echo -e "  ${BLUE}9)${NC} Create Command Shortcut"
        echo -e "  ${BLUE}h)${NC} Help & Documentation"
        echo -e "  ${RED}0)${NC} Exit"
        echo ""
        
        # Show current configuration
        echo -e "${CYAN}Current Configuration:${NC}"
        echo -e "  Port: ${GREEN}$PORT${NC} | Service Name: ${GREEN}$SERVICE_NAME${NC} | Admin Password: ${GREEN}$(echo $ADMIN_PASSWORD | sed 's/./*/g')${NC}"
        echo ""
        
        read -p "Please select an option: " choice
        
        case $choice in
            1) deploy_service ;;
            2) configure_service ;;
            3) view_status ;;
            4) view_logs ;;
            5) restart_service ;;
            6) stop_service ;;
            7) update_service ;;
            8) uninstall_service ;;
            9) create_command_shortcut; echo -e "${YELLOW}Press any key to return to the main menu...${NC}"; read -n 1 ;;
            h|H) show_help; echo -e "${YELLOW}Press any key to return to the main menu...${NC}"; read -n 1 ;;
            0) 
                clear
                echo -e "${GREEN}Thank you for using CIAO-CORS!${NC}"
                echo -e "${BLUE}Goodbye!${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid option. Please try again.${NC}"
                sleep 1
                ;;
        esac
    done
}

# Function to show help and documentation
show_help() {
    show_banner
    echo -e "${CYAN}==== CIAO-CORS Help & Documentation ====${NC}"
    echo ""
    echo -e "${BLUE}CIAO-CORS${NC} is a comprehensive CORS proxy with web management interface."
    echo -e "This script helps you deploy and manage your CIAO-CORS installation."
    echo ""
    echo -e "${CYAN}Available Commands:${NC}"
    echo -e "  ${BLUE}1. Deploy CIAO-CORS${NC} - Install and start the CIAO-CORS service"
    echo -e "  ${BLUE}2. Configure Service${NC} - Modify port, service name, and admin password"
    echo -e "  ${BLUE}3. View Status${NC} - Check if the service is running and view details"
    echo -e "  ${BLUE}4. View Logs${NC} - Display service logs"
    echo -e "  ${BLUE}5. Restart Service${NC} - Stop and start the service"
    echo -e "  ${BLUE}6. Stop Service${NC} - Stop the running service"
    echo -e "  ${BLUE}7. Update Service${NC} - Update to the latest version from GitHub"
    echo -e "  ${BLUE}8. Uninstall Service${NC} - Remove CIAO-CORS from your system"
    echo -e "  ${BLUE}9. Create Command Shortcut${NC} - Create an alias to run this script easily"
    echo ""
    echo -e "${CYAN}Usage After Installation:${NC}"
    echo -e "  - Access the web interface at http://localhost:$PORT"
    echo -e "  - Log in with the admin password you configured"
    echo -e "  - Configure your CORS proxy settings through the web interface"
    echo ""
    echo -e "${CYAN}Command Shortcut:${NC}"
    echo -e "  After creating a command shortcut, you can run this script by simply typing:"
    echo -e "  ${YELLOW}$ALIAS_NAME${NC}"
    echo ""
    echo -e "${CYAN}Need More Help?${NC}"
    echo -e "  Visit the GitHub repository: ${BLUE}$REPO_URL${NC}"
}

# Check if running with admin/root privileges for certain operations
check_privileges() {
    if [[ "$OSTYPE" == "linux-gnu"* ]] && [ "$EUID" -ne 0 ]; then
        echo -e "${YELLOW}Notice: Some operations may require sudo privileges.${NC}"
        echo -e "${YELLOW}You will be prompted for your password when needed.${NC}"
        echo ""
    fi
}

# --- Main Script Execution ---
check_privileges
load_config

# Check for updates
if [ -d "$HOME/ciao-cors" ] && command -v git &> /dev/null; then
    cd "$HOME/ciao-cors"
    git fetch -q
    LOCAL=$(git rev-parse HEAD)
    REMOTE=$(git rev-parse @{u})
    
    if [ "$LOCAL" != "$REMOTE" ]; then
        echo -e "${YELLOW}Update available for CIAO-CORS!${NC}"
        echo -e "${BLUE}Run the 'Update Service' option to get the latest features.${NC}"
        sleep 2
    fi
fi

main_menu
