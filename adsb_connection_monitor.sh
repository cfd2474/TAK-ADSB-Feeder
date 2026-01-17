#!/bin/bash
# ADS-B Aggregator Connection Monitor with Automatic Failover
# Monitors Tailscale connection and fails over to public IP if needed
# Part of TAK-ADSB-Feeder v5.5

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
TAILSCALE_IP="100.117.34.88"
PUBLIC_IP="104.225.219.254"
BEAST_PORT="30004"
MLAT_PORT="30105"

INSTALL_DIR="/opt/TAK_ADSB"
READSB_SERVICE="/etc/systemd/system/readsb.service"
MLAT_SERVICE="/etc/systemd/system/mlat-client.service"
STATE_FILE="/var/run/adsb-connection-state"
LOG_FILE="/var/log/adsb-failover.log"

# Check interval (seconds)
CHECK_INTERVAL=30

# Number of failed checks before failover
FAILURE_THRESHOLD=3

# Current state tracking
CURRENT_TARGET=""
CONSECUTIVE_FAILURES=0
CONSECUTIVE_SUCCESSES=0

# Logging function
log_event() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" | sudo tee -a "$LOG_FILE" > /dev/null
    
    case $level in
        ERROR)
            echo -e "${RED}[$level] $message${NC}"
            ;;
        WARNING)
            echo -e "${YELLOW}[$level] $message${NC}"
            ;;
        INFO)
            echo -e "${GREEN}[$level] $message${NC}"
            ;;
        *)
            echo "[$level] $message"
            ;;
    esac
}

# Check if we can connect to an IP:port
check_connection() {
    local target_ip="$1"
    local port="$2"
    local timeout=5
    
    # Use netcat to test connection
    if timeout $timeout bash -c "nc -zv $target_ip $port" &>/dev/null; then
        return 0  # Success
    else
        return 1  # Failure
    fi
}

# Get current connection target from state file
get_current_target() {
    if [ -f "$STATE_FILE" ]; then
        cat "$STATE_FILE"
    else
        echo "UNKNOWN"
    fi
}

# Set current connection target in state file
set_current_target() {
    local target="$1"
    echo "$target" | sudo tee "$STATE_FILE" > /dev/null
    CURRENT_TARGET="$target"
}

# Update readsb service to use specified IP
update_readsb_service() {
    local target_ip="$1"
    local service_name="$2"
    
    log_event "INFO" "Updating readsb service to connect to $target_ip:$BEAST_PORT"
    
    # Read current service file
    local current_service=$(sudo cat "$READSB_SERVICE")
    
    # Replace IP in the ExecStart line
    # This handles both Tailscale and public IPs
    local updated_service=$(echo "$current_service" | sed "s/--net-connector [0-9.]*,$BEAST_PORT/--net-connector $target_ip,$BEAST_PORT/g")
    
    # Write updated service
    echo "$updated_service" | sudo tee "$READSB_SERVICE" > /dev/null
    
    # Reload systemd and restart service
    sudo systemctl daemon-reload
    sudo systemctl restart readsb
    
    log_event "INFO" "Readsb service updated and restarted"
}

# Update mlat-client service to use specified IP
update_mlat_service() {
    local target_ip="$1"
    
    # Check if MLAT is enabled
    if ! sudo systemctl is-enabled mlat-client &>/dev/null; then
        log_event "INFO" "MLAT is disabled, skipping update"
        return
    fi
    
    log_event "INFO" "Updating mlat-client service to connect to $target_ip:$MLAT_PORT"
    
    # Read current service file
    local current_service=$(sudo cat "$MLAT_SERVICE")
    
    # Replace IP in the ExecStart line
    local updated_service=$(echo "$current_service" | sed "s/--server [0-9.]*:$MLAT_PORT/--server $target_ip:$MLAT_PORT/g")
    
    # Write updated service
    echo "$updated_service" | sudo tee "$MLAT_SERVICE" > /dev/null
    
    # Reload systemd and restart service
    sudo systemctl daemon-reload
    sudo systemctl restart mlat-client
    
    log_event "INFO" "MLAT service updated and restarted"
}

# Perform failover to specified target
failover_to() {
    local target="$1"
    local target_ip=""
    
    case $target in
        TAILSCALE)
            target_ip="$TAILSCALE_IP"
            log_event "INFO" "Failing over to Tailscale IP: $target_ip"
            ;;
        PUBLIC)
            target_ip="$PUBLIC_IP"
            log_event "WARNING" "Failing over to Public IP: $target_ip"
            ;;
        *)
            log_event "ERROR" "Unknown failover target: $target"
            return 1
            ;;
    esac
    
    # Update both services
    update_readsb_service "$target_ip"
    update_mlat_service "$target_ip"
    
    # Update state
    set_current_target "$target"
    
    # Reset counters
    CONSECUTIVE_FAILURES=0
    CONSECUTIVE_SUCCESSES=0
    
    log_event "INFO" "Failover to $target complete"
}

# Main monitoring loop
monitor_connection() {
    log_event "INFO" "Starting ADS-B connection monitor"
    log_event "INFO" "Tailscale IP: $TAILSCALE_IP, Public IP: $PUBLIC_IP"
    log_event "INFO" "Check interval: ${CHECK_INTERVAL}s, Failure threshold: $FAILURE_THRESHOLD"
    
    # Get initial state
    CURRENT_TARGET=$(get_current_target)
    
    # If unknown, assume Tailscale (default)
    if [ "$CURRENT_TARGET" = "UNKNOWN" ]; then
        log_event "INFO" "No previous state found, defaulting to Tailscale"
        set_current_target "TAILSCALE"
    fi
    
    log_event "INFO" "Current connection target: $CURRENT_TARGET"
    
    while true; do
        # Check Tailscale connectivity
        if check_connection "$TAILSCALE_IP" "$BEAST_PORT"; then
            # Tailscale is reachable
            CONSECUTIVE_SUCCESSES=$((CONSECUTIVE_SUCCESSES + 1))
            CONSECUTIVE_FAILURES=0
            
            # If we're on public IP and Tailscale is back, fail back
            if [ "$CURRENT_TARGET" = "PUBLIC" ] && [ $CONSECUTIVE_SUCCESSES -ge $FAILURE_THRESHOLD ]; then
                log_event "INFO" "Tailscale connection restored after $CONSECUTIVE_SUCCESSES checks"
                failover_to "TAILSCALE"
            fi
            
        else
            # Tailscale is unreachable
            CONSECUTIVE_FAILURES=$((CONSECUTIVE_FAILURES + 1))
            CONSECUTIVE_SUCCESSES=0
            
            log_event "WARNING" "Tailscale connection check failed ($CONSECUTIVE_FAILURES/$FAILURE_THRESHOLD)"
            
            # If we're on Tailscale and it's failing, fail over to public
            if [ "$CURRENT_TARGET" = "TAILSCALE" ] && [ $CONSECUTIVE_FAILURES -ge $FAILURE_THRESHOLD ]; then
                log_event "WARNING" "Tailscale connection failed after $CONSECUTIVE_FAILURES checks"
                
                # Verify public IP is reachable before failing over
                if check_connection "$PUBLIC_IP" "$BEAST_PORT"; then
                    log_event "INFO" "Public IP is reachable, initiating failover"
                    failover_to "PUBLIC"
                else
                    log_event "ERROR" "Public IP is also unreachable! No failover possible"
                    # Reset failure counter to avoid spam
                    CONSECUTIVE_FAILURES=0
                fi
            fi
        fi
        
        # Sleep before next check
        sleep $CHECK_INTERVAL
    done
}

# Handle script termination
cleanup() {
    log_event "INFO" "Connection monitor shutting down"
    exit 0
}

trap cleanup SIGINT SIGTERM

# Check if running as root (for service installation)
if [ "$1" = "install" ]; then
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}ERROR: Installation requires root privileges${NC}"
        echo "Run as: sudo $0 install"
        exit 1
    fi
    
    echo -e "${GREEN}Installing ADS-B Connection Monitor Service...${NC}"
    
    # Copy script to system location
    SCRIPT_PATH="/usr/local/bin/adsb-connection-monitor"
    cp "$0" "$SCRIPT_PATH"
    chmod +x "$SCRIPT_PATH"
    
    # Create systemd service
    cat > /etc/systemd/system/adsb-connection-monitor.service <<'EOF'
[Unit]
Description=ADS-B Aggregator Connection Monitor with Failover
After=network.target tailscaled.service readsb.service
Wants=tailscaled.service readsb.service

[Service]
Type=simple
ExecStart=/usr/local/bin/adsb-connection-monitor
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=adsb-connection-monitor

[Install]
WantedBy=multi-user.target
EOF
    
    # Enable and start service
    systemctl daemon-reload
    systemctl enable adsb-connection-monitor
    systemctl start adsb-connection-monitor
    
    echo -e "${GREEN}✓ Connection monitor service installed and started${NC}"
    echo ""
    echo -e "${YELLOW}Service Commands:${NC}"
    echo "  Check status:  sudo systemctl status adsb-connection-monitor"
    echo "  View logs:     sudo journalctl -fu adsb-connection-monitor"
    echo "  Stop monitor:  sudo systemctl stop adsb-connection-monitor"
    echo "  Start monitor: sudo systemctl start adsb-connection-monitor"
    echo "  Disable:       sudo systemctl disable adsb-connection-monitor"
    echo ""
    echo -e "${YELLOW}Log Files:${NC}"
    echo "  Failover log:  tail -f $LOG_FILE"
    echo "  Current state: cat $STATE_FILE"
    echo ""
    
    exit 0
fi

# Check if running as root (for service removal)
if [ "$1" = "uninstall" ]; then
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}ERROR: Uninstallation requires root privileges${NC}"
        echo "Run as: sudo $0 uninstall"
        exit 1
    fi
    
    echo -e "${YELLOW}Uninstalling ADS-B Connection Monitor Service...${NC}"
    
    # Stop and disable service
    systemctl stop adsb-connection-monitor 2>/dev/null || true
    systemctl disable adsb-connection-monitor 2>/dev/null || true
    
    # Remove service file
    rm -f /etc/systemd/system/adsb-connection-monitor.service
    rm -f /usr/local/bin/adsb-connection-monitor
    
    systemctl daemon-reload
    
    echo -e "${GREEN}✓ Connection monitor service uninstalled${NC}"
    echo ""
    echo -e "${YELLOW}Note: Log files and state files were preserved:${NC}"
    echo "  $LOG_FILE"
    echo "  $STATE_FILE"
    echo ""
    
    exit 0
fi

# Show status
if [ "$1" = "status" ]; then
    echo -e "${BLUE}=== ADS-B Connection Monitor Status ===${NC}"
    echo ""
    
    if [ -f "$STATE_FILE" ]; then
        CURRENT=$(cat "$STATE_FILE")
        echo -e "${GREEN}Current Target: $CURRENT${NC}"
        
        case $CURRENT in
            TAILSCALE)
                echo "  IP: $TAILSCALE_IP"
                echo "  Status: Primary connection (Tailscale VPN)"
                ;;
            PUBLIC)
                echo "  IP: $PUBLIC_IP"
                echo "  Status: Failover connection (Public IP)"
                ;;
        esac
    else
        echo -e "${YELLOW}No state file found${NC}"
    fi
    
    echo ""
    echo -e "${BLUE}Service Status:${NC}"
    systemctl status adsb-connection-monitor --no-pager 2>/dev/null || echo "Service not installed"
    
    echo ""
    echo -e "${BLUE}Recent Log Entries:${NC}"
    if [ -f "$LOG_FILE" ]; then
        tail -10 "$LOG_FILE"
    else
        echo "No log file found"
    fi
    
    exit 0
fi

# Show help
if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    echo "ADS-B Connection Monitor with Automatic Failover"
    echo ""
    echo "Usage:"
    echo "  sudo $0 install     - Install as systemd service"
    echo "  sudo $0 uninstall   - Remove systemd service"
    echo "  $0 status           - Show current connection status"
    echo "  $0                  - Run in foreground (for testing)"
    echo ""
    echo "Configuration:"
    echo "  Tailscale IP: $TAILSCALE_IP"
    echo "  Public IP:    $PUBLIC_IP"
    echo "  Beast Port:   $BEAST_PORT"
    echo "  MLAT Port:    $MLAT_PORT"
    echo ""
    echo "Behavior:"
    echo "  - Monitors Tailscale connection every ${CHECK_INTERVAL}s"
    echo "  - Fails over to public IP after $FAILURE_THRESHOLD failed checks"
    echo "  - Automatically fails back to Tailscale when restored"
    echo "  - Logs all events to: $LOG_FILE"
    echo ""
    exit 0
fi

# Run monitor (default)
monitor_connection
