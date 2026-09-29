#!/usr/bin/env bash
# ==============================================================================
# Script Name   : install.sh
# Description   : Professional Multi-Instance Odoo (v16-v20) + PostgreSQL 17 (pgvector) Installer
# Author        : elblasy.app
# Website       : https://elblasy.app
# GitHub        : https://github.com/elblasy33/last-odoo
# Compatibility : Ubuntu 20.04 / 22.04 / 24.04 LTS & Debian 11/12
# Supports      : Odoo 16 / 17 / 18 / 19 / 20 with PostgreSQL 17 + pgvector
# ==============================================================================
# Directory Layout per Instance:
#   /opt/elblasy-odoo/instances/<name>/
#   ├── etc/
#   │   ├── odoo.conf          → mounted to /etc/odoo/odoo.conf  (read-only)
#   │   └── addons/            → mounted to /mnt/extra-addons    (r/w)
#   │       └── <ver>.0/       → put your custom modules here (e.g. 18.0/)
#   ├── data/                  → /var/lib/odoo (filestore, sessions, addons cache)
#   ├── db_data/               → PostgreSQL 17 pgdata
#   ├── backups/               → automated & manual backups
#   ├── init-db/               → SQL scripts run on first DB init
#   ├── docker-compose.yml
#   └── .env
# ==============================================================================

set -euo pipefail

# ------------------------------------------------------------------------------
# Color & Typography (ANSI 256-Color — disabled when not a terminal)
# ------------------------------------------------------------------------------
if [[ -t 1 ]]; then
    NC='\033[0m';    BOLD='\033[1m';    DIM='\033[2m';  UNDERLINE='\033[4m'
    RED='\033[38;5;196m';   GREEN='\033[38;5;46m';   YELLOW='\033[38;5;220m'
    BLUE='\033[38;5;39m';   PURPLE='\033[38;5;135m'; CYAN='\033[38;5;51m'
    WHITE='\033[38;5;255m'; GRAY='\033[38;5;244m'
    B1='\033[38;5;99m'; B2='\033[38;5;105m'; B3='\033[38;5;75m'
    B4='\033[38;5;45m'; B5='\033[38;5;51m'
else
    NC=''; BOLD=''; DIM=''; UNDERLINE=''
    RED=''; GREEN=''; YELLOW=''; BLUE=''; PURPLE=''; CYAN=''; WHITE=''; GRAY=''
    B1=''; B2=''; B3=''; B4=''; B5=''
fi

# ------------------------------------------------------------------------------
# Global Paths
# ------------------------------------------------------------------------------
readonly BASE_DIR="/opt/elblasy-odoo"
readonly INSTANCES_DIR="${BASE_DIR}/instances"
readonly GLOBAL_BIN="/usr/local/bin"
readonly CLI_NAME="elblasy-odoo"
readonly CLI_ALIAS="elblasy"
readonly PG_IMAGE="pgvector/pgvector:pg17"
readonly LOG_DIR="/var/log/elblasy-odoo"

# Runtime variables (set by setup_wizard)
INSTANCE_NAME=""
TARGET_DIR=""
ODOO_VERSION=""
ODOO_VER_DOT=""     # e.g. "18.0" — used for the addons subfolder name
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
# UI
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
    echo -e "${B2}${BOLD}  ║${CYAN}  Isolated Deployments | Smart Port Hunter | AI-Ready (RAG + Vectors)    ${B2} ║${NC}"
    echo -e "${B2}${BOLD}  ║${YELLOW}  Powered by elblasy.app — Empowering Modern Cloud Infrastructure        ${B2} ║${NC}"
    echo -e "${B2}${BOLD}  ╚═══════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

info()    { echo -e "${BLUE}${BOLD}[INFO]${NC}    $*"; log "INFO: $*"; }
success() { echo -e "${GREEN}${BOLD}[SUCCESS]${NC} $*"; log "SUCCESS: $*"; }
warn()    { echo -e "${YELLOW}${BOLD}[WARN]${NC}    $*"; log "WARN: $*"; }
error()   { echo -e "${RED}${BOLD}[ERROR]${NC}   $*" >&2; log "ERROR: $*"; }
die()     { error "$*"; exit 1; }

step_header() {
    echo ""
    echo -e "${PURPLE}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}${BOLD}▶ $*${NC}"
    echo -e "${PURPLE}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    log "=== $* ==="
}

spinner() {
    local pid=$1 msg="$2" spin='|/-\\'
    while kill -0 "$pid" 2>/dev/null; do
        printf "\r${CYAN}[%c]${NC} %s..." "${spin:0:1}" "$msg"
        spin="${spin:1}${spin:0:1}"; sleep 0.15
    done
    printf "\r${GREEN}[OK]${NC} %s\n" "$msg"
}

read_tty() {
    local prompt="$1" varname="$2" default="${3:-}"
    local val=""
    if   [[ -t 0 ]];         then read -rp "$prompt" val || val=""
    elif [[ -e /dev/tty ]];  then read -rp "$prompt" val </dev/tty || val=""
    fi
    printf -v "$varname" '%s' "${val:-$default}"
}

# ------------------------------------------------------------------------------
# Pre-flight
# ------------------------------------------------------------------------------
check_root() { [[ $EUID -eq 0 ]] || die "Root required. Run: sudo bash $0"; }

check_os() {
    [[ -f /etc/os-release ]] || die "Cannot detect OS. Ubuntu/Debian required."
    source /etc/os-release
    if [[ "${ID:-}" != "ubuntu" && "${ID:-}" != "debian" ]]; then
        warn "Unsupported OS: ${NAME:-?}. Tested on Ubuntu 20.04/22.04/24.04 & Debian 11/12."
        local ans="n"; read_tty "Continue anyway? [y/N]: " ans "n"
        [[ "$ans" =~ ^[Yy]$ ]] || exit 1
    else
        success "Compatible OS: ${BOLD}${NAME} ${VERSION_ID:-}${NC}"
    fi
}

# ------------------------------------------------------------------------------
# Port Hunter
# ------------------------------------------------------------------------------
port_in_use() { ss -tuln 2>/dev/null | grep -q ":${1} "; }
next_free_port() {
    local p=$1
    while port_in_use "$p"; do log "Port $p busy → $((p+1))"; p=$((p+1)); done
    echo "$p"
}

# ------------------------------------------------------------------------------
# Docker
# ------------------------------------------------------------------------------
install_docker() {
    step_header "1. Verifying Docker Engine & Compose V2"
    if command -v docker &>/dev/null && docker compose version &>/dev/null; then
        success "Docker Engine & Compose V2 are ready."
        return
    fi
    info "Installing Docker Engine & Compose V2..."
    (
        export DEBIAN_FRONTEND=noninteractive
        apt-get update -y
        apt-get install -y ca-certificates curl gnupg lsb-release
        install -m 0755 -d /etc/apt/keyrings
        [[ -f /etc/apt/keyrings/docker.gpg ]] || {
            curl -fsSL "https://download.docker.com/linux/${ID}/gpg" \
                | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
            chmod a+r /etc/apt/keyrings/docker.gpg
        }
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/${ID} $(lsb_release -cs) stable" \
            > /etc/apt/sources.list.d/docker.list
        apt-get update -y
        apt-get install -y docker-ce docker-ce-cli containerd.io \
            docker-buildx-plugin docker-compose-plugin
        systemctl enable --now docker
    ) >> "${INSTALL_LOG}" 2>&1 &
    spinner $! "Installing Docker Engine"
    success "Docker Engine & Compose V2 installed."
}

# ------------------------------------------------------------------------------
# Odoo Version → Docker Image + version-dot string
# Docker Hub official tags: odoo:16, odoo:17, odoo:18
# Odoo 19 / 20 have NO official image yet → warn + fallback
# ------------------------------------------------------------------------------
resolve_odoo_version() {
    local ver="$1"
    case "$ver" in
        16) ODOO_IMAGE="odoo:16";  ODOO_VER_DOT="16.0" ;;
        17) ODOO_IMAGE="odoo:17";  ODOO_VER_DOT="17.0" ;;
        18) ODOO_IMAGE="odoo:18";  ODOO_VER_DOT="18.0" ;;
        19)
            ODOO_VER_DOT="19.0"
            warn "Odoo 19: no official Docker Hub image yet."
            # Check for local build
            local li
            li=$(docker images --format '{{.Repository}}:{{.Tag}}' 2>/dev/null \
                | grep -iE 'odoo.*19|odoo:19' | head -n1 || true)
            if [[ -n "$li" ]]; then
                ODOO_IMAGE="$li"
                warn "Using local image found: ${BOLD}${li}${NC}"
            else
                warn "Falling back to odoo:17. Update ODOO_IMAGE in .env once v19 is available."
                ODOO_IMAGE="odoo:17"
            fi
            ;;
        20)
            ODOO_VER_DOT="20.0"
            warn "Odoo 20: no official Docker Hub image yet."
            local li
            li=$(docker images --format '{{.Repository}}:{{.Tag}}' 2>/dev/null \
                | grep -iE 'odoo.*20|odoo:20|odoo20' | head -n1 || true)
            if [[ -n "$li" ]]; then
                ODOO_IMAGE="$li"
                warn "Using local image found: ${BOLD}${li}${NC}"
            else
                warn "Falling back to odoo:17. Update ODOO_IMAGE in .env once v20 is available."
                ODOO_IMAGE="odoo:17"
            fi
            ;;
        custom)
            ODOO_VER_DOT="custom"
            ;;
        *) ODOO_IMAGE="odoo:17"; ODOO_VER_DOT="17.0" ;;
    esac
}

# ------------------------------------------------------------------------------
# Instance list
# ------------------------------------------------------------------------------
list_existing_instances() {
    [[ -d "$INSTANCES_DIR" ]] || return 0
    local count; count=$(find "$INSTANCES_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l)
    [[ "$count" -gt 0 ]] || return 0
    echo -e "${YELLOW}${BOLD}Current instances on this server:${NC}"
    for inst in "${INSTANCES_DIR}"/*/; do
        [[ -d "$inst" ]] || continue
        local name; name=$(basename "$inst")
        local http_p="?"; [[ -f "${inst}.env" ]] && \
            http_p=$(grep -E '^ODOO_HTTP_PORT=' "${inst}.env" 2>/dev/null | cut -d= -f2 || echo "?")
        local img="?"; [[ -f "${inst}.env" ]] && \
            img=$(grep -E '^ODOO_IMAGE=' "${inst}.env" 2>/dev/null | cut -d= -f2 || echo "?")
        local stat
        if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^odoo_${name}$"; then
            stat="${GREEN}Running${NC}"
        else
            stat="${GRAY}Stopped${NC}"
        fi
        echo -e "  ${BOLD}${name}${NC}  |  Port: ${CYAN}${http_p}${NC}  |  Image: ${CYAN}${img}${NC}  |  ${stat}"
    done
    echo ""
}

auto_name() {
    local ver="${1:-18}"; local base="odoo${ver}"; local n=1
    while [[ -d "${INSTANCES_DIR}/${base}-${n}" ]]; do n=$((n+1)); done
    echo "${base}-${n}"
}

# ------------------------------------------------------------------------------
# Hardware tuning
# ------------------------------------------------------------------------------
tune_for_hardware() {
    local ram_mb; ram_mb=$(( $(grep MemTotal /proc/meminfo | awk '{print $2}') / 1024 ))
    if   [[ $ram_mb -lt 2048 ]]; then SHARED_BUFFERS="256MB"; EFFECTIVE_CACHE_SIZE="768MB";  WORK_MEM="32MB";  MAINTENANCE_WORK_MEM="128MB"; WORKERS_COUNT=2
    elif [[ $ram_mb -lt 4096 ]]; then SHARED_BUFFERS="512MB"; EFFECTIVE_CACHE_SIZE="1536MB"; WORK_MEM="64MB";  MAINTENANCE_WORK_MEM="256MB"; WORKERS_COUNT=3
    elif [[ $ram_mb -lt 8192 ]]; then SHARED_BUFFERS="1GB";   EFFECTIVE_CACHE_SIZE="3GB";    WORK_MEM="128MB"; MAINTENANCE_WORK_MEM="512MB"; WORKERS_COUNT=5
    else SHARED_BUFFERS="2GB"; EFFECTIVE_CACHE_SIZE="6GB"; WORK_MEM="256MB"; MAINTENANCE_WORK_MEM="1GB"; WORKERS_COUNT=$(( ($(nproc)*2)+1 ))
    fi
    log "Hardware tuning done: RAM=${ram_mb}MB workers=${WORKERS_COUNT}"
}

# ------------------------------------------------------------------------------
# Setup Wizard
# ------------------------------------------------------------------------------
setup_wizard() {
    step_header "2. Instance Configuration Wizard"
    mkdir -p "$INSTANCES_DIR"
    list_existing_instances

    # ── Version ────────────────────────────────────────────────────────────────
    echo -e "${WHITE}${BOLD}Select Odoo Version:${NC}"
    echo -e "  ${CYAN}1)${NC} Odoo ${BOLD}20${NC}  ${YELLOW}[Cutting-Edge — AI Agents & pgvector RAG]${NC}  ${GRAY}(no official image yet)${NC}"
    echo -e "  ${CYAN}2)${NC} Odoo ${BOLD}19${NC}  ${DIM}(Preview — no official Docker image yet)${NC}"
    echo -e "  ${CYAN}3)${NC} Odoo ${BOLD}18${NC}  ${GREEN}[Latest Stable | Official Docker Hub image: odoo:18]${NC}"
    echo -e "  ${CYAN}4)${NC} Odoo ${BOLD}17${NC}  ${GREEN}[Long Term Support | Official image: odoo:17]${NC}"
    echo -e "  ${CYAN}5)${NC} Odoo ${BOLD}16${NC}  ${GREEN}[Long Term Support | Official image: odoo:16]${NC}"
    echo -e "  ${CYAN}6)${NC} Custom Docker image  ${DIM}(provide your own tag)${NC}"
    echo ""

    local vchoice="3"
    read_tty "Choice [1-6, default=3 (Odoo 18)]: " vchoice "3"

    case "$vchoice" in
        1) ODOO_VERSION="20"; resolve_odoo_version 20 ;;
        2) ODOO_VERSION="19"; resolve_odoo_version 19 ;;
        3) ODOO_VERSION="18"; resolve_odoo_version 18 ;;
        4) ODOO_VERSION="17"; resolve_odoo_version 17 ;;
        5) ODOO_VERSION="16"; resolve_odoo_version 16 ;;
        6)
            ODOO_VERSION="custom"; ODOO_VER_DOT="custom"
            local ci="odoo:17"
            read_tty "Full Docker image tag (e.g. myrepo/odoo:20, odoo:18): " ci "odoo:17"
            ODOO_IMAGE="$ci"
            ;;
        *) ODOO_VERSION="18"; resolve_odoo_version 18 ;;
    esac
    success "Selected: Odoo ${BOLD}${ODOO_VERSION}${NC} | image: ${CYAN}${ODOO_IMAGE}${NC} | addons folder: ${CYAN}${ODOO_VER_DOT}/${NC}"

    # ── Instance name ──────────────────────────────────────────────────────────
    local def_name; def_name=$(auto_name "$ODOO_VERSION")
    echo ""
    local INPUT_NAME=""; read_tty "Instance name [default: ${def_name}]: " INPUT_NAME "$def_name"
    local raw
    raw=$(echo "${INPUT_NAME:-$def_name}" \
        | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9-' '-' | sed 's/^-*//;s/-*$//')
    [[ -z "$raw" ]] && raw="$def_name"
    if [[ "$raw" =~ ^odoo[0-9]+ ]]; then INSTANCE_NAME="$raw"
    else INSTANCE_NAME="odoo${ODOO_VERSION}-${raw}"; fi
    TARGET_DIR="${INSTANCES_DIR}/${INSTANCE_NAME}"
    [[ -d "$TARGET_DIR" ]] && die "Instance '${INSTANCE_NAME}' already exists. Delete with: elblasy delete ${INSTANCE_NAME}"
    info "Instance path: ${BOLD}${TARGET_DIR}${NC}"

    # ── Ports ──────────────────────────────────────────────────────────────────
    step_header "3. Smart Port Allocation"

    info "Scanning HTTP port from 8069..."
    HTTP_PORT=$(next_free_port 8069)
    [[ "$HTTP_PORT" -eq 8069 ]] \
        && success "HTTP port: ${CYAN}${HTTP_PORT}${NC}" \
        || warn "8069 busy → assigned: ${CYAN}${HTTP_PORT}${NC}"

    info "Scanning longpolling/gevent port..."
    local lp_start=$((HTTP_PORT + 3))
    if ! port_in_use 8072 && [[ "$HTTP_PORT" -ne 8072 ]]; then CHAT_PORT=8072
    else CHAT_PORT=$(next_free_port "$lp_start"); fi
    success "Longpolling port: ${CYAN}${CHAT_PORT}${NC}"

    info "Scanning PostgreSQL host port from 5432..."
    DB_PORT=$(next_free_port 5432)
    success "PostgreSQL host port: ${CYAN}${DB_PORT}${NC}  (127.0.0.1 only — not public)"

    # ── Credentials ────────────────────────────────────────────────────────────
    POSTGRES_USER="odoo_$(echo "${INSTANCE_NAME}" | tr '-' '_')"
    POSTGRES_PASSWORD=$(openssl rand -hex 20)
    ODOO_ADMIN_PASSWORD=$(openssl rand -base64 18 | tr -dc 'a-zA-Z0-9' | head -c 20)
    tune_for_hardware

    echo ""
    echo -e "${B3}${BOLD}  +-- Configuration Summary --------------------------------------------------------+${NC}"
    echo -e "  |  Instance Name  : ${WHITE}${INSTANCE_NAME}${NC}"
    echo -e "  |  Odoo Version   : ${GREEN}Odoo ${ODOO_VERSION}${NC}  →  image: ${CYAN}${ODOO_IMAGE}${NC}"
    echo -e "  |  Addons Folder  : ${CYAN}etc/addons/${ODOO_VER_DOT}/${NC}  (→ /mnt/extra-addons inside container)"
    echo -e "  |  HTTP Port      : ${CYAN}${HTTP_PORT}${NC}"
    echo -e "  |  Longpolling    : ${CYAN}${CHAT_PORT}${NC}"
    echo -e "  |  DB Host Port   : ${CYAN}${DB_PORT}${NC}  (127.0.0.1 only)"
    echo -e "  |  Workers        : ${GREEN}${WORKERS_COUNT}${NC}  (auto-tuned)"
    echo -e "  |  PostgreSQL     : ${PURPLE}pgvector/pgvector:pg17${NC}"
    echo -e "${B3}${BOLD}  +---------------------------------------------------------------------------------+${NC}"
    echo ""
}

# ------------------------------------------------------------------------------
# Filesystem
# The correct structure mirrors actual Odoo Enterprise deployments:
#
#   etc/odoo.conf          → /etc/odoo/odoo.conf     (read-only)
#   etc/addons/<ver>.0/    → /mnt/extra-addons        (rw)
#   data/                  → /var/lib/odoo            (filestore, sessions, addons cache)
#   db_data/               → PostgreSQL pgdata
# ------------------------------------------------------------------------------
create_filesystem() {
    step_header "4. Creating Isolated Directory Layout"

    local addons_ver_dir="${TARGET_DIR}/etc/addons/${ODOO_VER_DOT}"

    (
        # Standard dirs
        mkdir -p \
            "${TARGET_DIR}/etc" \
            "${addons_ver_dir}" \
            "${TARGET_DIR}/data" \
            "${TARGET_DIR}/db_data" \
            "${TARGET_DIR}/backups" \
            "${TARGET_DIR}/init-db"

        # Permissions
        # data/ — Odoo container runs as uid 101 (odoo user); needs full rw
        chmod 777 "${TARGET_DIR}/data"
        # addons — developers need rw, container needs r
        chmod -R 755 "${TARGET_DIR}/etc/addons"
        # config — read-only is enough for the container
        chmod 755 "${TARGET_DIR}/etc"
        # backups — private
        chmod 700 "${TARGET_DIR}/backups"

        # Placeholder README so the version folder is visible in git and guides devs
        cat > "${addons_ver_dir}/README.txt" <<RMTXT
# Odoo ${ODOO_VERSION} Custom Addons
# Place your custom module folders here.
# Each subfolder = one Odoo module.
#
# Container path: /mnt/extra-addons/${ODOO_VER_DOT}/
# addons_path  : /mnt/extra-addons/${ODOO_VER_DOT}
#
# After adding/updating modules:
#   docker exec odoo_${INSTANCE_NAME} odoo -u <module> -d <db> --stop-after-init
RMTXT
    ) &
    spinner $! "Creating folder structure"
    success "Directories ready: ${WHITE}${TARGET_DIR}${NC}"
    success "Custom addons dir: ${CYAN}etc/addons/${ODOO_VER_DOT}/${NC}  (mount → /mnt/extra-addons/${ODOO_VER_DOT})"
}

# ------------------------------------------------------------------------------
# Configuration Files
# Shell variables are expanded when writing these files (except docker-compose.yml
# which uses Docker Compose variable substitution from .env at runtime).
# ------------------------------------------------------------------------------
generate_configs() {
    step_header "5. Generating Configuration Files"

    local gen_date; gen_date=$(date '+%Y-%m-%d %H:%M:%S')

    # ── 1. PostgreSQL init SQL ─────────────────────────────────────────────────
    # ONLY installs extensions on postgres + template1.
    # Odoo will create its own databases; template1 ensures every new DB inherits extensions.
    cat > "${TARGET_DIR}/init-db/01-pgvector-init.sql" <<SQL
-- =============================================================================
-- pgvector & Extensions Bootstrap — elblasy.app
-- Runs ONCE on first PostgreSQL container startup (docker-entrypoint-initdb.d)
-- =============================================================================
\c postgres
CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS unaccent;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- template1: every future database Odoo creates will inherit these extensions
\c template1
CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS unaccent;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS pg_trgm;

DO \$\$
BEGIN
    RAISE NOTICE 'elblasy.app: pgvector + extensions loaded on postgres & template1.';
END \$\$;
SQL

    # ── 2. odoo.conf ──────────────────────────────────────────────────────────
    # addons_path includes the version-specific subfolder inside /mnt/extra-addons
    cat > "${TARGET_DIR}/etc/odoo.conf" <<ODOOCONF
[options]
; =============================================================================
; Odoo ${ODOO_VERSION} Configuration — elblasy.app
; Instance  : ${INSTANCE_NAME}
; Generated : ${gen_date}
; =============================================================================

; Custom addons: mounted from etc/addons/${ODOO_VER_DOT}/ on the host
; The version subfolder (${ODOO_VER_DOT}/) mirrors Odoo Enterprise convention
addons_path = /mnt/extra-addons/${ODOO_VER_DOT}

; Odoo data directory (filestore, sessions, installed addons cache)
data_dir = /var/lib/odoo

; Master Password (used by /web/database manager)
admin_passwd = ${ODOO_ADMIN_PASSWORD}

; Database connection (points to the db service in docker-compose)
db_host     = db
db_port     = 5432
db_user     = ${POSTGRES_USER}
db_password = ${POSTGRES_PASSWORD}
db_name     = False
db_maxconn  = 64
dbfilter    = .*
list_db     = True

; HTTP / Network  (Odoo 16 → 20 compatible keys)
http_interface = 0.0.0.0
http_port      = 8069
gevent_port    = 8072
proxy_mode     = True

; Workers & Performance (hardware-tuned for this server)
workers              = ${WORKERS_COUNT}
max_cron_threads     = 2
limit_memory_hard    = 2684354560
limit_memory_soft    = 2147483648
limit_request        = 8192
limit_time_cpu       = 600
limit_time_real      = 1200
limit_time_real_cron = 1800

; Logging — keep as stdout for Docker (do NOT set logfile in containers)
log_level = info
log_db    = False
ODOOCONF
    chmod 644 "${TARGET_DIR}/etc/odoo.conf"

    # ── 3. .env ───────────────────────────────────────────────────────────────
    cat > "${TARGET_DIR}/.env" <<ENVFILE
# =============================================================================
# Instance Environment — elblasy.app
# Instance  : ${INSTANCE_NAME}
# Generated : ${gen_date}
# =============================================================================
COMPOSE_PROJECT_NAME=elblasy_$(echo "${INSTANCE_NAME}" | tr '-' '_')
INSTANCE_NAME=${INSTANCE_NAME}
ODOO_VERSION=${ODOO_VERSION}
ODOO_VER_DOT=${ODOO_VER_DOT}

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

    # ── 4. docker-compose.yml ─────────────────────────────────────────────────
    # Written with single-quoted heredoc → NO shell expansion here.
    # All ${VAR} references are resolved by Docker Compose from .env at runtime.
    # Volume mount strategy:
    #   ./etc/odoo.conf                → /etc/odoo/odoo.conf     (ro)
    #   ./etc/addons/${ODOO_VER_DOT}   → /mnt/extra-addons/${ODOO_VER_DOT}  (rw)
    #   ./data                         → /var/lib/odoo
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
        -c log_min_duration_statement=1000
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
      retries: 20
      start_period: 15s

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
      # Config (read-only — never let the container modify it)
      - ./etc/odoo.conf:/etc/odoo/odoo.conf:ro
      # Custom addons (version-specific subfolder) — developers drop modules here
      - ./etc/addons/${ODOO_VER_DOT}:/mnt/extra-addons/${ODOO_VER_DOT}
      # Data dir: filestore, sessions, addons cache generated by Odoo
      - ./data:/var/lib/odoo
    networks:
      - odoo_net

networks:
  odoo_net:
    name: net_${INSTANCE_NAME}
    driver: bridge
COMPOSE_HEREDOC

    success "Configuration files written successfully."
}

# ------------------------------------------------------------------------------
# Pull & Start
# ------------------------------------------------------------------------------
start_and_verify() {
    step_header "6. Pulling Images & Starting Containers"

    if ! docker image inspect "${PG_IMAGE}" &>/dev/null; then
        info "Pulling ${PG_IMAGE}..."
        docker pull "${PG_IMAGE}" 2>&1 | tee -a "${INSTALL_LOG}"
        success "PostgreSQL 17 + pgvector image ready."
    else
        success "PostgreSQL 17 + pgvector image already cached."
    fi

    if ! docker image inspect "${ODOO_IMAGE}" &>/dev/null; then
        info "Pulling Odoo image ${ODOO_IMAGE} (may take a few minutes)..."
        docker pull "${ODOO_IMAGE}" 2>&1 | tee -a "${INSTALL_LOG}"
        success "Odoo image downloaded."
    else
        success "Odoo image ${ODOO_IMAGE} already cached locally."
    fi

    echo ""
    info "Starting container stack for '${INSTANCE_NAME}'..."
    (cd "${TARGET_DIR}" && docker compose up -d) 2>&1 | tee -a "${INSTALL_LOG}"
    success "Container stack launched in background."

    # Wait for PostgreSQL
    echo ""
    info "Waiting for PostgreSQL 17 healthcheck..."
    local db_ok=false i
    for i in $(seq 1 40); do
        printf "\r${CYAN}[%02d/40]${NC} Probing database..." "$i"
        if docker exec "db_${INSTANCE_NAME}" pg_isready -U "${POSTGRES_USER}" &>/dev/null; then
            db_ok=true
            printf "\r${GREEN}[OK]${NC} PostgreSQL is accepting connections.              \n"
            break
        fi
        sleep 3
    done
    $db_ok || { echo ""; warn "DB slow to start. Check: elblasy logs ${INSTANCE_NAME}"; }

    # Verify pgvector
    if $db_ok; then
        local vec
        vec=$(docker exec -i "db_${INSTANCE_NAME}" \
            psql -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" \
            -tAc "SELECT count(*) FROM pg_extension WHERE extname='vector';" 2>/dev/null \
            | tr -d '[:space:]' || echo "0")
        if [[ "${vec:-0}" -ge 1 ]]; then
            success "pgvector AI vector extension is ACTIVE on PostgreSQL 17!"
        else
            warn "pgvector not confirmed yet — init-db script may still be running."
        fi
    fi

    # Wait for Odoo HTTP
    echo ""
    info "Waiting for Odoo web service on port ${HTTP_PORT}..."
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
            printf "\r${GREEN}[OK]${NC} Odoo HTTP responded: HTTP ${code}                    \n"
            break
        fi
        sleep 3
    done
    $odoo_ok || {
        echo ""
        info "Odoo is still initializing. Normal for a fresh instance (DB schema creation)."
        info "Monitor: ${CYAN}elblasy logs ${INSTANCE_NAME}${NC}"
    }
}

# ------------------------------------------------------------------------------
# Install Global CLI
# ------------------------------------------------------------------------------
install_cli() {
    step_header "7. Installing Global CLI (elblasy)"
    local cli_path="${GLOBAL_BIN}/${CLI_NAME}"

    cat > "${cli_path}" <<'CLI_EOF'
#!/usr/bin/env bash
# =============================================================================
# elblasy-odoo — Multi-Instance Odoo CLI Manager
# Powered by elblasy.app | https://github.com/elblasy33/last-odoo
# Usage: elblasy [command] [instance_name]
# =============================================================================
readonly BASE_DIR="/opt/elblasy-odoo"
readonly INST_DIR="${BASE_DIR}/instances"

BOLD='\033[1m'; NC='\033[0m'
GREEN='\033[38;5;46m'; CYAN='\033[38;5;51m'; YELLOW='\033[38;5;220m'
RED='\033[38;5;196m';  GRAY='\033[38;5;244m'; WHITE='\033[38;5;255m'

usage() {
    echo -e "${CYAN}${BOLD}elblasy.app — Odoo Multi-Instance CLI${NC}"
    echo ""
    echo -e "  ${BOLD}Usage:${NC} elblasy <command> [instance]"
    echo ""
    printf "  %-18s %s\n" "list"            "List all instances (status, ports, version)"
    printf "  %-18s %s\n" "ps"              "Show running Odoo & DB containers"
    printf "  %-18s %s\n" "start <name>"    "Start an instance"
    printf "  %-18s %s\n" "stop <name>"     "Stop an instance"
    printf "  %-18s %s\n" "restart <name>"  "Restart an instance"
    printf "  %-18s %s\n" "logs <name>"     "Follow live container logs"
    printf "  %-18s %s\n" "info <name>"     "Show credentials, URLs & paths"
    printf "  %-18s %s\n" "backup <name>"   "Create full backup (DB dump + filestore)"
    printf "  %-18s %s\n" "restore <file>"  "Restore from a backup archive"
    printf "  %-18s %s\n" "delete <name>"   "Permanently delete instance (asks confirmation)"
    echo ""
}

get_all() {
    [[ -d "$INST_DIR" ]] || return
    find "$INST_DIR" -mindepth 1 -maxdepth 1 -type d -exec basename {} ';' 2>/dev/null | sort
}

require_inst() {
    [[ -n "${1:-}" && -d "${INST_DIR}/${1}" ]] || {
        echo -e "${RED}[ERROR]${NC} Instance '${1:-<none>}' not found."
        echo "Available instances:"; get_all; exit 1
    }
}

cmd_list() {
    echo -e "${BOLD}${CYAN}Odoo Instances — elblasy.app${NC}"
    printf "  %-24s %-10s %-6s %-6s %-8s %s\n" "INSTANCE" "STATUS" "HTTP" "CHAT" "VERSION" "IMAGE"
    echo -e "${GRAY}  ─────────────────────────────────────────────────────────────────${NC}"
    local found=0
    for inst in $(get_all); do
        found=1; local dir="${INST_DIR}/${inst}"
        local http_p="?" chat_p="?" ver="?" img="?"
        if [[ -f "${dir}/.env" ]]; then
            http_p=$(grep -E '^ODOO_HTTP_PORT='  "${dir}/.env" 2>/dev/null | cut -d= -f2 || echo "?")
            chat_p=$(grep -E '^ODOO_CHAT_PORT='  "${dir}/.env" 2>/dev/null | cut -d= -f2 || echo "?")
            ver=$(grep   -E '^ODOO_VERSION='     "${dir}/.env" 2>/dev/null | cut -d= -f2 || echo "?")
            img=$(grep   -E '^ODOO_IMAGE='       "${dir}/.env" 2>/dev/null | cut -d= -f2 || echo "?")
        fi
        local stat
        if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^odoo_${inst}$"; then
            stat="${GREEN}Running${NC}"
        else
            stat="${GRAY}Stopped${NC}"
        fi
        printf "  %-24s %-19b %-6s %-6s %-8s %s\n" "$inst" "$stat" "$http_p" "$chat_p" "$ver" "$img"
    done
    [[ $found -eq 0 ]] && echo -e "  ${GRAY}No instances found.${NC}"
    echo ""
}

cmd_ps() {
    docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}' 2>/dev/null \
        | grep -E "odoo_|db_|NAMES" || echo "No running Odoo/DB containers."
}

cmd_info() {
    require_inst "$1"; local dir="${INST_DIR}/$1"
    echo -e "${BOLD}${CYAN}Instance: $1${NC}"
    local http_p ver img pg_user admin_pw pg_port
    http_p=$(grep -E '^ODOO_HTTP_PORT='  "${dir}/.env" 2>/dev/null | cut -d= -f2 || echo "?")
    ver=$(grep    -E '^ODOO_VERSION='    "${dir}/.env" 2>/dev/null | cut -d= -f2 || echo "?")
    img=$(grep    -E '^ODOO_IMAGE='      "${dir}/.env" 2>/dev/null | cut -d= -f2 || echo "?")
    pg_user=$(grep -E '^POSTGRES_USER='  "${dir}/.env" 2>/dev/null | cut -d= -f2 || echo "?")
    admin_pw=$(grep -E '^ODOO_ADMIN_PASSWORD=' "${dir}/.env" 2>/dev/null | cut -d= -f2 || echo "?")
    pg_port=$(grep -E '^POSTGRES_EXTERNAL_PORT=' "${dir}/.env" 2>/dev/null | cut -d= -f2 || echo "?")
    local sip; sip=$(curl -s -4 --max-time 3 ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')
    echo -e "  Web URL       : ${CYAN}http://${sip}:${http_p}${NC}"
    echo -e "  Odoo Version  : ${GREEN}${ver}${NC}  (${img})"
    echo -e "  Admin Passwd  : ${YELLOW}${admin_pw}${NC}"
    echo -e "  DB User       : ${pg_user}  |  DB Port: 127.0.0.1:${pg_port}"
    echo -e "  Config file   : ${dir}/etc/odoo.conf"
    echo -e "  Custom addons : ${dir}/etc/addons/"
    echo -e "  Filestore     : ${dir}/data/"
    echo ""
}

cmd_backup() {
    require_inst "$1"; local inst="$1"; local dir="${INST_DIR}/${inst}"
    local bdir="${dir}/backups"; local ts; ts=$(date +%Y%m%d_%H%M%S)
    mkdir -p "$bdir"
    local pg_user; pg_user=$(grep -E '^POSTGRES_USER=' "${dir}/.env" | cut -d= -f2)
    echo -e "${CYAN}Creating backup for ${inst}...${NC}"
    local dump="${bdir}/dump_${ts}.sql"
    docker exec -t "db_${inst}" pg_dumpall -U "${pg_user}" > "${dump}" || {
        echo -e "${RED}[ERROR]${NC} DB dump failed."; rm -f "${dump}"; exit 1
    }
    local archive="${bdir}/backup_${inst}_${ts}.tar.gz"
    tar -czf "${archive}" -C "${dir}" data etc backups/$(basename "${dump}")
    rm -f "${dump}"
    echo -e "${GREEN}[OK]${NC} Backup: ${archive}"
}

ACTION="${1:-}"; INST="${2:-}"
case "$ACTION" in
    ""|list)  cmd_list ;;
    ps)       cmd_ps ;;
    start)    require_inst "$INST"; (cd "${INST_DIR}/${INST}" && docker compose up -d) ;;
    stop)     require_inst "$INST"; (cd "${INST_DIR}/${INST}" && docker compose stop) ;;
    restart)  require_inst "$INST"; (cd "${INST_DIR}/${INST}" && docker compose restart) ;;
    logs)     require_inst "$INST"; (cd "${INST_DIR}/${INST}" && docker compose logs -f --tail=150) ;;
    info)     cmd_info "$INST" ;;
    backup)   cmd_backup "$INST" ;;
    delete)
        require_inst "$INST"
        local_confirm="no"
        if   [[ -t 0 ]];        then read -rp "Type 'yes' to permanently delete '${INST}': " local_confirm || true
        elif [[ -e /dev/tty ]]; then read -rp "Type 'yes' to permanently delete '${INST}': " local_confirm </dev/tty || true
        fi
        if [[ "$local_confirm" == "yes" ]]; then
            (cd "${INST_DIR}/${INST}" && docker compose down -v) 2>/dev/null || true
            rm -rf "${INST_DIR:?}/${INST}"
            echo -e "${GREEN}[OK]${NC} Instance '${INST}' deleted."
        else
            echo "Cancelled."
        fi
        ;;
    *) usage ;;
esac
CLI_EOF

    chmod +x "${cli_path}"
    ln -sf "${cli_path}" "${GLOBAL_BIN}/${CLI_ALIAS}"
    success "CLI ready: ${BOLD}${CLI_ALIAS}${NC} and ${DIM}${CLI_NAME}${NC}. Try: ${CYAN}elblasy list${NC}"
}

# ------------------------------------------------------------------------------
# Summary
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
    echo -e "  🏢  ${BOLD}Provider         :${NC} elblasy.app"
    echo -e "  🏷   ${BOLD}Instance Name    :${NC} ${WHITE}${BOLD}${INSTANCE_NAME}${NC}"
    echo -e "  📦  ${BOLD}Odoo Version     :${NC} ${GREEN}Odoo ${ODOO_VERSION}${NC}  (${CYAN}${ODOO_IMAGE}${NC})"
    echo -e "  🌐  ${BOLD}Web URL          :${NC} ${CYAN}http://${server_ip}:${HTTP_PORT}${NC}"
    echo -e "  💬  ${BOLD}Longpolling      :${NC} ${CYAN}:${CHAT_PORT}${NC}"
    echo -e "  🐘  ${BOLD}Database         :${NC} ${PURPLE}PostgreSQL 17 + pgvector (AI Vector Ready)${NC}"
    echo -e "  🔑  ${BOLD}Master Password  :${NC} ${YELLOW}${BOLD}${ODOO_ADMIN_PASSWORD}${NC}"
    echo ""
    echo -e "  📁  ${BOLD}Instance Root    :${NC} ${TARGET_DIR}/"
    echo -e "  ⚙   ${BOLD}Config File      :${NC} ${TARGET_DIR}/etc/odoo.conf"
    echo -e "  🧩  ${BOLD}Custom Addons    :${NC} ${TARGET_DIR}/etc/addons/${ODOO_VER_DOT}/"
    echo -e "      ${DIM}(drop your modules here → auto-mapped to /mnt/extra-addons/${ODOO_VER_DOT} inside container)${NC}"
    echo -e "  💾  ${BOLD}Filestore        :${NC} ${TARGET_DIR}/data/"
    echo -e "  📋  ${BOLD}Install Log      :${NC} ${INSTALL_LOG}"
    echo ""
    echo -e "${B2}${BOLD}  Multi-Instance:${NC} Run this script again to deploy additional isolated instances."
    echo ""
    echo -e "${B3}${BOLD}  CLI Quick Reference:${NC}"
    echo -e "    ${CYAN}elblasy list${NC}                     — all instances"
    echo -e "    ${CYAN}elblasy logs ${INSTANCE_NAME}${NC}    — live logs"
    echo -e "    ${CYAN}elblasy restart ${INSTANCE_NAME}${NC} — restart"
    echo -e "    ${CYAN}elblasy backup ${INSTANCE_NAME}${NC}  — full backup"
    echo -e "    ${CYAN}elblasy info ${INSTANCE_NAME}${NC}    — credentials & URLs"
    echo ""
    echo -e "${GREEN}${BOLD}══════════════════════════════════════════════════════════════════════════════${NC}"
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
