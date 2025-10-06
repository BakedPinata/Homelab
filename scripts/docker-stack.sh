#!/bin/bash
# scripts/docker-stack.sh
# Manage Docker Compose stacks easily

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
COMPOSE_DIR="compose"
BASE_COMPOSE="docker-compose.yml"
ENV_FILE=".env"

# Check if .env exists
if [ ! -f "$ENV_FILE" ]; then
    echo -e "${RED}Error: .env file not found!${NC}"
    echo "Please copy .env.example to .env and configure it."
    exit 1
fi

# Source the .env file to get DATA_PATH
export $(cat .env | grep -v '^#' | xargs)

# Function to print usage
usage() {
    echo "Usage: $0 [COMMAND] [OPTIONS] [STACKS]"
    echo ""
    echo "Commands:"
    echo "  up        Start stacks (default: all)"
    echo "  down      Stop stacks"
    echo "  restart   Restart stacks"
    echo "  logs      View logs"
    echo "  ps        List running containers"
    echo "  pull      Pull latest images"
    echo "  build     Build images"
    echo "  init      Initialize environment"
    echo ""
    echo "Stacks:"
    echo "  all              All stacks (default)"
    echo "  infrastructure   Core services (Traefik, Portainer, etc.)"
    echo "  homeautomation   Home Assistant and IoT services"
    echo "  monitoring       Grafana and monitoring stack"
    echo "  productivity     BookStack, etc."
    echo "  media           Media services"
    echo ""
    echo "Examples:"
    echo "  $0 up                    # Start all stacks"
    echo "  $0 up infrastructure     # Start only infrastructure"
    echo "  $0 logs homeautomation   # View Home Assistant logs"
    echo "  $0 down all             # Stop everything"
}

# Function to get compose files for selected stacks
# Returns: compose files string on success, exits on error
get_compose_files() {
    local stacks="$@"
    local files="-f $BASE_COMPOSE"
    local found_valid=false
    local invalid_stacks=""
    
    if [ -z "$stacks" ] || [ "$stacks" = "all" ]; then
        # Include all compose files
        for file in $COMPOSE_DIR/*.yml; do
            if [ -f "$file" ]; then
                files="$files -f $file"
                found_valid=true
            fi
        done
        
        # If no stack files found in compose directory, just use base
        if [ "$found_valid" = false ]; then
            echo -e "${YELLOW}Warning: No stack files found in $COMPOSE_DIR, using base compose file only${NC}" >&2
        fi
    else
        # Include only specified stacks
        for stack in $stacks; do
            if [ -f "$COMPOSE_DIR/$stack.yml" ]; then
                files="$files -f $COMPOSE_DIR/$stack.yml"
                found_valid=true
            else
                invalid_stacks="$invalid_stacks $stack"
            fi
        done
        
        # If invalid stacks were specified, report and exit
        if [ -n "$invalid_stacks" ]; then
            echo -e "${RED}Error: Invalid stack name(s):$invalid_stacks${NC}" >&2
            echo -e "${YELLOW}Available stacks:${NC}" >&2
            for file in $COMPOSE_DIR/*.yml; do
                if [ -f "$file" ]; then
                    basename "$file" .yml >&2
                fi
            done
            exit 1
        fi
        
        # If no valid stacks found, exit
        if [ "$found_valid" = false ]; then
            echo -e "${RED}Error: No valid stacks specified${NC}" >&2
            exit 1
        fi
    fi
    
    echo "$files"
}

# Function to initialize the environment
init_environment() {
    echo -e "${GREEN}Initializing Docker environment...${NC}"
    
    # Create the external network if it doesn't exist
    if ! docker network ls | grep -q " proxy "; then
        echo "Creating proxy network..."
        docker network create proxy
    fi
    
    # Create data directories
    echo "Creating data directories..."
    mkdir -p "$DATA_PATH"/{traefik,portainer,homeassistant,grafana,bookstack,vaultwarden}
    mkdir -p "$DATA_PATH"/{duplicati,mosquitto,code-server,nodered,zigbee2mqtt,influxdb}
    mkdir -p "$DATA_PATH"/{unifi,adguard,tailscale,qbittorrent,matter,esphome}
    mkdir -p "$DATA_PATH"/traefik/{letsencrypt,config}
    
    # Set up Traefik files
    if [ ! -f "$DATA_PATH/traefik/letsencrypt/acme.json" ]; then
        echo "Creating Traefik acme.json..."
        touch "$DATA_PATH/traefik/letsencrypt/acme.json"
        chmod 600 "$DATA_PATH/traefik/letsencrypt/acme.json"
    fi
    
    echo -e "${GREEN}Environment initialized successfully!${NC}"
}

# Function to check stack health
check_health() {
    local stacks="$@"
    local compose_files=$(get_compose_files $stacks)
    
    echo -e "${GREEN}Checking container health...${NC}"
    docker compose $compose_files ps --format "table {{.Name}}\t{{.Status}}\t{{.State}}"
}

# Function to backup data
backup_data() {
    echo -e "${GREEN}Creating backup...${NC}"
    
    # Get compose files for all stacks
    COMPOSE_FILES=$(get_compose_files all)
    
    # Stop containers for consistent backup
    docker compose $COMPOSE_FILES down
    
    # Create backup with timestamp
    BACKUP_NAME="homelab-backup-$(date +%Y%m%d-%H%M%S).tar.gz"
    tar -czf "$BACKUP_PATH/$BACKUP_NAME" -C "$DATA_PATH" .
    
    # Restart containers
    docker compose $COMPOSE_FILES up -d
    
    echo -e "${GREEN}Backup created: $BACKUP_PATH/$BACKUP_NAME${NC}"
}

# Parse command
COMMAND=${1:-up}
shift || true

# Handle commands
case "$COMMAND" in
    init)
        init_environment
        ;;
    up)
        STACKS="$@"
        # get_compose_files will exit on error, so no need to check
        COMPOSE_FILES=$(get_compose_files $STACKS)
        echo -e "${GREEN}Starting stacks...${NC}"
        docker compose $COMPOSE_FILES up -d
        check_health $STACKS
        ;;
    down)
        STACKS="$@"
        COMPOSE_FILES=$(get_compose_files $STACKS)
        echo -e "${YELLOW}Stopping stacks...${NC}"
        docker compose $COMPOSE_FILES down
        ;;
    restart)
        STACKS="$@"
        COMPOSE_FILES=$(get_compose_files $STACKS)
        echo -e "${YELLOW}Restarting stacks...${NC}"
        docker compose $COMPOSE_FILES restart
        ;;
    logs)
        STACKS="$@"
        COMPOSE_FILES=$(get_compose_files $STACKS)
        docker compose $COMPOSE_FILES logs -f --tail=100
        ;;
    ps)
        STACKS="$@"
        COMPOSE_FILES=$(get_compose_files $STACKS)
        docker compose $COMPOSE_FILES ps
        ;;
    pull)
        STACKS="$@"
        COMPOSE_FILES=$(get_compose_files $STACKS)
        echo -e "${GREEN}Pulling latest images...${NC}"
        docker compose $COMPOSE_FILES pull
        ;;
    build)
        STACKS="$@"
        COMPOSE_FILES=$(get_compose_files $STACKS)
        docker compose $COMPOSE_FILES build
        ;;
    health)
        STACKS="$@"
        check_health $STACKS
        ;;
    backup)
        backup_data
        ;;
    *)
        echo -e "${RED}Unknown command: $COMMAND${NC}"
        usage
        exit 1
        ;;
esac
