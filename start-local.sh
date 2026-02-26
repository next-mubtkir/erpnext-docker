#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

ENV_FILE=".env"
ENV_LOCAL=".env.local"
ENV_EXAMPLE=".env.example"

usage() {
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  start       Start ERPNext and Traefik (default)"
    echo "  stop        Stop all containers"
    echo "  restart     Restart containers"
    echo "  status      Show container status"
    echo "  logs        Show logs"
    echo "  reset       Reset everything (DESTRUCTIVE)"
    echo "  help        Show this help"
    exit 0
}

check_env() {
    if [ ! -f "$ENV_FILE" ]; then
        if [ -f "$ENV_LOCAL" ]; then
            echo "Copying .env.local to .env..."
            cp "$ENV_LOCAL" "$ENV_FILE"
        elif [ -f "$ENV_EXAMPLE" ]; then
            echo "Copying .env.example to .env..."
            echo "IMPORTANT: Edit .env and set DB_PASSWORD and ADMIN_PASSWORD!"
            cp "$ENV_EXAMPLE" "$ENV_FILE"
        else
            echo "Error: No .env file found. Create one from .env.example"
            exit 1
        fi
    fi
    
    source "$ENV_FILE"
    
    if [ -z "$DB_PASSWORD" ] || [ "$DB_PASSWORD" = "change_me_db_password" ]; then
        echo "Error: Set DB_PASSWORD in .env file"
        exit 1
    fi
    
    if [ -z "$ADMIN_PASSWORD" ] || [ "$ADMIN_PASSWORD" = "change_me_admin_password" ]; then
        echo "Error: Set ADMIN_PASSWORD in .env file"
        exit 1
    fi
}

start_traefik() {
    if ! docker network inspect traefik-local &>/dev/null; then
        echo "Creating traefik-local network..."
        docker network create traefik-local
    fi
    
    echo "Starting Traefik..."
    docker compose -f traefik-compose.yaml up -d
    sleep 3
}

start_erpnext() {
    check_env
    
    SITE_NAME="${SITE_NAME:-erpnext.localhost}"
    TRAEFIK_HTTPS_PORT="${TRAEFIK_HTTPS_PORT:-9443}"
    TRAEFIK_DASHBOARD_PORT="${TRAEFIK_DASHBOARD_PORT:-9081}"
    
    echo "Starting ERPNext..."
    docker compose -f compose.yaml -f compose.local.yaml up -d
    
    echo "Waiting for containers..."
    sleep 10
    
    if ! docker compose exec -T backend bench --site "$SITE_NAME" list-apps &>/dev/null; then
        echo ""
        echo "Site '$SITE_NAME' not found. Creating..."
        
        for i in {1..30}; do
            if docker compose exec -T db healthcheck.sh --connect --innodb_initialized 2>/dev/null; then
                echo "Database ready!"
                break
            fi
            echo "Waiting for database... ($i/30)"
            sleep 2
        done
        
        docker compose exec -T backend bench new-site "$SITE_NAME" \
            --mariadb-user-host-login-scope='%' \
            --db-root-password "$DB_PASSWORD" \
            --admin-password "$ADMIN_PASSWORD" \
            --install-app erpnext \
            --no-mariadb-socket 2>&1 | tail -10
    fi
}

stop_all() {
    echo "Stopping ERPNext..."
    docker compose -f compose.yaml -f compose.local.yaml down 2>/dev/null || true
    echo "Stopping Traefik..."
    docker compose -f traefik-compose.yaml down 2>/dev/null || true
}

show_status() {
    echo "=== Traefik ==="
    docker compose -f traefik-compose.yaml ps 2>/dev/null || echo "Not running"
    echo ""
    echo "=== ERPNext ==="
    docker compose -f compose.yaml -f compose.local.yaml ps 2>/dev/null || echo "Not running"
}

show_logs() {
    docker compose -f compose.yaml -f compose.local.yaml logs -f
}

reset_all() {
    echo "WARNING: This will delete all data!"
    read -p "Are you sure? (yes/no): " confirm
    if [ "$confirm" = "yes" ]; then
        echo "Stopping and removing containers and volumes..."
        docker compose -f compose.yaml -f compose.local.yaml down -v 2>/dev/null || true
        docker compose -f traefik-compose.yaml down -v 2>/dev/null || true
        rm -f .env
        echo "Reset complete. Run './start-local.sh start' to recreate."
    else
        echo "Cancelled."
    fi
}

COMMAND="${1:-start}"

case "$COMMAND" in
    start)
        echo "============================================================"
        echo "  ERPNext Local - Starting"
        echo "============================================================"
        start_traefik
        start_erpnext
        source "$ENV_FILE" 2>/dev/null || true
        SITE_NAME="${SITE_NAME:-erpnext.localhost}"
        TRAEFIK_HTTPS_PORT="${TRAEFIK_HTTPS_PORT:-9443}"
        TRAEFIK_DASHBOARD_PORT="${TRAEFIK_DASHBOARD_PORT:-9081}"
        echo "Setting host_name"
        docker compose exec backend bench --site ${SITE_NAME} set-config host_name "https://${SITE_NAME}:${TRAEFIK_HTTPS_PORT}"
        echo ""
        echo "============================================================"
        echo "  ERPNext Ready!"
        echo ""
        echo "  URL:      https://${SITE_NAME}:${TRAEFIK_HTTPS_PORT}"
        echo "  User:     Administrator"
        echo "  Password: (see .env file)"
        echo ""
        echo "  Traefik Dashboard: http://localhost:${TRAEFIK_DASHBOARD_PORT}"
        echo ""
        echo "  Add to /etc/hosts:"
        echo "  127.0.0.1 ${SITE_NAME}"
        echo "============================================================"
        ;;
    stop)
        stop_all
        ;;
    restart)
        stop_all
        sleep 2
        start_traefik
        start_erpnext
        ;;
    status)
        show_status
        ;;
    logs)
        show_logs
        ;;
    reset)
        reset_all
        ;;
    help|--help|-h)
        usage
        ;;
    *)
        echo "Unknown command: $COMMAND"
        usage
        ;;
esac
