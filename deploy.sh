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

# Function to display the beautiful banner
show_banner() {
    clear
    echo -e "${BLUE}"
    echo '  ______ _____          ____        ______  ____  _____   _____ '
    echo ' / _____|_   _|   /\   / __ \      / _____|/ __ \|  __ \ / ____|'
    echo '| |       | |    /  \ | |  | |    | |     | |  | | |__) | (___  '
    echo '| |       | |   / /\ \| |  | |    | |     | |  | |  _  / \___ \ '
    echo '| |____  _| |_ / ____ \ |__| |    | |____ | |__| | | \ \ ____) |'
    echo ' \_____| |____/_/    \_\____/      \______|\____/|_|  \_\_____/ '
    echo -e "${NC}"
    echo -e "${CYAN}Comprehensive CORS Proxy with Web Management Interface${NC}"
    echo -e "${PURPLE}=================================================${NC}"
    echo ""
}

# Function to check if Deno is installed
check_deno() {
    if ! command -v deno &> /dev/null; then
        echo -e "${YELLOW}Deno is not installed on your system.${NC}"
        read -p "Would you like to install Deno now? (y/n): " install_deno
        if [[ $install_deno =~ ^[Yy]$ ]]; then
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
        else
            echo -e "${RED}Deno is required to run CIAO-CORS. Exiting.${NC}"
            exit 1
        fi
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
    echo "PORT=$PORT" > "$CONFIG_FILE"
    echo "SERVICE_NAME=$SERVICE_NAME" >> "$CONFIG_FILE"
    echo "ADMIN_PASSWORD=$ADMIN_PASSWORD" >> "$CONFIG_FILE"
    echo -e "${GREEN}Configuration saved to $CONFIG_FILE${NC}"
}

# Function to configure the service
configure_service() {
    show_banner
    echo -e "${CYAN}==== CIAO-CORS Configuration ====${NC}"
    echo ""
    
    # Load current configuration if it exists
    load_config
    
    # Ask for port
    read -p "Enter port number [$PORT]: " new_port
    PORT=${new_port:-$PORT}
    
    # Ask for service name
    read -p "Enter service name [$SERVICE_NAME]: " new_name
    SERVICE_NAME=${new_name:-$SERVICE_NAME}
    
    # Ask for admin password
    read -p "Enter admin password [$ADMIN_PASSWORD]: " new_password
    ADMIN_PASSWORD=${new_password:-$ADMIN_PASSWORD}
    
    # Save the configuration
    save_config
    
    echo ""
    echo -e "${GREEN}Configuration updated successfully!${NC}"
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
    
    # Check if service is already running
    if check_service; then
        echo -e "${YELLOW}CIAO-CORS is already running.${NC}"
        read -p "Do you want to stop it and redeploy? (y/n): " redeploy
        if [[ $redeploy =~ ^[Yy]$ ]]; then
            stop_service
        else
            echo -e "${YELLOW}Deployment cancelled.${NC}"
            echo -e "${YELLOW}Press any key to return to the main menu...${NC}"
            read -n 1
            return
        fi
    fi
    
    # Check if we need to clone the repository
    local repo_dir="$HOME/ciao-cors"
    if [ ! -d "$repo_dir" ]; then
        echo -e "${CYAN}Cloning the CIAO-CORS repository...${NC}"
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
            echo -e "${YELLOW}Press any key to return to the main menu...${NC}"
            read -n 1
            return
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
        
        # Install service file
        sudo mv /tmp/ciao-cors.service /etc/systemd/system/$SERVICE_NAME.service
        sudo systemctl daemon-reload
        sudo systemctl enable $SERVICE_NAME
        sudo systemctl start $SERVICE_NAME
        
        echo -e "${GREEN}CIAO-CORS has been deployed as a systemd service!${NC}"
        echo -e "${GREEN}Service name: $SERVICE_NAME${NC}"
        echo -e "${GREEN}Service status: $(systemctl is-active $SERVICE_NAME)${NC}"
        echo -e "${GREEN}Access the web interface at: http://localhost:$PORT${NC}"
    else
        # Start as background process for non-systemd systems
        echo -e "${CYAN}Starting as a background process...${NC}"
        nohup deno run --allow-net --allow-env --allow-read $MAIN_FILE > ciao-cors.log 2>&1 &
        echo $! > ciao-cors.pid
        
        echo -e "${GREEN}CIAO-CORS has been started in the background!${NC}"
        echo -e "${GREEN}PID: $(cat ciao-cors.pid)${NC}"
        echo -e "${GREEN}Access the web interface at: http://localhost:$PORT${NC}"
        echo -e "${YELLOW}Logs are being written to: $repo_dir/ciao-cors.log${NC}"
    fi
    
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
    if [[ "$OSTYPE" == "linux-gnu"* ]] && systemctl list-unit-files | grep -q "$SERVICE_NAME.service"; then
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
    
    # Check if repository exists
    local repo_dir="$HOME/ciao-cors"
    if [ ! -d "$repo_dir" ]; then
        echo -e "${RED}Repository not found. Please deploy the service first.${NC}"
        echo -e "${YELLOW}Press any key to return to the main menu...${NC}"
        read -n 1
        return
    fi
    
    # Pull latest changes
    echo -e "${CYAN}Pulling latest changes from repository...${NC}"
    cd "$repo_dir" && git pull || {
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
        echo -e "  ${RED}0)${NC} Exit"
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
main_menu
