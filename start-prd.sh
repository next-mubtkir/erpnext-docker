#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

ENV_FILE=".env"
ENV_PRD=".env.prd"
ENV_EXAMPLE=".env.example"
SITE_NAME="${SITE_NAME:-erpnext.example.com}"
BACKUP_DIR="${BACKUP_DIR:-/srv/backups}"

usage() {
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  start       Start ERPNext containers (default)"
    echo "  stop        Stop all containers"
    echo "  restart     Restart containers"
    echo "  status      Show container status"
    echo "  logs        Show logs"
    echo "  backup      Create database backup"
    echo "  migrate     Run database migrations"
    echo "  console     Open Python console"
    echo "  help        Show this help"
    exit 0
}

check_env() {
    if [ ! -f "$ENV_FILE" ]; then
        if [ -f "$ENV_PRD" ]; then
            echo "Copying .env.prd to .env..."
            cp "$ENV_PRD" "$ENV_FILE"
        elif [ -f "$ENV_EXAMPLE" ]; then
            echo "Copying .env.example to .env..."
            echo "IMPORTANT: Edit .env and set your production values!"
            cp "$ENV_EXAMPLE" "$ENV_FILE"
        else
            echo "Error: No .env file found."
            exit 1
        fi
    fi
    
    source "$ENV_FILE"
}

start_erpnext() {
    check_env
    SITE_NAME="${SITE_NAME:-erpnext.example.com}"
    
    echo "Starting ERPNext..."
    docker compose -f compose.yaml -f compose.prd.yaml up -d
    
    echo "Waiting for containers..."
    sleep 5
}

stop_all() {
    echo "Stopping ERPNext..."
    docker compose -f compose.yaml -f compose.prd.yaml down 2>/dev/null || true
}

show_status() {
    echo "=== ERPNext ==="
    docker compose -f compose.yaml -f compose.prd.yaml ps 2>/dev/null || echo "Not running"
}

show_logs() {
    docker compose -f compose.yaml -f compose.prd.yaml logs -f --tail=100
}

create_backup() {
    source "$ENV_FILE" 2>/dev/null || true
    DB_PASSWORD="${DB_PASSWORD:-$(grep '^DB_PASSWORD=' "$ENV_FILE" 2>/dev/null | cut -d'=' -f2)}"
    
    if [ -z "$DB_PASSWORD" ]; then
        echo "Error: DB_PASSWORD not set in .env"
        exit 1
    fi
    
    mkdir -p "$BACKUP_DIR"
    
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    BACKUP_FILE="${BACKUP_DIR}/erpnext_${TIMESTAMP}.sql.gz"
    
    echo "Creating backup: $BACKUP_FILE"
    
    docker compose exec -T db mysqldump -u root -p"${DB_PASSWORD}" --single-transaction --routines --triggers --all-databases | gzip > "$BACKUP_FILE"
    
    echo "Backup completed: $BACKUP_FILE"
    echo "Size: $(du -h "$BACKUP_FILE" | cut -f1)"
    
    echo ""
    echo "Cleaning old backups (keeping last 7)..."
    ls -t "${BACKUP_DIR}"/erpnext_*.sql.gz 2>/dev/null | tail -n +8 | xargs -r rm -f
    echo "Done."
}

run_migrate() {
    echo "Running migrations for $SITE_NAME..."
    docker compose exec backend bench --site "$SITE_NAME" migrate
    echo "Migration completed."
}

open_console() {
    docker compose exec backend bench --site "$SITE_NAME" console
}

COMMAND="${1:-start}"

case "$COMMAND" in
    start)
        echo "============================================================"
        echo "  ERPNext PRD - Starting"
        echo "============================================================"
        start_erpnext
        source "$ENV_FILE" 2>/dev/null || true
        SITE_NAME="${SITE_NAME:-erpnext.example.com}"
        echo ""
        echo "============================================================"
        echo "  ERPNext Ready!"
        echo ""
        echo "  URL:   https://${SITE_NAME}"
        echo "  User:  Administrator"
        echo "============================================================"
        ;;
    stop)
        stop_all
        ;;
    restart)
        stop_all
        sleep 2
        start_erpnext
        ;;
    status)
        show_status
        ;;
    logs)
        show_logs
        ;;
    backup)
        create_backup
        ;;
    migrate)
        run_migrate
        ;;
    console)
        open_console
        ;;
    help|--help|-h)
        usage
        ;;
    *)
        echo "Unknown command: $COMMAND"
        usage
        ;;
esac
