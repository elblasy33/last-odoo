#!/usr/bin/env bash
# ==============================================================================
# Script Name   : install.sh
# Description   : Ultra-Fast, Multi-Instance Odoo & PostgreSQL 17 (pgvector) Installer
# Author        : elblasy.app
# Website       : https://elblasy.app
# GitHub        : https://github.com/elblasy33/last-odoo
# Compatibility : Ubuntu 20.04 / 22.04 / 24.04 LTS & Debian 11/12
# Supports      : Odoo 17 / 18 / 19 / 20 (AI Agents & RAG with PostgreSQL 17)
# ==============================================================================

set -eo pipefail

# ------------------------------------------------------------------------------
# Colors & Typography (ANSI & 256 Colors)
# ------------------------------------------------------------------------------
if [[ -t 1 ]]; then
    NC='\033[0m'
    BOLD='\033[1m'
    DIM='\033[2m'
    ITALIC='\033[3m'
    UNDERLINE='\033[4m'
    
    # Foreground colors
    RED='\033[38;5;196m'
    GREEN='\033[38;5;46m'
    YELLOW='\033[38;5;220m'
    BLUE='\033[38;5;39m'
    PURPLE='\033[38;5;135m'
    CYAN='\033[38;5;51m'
    WHITE='\033[38;5;255m'
    GRAY='\033[38;5;244m'
    
    # Brand gradient colors (Purple to Cyan)
    B1='\033[38;5;99m'
    B2='\033[38;5;105m'
    B3='\033[38;5;75m'
    B4='\033[38;5;45m'
    B5='\033[38;5;51m'
else
    NC=''
    BOLD=''
    DIM=''
    ITALIC=''
    UNDERLINE=''
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    PURPLE=''
    CYAN=''
    WHITE=''
    GRAY=''
    B1=''
    B2=''
    B3=''
    B4=''
    B5=''
fi

# ------------------------------------------------------------------------------
# Global Defaults & Configuration
# ------------------------------------------------------------------------------
BASE_OPT_DIR="/opt/elblasy-odoo"
INSTANCES_DIR="${BASE_OPT_DIR}/instances"
GLOBAL_BIN_DIR="/usr/local/bin"
CLI_NAME="elblasy-odoo"
CLI_ALIAS="elblasy"

POSTGRES_PGVECTOR_IMAGE="pgvector/pgvector:pg17"

# Logging setup
LOG_DIR="/var/log/elblasy-odoo"
mkdir -p "$LOG_DIR"
INSTALL_LOG="${LOG_DIR}/install_$(date +%Y%m%d_%H%M%S).log"

log_to_file() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $1" >> "$INSTALL_LOG"
}

# ------------------------------------------------------------------------------
# UI Helpers & Visuals
# ------------------------------------------------------------------------------
print_banner() {
    clear
    echo -e "${B1}   ______  __      ____  __       ___    _______  __          ___     ____  ____ ${NC}"
    echo -e "${B2}  / ____/ / /     / __ )/ /      /   |  / ___/\\ \\/ /         /   |   / __ \\/ __ \\${NC}"
    echo -e "${B3} / __/   / /     / __  / /      / /| |  \\__ \\  \\  /         / /| |  / /_/ / /_/ /${NC}"
    echo -e "${B4}/ /___  / /___  / /_/ / /___   / ___ | ___/ /  / /         / ___ | / ____/ ____/ ${NC}"
    echo -e "${B5}\\____/ /_____/ /_____/_____/  /_/  |_|/____/  /_/         /_/  |_|/_/   /_/      ${NC}"
    echo -e "${B2}${BOLD}  ╔═══════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${B2}${BOLD}  ║${WHITE}  Enterprise Odoo (v16 - v20) Multi-Instance Suite + PostgreSQL 17        ${B2}║${NC}"
    echo -e "${B2}${BOLD}  ║${CYAN}  AI-Ready Architecture | pgvector Embeddings | Dynamic Port Hunter       ${B2}║${NC}"
    echo -e "${B2}${BOLD}  ║${YELLOW}  Powered by elblasy.app — Empowering Modern Cloud Infrastructure        ${B2}║${NC}"
    echo -e "${B2}${BOLD}  ╚═══════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

info() {
    echo -e "${BLUE}${BOLD}[INFO]${NC} $1"
    log_to_file "INFO: $1"
}

success() {
    echo -e "${GREEN}${BOLD}[SUCCESS]${NC} $1"
    log_to_file "SUCCESS: $1"
}

warn() {
    echo -e "${YELLOW}${BOLD}[WARNING]${NC} $1"
    log_to_file "WARNING: $1"
}

error() {
    echo -e "${RED}${BOLD}[ERROR]${NC} $1"
    log_to_file "ERROR: $1"
}

step_header() {
    echo ""
    echo -e "${PURPLE}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}${BOLD}▶ $1${NC}"
    echo -e "${PURPLE}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    log_to_file "STEP: $1"
}

spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local message="$2"
    while ps -p "$pid" > /dev/null 2>&1; do
        local temp=${spinstr#?}
        printf "\r${CYAN}[%c]${NC} ${message}..." "$spinstr"
        spinstr=$temp${spinstr%"$temp"}
        sleep $delay
    done
    printf "\r${GREEN}[✓]${NC} ${message} (Done)\n"
}

read_from_tty() {
    local prompt="$1"
    local var_name="$2"
    local default_val="$3"
    local input=""
    
    # When executed via `curl ... | bash`, stdin is consumed by the pipe.
    # We must read from /dev/tty to capture terminal keystrokes.
    if [ -t 0 ]; then
        read -r -p "$prompt" input || true
    elif [ -e /dev/tty ]; then
        read -r -p "$prompt" input < /dev/tty || true
    else
        input=""
    fi
    input="${input:-$default_val}"
    printf -v "$var_name" "%s" "$input"
}

# ------------------------------------------------------------------------------
# System & Root Check
# ------------------------------------------------------------------------------
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script requires root privileges! Please rerun using: sudo bash $0"
        exit 1
    fi
}

check_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_NAME=$NAME
        OS_VER=$VERSION_ID
    else
        error "Unable to detect operating system. This script is designed for Ubuntu / Debian."
        exit 1
    fi

    if [[ "$ID" != "ubuntu" && "$ID" != "debian" ]]; then
        warn "Detected OS: $OS_NAME. This script is built and tested for Ubuntu / Debian."
        local proceed="n"
        read_from_tty "Do you want to proceed anyway? (y/n): " proceed "n"
        if [[ "$proceed" != "y" && "$proceed" != "Y" ]]; then
            exit 1
        fi
    else
        info "Operating System is compatible: ${BOLD}$OS_NAME $OS_VER${NC}"
    fi
}

# ------------------------------------------------------------------------------
# Port Hunting Logic (Prevents Any Conflict!)
# ------------------------------------------------------------------------------
is_port_in_use() {
    local port=$1
    if command -v ss >/dev/null 2>&1; then
        ss -tuln | grep -q ":${port} " && return 0
    elif command -v netstat >/dev/null 2>&1; then
        netstat -tuln | grep -q ":${port} " && return 0
    elif command -v lsof >/dev/null 2>&1; then
        lsof -i :"$port" >/dev/null 2>&1 && return 0
    else
        (echo > /dev/tcp/127.0.0.1/"$port") >/dev/null 2>&1 && return 0
    fi
    return 1
}

find_next_free_port() {
    local start_port=$1
    local current_port=$start_port
    while is_port_in_use "$current_port"; do
        log_to_file "Port $current_port is in use, checking next..."
        current_port=$((current_port + 1))
    done
    echo "$current_port"
}

# ------------------------------------------------------------------------------
# Docker & Compose Engine Setup
# ------------------------------------------------------------------------------
install_docker_prerequisites() {
    step_header "1. Verifying Docker & Container Engine (Docker & Compose V2)"

    local need_docker=false
    if ! command -v docker &> /dev/null; then
        need_docker=true
    fi

    if ! docker compose version &> /dev/null; then
        need_docker=true
    fi

    if [ "$need_docker" = true ]; then
        info "Installing and updating Docker Engine & Docker Compose V2..."
        (
            apt-get update -y >> "$INSTALL_LOG" 2>&1
            apt-get install -y ca-certificates curl gnupg lsb-release jq ufw >> "$INSTALL_LOG" 2>&1
            install -m 0755 -d /etc/apt/keyrings
            if [ ! -f /etc/apt/keyrings/docker.gpg ]; then
                curl -fsSL "https://download.docker.com/linux/$ID/gpg" | gpg --dearmor -o /etc/apt/keyrings/docker.gpg >> "$INSTALL_LOG" 2>&1
                chmod a+r /etc/apt/keyrings/docker.gpg
            fi
            echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$ID $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
            apt-get update -y >> "$INSTALL_LOG" 2>&1
            apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin >> "$INSTALL_LOG" 2>&1
            systemctl enable docker >> "$INSTALL_LOG" 2>&1
            systemctl start docker >> "$INSTALL_LOG" 2>&1
        ) &
        spinner $! "Installing Docker Engine & Docker Compose V2"
        success "Docker Engine & Docker Compose V2 installed successfully!"
    else
        success "Docker Engine and Docker Compose are already installed and ready!"
    fi
}

# ------------------------------------------------------------------------------
# Multi-Instance Discovery & Name Selection
# ------------------------------------------------------------------------------
list_existing_instances() {
    if [ -d "$INSTANCES_DIR" ]; then
        local count
        count=$(find "$INSTANCES_DIR" -mindepth 1 -maxdepth 1 -type d | wc -l)
        if [ "$count" -gt 0 ]; then
            echo -e "${YELLOW}${BOLD}Existing Odoo instances on this server:${NC}"
            for inst in "$INSTANCES_DIR"/*; do
                if [ -d "$inst" ]; then
                    local name
                    name=$(basename "$inst")
                    local http_p="Unknown"
                    local status="Stopped"
                    if [ -f "$inst/.env" ]; then
                        http_p=$(grep -E '^ODOO_HTTP_PORT=' "$inst/.env" | cut -d '=' -f2 || echo "8069")
                    fi
                    if docker ps --format '{{.Names}}' | grep -q "odoo_${name}"; then
                        status="${GREEN}Running${NC}"
                    else
                        status="${GRAY}Stopped${NC}"
                    fi
                    echo -e "  • ${BOLD}${name}${NC} | HTTP Port: ${CYAN}${http_p}${NC} | Status: ${status}"
                fi
            done
            echo ""
        fi
    fi
}

generate_unique_instance_name() {
    local version_tag="${1:-20}"
    local base_name="odoo${version_tag}"
    local idx=1
    while [ -d "${INSTANCES_DIR}/${base_name}-${idx}" ]; do
        idx=$((idx + 1))
    done
    echo "${base_name}-${idx}"
}

# ------------------------------------------------------------------------------
# Auto-Tuning PostgreSQL for Hardware & AI Vector Workloads
# ------------------------------------------------------------------------------
calculate_postgres_tuning() {
    local total_ram_kb
    total_ram_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    local total_ram_mb=$((total_ram_kb / 1024))
    
    # Defaults tailored for vector workloads & Odoo
    if [ "$total_ram_mb" -lt 2048 ]; then
        SHARED_BUFFERS="256MB"
        EFFECTIVE_CACHE_SIZE="768MB"
        WORK_MEM="32MB"
        MAINTENANCE_WORK_MEM="128MB"
        WORKERS_COUNT=2
    elif [ "$total_ram_mb" -lt 4096 ]; then
        SHARED_BUFFERS="512MB"
        EFFECTIVE_CACHE_SIZE="1536MB"
        WORK_MEM="64MB"
        MAINTENANCE_WORK_MEM="256MB"
        WORKERS_COUNT=3
    elif [ "$total_ram_mb" -lt 8192 ]; then
        SHARED_BUFFERS="1GB"
        EFFECTIVE_CACHE_SIZE="3GB"
        WORK_MEM="128MB"
        MAINTENANCE_WORK_MEM="512MB"
        WORKERS_COUNT=5
    else
        SHARED_BUFFERS="2GB"
        EFFECTIVE_CACHE_SIZE="6GB"
        WORK_MEM="256MB"
        MAINTENANCE_WORK_MEM="1GB"
        local cpu_cores
        cpu_cores=$(nproc || echo 2)
        WORKERS_COUNT=$(( (cpu_cores * 2) + 1 ))
    fi
}

# ------------------------------------------------------------------------------
# Instance Creation Wizard
# ------------------------------------------------------------------------------
setup_instance_details() {
    local passed_name="$1"
    step_header "2. Customizing New Odoo Instance (Multi-Tenancy Setup)"

    mkdir -p "$INSTANCES_DIR"
    list_existing_instances

    # 1. Version Selection (Odoo 16 to 20)
    echo -e "${WHITE}${BOLD}Select Odoo Version to deploy:${NC}"
    echo -e "  ${CYAN}1)${NC} Odoo ${BOLD}20${NC} (AI Agents, RAG & Vector Embeddings — Next-Gen) ${GREEN}[Recommended / Default]${NC}"
    echo -e "  ${CYAN}2)${NC} Odoo ${BOLD}19${NC} (Modern Enterprise & Community)"
    echo -e "  ${CYAN}3)${NC} Odoo ${BOLD}18${NC} (Long Term Support - LTS)"
    echo -e "  ${CYAN}4)${NC} Odoo ${BOLD}17${NC} (Long Term Support - LTS)"
    echo -e "  ${CYAN}5)${NC} Odoo ${BOLD}16${NC} (Long Term Support - LTS)"
    echo -e "  ${CYAN}6)${NC} Custom Docker Image (Specify your own tag/repository)"
    
    local version_choice="1"
    read_from_tty "Enter choice [1-6, default: 1]: " version_choice "1"

    ODOO_VERSION="20"
    case "$version_choice" in
        1)
            ODOO_VERSION="20"
            if docker images --format '{{.Repository}}:{{.Tag}}' | grep -qi "odoo20"; then
                ODOO_IMAGE=$(docker images --format '{{.Repository}}:{{.Tag}}' | grep -i "odoo20" | head -n1)
            else
                ODOO_IMAGE="odoo:latest"
            fi
            ;;
        2)
            ODOO_VERSION="19"
            ODOO_IMAGE="odoo:19"
            ;;
        3)
            ODOO_VERSION="18"
            ODOO_IMAGE="odoo:18"
            ;;
        4)
            ODOO_VERSION="17"
            ODOO_IMAGE="odoo:17"
            ;;
        5)
            ODOO_VERSION="16"
            ODOO_IMAGE="odoo:16"
            ;;
        6)
            ODOO_VERSION="custom"
            local custom_img="odoo:latest"
            echo -e "${WHITE}Enter full Docker image tag (e.g. odoo:18, myrepo/odoo:20):${NC}"
            read_from_tty "Custom Image: " custom_img "odoo:latest"
            ODOO_IMAGE="$custom_img"
            ;;
        *)
            ODOO_VERSION="20"
            ODOO_IMAGE="odoo:latest"
            ;;
    esac

    # 2. Instance Naming based on selected version
    local version_prefix="odoo${ODOO_VERSION}"
    local default_name
    default_name=$(generate_unique_instance_name "$ODOO_VERSION")

    if [ -n "$passed_name" ]; then
        INPUT_INSTANCE_NAME="$passed_name"
    else
        echo ""
        echo -e "${WHITE}Enter instance identifier (Press Enter for default: ${CYAN}${default_name}${WHITE}):${NC}"
        read_from_tty "Instance Name [default: ${default_name}]: " INPUT_INSTANCE_NAME "$default_name"
    fi

    # Ensure instance name always contains odoo<version> prefix (e.g. odoo20-1)
    local raw_name="${INPUT_INSTANCE_NAME:-$default_name}"
    raw_name=$(echo "$raw_name" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9_-' '-' | sed 's/^-//;s/-$//')
    
    if [[ "$raw_name" =~ ^odoo[0-9]+ ]]; then
        INSTANCE_NAME="$raw_name"
    else
        INSTANCE_NAME="${version_prefix}-${raw_name}"
    fi

    TARGET_DIR="${INSTANCES_DIR}/${INSTANCE_NAME}"

    if [ -d "$TARGET_DIR" ]; then
        error "Directory $TARGET_DIR already exists! An instance with this name already exists."
        echo -e "${YELLOW}Choose a different name or remove previous instance using:${NC} ${BOLD}elblasy delete ${INSTANCE_NAME}${NC}"
        exit 1
    fi

    info "Instance will be deployed in isolated path: ${BOLD}${TARGET_DIR}${NC}"

    # Auto-detect ports without conflict!
    step_header "3. Scanning & Allocating Free Ports (Smart Port Hunter)"

    info "Checking default HTTP web port (8069)..."
    HTTP_PORT=$(find_next_free_port 8069)
    if [ "$HTTP_PORT" -ne 8069 ]; then
        warn "Port 8069 is in use! Automatically assigned next available port: ${BOLD}${CYAN}${HTTP_PORT}${NC}"
    else
        success "Allocated HTTP web port: ${BOLD}${CYAN}${HTTP_PORT}${NC}"
    fi

    info "Checking longpolling / chat port (8072)..."
    local start_lp=$((HTTP_PORT + 3))
    if ! is_port_in_use 8072 && [ "$HTTP_PORT" -ne 8072 ]; then
        CHAT_PORT=8072
    else
        CHAT_PORT=$(find_next_free_port "$start_lp")
    fi
    success "Allocated longpolling / chat port: ${BOLD}${CYAN}${CHAT_PORT}${NC}"

    info "Checking PostgreSQL direct host port (5432)..."
    DB_PORT=$(find_next_free_port 5432)
    success "Allocated PostgreSQL direct port: ${BOLD}${CYAN}${DB_PORT}${NC}"

    # Security Credentials Generation (tied to the specific version & instance)
    POSTGRES_USER="odoo_${INSTANCE_NAME//-/_}"
    POSTGRES_PASSWORD=$(openssl rand -hex 16)
    POSTGRES_DB="postgres"
    ODOO_ADMIN_PASSWORD=$(openssl rand -base64 15 | tr -dc 'a-zA-Z0-9' | head -c 16)

    calculate_postgres_tuning

    echo ""
    echo -e "${B3}${BOLD}  Instance Configuration Summary:${NC}"
    echo -e "  • Instance Name            : ${WHITE}${BOLD}${INSTANCE_NAME}${NC}"
    echo -e "  • Odoo Version Selected    : ${GREEN}${BOLD}Odoo ${ODOO_VERSION}${NC} (${CYAN}${ODOO_IMAGE}${NC})"
    echo -e "  • Odoo Web Port (HTTP)     : ${CYAN}${BOLD}${HTTP_PORT}${NC}"
    echo -e "  • Longpolling Port (Chat)  : ${CYAN}${BOLD}${CHAT_PORT}${NC}"
    echo -e "  • Database Port (PG Host)  : ${CYAN}${BOLD}${DB_PORT}${NC}"
    echo -e "  • Odoo Workers (Calculated): ${GREEN}${BOLD}${WORKERS_COUNT}${NC} (Hardware optimized)"
    echo -e "  • AI Vector Engine         : ${PURPLE}${BOLD}pgvector/pgvector:pg17 (PostgreSQL 17 + Vector Embeddings)${NC}"
    echo ""
}

# ------------------------------------------------------------------------------
# Directory Structure Creation (Standardized etc, addons, data, db_data)
# ------------------------------------------------------------------------------
create_instance_filesystem() {
    step_header "4. Creating Isolated Directory Structure in /opt (${INSTANCE_NAME})"

    (
        mkdir -p "${TARGET_DIR}/etc"
        mkdir -p "${TARGET_DIR}/addons"
        mkdir -p "${TARGET_DIR}/data"
        mkdir -p "${TARGET_DIR}/db_data"
        mkdir -p "${TARGET_DIR}/backups"
        mkdir -p "${TARGET_DIR}/init-db"

        # Permission calibration: grant full write permissions to data and addons
        # so any UID inside container (100, 101, 104, 1000) will never hit Permission Denied
        chmod -R 777 "${TARGET_DIR}/data"
        chmod -R 777 "${TARGET_DIR}/addons"
        chmod -R 755 "${TARGET_DIR}/etc"
    ) &
    spinner $! "Creating folders and applying security permissions"
    success "Directories created successfully in ${TARGET_DIR} (etc, addons, data, db_data)"
}

# ------------------------------------------------------------------------------
# Configuration Generation (Modern etc/odoo.conf, docker-compose.yml, init-db)
# ------------------------------------------------------------------------------
generate_configurations() {
    step_header "5. Generating Configurations & Wiring PostgreSQL 17 (pgvector)"

    # 1. Generate pgvector auto-initialization script for PostgreSQL 17
    cat << EOF > "${TARGET_DIR}/init-db/01-init-pgvector.sql"
-- =============================================================================
-- Automated pgvector Extension & AI Vector Support
-- Provided by elblasy.app
-- =============================================================================
\c postgres
CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS unaccent;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Connect to template1 so every newly created database in Odoo inherits pgvector!
\c template1
CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS unaccent;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Pre-create database matching the user so Odoo never encounters "database does not exist"
CREATE DATABASE ${POSTGRES_USER} OWNER ${POSTGRES_USER};
\c ${POSTGRES_USER}
CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS unaccent;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Also pre-create standard odoo database
CREATE DATABASE odoo OWNER ${POSTGRES_USER};
\c odoo
CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS unaccent;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

DO \$\$
BEGIN
    RAISE NOTICE 'elblasy.app: pgvector extension successfully loaded on postgres, template1, ${POSTGRES_USER} and odoo for PostgreSQL 17!';
END \$\$;
EOF

    # 2. Generate standard etc/odoo.conf for Modern Odoo (16 / 17 / 18 / 19 / 20)
    cat << EOF > "${TARGET_DIR}/etc/odoo.conf"
[options]
; ==============================================================================
; Odoo Enterprise & Community Configuration
; Automated Deployment & Tuning by elblasy.app
; Modern Odoo 16 / 17 / 18 / 19 / 20 Compatible
; Instance: ${INSTANCE_NAME}
; ==============================================================================
addons_path = /mnt/extra-addons
data_dir = /var/lib/odoo

; Master Password for Database Management
admin_passwd = ${ODOO_ADMIN_PASSWORD}

; Database Connection
db_host = db
db_port = 5432
db_user = ${POSTGRES_USER}
db_password = ${POSTGRES_PASSWORD}
db_name = False
db_maxconn = 64
dbfilter = .*
list_db = True

; Network & HTTP Settings (Compatible with Odoo 16, 17, 18, 19, 20)
http_interface = 0.0.0.0
http_port = 8069
gevent_port = 8072
longpolling_port = 8072
proxy_mode = True

; Performance & Concurrency Tuning
workers = ${WORKERS_COUNT}
max_cron_threads = 2
limit_memory_hard = 2684354560
limit_memory_soft = 2147483648
limit_request = 8192
limit_time_cpu = 600
limit_time_real = 1200

; Logging Configuration (Stdout for native Docker container logging)
logfile = False
log_level = info
log_db = False
EOF
    chmod 644 "${TARGET_DIR}/etc/odoo.conf"

    # 3. Generate .env file
    cat << EOF > "${TARGET_DIR}/.env"
# ==============================================================================
# Instance Environment Variables - elblasy.app
# ==============================================================================
INSTANCE_NAME=${INSTANCE_NAME}
COMPOSE_PROJECT_NAME=elblasy_${INSTANCE_NAME//-/_}
ODOO_IMAGE=${ODOO_IMAGE}
POSTGRES_IMAGE=${POSTGRES_PGVECTOR_IMAGE}

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
EOF
    chmod 600 "${TARGET_DIR}/.env"

    # 4. Generate docker-compose.yml with standard etc mount
    cat << 'EOF' > "${TARGET_DIR}/docker-compose.yml"
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
    environment:
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_DB: ${POSTGRES_DB}
      PGDATA: /var/lib/postgresql/data/pgdata
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
      retries: 10

  web:
    image: ${ODOO_IMAGE}
    container_name: odoo_${INSTANCE_NAME}
    restart: unless-stopped
    command: odoo -c /etc/odoo/odoo.conf
    depends_on:
      db:
        condition: service_healthy
    environment:
      - HOST=db
      - PORT=5432
      - USER=${POSTGRES_USER}
      - PASSWORD=${POSTGRES_PASSWORD}
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
EOF

    success "Configurations generated successfully in etc/odoo.conf with pgvector and secure credentials!"
}

# ------------------------------------------------------------------------------
# Launch & Health Verification
# ------------------------------------------------------------------------------
start_instance_and_verify() {
    step_header "6. Starting Containers & Verifying Health (Odoo + pgvector)"

    if ! docker image inspect "${POSTGRES_PGVECTOR_IMAGE}" >/dev/null 2>&1; then
        info "Pulling PostgreSQL 17 with pgvector AI image (${POSTGRES_PGVECTOR_IMAGE})..."
        docker pull "${POSTGRES_PGVECTOR_IMAGE}" 2>&1 | tee -a "$INSTALL_LOG"
        success "PostgreSQL 17 (pgvector) image is ready!"
    else
        success "PostgreSQL 17 image already cached locally!"
    fi

    echo ""
    if ! docker image inspect "${ODOO_IMAGE}" >/dev/null 2>&1; then
        info "Pulling Odoo application image (${ODOO_IMAGE}) — this may take 1-2 minutes depending on network..."
        docker pull "${ODOO_IMAGE}" 2>&1 | tee -a "$INSTALL_LOG"
        success "Odoo image downloaded successfully!"
    else
        success "Odoo image (${ODOO_IMAGE}) already exists locally, skipping download!"
    fi

    echo ""
    info "Launching isolated container stack (${INSTANCE_NAME})..."
    (cd "$TARGET_DIR" && docker compose up -d) 2>&1 | tee -a "$INSTALL_LOG"
    success "Containers started in background!"

    echo ""
    info "Verifying PostgreSQL 17 and pgvector AI extension initialization..."
    local db_ready=false
    for i in {1..30}; do
        printf "\r${CYAN}⏳ [Check %02d/30]${NC} Waiting for database engine to accept connections... " "$i"
        if docker exec "db_${INSTANCE_NAME}" pg_isready -U "$POSTGRES_USER" >/dev/null 2>&1; then
            printf "\r${CYAN}⏳ [Check %02d/30]${NC} Database is online! Testing pgvector extension...       " "$i"
            local vec_check
            vec_check=$(docker exec -i "db_${INSTANCE_NAME}" psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -tAc "SELECT count(*) FROM pg_extension WHERE extname='vector';" 2>/dev/null || echo "0")
            if [ "$vec_check" -ge 1 ]; then
                db_ready=true
                echo ""
                break
            fi
        fi
        sleep 2
    done

    if [ "$db_ready" = true ]; then
        success "Verified: PostgreSQL 17 is healthy and ${BOLD}pgvector (AI Vector Embeddings)${NC} extension is 100% loaded!"
    else
        echo ""
        warn "Database is taking longer to initialize, proceeding with web service probe..."
    fi

    # Verify Odoo HTTP endpoint
    echo ""
    info "Verifying Odoo web service initialization on port ${HTTP_PORT}..."
    local odoo_ready=false
    for i in {1..40}; do
        printf "\r${CYAN}⏳ [Check %02d/40]${NC} Probing Odoo HTTP service (http://127.0.0.1:${HTTP_PORT})... " "$i"
        local code
        code=$(curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:${HTTP_PORT}/web/health" 2>/dev/null || curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:${HTTP_PORT}" 2>/dev/null || echo "000")
        if [[ "$code" =~ ^(200|404|303|302)$ ]]; then
            odoo_ready=true
            echo ""
            break
        fi
        sleep 2
    done

    if [ "$odoo_ready" = true ]; then
        success "Odoo server (${INSTANCE_NAME}) is up and responding successfully!"
    else
        echo ""
        info "Odoo is initializing database tables in background and will be fully ready in seconds."
    fi
}

# ------------------------------------------------------------------------------
# Install Global Management CLI (elblasy-odoo)
# ------------------------------------------------------------------------------
install_management_cli() {
    step_header "7. Installing Global CLI Management Tool (${CLI_ALIAS})"

    local cli_path="${GLOBAL_BIN_DIR}/${CLI_NAME}"
    cat << 'EOF' > "$cli_path"
#!/usr/bin/env bash
# ==============================================================================
# elblasy-odoo CLI Manager
# Developed by elblasy.app
# ==============================================================================
BASE_OPT_DIR="/opt/elblasy-odoo"
INSTANCES_DIR="${BASE_OPT_DIR}/instances"

BOLD='\033[1m'
GREEN='\033[38;5;46m'
CYAN='\033[38;5;51m'
YELLOW='\033[38;5;220m'
RED='\033[38;5;196m'
NC='\033[0m'

show_help() {
    echo -e "${CYAN}${BOLD}elblasy.app — Odoo Multi-Instance CLI Manager${NC}"
    echo "Usage: elblasy [command] [instance_name]"
    echo ""
    echo "Available Commands:"
    echo "  list                     List all installed Odoo instances and status"
    echo "  start   <instance>       Start a specific instance"
    echo "  stop    <instance>       Stop a specific instance"
    echo "  restart <instance>       Restart a specific instance"
    echo "  logs    <instance>       View live logs for an instance"
    echo "  backup  <instance>       Create a full backup (DB + Filestore)"
    echo "  info    <instance>       Display instance configuration and passwords"
    echo "  delete  <instance>       Safely delete an instance and its containers"
    echo ""
}

get_instances() {
    if [ ! -d "$INSTANCES_DIR" ]; then
        echo ""
        return
    fi
    find "$INSTANCES_DIR" -mindepth 1 -maxdepth 1 -type d -exec basename {} \;
}

cmd_list() {
    echo -e "${BOLD}${CYAN}Installed Odoo Instances on Server (elblasy.app):${NC}"
    printf "%-18s %-12s %-10s %-10s %-25s\n" "INSTANCE" "STATUS" "HTTP PORT" "CHAT PORT" "PATH"
    echo "--------------------------------------------------------------------------------"
    for inst in $(get_instances); do
        dir="${INSTANCES_DIR}/${inst}"
        http_p="N/A"
        chat_p="N/A"
        status="${RED}Stopped${NC}"
        if [ -f "$dir/.env" ]; then
            http_p=$(grep -E '^ODOO_HTTP_PORT=' "$dir/.env" | cut -d '=' -f2)
            chat_p=$(grep -E '^ODOO_CHAT_PORT=' "$dir/.env" | cut -d '=' -f2)
        fi
        if docker ps --format '{{.Names}}' | grep -q "^odoo_${inst}$"; then
            status="${GREEN}Running${NC}"
        fi
        printf "%-18s %-21b %-10s %-10s %-25s\n" "$inst" "$status" "$http_p" "$chat_p" "$dir"
    done
    echo ""
}

verify_inst() {
    local inst=$1
    if [ -z "$inst" ] || [ ! -d "${INSTANCES_DIR}/${inst}" ]; then
        echo -e "${RED}[ERROR] Instance '${inst}' not found!${NC}"
        echo "Available instances are:"
        get_instances
        exit 1
    fi
}

ACTION=$1
TARGET=$2

case "$ACTION" in
    list|"")
        cmd_list
        ;;
    start)
        verify_inst "$TARGET"
        echo -e "${CYAN}Starting instance ${TARGET}...${NC}"
        cd "${INSTANCES_DIR}/${TARGET}" && docker compose up -d
        ;;
    stop)
        verify_inst "$TARGET"
        echo -e "${YELLOW}Stopping instance ${TARGET}...${NC}"
        cd "${INSTANCES_DIR}/${TARGET}" && docker compose stop
        ;;
    restart)
        verify_inst "$TARGET"
        echo -e "${CYAN}Restarting instance ${TARGET}...${NC}"
        cd "${INSTANCES_DIR}/${TARGET}" && docker compose restart
        ;;
    logs)
        verify_inst "$TARGET"
        cd "${INSTANCES_DIR}/${TARGET}" && docker compose logs -f --tail=100
        ;;
    info)
        verify_inst "$TARGET"
        dir="${INSTANCES_DIR}/${TARGET}"
        echo -e "${BOLD}${CYAN}=== Instance Details: ${TARGET} ===${NC}"
        cat "$dir/.env"
        echo ""
        echo "Configuration: ${dir}/etc/odoo.conf"
        echo "Extra Addons : ${dir}/addons"
        echo "Data Filestore: ${dir}/data"
        ;;
    backup)
        verify_inst "$TARGET"
        dir="${INSTANCES_DIR}/${TARGET}"
        bdir="${dir}/backups"
        mkdir -p "$bdir"
        ts=$(date +%Y%m%d_%H%M%S)
        bfile="${bdir}/backup_${TARGET}_${ts}.tar.gz"
        echo -e "${CYAN}Creating complete backup for instance ${TARGET}...${NC}"
        
        eval $(grep -E '^POSTGRES_USER=|^POSTGRES_DB=' "$dir/.env")
        docker exec -t "db_${TARGET}" pg_dumpall -U "$POSTGRES_USER" > "${dir}/backups/dump_${ts}.sql"
        tar -czf "$bfile" -C "$dir" data etc/odoo.conf "backups/dump_${ts}.sql"
        rm -f "${dir}/backups/dump_${ts}.sql"
        echo -e "${GREEN}✓ Backup created successfully:${NC} ${bfile}"
        ;;
    delete)
        verify_inst "$TARGET"
        confirm="no"
        if [ -t 0 ]; then
            read -r -p "Are you absolutely sure you want to delete instance '${TARGET}' and all its data? (type 'yes' to confirm): " confirm || true
        elif [ -e /dev/tty ]; then
            read -r -p "Are you absolutely sure you want to delete instance '${TARGET}' and all its data? (type 'yes' to confirm): " confirm < /dev/tty || true
        fi
        if [ "$confirm" == "yes" ]; then
            echo -e "${RED}Stopping and removing containers, volumes and files...${NC}"
            cd "${INSTANCES_DIR}/${TARGET}" && docker compose down -v
            rm -rf "${INSTANCES_DIR}/${TARGET}"
            echo -e "${GREEN}Instance ${TARGET} deleted successfully.${NC}"
        else
            echo "Deletion cancelled."
        fi
        ;;
    *)
        show_help
        ;;
esac
EOF
    chmod +x "$cli_path"
    ln -sf "$cli_path" "${GLOBAL_BIN_DIR}/${CLI_ALIAS}"
    success "Installed management CLI ${BOLD}${CLI_ALIAS}${NC} successfully! You can type ${CYAN}elblasy list${NC} anytime."
}

# ------------------------------------------------------------------------------
# Final Summary Card
# ------------------------------------------------------------------------------
display_summary() {
    local server_ip
    server_ip=$(curl -s -4 ifconfig.me || curl -s -4 icanhazip.com || hostname -I | awk '{print $1}')

    echo ""
    echo -e "${GREEN}${BOLD}════════════════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}${BOLD}              🎉 Odoo Instance Successfully Deployed (AI Ready)!              ${NC}"
    echo -e "${GREEN}${BOLD}════════════════════════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "  🏢 ${BOLD}Provider           :${NC} ${B4}${BOLD}elblasy.app${NC}"
    echo -e "  🏷️  ${BOLD}Instance Name      :${NC} ${WHITE}${BOLD}${INSTANCE_NAME}${NC}"
    echo -e "  📦 ${BOLD}Odoo Version       :${NC} ${GREEN}${BOLD}Odoo ${ODOO_VERSION}${NC} (${CYAN}${ODOO_IMAGE}${NC})"
    echo -e "  🌐 ${BOLD}Web Access (HTTP)  :${NC} ${CYAN}${UNDERLINE}http://${server_ip}:${HTTP_PORT}${NC}  ${DIM}(or http://localhost:${HTTP_PORT})${NC}"
    echo -e "  💬 ${BOLD}Longpolling (Chat) :${NC} ${CYAN}${CHAT_PORT}${NC}"
    echo -e "  🐘 ${BOLD}Database           :${NC} ${PURPLE}PostgreSQL 17 + pgvector (AI Vector Enabled)${NC}"
    echo -e "  🔑 ${BOLD}Master Password    :${NC} ${YELLOW}${BOLD}${ODOO_ADMIN_PASSWORD}${NC}"
    echo -e "  📁 ${BOLD}Instance Root      :${NC} ${WHITE}${TARGET_DIR}${NC}"
    echo -e "  ⚙️  ${BOLD}Config File        :${NC} ${WHITE}${TARGET_DIR}/etc/odoo.conf${NC}"
    echo -e "  🧩 ${BOLD}Extra Addons       :${NC} ${WHITE}${TARGET_DIR}/addons${NC}"
    echo -e "  📋 ${BOLD}Install Log        :${NC} ${WHITE}${INSTALL_LOG}${NC}"
    echo ""
    echo -e "${B2}${BOLD}  💡 Multi-Instance Tip:${NC}"
    echo -e "  Run this script again anytime to create 2nd, 3rd, or multiple isolated"
    echo -e "  instances on this server with zero port or file conflicts!"
    echo ""
    echo -e "${B3}${BOLD}  🛠️  CLI Quick Commands (elblasy CLI):${NC}"
    echo -e "  • List all instances  : ${CYAN}elblasy list${NC}"
    echo -e "  • View live logs      : ${CYAN}elblasy logs ${INSTANCE_NAME}${NC}"
    echo -e "  • Restart instance    : ${CYAN}elblasy restart ${INSTANCE_NAME}${NC}"
    echo -e "  • Create backup       : ${CYAN}elblasy backup ${INSTANCE_NAME}${NC}"
    echo -e "  • View info/passwords : ${CYAN}elblasy info ${INSTANCE_NAME}${NC}"
    echo ""
    echo -e "${GREEN}${BOLD}════════════════════════════════════════════════════════════════════════════════${NC}"
    echo ""
}

# ------------------------------------------------------------------------------
# Main Execution Pipeline
# ------------------------------------------------------------------------------
main() {
    local passed_instance="$1"
    print_banner
    check_root
    check_os
    install_docker_prerequisites
    setup_instance_details "$passed_instance"
    create_instance_filesystem
    generate_configurations
    start_instance_and_verify
    install_management_cli
    display_summary
}

main "$@"
