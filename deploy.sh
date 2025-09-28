#!/bin/bash
# FastAPI Dagobah Deployment Script
# Usage: ./deploy.sh [start|stop|restart|debug|logs|watch|shell|status|health|clean|help]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
PROJECT_NAME="fastapi-dagobah"
CONTAINER_NAME="fastapi-production"
COMPOSE_SERVICE="fastapi-production"
NETWORK_NAME="apisix-network"
HEALTH_URL="http://localhost:8001/api/v1/health"

# Logging functions
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

log_debug() {
    echo -e "${PURPLE}🔧 $1${NC}"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check APISIX dependencies
check_dependencies() {
    local errors=0

    log_info "Checking APISIX dependencies..."

    # Check Docker
    if ! command_exists docker; then
        log_error "Docker not found"
        ((errors++))
    fi

    if ! command_exists docker-compose; then
        log_error "Docker Compose not found"
        ((errors++))
    fi

    # Check APISIX network
    if ! docker network ls | grep -q "$NETWORK_NAME"; then
        log_error "APISIX network '$NETWORK_NAME' not found"
        ((errors++))
    fi

    # Check APISIX gateway
    if ! docker ps | grep -q "apisix-gateway"; then
        log_error "APISIX gateway not running"
        ((errors++))
    fi

    # Check PostgreSQL
    if ! docker ps | grep -q "apisix-dagobah-postgres"; then
        log_error "PostgreSQL container not running"
        ((errors++))
    else
        # Check if PostgreSQL is accepting connections
        if ! docker exec apisix-dagobah-postgres pg_isready -U postgres >/dev/null 2>&1; then
            log_error "PostgreSQL not accepting connections"
            ((errors++))
        fi
    fi

    if [ $errors -gt 0 ]; then
        echo ""
        log_error "Dependencies not met. Start APISIX stack first:"
        echo -e "${CYAN}  cd /3spread/apisix-dagobah${NC}"
        echo -e "${CYAN}  docker-compose up -d${NC}"
        echo ""
        exit 1
    fi

    log_success "All dependencies ready"
}

# Check and create .env file
check_env_file() {
    if [ ! -f .env ]; then
        if [ -f .env.production.example ]; then
            log_info "Creating .env from production template..."
            cp .env.production.example .env
            log_warning "Please review .env file and update as needed"
        else
            log_error ".env file not found and no template available"
            exit 1
        fi
    fi
}

# Get container status
get_container_status() {
    if docker ps --filter "name=${PROJECT_NAME}-${COMPOSE_SERVICE}" --format "{{.Status}}" | grep -q "Up"; then
        echo "running"
    elif docker ps -a --filter "name=${PROJECT_NAME}-${COMPOSE_SERVICE}" --format "{{.Status}}" | grep -q "Exited"; then
        echo "stopped"
    else
        echo "not_found"
    fi
}

# Get container uptime
get_uptime() {
    local status=$(docker ps --filter "name=${PROJECT_NAME}-${COMPOSE_SERVICE}" --format "{{.Status}}" 2>/dev/null || echo "")
    if [[ $status =~ Up\ ([^\ ]+) ]]; then
        echo "${BASH_REMATCH[1]}"
    else
        echo "N/A"
    fi
}

# Health check
check_health() {
    if curl -sf "$HEALTH_URL" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Start service
start_service() {
    log_info "Starting FastAPI Dagobah..."

    check_dependencies
    check_env_file

    # Start the service
    log_info "Starting production container..."
    docker-compose --profile production up -d $COMPOSE_SERVICE

    # Wait for service to be ready
    log_info "Waiting for service to be ready..."
    sleep 5

    # Health check
    if check_health; then
        log_success "Service is running and healthy!"
        show_endpoints
    else
        log_error "Service started but health check failed"
        echo ""
        log_info "Showing recent logs:"
        docker-compose --profile production logs --tail=20 $COMPOSE_SERVICE
    fi
}

# Stop service
stop_service() {
    log_info "Stopping FastAPI Dagobah..."

    if [ "$(get_container_status)" == "not_found" ]; then
        log_warning "No containers found to stop"
        return
    fi

    docker-compose --profile production down
    log_success "Service stopped"
}

# Restart service (skip dependency checks)
restart_service() {
    log_info "Restarting FastAPI Dagobah..."

    # Stop
    if [ "$(get_container_status)" != "not_found" ]; then
        docker-compose --profile production down
    fi

    # Quick start (no dependency checks)
    check_env_file
    docker-compose --profile production up -d $COMPOSE_SERVICE

    log_info "Waiting for service..."
    sleep 3

    if check_health; then
        log_success "Service restarted successfully!"
    else
        log_warning "Service restarted but health check failed"
    fi
}

# Debug mode with interactive prompts
debug_mode() {
    log_debug "Entering DEBUG mode..."

    # Show current image info
    local image_info=$(docker images ${PROJECT_NAME} --format "table {{.Repository}}:{{.Tag}}\t{{.CreatedSince}}" | tail -n +2)
    if [ -n "$image_info" ]; then
        echo "Current image: $image_info"
    else
        echo "No existing image found"
    fi

    echo ""

    # Prompt for rebuild
    read -p "Do you want to rebuild the image? (y/n): " -n 1 -r rebuild_choice
    echo ""

    if [[ $rebuild_choice =~ ^[Yy]$ ]]; then
        log_info "Rebuilding image..."
        docker-compose build --no-cache $COMPOSE_SERVICE
        log_success "Image rebuilt"
        echo ""
    fi

    # Prompt for start
    read -p "Do you want to start the service? (y/n): " -n 1 -r start_choice
    echo ""

    if [[ $start_choice =~ ^[Yy]$ ]]; then
        check_dependencies
        check_env_file

        log_info "Starting in debug mode (foreground)..."
        log_warning "Press Ctrl+C to stop"
        echo ""

        # Start in foreground
        docker-compose --profile production up $COMPOSE_SERVICE
    else
        log_info "Image ready. Run './deploy.sh start' when ready"
    fi
}

# Show logs
show_logs() {
    log_info "Showing logs (Ctrl+C to exit)..."

    if [ "$(get_container_status)" != "running" ]; then
        log_error "Container not running"
        exit 1
    fi

    docker-compose --profile production logs -f $COMPOSE_SERVICE
}

# Watch dashboard
watch_dashboard() {
    log_info "Starting live monitor (Ctrl+C to exit)..."
    echo ""

    while true; do
        clear

        # Header
        echo "┌──────────────────────────────────────────────────────────────┐"
        echo "│ FastAPI Dagobah - Live Monitor                              │"
        echo "│ Updated: $(date '+%Y-%m-%d %H:%M:%S')                        │"
        echo "├──────────────────────────────────────────────────────────────┤"

        # Status
        local status=$(get_container_status)
        local uptime=$(get_uptime)

        if [ "$status" == "running" ]; then
            echo "│ Container: Running ✅                                        │"
            echo "│ Uptime: $uptime                                              │"

            if check_health; then
                echo "│ Health: $HEALTH_URL ✅                                       │"
            else
                echo "│ Health: $HEALTH_URL ❌                                       │"
            fi
        elif [ "$status" == "stopped" ]; then
            echo "│ Container: Stopped ❌                                        │"
            echo "│ Uptime: N/A                                                 │"
            echo "│ Health: N/A                                                 │"
        else
            echo "│ Container: Not Found ❓                                      │"
            echo "│ Uptime: N/A                                                 │"
            echo "│ Health: N/A                                                 │"
        fi

        echo "│ Port: 8001 → 8000                                           │"
        echo "├──────────────────────────────────────────────────────────────┤"
        echo "│ Recent Logs (last 10):                                      │"

        # Show logs if container is running
        if [ "$status" == "running" ]; then
            docker-compose --profile production logs --tail=10 $COMPOSE_SERVICE 2>/dev/null | while IFS= read -r line; do
                # Truncate long lines
                truncated=$(echo "$line" | cut -c1-58)
                printf "│ %-58s │\n" "$truncated"
            done
        else
            echo "│ No logs available - container not running                   │"
        fi

        echo "└──────────────────────────────────────────────────────────────┘"
        echo ""
        echo "Press Ctrl+C to exit"

        sleep 2
    done
}

# Interactive shell
interactive_shell() {
    log_info "Opening interactive shell..."

    if [ "$(get_container_status)" != "running" ]; then
        log_error "Container not running. Start it first with './deploy.sh start'"
        exit 1
    fi

    local container_name="${PROJECT_NAME}-${COMPOSE_SERVICE}-1"
    docker exec -it "$container_name" /bin/bash
}

# Show status
show_status() {
    log_info "FastAPI Dagobah Status:"
    echo ""

    local status=$(get_container_status)
    local uptime=$(get_uptime)

    case $status in
        "running")
            echo -e "Status: ${GREEN}Running ✅${NC}"
            echo "Uptime: $uptime"
            ;;
        "stopped")
            echo -e "Status: ${RED}Stopped ❌${NC}"
            echo "Uptime: N/A"
            ;;
        "not_found")
            echo -e "Status: ${YELLOW}Not Found ❓${NC}"
            echo "Uptime: N/A"
            ;;
    esac

    # Port mapping
    local ports=$(docker ps --filter "name=${PROJECT_NAME}-${COMPOSE_SERVICE}" --format "{{.Ports}}" 2>/dev/null || echo "N/A")
    echo "Ports: $ports"

    # Health check
    if [ "$status" == "running" ]; then
        if check_health; then
            echo -e "Health: ${GREEN}✅ Healthy${NC}"
        else
            echo -e "Health: ${RED}❌ Unhealthy${NC}"
        fi
    else
        echo "Health: N/A"
    fi

    # Resource usage
    if [ "$status" == "running" ]; then
        local stats=$(docker stats --no-stream --format "table {{.MemUsage}}\t{{.CPUPerc}}" "${PROJECT_NAME}-${COMPOSE_SERVICE}-1" 2>/dev/null | tail -n +2)
        if [ -n "$stats" ]; then
            echo "Resources: $stats"
        fi
    fi
}

# Check health endpoint
check_health_endpoint() {
    log_info "Checking health endpoint..."

    if [ "$(get_container_status)" != "running" ]; then
        log_error "Container not running"
        exit 1
    fi

    echo "URL: $HEALTH_URL"
    echo ""

    if curl -s "$HEALTH_URL"; then
        echo ""
        log_success "Health check passed"
    else
        echo ""
        log_error "Health check failed"
        exit 1
    fi
}

# Clean everything
clean_service() {
    log_warning "This will remove containers and volumes"

    # Stop and remove
    docker-compose --profile production down -v 2>/dev/null || true

    # Prompt for image removal
    echo ""
    read -p "Remove Docker images too? (y/n): " -n 1 -r remove_images
    echo ""

    if [[ $remove_images =~ ^[Yy]$ ]]; then
        log_info "Removing images..."
        docker rmi "${PROJECT_NAME}:latest" 2>/dev/null || true
        docker image prune -f >/dev/null 2>&1 || true
    fi

    log_success "Cleanup completed"
}

# Show endpoints
show_endpoints() {
    echo ""
    log_success "🔗 Service Endpoints:"
    echo "   FastAPI: http://localhost:8001"
    echo "   API Docs: http://localhost:8001/api/v1/docs"
    echo "   Health: http://localhost:8001/api/v1/health"
    echo ""
    echo -e "${CYAN}🔧 APISIX Integration:${NC}"
    echo "   Admin API: http://100.81.158.27:9180"
    echo "   Dashboard: http://100.81.158.27:9000"
    echo "   Configure routes to: http://fastapi:8000"
    echo ""
}

# Show help
show_help() {
    echo "FastAPI Dagobah Deployment Script"
    echo ""
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  start     Start the service (checks APISIX dependencies)"
    echo "  stop      Stop the service"
    echo "  restart   Restart the service (skips dependency checks)"
    echo "  debug     Interactive rebuild and start"
    echo "  logs      Show and follow logs"
    echo "  watch     Live dashboard monitor"
    echo "  shell     Open interactive shell in container"
    echo "  status    Show detailed service status"
    echo "  health    Check health endpoint"
    echo "  clean     Remove containers, volumes, and optionally images"
    echo "  help      Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 start"
    echo "  $0 debug"
    echo "  $0 watch"
    echo ""
}

# Main script logic
case "${1:-help}" in
    start)
        start_service
        ;;
    stop)
        stop_service
        ;;
    restart)
        restart_service
        ;;
    debug)
        debug_mode
        ;;
    logs)
        show_logs
        ;;
    watch)
        watch_dashboard
        ;;
    shell)
        interactive_shell
        ;;
    status)
        show_status
        ;;
    health)
        check_health_endpoint
        ;;
    clean)
        clean_service
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        log_error "Unknown command: $1"
        echo ""
        show_help
        exit 1
        ;;
esac