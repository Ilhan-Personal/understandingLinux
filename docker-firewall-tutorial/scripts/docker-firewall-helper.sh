#!/bin/bash

# Docker Firewall Helper Script
# Utility for managing Docker iptables rules safely

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script configuration
CHAIN="DOCKER-USER"
BACKUP_DIR="/tmp/docker-firewall-backups"

# Ensure backup directory exists
mkdir -p "$BACKUP_DIR"

# Functions
print_header() {
    echo -e "${BLUE}================================================${NC}"
    echo -e "${BLUE}         Docker Firewall Helper v1.0${NC}"
    echo -e "${BLUE}================================================${NC}"
    echo
}

print_usage() {
    cat << EOF
Usage: $0 [COMMAND] [OPTIONS]

Commands:
    status              Show current Docker firewall rules
    backup              Backup current iptables rules
    restore [file]      Restore iptables from backup
    allow-network       Allow access from specific network
    allow-ip           Allow access from specific IP
    block-network      Block access from specific network
    block-ip          Block access from specific IP
    reset             Clear all DOCKER-USER rules
    test-container    Start test container for rule testing
    help              Show this help message

Examples:
    $0 status
    $0 allow-network 192.168.1.0/24
    $0 allow-ip 203.0.113.100
    $0 block-network 10.0.0.0/8
    $0 backup
    $0 test-container

EOF
}

check_privileges() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}Error: This script requires root privileges${NC}"
        echo "Please run with sudo: sudo $0 $*"
        exit 1
    fi
}

backup_rules() {
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="$BACKUP_DIR/iptables_backup_$timestamp.rules"
    
    echo -e "${YELLOW}Backing up current iptables rules...${NC}"
    iptables-save > "$backup_file"
    echo -e "${GREEN}Backup saved to: $backup_file${NC}"
    
    # Keep only last 10 backups
    ls -t "$BACKUP_DIR"/iptables_backup_*.rules | tail -n +11 | xargs -r rm
}

restore_rules() {
    local backup_file="$1"
    
    if [[ -z "$backup_file" ]]; then
        echo -e "${YELLOW}Available backups:${NC}"
        ls -la "$BACKUP_DIR"/iptables_backup_*.rules 2>/dev/null || {
            echo -e "${RED}No backups found${NC}"
            exit 1
        }
        echo
        echo "Usage: $0 restore /path/to/backup.rules"
        exit 1
    fi
    
    if [[ ! -f "$backup_file" ]]; then
        echo -e "${RED}Error: Backup file not found: $backup_file${NC}"
        exit 1
    fi
    
    echo -e "${YELLOW}Restoring iptables from: $backup_file${NC}"
    iptables-restore < "$backup_file"
    echo -e "${GREEN}Rules restored successfully${NC}"
}

show_status() {
    echo -e "${BLUE}Current Docker Firewall Status:${NC}"
    echo "=================================="
    echo
    
    echo -e "${YELLOW}DOCKER-USER Chain Rules:${NC}"
    iptables -L DOCKER-USER -n -v --line-numbers 2>/dev/null || {
        echo -e "${RED}DOCKER-USER chain not found (Docker not running?)${NC}"
        return 1
    }
    
    echo
    echo -e "${YELLOW}Docker Containers with Published Ports:${NC}"
    docker ps --format "table {{.Names}}\t{{.Ports}}" 2>/dev/null || {
        echo -e "${RED}Docker not running or no containers found${NC}"
    }
    
    echo
    echo -e "${YELLOW}Network Interfaces:${NC}"
    ip link show | grep -E '^[0-9]+:' | awk '{print $2}' | sed 's/:$//'
}

allow_network() {
    local network="$1"
    local port="$2"
    
    if [[ -z "$network" ]]; then
        echo -e "${RED}Error: Network not specified${NC}"
        echo "Usage: $0 allow-network <network> [port]"
        echo "Example: $0 allow-network 192.168.1.0/24 8080"
        exit 1
    fi
    
    backup_rules
    
    # Add established connections rule if not exists
    if ! iptables -C DOCKER-USER -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null; then
        echo -e "${YELLOW}Adding ESTABLISHED,RELATED rule...${NC}"
        iptables -I DOCKER-USER -m state --state RELATED,ESTABLISHED -j ACCEPT
    fi
    
    if [[ -n "$port" ]]; then
        echo -e "${YELLOW}Allowing network $network access to port $port...${NC}"
        iptables -I DOCKER-USER -p tcp --dport "$port" -s "$network" -j ACCEPT
    else
        echo -e "${YELLOW}Allowing network $network full access...${NC}"
        iptables -I DOCKER-USER -s "$network" -j ACCEPT
    fi
    
    echo -e "${GREEN}Rule added successfully${NC}"
}

allow_ip() {
    local ip="$1"
    local port="$2"
    
    if [[ -z "$ip" ]]; then
        echo -e "${RED}Error: IP address not specified${NC}"
        echo "Usage: $0 allow-ip <ip> [port]"
        echo "Example: $0 allow-ip 203.0.113.100 8080"
        exit 1
    fi
    
    allow_network "$ip" "$port"
}

block_network() {
    local network="$1"
    local port="$2"
    
    if [[ -z "$network" ]]; then
        echo -e "${RED}Error: Network not specified${NC}"
        echo "Usage: $0 block-network <network> [port]"
        echo "Example: $0 block-network 10.0.0.0/8 8080"
        exit 1
    fi
    
    backup_rules
    
    if [[ -n "$port" ]]; then
        echo -e "${YELLOW}Blocking network $network access to port $port...${NC}"
        iptables -I DOCKER-USER -p tcp --dport "$port" -s "$network" -j DROP
    else
        echo -e "${YELLOW}Blocking network $network completely...${NC}"
        iptables -I DOCKER-USER -s "$network" -j DROP
    fi
    
    echo -e "${GREEN}Block rule added successfully${NC}"
}

block_ip() {
    local ip="$1"
    local port="$2"
    
    if [[ -z "$ip" ]]; then
        echo -e "${RED}Error: IP address not specified${NC}"
        echo "Usage: $0 block-ip <ip> [port]"
        echo "Example: $0 block-ip 192.168.1.100 8080"
        exit 1
    fi
    
    block_network "$ip" "$port"
}

reset_rules() {
    echo -e "${YELLOW}WARNING: This will clear all DOCKER-USER rules!${NC}"
    read -p "Are you sure? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        backup_rules
        echo -e "${YELLOW}Clearing DOCKER-USER chain...${NC}"
        iptables -F DOCKER-USER
        echo -e "${GREEN}All DOCKER-USER rules cleared${NC}"
    else
        echo "Operation cancelled"
    fi
}

start_test_container() {
    echo -e "${YELLOW}Starting test web server container...${NC}"
    
    if docker ps -q -f name=firewall-test | grep -q .; then
        echo "Test container already running"
    else
        docker run -d --name firewall-test -p 8888:80 nginx:alpine
        echo -e "${GREEN}Test container started on port 8888${NC}"
    fi
    
    echo
    echo "Test URLs:"
    echo "  Local: http://localhost:8888"
    echo "  External: http://$(curl -s ifconfig.me 2>/dev/null || echo 'YOUR_PUBLIC_IP'):8888"
    echo
    echo "To stop test container: docker stop firewall-test && docker rm firewall-test"
}

# Main script logic
main() {
    print_header
    
    case "${1:-help}" in
        "status")
            show_status
            ;;
        "backup")
            check_privileges
            backup_rules
            ;;
        "restore")
            check_privileges
            restore_rules "$2"
            ;;
        "allow-network")
            check_privileges
            allow_network "$2" "$3"
            ;;
        "allow-ip")
            check_privileges
            allow_ip "$2" "$3"
            ;;
        "block-network")
            check_privileges
            block_network "$2" "$3"
            ;;
        "block-ip")
            check_privileges
            block_ip "$2" "$3"
            ;;
        "reset")
            check_privileges
            reset_rules
            ;;
        "test-container")
            start_test_container
            ;;
        "help"|*)
            print_usage
            ;;
    esac
}

# Run main function with all arguments
main "$@" 
