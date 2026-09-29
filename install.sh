#!/usr/bin/env bash
# ==============================================================================
# Script Name   : install.sh
# Description   : Professional Multi-Instance Odoo (v16-v20) + PostgreSQL 17 (pgvector) Installer
# Author        : elblasy.app
# Website       : https://elblasy.app
# GitHub        : https://github.com/elblasy33/last-odoo
# Compatibility : Ubuntu 20.04 / 22.04 / 24.04 LTS & Debian 11/12
# Supports      : Odoo 16 / 17 / 18 / 19 / 20 (AI Agents & RAG with PostgreSQL 17 + pgvector)
# ==============================================================================

set -euo pipefail

# ------------------------------------------------------------------------------
# Color & Typography System (ANSI 256-Color)
# ------------------------------------------------------------------------------
if [[ -t 1 ]]; then
    NC='\033[0m'; BOLD='\033[1m'; DIM='\033[2m'; UNDERLINE='\033[4m'
    RED='\033[38;5;196m'; GREEN='\033[38;5;46m'; YELLOW='\033[38;5;220m'
    BLUE='\033[38;5;39m'; PURPLE='\033[38;5;135m'; CYAN='\033[38;5;51m'
    WHITE='\033[38;5;255m'; GRAY='\033[38;5;244m'
    B1='\033[38;5;99m'; B2='\033[38;5;105m'; B3='\033[38;5;75m'
    B4='\033[38;5;45m'; B5='\033[38;5;51m'
else
    NC=''; BOLD=''; DIM=''; UNDERLINE=''
    RED=''; GREEN=''; YELLOW=''; BLUE=''
    PURPLE=''; CYAN=''; WHITE=''; GRAY=''
    B1=''; B2=''; B3=''; B4=''; B5=''
fi

# ------------------------------------------------------------------------------
# Global Paths & Constants
# ------------------------------------------------------------------------------
readonly BASE_DIR="/opt/elblasy-odoo"
readonly INSTANCES_DIR="${BASE_DIR}/instances"
readonly GLOBAL_BIN="/usr/local/bin"
readonly CLI_NAME="elblasy-odoo"
readonly CLI_ALIAS="elblasy"
readonly PG_IMAGE="pgvector/pgvector:pg17"
readonly LOG_DIR="/var/log/elblasy-odoo"

# Runtime variables (populated during setup wizard)
INSTANCE_NAME=""
TARGET_DIR=""
ODOO_VERSION=""
ODOO_IMAGE=""
HTTP_PORT=""
CHAT_PORT=""
DB_PORT=""
POSTGRES_USER=""
POSTGRES_PASSWORD=""
POSTGRES_DB="postgres"
ODOO_ADMIN_PASSWORD=""
WORKERS_COUNT=2
SHARED_BUFFERS="256MB"
EFFECTIVE_CACHE_SIZE="768MB"
WORK_MEM="32MB"
MAINTENANCE_WORK_MEM="128MB"

# ------------------------------------------------------------------------------
# Logging
# ------------------------------------------------------------------------------
mkdir -p "${LOG_DIR}" 2>/dev/null || true
INSTALL_LOG="${LOG_DIR}/install_$(date +%Y%m%d_%H%M%S).log"
touch "${INSTALL_LOG}" 2>/dev/null || INSTALL_LOG="/tmp/elblasy_install_$(date +%Y%m%d_%H%M%S).log"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "${INSTALL_LOG}"; }

# ------------------------------------------------------------------------------
# UI Helpers
# ------------------------------------------------------------------------------
print_banner() {
    clear
    echo -e "${B1}   ______  __      ____  __       ___    _______  __     ${B5}     ___     ____  ____ ${NC}"
    echo -e "${B2}  / ____/ / /     / __ )/ /      /   |  / ___/\\ \\/ /     ${B5}    /   |   / __ \\/ __ \\${NC}"
    echo -e "${B3} / __/   / /     / __  / /      / /| |  \\__ \\  \\  /      ${B5}   / /| |  / /_/ / /_/ /${NC}"
    echo -e "${B4}/ /___  / /___  / /_/ / /___   / ___ | ___/ /  / /       ${B5}  / ___ | / ____/ ____/ ${NC}"
    echo -e "${B5}\\____/ /_____/ /_____/_____/  /_/  |_|/____/  /_/        ${B5} /_/  |_|/_/   /_/      ${NC}"
    echo ""
    echo -e "${B2}${BOLD}  ╔═══════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${B2}${BOLD}  ║${WHITE}  Enterprise Odoo (v16-v20) Multi-Instance Suite + PostgreSQL 17 pgvector${B2} ║${NC}"
    echo -e "${B2}${BOLD}  ║${CYAN}  AI-Ready Architecture | Dynamic Port Hunter | Zero-Conflict Deployment  ${B2} ║${NC}"
    echo -e "${B2}${BOLD}  ║${YELLOW}  Powered by elblasy.app — Empowering Modern Cloud Infrastructure        ${B2} ║${NC}"
    echo -e "${B2}${BOLD}  ╚═══════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

info()    { echo -e "${BLUE}${BOLD}[INFO]${NC}    $*"; log "INFO: $*"; }
success() { echo -e "${GREEN}${BOLD}[SUCCESS]${NC} $*"; log "SUCCESS: $*"; }
warn()    { echo -e "${YELLOW}${BOLD}[WARNING]${NC} $*"; log "WARNING: $*"; }
error()   { echo -e "${RED}${BOLD}[ERROR]${NC}   $*" >&2; log "ERROR: $*"; }
die()     { error "$*"; exit 1; }

step_header() {
    echo ""
    echo -e "${PURPLE}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}${BOLD}▶ $*${NC}"
    echo -e "${PURPLE}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    log "STEP: $*"
}

spinner() {
    local pid=$1 msg="$2"
    local spin='|/-\\'
    while kill -0 "$pid" 2>/dev/null; do
        printf "\r${CYAN}[%c]${NC} %s..." "${spin:0:1}" "$msg"
        spin="${spin:1}${spin:0:1}"
        sleep 0.15
    done
    printf "\r${GREEN}[OK]${NC} %s\n" "$msg"
}

read_tty() {
    local prompt="$1" varname="$2" default="${3:-}"
    local val=""
    if [[ -t 0 ]]; then
        read -rp "$prompt" val || val=""
    elif [[ -e /dev/tty ]]; then
        read -rp "$prompt" val </dev/tty || val=""
    fi
    printf -v "$varname" '%s' "${val:-$default}"
}

# ------------------------------------------------------------------------------
# Pre-flight Checks
# ------------------------------------------------------------------------------
check_root() {
    [[ $EUID -eq 0 ]] || die "Root privileges required. Run: sudo bash $0"
}

check_os() {
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
    else
        die "Cannot detect OS. This script targets Ubuntu / Debian."
    fi
    if [[ "${ID:-}" != "ubuntu" && "${ID:-}" != "debian" ]]; then
        warn "Unsupported OS: ${NAME:-Unknown}. Tested on Ubuntu/Debian only."
        local ans="n"
        read_tty "Continue anyway? [y/N]: " ans "n"
        [[ "$ans" =~ ^[Yy]$ ]] || exit 1
    else
        success "Compatible OS: ${BOLD}${NAME} ${VERSION_ID:-}${NC}"
    fi
}

# ------------------------------------------------------------------------------
# Port Hunter
# ------------------------------------------------------------------------------
port_in_use() {
    local p=$1
    ss -tuln 2>/dev/null | grep -q ":${p} " && return 0
    return 1
}

next_free_port() {
    local p=$1
    while port_in_use "$p"; do
        log "Port ${p} busy, trying $((p+1))"
        p=$((p + 1))
    done
    echo "$p"
}

# ------------------------------------------------------------------------------
# Docker & Compose Setup
# ------------------------------------------------------------------------------
install_docker() {
    step_header "1. Verifying Docker Engine & Compose V2"

    if command -v docker &>/dev/null && docker compose version &>/dev/null; then
        success "Docker Engine & Compose V2 already installed."
        return
    fi

    info "Installing Docker Engine & Compose V2..."
    (
        export DEBIAN_FRONTEND=noninteractive
        apt-get update -y
        apt-get install -y ca-certificates curl gnupg lsb-release jq
        install -m 0755 -d /etc/apt/keyrings
        if [[ ! -f /etc/apt/keyrings/docker.gpg ]]; then
            curl -fsSL "https://download.docker.com/linux/${ID}/gpg" \
                | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
            chmod a+r /etc/apt/keyrings/docker.gpg
        fi
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/${ID} $(lsb_release -cs) stable" \
            > /etc/apt/sources.list.d/docker.list
        apt-get update -y
        apt-get install -y docker-ce docker-ce-cli containerd.io \
            docker-buildx-plugin docker-compose-plugin
        systemctl enable --now docker
    ) >> "${INSTALL_LOG}" 2>&1 &
    spinner $! "Installing Docker Engine"
    success "Docker Engine & Compose V2 ready."
}

# ------------------------------------------------------------------------------
# Odoo Version -> Docker Image Mapping
# ------------------------------------------------------------------------------
resolve_odoo_image() {
    local ver="$1"
    case "$ver" in
        16) echo "odoo:16" ;;
        17) echo "odoo:17" ;;
        18) echo "odoo:18" ;;
        19)
            warn "Odoo 19 has no official Docker Hub image yet — using odoo:17 as placeholder."
            warn "Update ODOO_IMAGE in .env once the official image is published."
            echo "odoo:17"
            ;;
        20)
            # Check for locally built image
            local local_img
            local_img=$(docker images --format '{{.Repository}}:{{.Tag}}' 2>/dev/null \
                | grep -iE '^odoo:20$|^odoo20' | head -n1 || true)
            if [[ -n "$local_img" ]]; then
                echo "$local_img"
            else
                warn "Odoo 20 has no official Docker Hub image yet — using odoo:17 as placeholder."
                warn "Update ODOO_IMAGE in .env once the official image is published."
                echo "odoo:17"
            fi
            ;;
        *) echo "odoo:17" ;;
    esac
}

# ------------------------------------------------------------------------------
# List Existing Instances
# ------------------------------------------------------------------------------
list_existing_instances() {
    [[ -d "$INSTANCES_DIR" ]] || return 0
    local count
    count=$(find "$INSTANCES_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l)
    [[ "$count" -gt 0 ]] || return 0

    echo -e "${YELLOW}${BOLD}Existing instances on this server:${NC}"
    local inst http_p stat
    for inst in "${INSTANCES_DIR}"/*/; do
        [[ -d "$inst" ]] || continue
        local name; name=$(basename "$inst")
        http_p="?"
        [[ -f "${inst}.env" ]] && http_p=$(grep -E '^ODOO_HTTP_PORT=' "${inst}.env" 2>/dev/null | cut -d= -f2 || echo "?")
        if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^odoo_${name}$"; then
            stat="${GREEN}Running${NC}"
        else
            stat="${GRAY}Stopped${NC}"
        fi
        echo -e "  ${BOLD}${name}${NC}  |  Port: ${CYAN}${http_p}${NC}  |  ${stat}"
    done
    echo ""
}

auto_name() {
    local ver="${1:-20}"
    local base="odoo${ver}"
    local n=1
    while [[ -d "${INSTANCES_DIR}/${base}-${n}" ]]; do n=$((n+1)); done
    echo "${base}-${n}"
}

# ------------------------------------------------------------------------------
# Hardware Auto-Tuning
# ------------------------------------------------------------------------------
tune_for_hardware() {
    local ram_kb ram_mb
    ram_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    ram_mb=$((ram_kb / 1024))

    if   [[ $ram_mb -lt 2048 ]]; then
        SHARED_BUFFERS="256MB"; EFFECTIVE_CACHE_SIZE="768MB"
        WORK_MEM="32MB";  MAINTENANCE_WORK_MEM="128MB"; WORKERS_COUNT=2
    elif [[ $ram_mb -lt 4096 ]]; then
        SHARED_BUFFERS="512MB"; EFFECTIVE_CACHE_SIZE="1536MB"
        WORK_MEM="64MB";  MAINTENANCE_WORK_MEM="256MB"; WORKERS_COUNT=3
    elif [[ $ram_mb -lt 8192 ]]; then
        SHARED_BUFFERS="1GB";   EFFECTIVE_CACHE_SIZE="3GB"
        WORK_MEM="128MB"; MAINTENANCE_WORK_MEM="512MB"; WORKERS_COUNT=5
    else
        SHARED_BUFFERS="2GB";   EFFECTIVE_CACHE_SIZE="6GB"
        WORK_MEM="256MB"; MAINTENANCE_WORK_MEM="1GB"
        WORKERS_COUNT=$(( ($(nproc) * 2) + 1 ))
    fi
    log "Tuning: RAM=${ram_mb}MB workers=${WORKERS_COUNT} shared_buffers=${SHARED_BUFFERS}"
}

# ------------------------------------------------------------------------------
# Interactive Setup Wizard
# ------------------------------------------------------------------------------
setup_wizard() {
    step_header "2. Instance Configuration Wizard"
    mkdir -p "$INSTANCES_DIR"
    list_existing_instances

    # Version selection
    echo -e "${WHITE}${BOLD}Select Odoo Version to deploy:${NC}"
    echo -e "  ${CYAN}1)${NC} Odoo ${BOLD}20${NC} ${YELLOW}[Cutting-Edge — AI Agents & pgvector RAG]${NC}"
    echo -e "  ${CYAN}2)${NC} Odoo ${BOLD}19${NC} ${DIM}(Preview — no official image yet)${NC}"
    echo -e "  ${CYAN}3)${NC} Odoo ${BOLD}18${NC} ${GREEN}[Latest Stable LTS — Recommended]${NC}"
    echo -e "  ${CYAN}4)${NC} Odoo ${BOLD}17${NC} ${GREEN}[Long Term Support]${NC}"
    echo -e "  ${CYAN}5)${NC} Odoo ${BOLD}16${NC} ${GREEN}[Long Term Support]${NC}"
    echo -e "  ${CYAN}6)${NC} Custom Docker image"
    echo ""

    local vchoice="3"
    read_tty "Enter choice [1-6, default=3 (Odoo 18)]: " vchoice "3"

    case "$vchoice" in
        1) ODOO_VERSION="20"; ODOO_IMAGE=$(resolve_odoo_image 20) ;;
        2) ODOO_VERSION="19"; ODOO_IMAGE=$(resolve_odoo_image 19) ;;
        3) ODOO_VERSION="18"; ODOO_IMAGE=$(resolve_odoo_image 18) ;;
        4) ODOO_VERSION="17"; ODOO_IMAGE=$(resolve_odoo_image 17) ;;
        5) ODOO_VERSION="16"; ODOO_IMAGE=$(resolve_odoo_image 16) ;;
        6)
            ODOO_VERSION="custom"
            read_tty "Custom Docker image (e.g. odoo:18, myrepo/odoo:20): " ODOO_IMAGE "odoo:17"
            ;;
        *) ODOO_VERSION="18"; ODOO_IMAGE="odoo:18" ;;
    esac
    success "Selected: Odoo ${BOLD}${ODOO_VERSION}${NC} — image: ${CYAN}${ODOO_IMAGE}${NC}"

    # Instance name
    local default_name; default_name=$(auto_name "$ODOO_VERSION")
    echo ""
    local INPUT_NAME=""
    read_tty "Instance name [default: ${default_name}]: " INPUT_NAME "$default_name"

    # Sanitize
    local raw
    raw=$(echo "${INPUT_NAME:-$default_name}" \
        | tr '[:upper:]' '[:lower:]' \
        | tr -cs 'a-z0-9-' '-' \
        | sed 's/^-*//;s/-*$//')
    [[ -z "$raw" ]] && raw="$default_name"

    if [[ "$raw" =~ ^odoo[0-9]+ ]]; then
        INSTANCE_NAME="$raw"
    else
        INSTANCE_NAME="odoo${ODOO_VERSION}-${raw}"
    fi
    TARGET_DIR="${INSTANCES_DIR}/${INSTANCE_NAME}"

    if [[ -d "$TARGET_DIR" ]]; then
        die "Instance '${INSTANCE_NAME}' already exists. Choose a different name or run: elblasy delete ${INSTANCE_NAME}"
    fi
    info "Instance path: ${BOLD}${TARGET_DIR}${NC}"

    # Port allocation
    step_header "3. Smart Port Allocation (Zero-Conflict Hunter)"

    info "Scanning for free HTTP port starting at 8069..."
    HTTP_PORT=$(next_free_port 8069)
    [[ "$HTTP_PORT" -eq 8069 ]] \
        && success "HTTP port: ${CYAN}${HTTP_PORT}${NC}" \
        || warn "8069 busy — assigned: ${CYAN}${HTTP_PORT}${NC}"

    info "Scanning for free longpolling port starting at 8072..."
    local lp_start=$((HTTP_PORT + 3))
    if ! port_in_use 8072 && [[ "$HTTP_PORT" -ne 8072 ]]; then
        CHAT_PORT=8072
    else
        CHAT_PORT=$(next_free_port "$lp_start")
    fi
    success "Longpolling port: ${CYAN}${CHAT_PORT}${NC}"

    info "Scanning for free PostgreSQL host port starting at 5432..."
    DB_PORT=$(next_free_port 5432)
    success "PostgreSQL host port: ${CYAN}${DB_PORT}${NC}  (bound to 127.0.0.1 only)"

    # Credentials
    POSTGRES_USER="odoo_$(echo "${INSTANCE_NAME}" | tr '-' '_')"
    POSTGRES_PASSWORD=$(openssl rand -hex 20)
    ODOO_ADMIN_PASSWORD=$(openssl rand -base64 18 | tr -dc 'a-zA-Z0-9' | head -c 20)

    tune_for_hardware

    echo ""
    echo -e "${B3}${BOLD}  +-- Instance Summary --------------------------------------------------------+${NC}"
    echo -e "  |  Instance Name  : ${WHITE}${INSTANCE_NAME}${NC}"
    echo -e "  |  Odoo Version   : ${GREEN}Odoo ${ODOO_VERSION}${NC} -> ${CYAN}${ODOO_IMAGE}${NC}"
    echo -e "  |  HTTP Port      : ${CYAN}${HTTP_PORT}${NC}"
    echo -e "  |  Longpolling    : ${CYAN}${CHAT_PORT}${NC}"
    echo -e "  |  DB Host Port   : ${CYAN}${DB_PORT}${NC}  (127.0.0.1 only)"
    echo -e "  |  Workers        : ${GREEN}${WORKERS_COUNT}${NC}  (auto-tuned to hardware)"
    echo -e "  |  PostgreSQL     : ${PURPLE}pgvector/pgvector:pg17 (AI Vector Ready)${NC}"
    echo -e "${B3}${BOLD}  +----------------------------------------------------------------------------+${NC}"
    echo ""
}

# ------------------------------------------------------------------------------
# Directory Structure
# ------------------------------------------------------------------------------
create_filesystem() {
    step_header "4. Creating Isolated Directory Layout"
    (
        mkdir -p \
            "${TARGET_DIR}/etc" \
            "${TARGET_DIR}/addons" \
            "${TARGET_DIR}/data" \
            "${TARGET_DIR}/db_data" \
            "${TARGET_DIR}/backups" \
            "${TARGET_DIR}/init-db"
        chmod 777 "${TARGET_DIR}/data" "${TARGET_DIR}/addons"
        chmod 755 "${TARGET_DIR}/etc" "${TARGET_DIR}/db_data"
        chmod 700 "${TARGET_DIR}/backups"
    ) &
    spinner $! "Creating folder structure"
    success "Directory layout ready: ${WHITE}${TARGET_DIR}${NC}"
}

# ------------------------------------------------------------------------------
# Configuration Files
# Variables are expanded here when writing; docker-compose.yml uses literal
# ${VAR} so Docker Compose reads them from .env at runtime.
# ------------------------------------------------------------------------------
generate_configs() {
    step_header "5. Generating Configuration Files"

    local gen_date; gen_date=$(date '+%Y-%m-%d %H:%M:%S')

    # 1. PostgreSQL init SQL (extensions only — Odoo creates its own databases)
    cat > "${TARGET_DIR}/init-db/01-pgvector-init.sql" <<SQL
-- =============================================================================
-- pgvector & Essential Extensions Bootstrap — elblasy.app
-- Runs ONCE on first PostgreSQL container startup
-- =============================================================================
\\c postgres
CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS unaccent;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- template1 ensures every new database created by Odoo inherits these extensions
\\c template1
CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS unaccent;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS pg_trgm;

DO \$\$
BEGIN
    RAISE NOTICE 'elblasy.app: pgvector extensions loaded on postgres & template1 successfully.';
END \$\$;
SQL

    # 2. Odoo config (etc/odoo.conf)
    cat > "${TARGET_DIR}/etc/odoo.conf" <<ODOOCONF
[options]
; =============================================================================
; Odoo ${ODOO_VERSION} Configuration — elblasy.app
; Instance  : ${INSTANCE_NAME}
; Generated : ${gen_date}
; =============================================================================

addons_path = /mnt/extra-addons
data_dir    = /var/lib/odoo

; Master Password (database manager access)
admin_passwd = ${ODOO_ADMIN_PASSWORD}

; Database
db_host     = db
db_port     = 5432
db_user     = ${POSTGRES_USER}
db_password = ${POSTGRES_PASSWORD}
db_name     = False
db_maxconn  = 64
dbfilter    = .*
list_db     = True

; Network (compatible with Odoo 16 through 20)
http_interface = 0.0.0.0
http_port      = 8069
gevent_port    = 8072
proxy_mode     = True

; Workers & Performance (hardware-tuned)
workers              = ${WORKERS_COUNT}
max_cron_threads     = 2
limit_memory_hard    = 2684354560
limit_memory_soft    = 2147483648
limit_request        = 8192
limit_time_cpu       = 600
limit_time_real      = 1200
limit_time_real_cron = 1800

; Logging — Docker stdout (do NOT set logfile)
log_level = info
log_db    = False
ODOOCONF
    chmod 644 "${TARGET_DIR}/etc/odoo.conf"

    # 3. .env file
    cat > "${TARGET_DIR}/.env" <<ENVFILE
# =============================================================================
# Instance Environment — elblasy.app
# Instance  : ${INSTANCE_NAME}
# Generated : ${gen_date}
# =============================================================================
COMPOSE_PROJECT_NAME=elblasy_$(echo "${INSTANCE_NAME}" | tr '-' '_')
INSTANCE_NAME=${INSTANCE_NAME}

ODOO_IMAGE=${ODOO_IMAGE}
POSTGRES_IMAGE=${PG_IMAGE}

ODOO_HTTP_PORT=${HTTP_PORT}
ODOO_CHAT_PORT=${CHAT_PORT}
POSTGRES_EXTERNAL_PORT=${DB_PORT}

POSTGRES_USER=${POSTGRES_USER}
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
POSTGRES_DB=${POSTGRES_DB}
ODOO_ADMIN_PASSWORD=${ODOO_ADMIN_PASSWORD}

SHARED_BUFFERS=${SHARED_BUFFERS}
EFFECTIVE_CACHE_SIZE=${EFFECTIVE_CACHE_SIZE}
WORK_MEM=${WORK_MEM}
MAINTENANCE_WORK_MEM=${MAINTENANCE_WORK_MEM}
ENVFILE
    chmod 600 "${TARGET_DIR}/.env"

    # 4. docker-compose.yml  — uses literal ${VAR} (read from .env by Compose)
    # Single-quote EOF prevents shell expansion; Compose will expand from .env
    cat > "${TARGET_DIR}/docker-compose.yml" <<'COMPOSE_HEREDOC'
# =============================================================================
# Docker Compose — elblasy.app Multi-Instance Odoo Stack
# Variables are resolved from .env at runtime by Docker Compose
# =============================================================================
services:

  db:
    image: ${POSTGRES_IMAGE}
    container_name: db_${INSTANCE_NAME}
    restart: unless-stopped
    command: >
      postgres
        -c shared_buffers=${SHARED_BUFFERS}
        -c effective_cache_size=${EFFECTIVE_CACHE_SIZE}
        -c work_mem=${WORK_MEM}
        -c maintenance_work_mem=${MAINTENANCE_WORK_MEM}
        -c max_connections=200
        -c random_page_cost=1.1
        -c checkpoint_completion_target=0.9
        -c wal_buffers=16MB
    environment:
      POSTGRES_USER:     ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_DB:       ${POSTGRES_DB}
      PGDATA:            /var/lib/postgresql/data/pgdata
    volumes:
      - ./db_data:/var/lib/postgresql/data
      - ./init-db:/docker-entrypoint-initdb.d:ro
    ports:
      - "127.0.0.1:${POSTGRES_EXTERNAL_PORT}:5432"
    networks:
      - odoo_net
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB}"]
      interval: 5s
      timeout: 5s
      retries: 15
      start_period: 10s

  web:
    image: ${ODOO_IMAGE}
    container_name: odoo_${INSTANCE_NAME}
    restart: unless-stopped
    command: odoo --config=/etc/odoo/odoo.conf
    depends_on:
      db:
        condition: service_healthy
    environment:
      HOST:     db
      PORT:     "5432"
      USER:     ${POSTGRES_USER}
      PASSWORD: ${POSTGRES_PASSWORD}
    ports:
      - "${ODOO_HTTP_PORT}:8069"
      - "${ODOO_CHAT_PORT}:8072"
    volumes:
      - ./etc/odoo.conf:/etc/odoo/odoo.conf:ro
      - ./data:/var/lib/odoo
      - ./addons:/mnt/extra-addons
    networks:
      - odoo_net

networks:
  odoo_net:
    name: net_${INSTANCE_NAME}
    driver: bridge
COMPOSE_HEREDOC

    success "Configuration files generated successfully."
}

# ------------------------------------------------------------------------------
# Pull Images & Launch Containers
# ------------------------------------------------------------------------------
start_and_verify() {
    step_header "6. Pulling Images & Launching Containers"

    if ! docker image inspect "${PG_IMAGE}" &>/dev/null; then
        info "Pulling ${PG_IMAGE} ..."
        docker pull "${PG_IMAGE}" 2>&1 | tee -a "${INSTALL_LOG}"
        success "PostgreSQL 17 + pgvector image ready."
    else
        success "PostgreSQL 17 + pgvector image already cached locally."
    fi

    if ! docker image inspect "${ODOO_IMAGE}" &>/dev/null; then
        info "Pulling Odoo image ${ODOO_IMAGE} (may take 2-5 min)..."
        docker pull "${ODOO_IMAGE}" 2>&1 | tee -a "${INSTALL_LOG}"
        success "Odoo image downloaded."
    else
        success "Odoo image ${ODOO_IMAGE} already cached locally."
    fi

    echo ""
    info "Launching container stack for instance '${INSTANCE_NAME}'..."
    (cd "${TARGET_DIR}" && docker compose up -d) 2>&1 | tee -a "${INSTALL_LOG}"
    success "Container stack started in background."

    # Wait for DB
    echo ""
    info "Waiting for PostgreSQL 17 to become ready..."
    local db_ok=false i
    for i in $(seq 1 40); do
        printf "\r${CYAN}[%02d/40]${NC} Database health probe..." "$i"
        if docker exec "db_${INSTANCE_NAME}" pg_isready -U "${POSTGRES_USER}" &>/dev/null; then
            db_ok=true
            printf "\r${GREEN}[OK]${NC} PostgreSQL is accepting connections!                          \n"
            break
        fi
        sleep 3
    done
    $db_ok || { echo ""; warn "DB taking longer; monitor with: elblasy logs ${INSTANCE_NAME}"; }

    # Check pgvector
    if $db_ok; then
        local vec
        vec=$(docker exec -i "db_${INSTANCE_NAME}" \
            psql -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" \
            -tAc "SELECT count(*) FROM pg_extension WHERE extname='vector';" 2>/dev/null || echo "0")
        vec=$(echo "$vec" | tr -d '[:space:]')
        if [[ "${vec:-0}" -ge 1 ]]; then
            success "pgvector (AI Vector Embeddings) extension is ACTIVE!"
        else
            warn "pgvector not confirmed yet — may still be initializing via init-db script."
        fi
    fi

    # Wait for Odoo HTTP
    echo ""
    info "Waiting for Odoo HTTP service on port ${HTTP_PORT}..."
    local odoo_ok=false
    for i in $(seq 1 50); do
        printf "\r${CYAN}[%02d/50]${NC} Probing http://127.0.0.1:${HTTP_PORT} ..." "$i"
        local code
        code=$(curl -s -o /dev/null -w "%{http_code}" \
            "http://127.0.0.1:${HTTP_PORT}/web/health" 2>/dev/null \
            || curl -s -o /dev/null -w "%{http_code}" \
            "http://127.0.0.1:${HTTP_PORT}" 2>/dev/null || echo "000")
        if [[ "$code" =~ ^(200|302|303|404)$ ]]; then
            odoo_ok=true
            printf "\r${GREEN}[OK]${NC} Odoo responded — HTTP ${code}                              \n"
            break
        fi
        sleep 3
    done
    $odoo_ok || {
        echo ""
        info "Odoo is still initializing its database. Normal for a fresh instance."
        info "Monitor: ${CYAN}elblasy logs ${INSTANCE_NAME}${NC}"
    }
}

# ------------------------------------------------------------------------------
# Install Global CLI (elblasy / elblasy-odoo)
# Written to disk as a separate file (no nested heredoc issues)
# ------------------------------------------------------------------------------
install_cli() {
    step_header "7. Installing Global CLI Tool (elblasy)"

    local cli_path="${GLOBAL_BIN}/${CLI_NAME}"

    cat > "${cli_path}" <<'CLI_EOF'
#!/usr/bin/env bash
# =============================================================================
# elblasy-odoo CLI Manager — Powered by elblasy.app
# Usage: elblasy [command] [instance_name]
# =============================================================================
readonly BASE_DIR="/opt/elblasy-odoo"
readonly INST_DIR="${BASE_DIR}/instances"

BOLD='\033[1m'; NC='\033[0m'
GREEN='\033[38;5;46m'; CYAN='\033[38;5;51m'
YELLOW='\033[38;5;220m'; RED='\033[38;5;196m'
GRAY='\033[38;5;244m'; WHITE='\033[38;5;255m'
PURPLE='\033[38;5;135m'

usage() {
    echo -e "${CYAN}${BOLD}elblasy.app - Odoo Multi-Instance CLI Manager${NC}"
    echo ""
    echo -e "  ${BOLD}Usage:${NC} elblasy <command> [instance]"
    echo ""
    echo -e "${BOLD}Commands:${NC}"
    echo -e "  ${CYAN}list${NC}              List all instances with status & ports"
    echo -e "  ${CYAN}ps${NC}                Show running Odoo containers"
    echo -e "  ${CYAN}start${NC}   <name>    Start an instance"
    echo -e "  ${CYAN}stop${NC}    <name>    Stop an instance"
    echo -e "  ${CYAN}restart${NC} <name>    Restart an instance"
    echo -e "  ${CYAN}logs${NC}    <name>    Follow live logs"
    echo -e "  ${CYAN}info${NC}    <name>    Show credentials & URLs"
    echo -e "  ${CYAN}backup${NC}  <name>    Create a full backup (DB + filestore)"
    echo -e "  ${CYAN}delete${NC}  <name>    Permanently delete instance (with confirmation)"
    echo ""
}

get_all() {
    [[ -d "$INST_DIR" ]] || { echo ""; return; }
    find "$INST_DIR" -mindepth 1 -maxdepth 1 -type d -exec basename {} ';' 2>/dev/null | sort
}

require_inst() {
    local name="$1"
    [[ -n "$name" && -d "${INST_DIR}/${name}" ]] || {
        echo -e "${RED}[ERROR]${NC} Instance '${name}' not found."
        echo "Available instances:"; get_all
        exit 1
    }
}

cmd_list() {
    echo -e "${BOLD}${CYAN}Odoo Instances (elblasy.app)${NC}"
    printf "  %-24s %-10s %-8s %-8s %s\n" "INSTANCE" "STATUS" "HTTP" "CHAT" "IMAGE"
    echo -e "${GRAY}  ---------------------------------------------------------------${NC}"
    local found=0
    for inst in $(get_all); do
        found=1
        local dir="${INST_DIR}/${inst}"
        local http_p="?" chat_p="?" img="?"
        if [[ -f "${dir}/.env" ]]; then
            http_p=$(grep -E '^ODOO_HTTP_PORT=' "${dir}/.env" 2>/dev/null | cut -d= -f2 || echo "?")
            chat_p=$(grep -E '^ODOO_CHAT_PORT='  "${dir}/.env" 2>/dev/null | cut -d= -f2 || echo "?")
            img=$(grep -E '^ODOO_IMAGE=' "${dir}/.env" 2>/dev/null | cut -d= -f2 || echo "?")
        fi
        local stat
        if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^odoo_${inst}$"; then
            stat="${GREEN}Running${NC}"
        else
            stat="${GRAY}Stopped${NC}"
        fi
        printf "  %-24s %-19b %-8s %-8s %s\n" "$inst" "$stat" "$http_p" "$chat_p" "$img"
    done
    [[ $found -eq 0 ]] && echo -e "  ${GRAY}No instances found. Run the installer to create one.${NC}"
    echo ""
}

cmd_ps() {
    docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}' 2>/dev/null \
        | grep -E "odoo_|db_|NAMES" || echo "No running Odoo containers."
}

cmd_info() {
    local inst="$1"
    require_inst "$inst"
    local dir="${INST_DIR}/${inst}"
    echo -e "${BOLD}${CYAN}--- Instance: ${inst} ---${NC}"
    if [[ -f "${dir}/.env" ]]; then
        grep -v '^#' "${dir}/.env" | grep -v '^$' | while IFS= read -r line; do
            echo -e "  ${GRAY}${line}${NC}"
        done
    fi
    echo ""
    local http_p; http_p=$(grep -E '^ODOO_HTTP_PORT=' "${dir}/.env" 2>/dev/null | cut -d= -f2 || echo "?")
    local server_ip; server_ip=$(curl -s -4 --max-time 3 ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')
    echo -e "  ${BOLD}Web URL   :${NC} ${CYAN}http://${server_ip}:${http_p}${NC}"
    echo -e "  ${BOLD}Config    :${NC} ${dir}/etc/odoo.conf"
    echo -e "  ${BOLD}Addons    :${NC} ${dir}/addons"
    echo -e "  ${BOLD}Filestore :${NC} ${dir}/data"
    echo ""
}

cmd_backup() {
    local inst="$1"
    require_inst "$inst"
    local dir="${INST_DIR}/${inst}"
    local bdir="${dir}/backups"
    local ts; ts=$(date +%Y%m%d_%H%M%S)
    mkdir -p "$bdir"

    local pg_user pg_db
    pg_user=$(grep -E '^POSTGRES_USER=' "${dir}/.env" | cut -d= -f2)
    pg_db=$(grep   -E '^POSTGRES_DB='   "${dir}/.env" | cut -d= -f2)

    echo -e "${CYAN}Creating backup for ${inst}...${NC}"
    local dump="${bdir}/dump_${ts}.sql"
    docker exec -t "db_${inst}" pg_dumpall -U "${pg_user}" > "${dump}" || {
        echo -e "${RED}[ERROR]${NC} Database dump failed."
        exit 1
    }
    local archive="${bdir}/backup_${inst}_${ts}.tar.gz"
    tar -czf "${archive}" -C "${dir}" data etc backups/$(basename "${dump}")
    rm -f "${dump}"
    echo -e "${GREEN}[OK]${NC} Backup saved: ${archive}"
}

ACTION="${1:-}"
INST="${2:-}"

case "$ACTION" in
    ""|list)  cmd_list ;;
    ps)       cmd_ps ;;
    start)    require_inst "$INST"; echo -e "${CYAN}Starting ${INST}...${NC}"; (cd "${INST_DIR}/${INST}" && docker compose up -d) ;;
    stop)     require_inst "$INST"; echo -e "${YELLOW}Stopping ${INST}...${NC}"; (cd "${INST_DIR}/${INST}" && docker compose stop) ;;
    restart)  require_inst "$INST"; echo -e "${CYAN}Restarting ${INST}...${NC}"; (cd "${INST_DIR}/${INST}" && docker compose restart) ;;
    logs)     require_inst "$INST"; (cd "${INST_DIR}/${INST}" && docker compose logs -f --tail=150) ;;
    info)     cmd_info "$INST" ;;
    backup)   cmd_backup "$INST" ;;
    delete)
        require_inst "$INST"
        local_confirm="no"
        if [[ -t 0 ]]; then
            read -rp "Type 'yes' to permanently delete '${INST}' and ALL its data: " local_confirm || true
        elif [[ -e /dev/tty ]]; then
            read -rp "Type 'yes' to permanently delete '${INST}' and ALL its data: " local_confirm </dev/tty || true
        fi
        if [[ "$local_confirm" == "yes" ]]; then
            echo -e "${RED}Stopping containers and removing data...${NC}"
            (cd "${INST_DIR}/${INST}" && docker compose down -v) 2>/dev/null || true
            rm -rf "${INST_DIR:?}/${INST}"
            echo -e "${GREEN}Instance '${INST}' deleted successfully.${NC}"
        else
            echo "Deletion cancelled."
        fi
        ;;
    *) usage ;;
esac
CLI_EOF

    chmod +x "${cli_path}"
    ln -sf "${cli_path}" "${GLOBAL_BIN}/${CLI_ALIAS}"
    success "CLI installed: ${BOLD}${CLI_ALIAS}${NC}  (also available as: ${DIM}${CLI_NAME}${NC})"
}

# ------------------------------------------------------------------------------
# Final Summary Card
# ------------------------------------------------------------------------------
display_summary() {
    local server_ip
    server_ip=$(curl -s -4 --max-time 5 ifconfig.me \
        || curl -s -4 --max-time 5 icanhazip.com \
        || hostname -I | awk '{print $1}')

    echo ""
    echo -e "${GREEN}${BOLD}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}${BOLD}║         Odoo Instance Deployed Successfully — AI Ready!                    ║${NC}"
    echo -e "${GREEN}${BOLD}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  🏢  ${BOLD}Provider          :${NC} ${B4}elblasy.app${NC}"
    echo -e "  🏷   ${BOLD}Instance Name     :${NC} ${WHITE}${BOLD}${INSTANCE_NAME}${NC}"
    echo -e "  📦  ${BOLD}Odoo Version      :${NC} ${GREEN}Odoo ${ODOO_VERSION}${NC}  (${CYAN}${ODOO_IMAGE}${NC})"
    echo -e "  🌐  ${BOLD}Web Access        :${NC} ${CYAN}http://${server_ip}:${HTTP_PORT}${NC}"
    echo -e "  💬  ${BOLD}Longpolling       :${NC} ${CYAN}:${CHAT_PORT}${NC}"
    echo -e "  🐘  ${BOLD}Database          :${NC} ${PURPLE}PostgreSQL 17 + pgvector (AI Vector Ready)${NC}"
    echo -e "  🔑  ${BOLD}Master Password   :${NC} ${YELLOW}${BOLD}${ODOO_ADMIN_PASSWORD}${NC}"
    echo -e "  📁  ${BOLD}Instance Root     :${NC} ${WHITE}${TARGET_DIR}${NC}"
    echo -e "  ⚙   ${BOLD}Config File       :${NC} ${WHITE}${TARGET_DIR}/etc/odoo.conf${NC}"
    echo -e "  🧩  ${BOLD}Custom Addons     :${NC} ${WHITE}${TARGET_DIR}/addons${NC}"
    echo -e "  📋  ${BOLD}Install Log       :${NC} ${WHITE}${INSTALL_LOG}${NC}"
    echo ""
    echo -e "${B2}${BOLD}  Multi-Instance Tip:${NC} Run this script again to create more isolated Odoo instances!"
    echo ""
    echo -e "${B3}${BOLD}  CLI Quick Reference:${NC}"
    echo -e "    ${CYAN}elblasy list${NC}                     - Show all instances"
    echo -e "    ${CYAN}elblasy logs ${INSTANCE_NAME}${NC}    - Follow live logs"
    echo -e "    ${CYAN}elblasy restart ${INSTANCE_NAME}${NC} - Restart instance"
    echo -e "    ${CYAN}elblasy backup ${INSTANCE_NAME}${NC}  - Create a full backup"
    echo -e "    ${CYAN}elblasy info ${INSTANCE_NAME}${NC}    - Show credentials & URLs"
    echo -e "    ${CYAN}elblasy delete ${INSTANCE_NAME}${NC}  - Remove instance"
    echo ""
    echo -e "${GREEN}${BOLD}══════════════════════════════════════════════════════════════════════════════${NC}"
    echo ""
}

# ------------------------------------------------------------------------------
# Main
# ------------------------------------------------------------------------------
main() {
    print_banner
    check_root
    check_os
    install_docker
    setup_wizard
    create_filesystem
    generate_configs
    start_and_verify
    install_cli
    display_summary
}

main "$@"
