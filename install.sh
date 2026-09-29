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
# Smart Port Allocation (version-aware, instant, no sequential scan):
#   HTTP : 8000 + version        (8016 / 8017 / 8018 / 8019 / 8020)
#   Chat : 9000 + version        (9016 / 9017 / 9018 / 9019 / 9020)
#   DB   : 5400 + version - 10   (5406 / 5407 / 5408 / 5409 / 5410)
#   Each additional instance of same version → HTTP/Chat += 10, DB += 1
#   Example: Odoo 20 #2 → HTTP=8030, Chat=9030, DB=5411
# ==============================================================================
# Directory Layout per Instance:
#   /opt/elblasy-odoo/instances/<name>/
#   ├── etc/
#   │   ├── odoo.conf          → /etc/odoo/odoo.conf  (read-only)
#   │   └── addons/<ver>.0/    → /mnt/extra-addons/<ver>.0/
#   ├── data/                  → /var/lib/odoo  (filestore, sessions)
#   ├── db_data/               → PostgreSQL 17 pgdata
#   ├── backups/
#   ├── init-db/
#   ├── docker-compose.yml
#   └── .env
# ==============================================================================

set -euo pipefail

# ------------------------------------------------------------------------------
# Colors (disabled when not a terminal)
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
ODOO_VERSION=""         # e.g. "18"
ODOO_VER_NUM=18         # numeric
ODOO_VER_DOT=""         # e.g. "18.0"
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
touch "${INSTALL_LOG}" 2>/dev/null || INSTALL_LOG="/tmp/elblasy_$(date +%Y%m%d_%H%M%S).log"
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
    echo -e "${B2}${BOLD}  ║${CYAN}  Version-Aware Port Allocation | Isolated Deployments | AI-Ready        ${B2} ║${NC}"
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
# Port Availability Check
# Uses ss (fast) with netstat fallback — checks a single port instantly
# ------------------------------------------------------------------------------
port_in_use() {
    local p=$1
    # ss is fastest and most reliable on modern Linux
    if command -v ss &>/dev/null; then
        ss -tuln 2>/dev/null | grep -q ":${p} \|:${p}$" && return 0
    elif command -v netstat &>/dev/null; then
        netstat -tuln 2>/dev/null | grep -q ":${p} " && return 0
    else
        # fallback: try a TCP connect
        (echo >/dev/tcp/127.0.0.1/"$p") &>/dev/null && return 0
    fi
    return 1
}

# ------------------------------------------------------------------------------
# Smart Version-Aware Port Allocator
# Port scheme (no slow sequential scan):
#   HTTP base  = 8000 + ver_num    (Odoo 16→8016, 17→8017, 18→8018, 19→8019, 20→8020)
#   Chat base  = 9000 + ver_num    (Odoo 16→9016, 17→9017, 18→9018, 19→9019, 20→9020)
#   DB   base  = 5400 + ver_num-10 (Odoo 16→5406, 17→5407, 18→5408, 19→5409, 20→5410)
#   Per additional instance: HTTP/Chat += 10, DB += 1
#   → Odoo 20 #1: 8020/9020/5410  #2: 8030/9030/5411  #3: 8040/9040/5412
# ------------------------------------------------------------------------------
allocate_ports() {
    local ver_num="$1"    # numeric: 16-20 (or 17 for custom)

    local http_base=$((8000 + ver_num))
    local chat_base=$((9000 + ver_num))
    local db_base=$((5400 + ver_num - 10))

    step_header "3. Smart Port Allocation (Version-Aware)"
    info "Port scheme for Odoo ${ver_num}:"
    echo -e "  HTTP base : ${CYAN}${http_base}${NC}  (${http_base}, $((http_base+10)), $((http_base+20)), ...)"
    echo -e "  Chat base : ${CYAN}${chat_base}${NC}  (${chat_base}, $((chat_base+10)), $((chat_base+20)), ...)"
    echo -e "  DB   base : ${CYAN}${db_base}${NC}  (${db_base}, $((db_base+1)), $((db_base+2)), ...)"
    echo ""

    # Try each slot: n=0,1,2,...
    local n=0 found=false
    while [[ $n -le 99 ]]; do
        local h=$((http_base + n * 10))
        local c=$((chat_base + n * 10))
        local d=$((db_base + n))

        local h_ok=true c_ok=true d_ok=true
        port_in_use "$h" && h_ok=false
        port_in_use "$c" && c_ok=false
        port_in_use "$d" && d_ok=false

        if $h_ok && $c_ok && $d_ok; then
            HTTP_PORT=$h
            CHAT_PORT=$c
            DB_PORT=$d
            found=true
            log "Port slot n=${n}: HTTP=${HTTP_PORT} Chat=${CHAT_PORT} DB=${DB_PORT}"
            break
        else
            log "Slot n=${n} busy (HTTP=${h}:${h_ok}, Chat=${c}:${c_ok}, DB=${d}:${d_ok}) → next"
            n=$((n + 1))
        fi
    done

    $found || die "No free port combination found for Odoo ${ver_num} after 100 attempts."

    if [[ $n -eq 0 ]]; then
        success "Ports allocated (base slot, no conflicts):"
    else
        warn "Base ports busy — allocated slot #$((n+1)):"
    fi
    echo -e "  HTTP (web)       : ${GREEN}${BOLD}${HTTP_PORT}${NC}"
    echo -e "  Chat (longpoll)  : ${GREEN}${BOLD}${CHAT_PORT}${NC}"
    echo -e "  DB   (host-side) : ${GREEN}${BOLD}${DB_PORT}${NC}  ${GRAY}(127.0.0.1 only)${NC}"
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
# Odoo Version → Docker Image + dot-version string
# For Odoo 19/20 (no official image): interactive selector shown
# ------------------------------------------------------------------------------
resolve_odoo_version() {
    local ver="$1"
    ODOO_VER_NUM=$ver
    case "$ver" in
        16) ODOO_IMAGE="odoo:16";  ODOO_VER_DOT="16.0" ;;
        17) ODOO_IMAGE="odoo:17";  ODOO_VER_DOT="17.0" ;;
        18) ODOO_IMAGE="odoo:18";  ODOO_VER_DOT="18.0" ;;
        19|20)
            ODOO_VER_DOT="${ver}.0"
            ODOO_VER_NUM=$ver
            warn "Odoo ${ver} has no official Docker Hub image yet."
            echo ""

            # Collect ALL local images that might be Odoo ${ver}
            local found_images=()
            while IFS= read -r img; do
                [[ -n "$img" ]] && found_images+=("$img")
            done < <(docker images --format '{{.Repository}}:{{.Tag}}' 2>/dev/null \
                | grep -iE "odoo.*${ver}|${ver}.*odoo|^odoo:${ver}" | grep -v '<none>' | sort -u || true)

            if [[ ${#found_images[@]} -gt 0 ]]; then
                echo -e "${CYAN}${BOLD}Local images found matching Odoo ${ver}:${NC}"
                local idx=1
                for img in "${found_images[@]}"; do
                    echo -e "  ${CYAN}${idx})${NC} ${img}"
                    idx=$((idx + 1))
                done
                echo -e "  ${CYAN}${idx})${NC} Enter a different image tag manually"
                echo ""
                local pick=""
                read_tty "Select image [1-${idx}, default=1]: " pick "1"

                if [[ "$pick" =~ ^[0-9]+$ ]] && [[ "$pick" -ge 1 ]] && [[ "$pick" -lt $idx ]]; then
                    ODOO_IMAGE="${found_images[$((pick-1))]}"
                    success "Using local image: ${CYAN}${ODOO_IMAGE}${NC}"
                else
                    # Manual entry
                    local custom_img=""
                    read_tty "Docker image tag for Odoo ${ver} [default: odoo:${ver}]: " custom_img "odoo:${ver}"
                    ODOO_IMAGE="${custom_img:-odoo:${ver}}"
                    success "Using image: ${CYAN}${ODOO_IMAGE}${NC}"
                fi
            else
                echo -e "${GRAY}No local Odoo ${ver} images detected in Docker.${NC}"
                echo ""
                echo -e "  ${CYAN}1)${NC} Use ${BOLD}odoo:${ver}${NC} (or specify custom tag)  ${DIM}(e.g. odoo20-odoo20:latest, myrepo/odoo:${ver})${NC}"
                echo -e "  ${CYAN}2)${NC} Use ${BOLD}odoo:18${NC} as temporary fallback      ${DIM}(Latest LTS stable; update .env later)${NC}"
                echo ""
                local pick=""
                read_tty "Choice [1/2, default=1]: " pick "1"

                if [[ "$pick" == "2" ]]; then
                    warn "Using odoo:18 as fallback. Update ODOO_IMAGE in .env when ready."
                    ODOO_IMAGE="odoo:18"
                else
                    local custom_img=""
                    read_tty "Docker image tag [default: odoo:${ver}]: " custom_img "odoo:${ver}"
                    ODOO_IMAGE="${custom_img:-odoo:${ver}}"
                    success "Using image: ${CYAN}${ODOO_IMAGE}${NC}"
                fi
            fi
            ;;
        *) ODOO_IMAGE="odoo:18"; ODOO_VER_DOT="18.0"; ODOO_VER_NUM=18 ;;
    esac
}

# ------------------------------------------------------------------------------
# Existing Instance List
# ------------------------------------------------------------------------------
list_existing_instances() {
    [[ -d "$INSTANCES_DIR" ]] || return 0
    local count; count=$(find "$INSTANCES_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l)
    [[ "$count" -gt 0 ]] || return 0
    echo -e "${YELLOW}${BOLD}Existing instances on this server:${NC}"
    for inst in "${INSTANCES_DIR}"/*/; do
        [[ -d "$inst" ]] || continue
        local name; name=$(basename "$inst")
        local http_p="?" ver="?" img="?"
        if [[ -f "${inst}.env" ]]; then
            http_p=$(grep -E '^ODOO_HTTP_PORT=' "${inst}.env" 2>/dev/null | cut -d= -f2 || echo "?")
            ver=$(grep  -E '^ODOO_VERSION='    "${inst}.env" 2>/dev/null | cut -d= -f2 || echo "?")
            img=$(grep  -E '^ODOO_IMAGE='      "${inst}.env" 2>/dev/null | cut -d= -f2 || echo "?")
        fi
        local stat
        if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^odoo_${name}$"; then
            stat="${GREEN}Running${NC}"
        else
            stat="${GRAY}Stopped${NC}"
        fi
        echo -e "  ${BOLD}${name}${NC}  v${ver}  Port:${CYAN}${http_p}${NC}  Image:${CYAN}${img}${NC}  ${stat}"
    done
    echo ""
}

auto_name() {
    local ver="${1:-18}"; local base="odoo${ver}"; local n=1
    while [[ -d "${INSTANCES_DIR}/${base}-${n}" ]]; do n=$((n+1)); done
    echo "${base}-${n}"
}

# ------------------------------------------------------------------------------
# Hardware Tuning
# ------------------------------------------------------------------------------
tune_for_hardware() {
    local ram_mb; ram_mb=$(( $(grep MemTotal /proc/meminfo | awk '{print $2}') / 1024 ))
    if   [[ $ram_mb -lt 2048 ]]; then SHARED_BUFFERS="256MB"; EFFECTIVE_CACHE_SIZE="768MB";  WORK_MEM="32MB";  MAINTENANCE_WORK_MEM="128MB"; WORKERS_COUNT=2
    elif [[ $ram_mb -lt 4096 ]]; then SHARED_BUFFERS="512MB"; EFFECTIVE_CACHE_SIZE="1536MB"; WORK_MEM="64MB";  MAINTENANCE_WORK_MEM="256MB"; WORKERS_COUNT=3
    elif [[ $ram_mb -lt 8192 ]]; then SHARED_BUFFERS="1GB";   EFFECTIVE_CACHE_SIZE="3GB";    WORK_MEM="128MB"; MAINTENANCE_WORK_MEM="512MB"; WORKERS_COUNT=5
    else SHARED_BUFFERS="2GB"; EFFECTIVE_CACHE_SIZE="6GB"; WORK_MEM="256MB"; MAINTENANCE_WORK_MEM="1GB"; WORKERS_COUNT=$(( ($(nproc)*2)+1 ))
    fi
    log "Hardware: RAM=${ram_mb}MB workers=${WORKERS_COUNT} shared_buffers=${SHARED_BUFFERS}"
}

# ------------------------------------------------------------------------------
# Setup Wizard
# ------------------------------------------------------------------------------
setup_wizard() {
    step_header "2. Instance Configuration Wizard"
    mkdir -p "$INSTANCES_DIR"
    list_existing_instances

    # ── Version Selection ──────────────────────────────────────────────────────
    echo -e "${WHITE}${BOLD}Select Odoo Version:${NC}"
    echo ""
    echo -e "  ${CYAN}1)${NC} Odoo ${BOLD}20${NC}  ${YELLOW}[Cutting-Edge — AI Agents & RAG]${NC}          HTTP: ${CYAN}8020${NC} | Chat: ${CYAN}9020${NC}"
    echo -e "  ${CYAN}2)${NC} Odoo ${BOLD}19${NC}  ${DIM}[Preview — no official image yet]${NC}             HTTP: ${CYAN}8019${NC} | Chat: ${CYAN}9019${NC}"
    echo -e "  ${CYAN}3)${NC} Odoo ${BOLD}18${NC}  ${GREEN}[Latest Stable | image: odoo:18]${NC}             HTTP: ${CYAN}8018${NC} | Chat: ${CYAN}9018${NC}"
    echo -e "  ${CYAN}4)${NC} Odoo ${BOLD}17${NC}  ${GREEN}[Long Term Support | image: odoo:17]${NC}         HTTP: ${CYAN}8017${NC} | Chat: ${CYAN}9017${NC}"
    echo -e "  ${CYAN}5)${NC} Odoo ${BOLD}16${NC}  ${GREEN}[Long Term Support | image: odoo:16]${NC}         HTTP: ${CYAN}8016${NC} | Chat: ${CYAN}9016${NC}"
    echo -e "  ${CYAN}6)${NC} Custom Docker image"
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
            local ci="odoo:18"
            read_tty "Docker image tag (e.g. odoo20-odoo20:latest, myrepo/odoo:18): " ci "odoo:18"
            ODOO_IMAGE="$ci"
            local detected_ver="18"
            if [[ "$ci" =~ 20 ]]; then detected_ver="20"
            elif [[ "$ci" =~ 19 ]]; then detected_ver="19"
            elif [[ "$ci" =~ 18 ]]; then detected_ver="18"
            elif [[ "$ci" =~ 17 ]]; then detected_ver="17"
            elif [[ "$ci" =~ 16 ]]; then detected_ver="16"
            fi
            local user_ver=""
            read_tty "Odoo major version number [16/17/18/19/20, default=${detected_ver}]: " user_ver "$detected_ver"
            ODOO_VERSION="${user_ver:-$detected_ver}"
            ODOO_VER_NUM="${ODOO_VERSION}"
            ODOO_VER_DOT="${ODOO_VERSION}.0"
            ;;
        *) ODOO_VERSION="18"; resolve_odoo_version 18 ;;
    esac
    success "Selected: Odoo ${BOLD}${ODOO_VERSION}${NC} | image: ${CYAN}${ODOO_IMAGE}${NC}"

    # ── Instance Name ──────────────────────────────────────────────────────────
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
    [[ -d "$TARGET_DIR" ]] && die "Instance '${INSTANCE_NAME}' already exists. Delete it first: elblasy delete ${INSTANCE_NAME}"
    info "Instance path: ${BOLD}${TARGET_DIR}${NC}"

    # ── Smart Port Allocation ──────────────────────────────────────────────────
    allocate_ports "$ODOO_VER_NUM"

    # ── Credentials ───────────────────────────────────────────────────────────
    POSTGRES_USER="odoo_$(echo "${INSTANCE_NAME}" | tr '-' '_')"
    POSTGRES_PASSWORD=$(openssl rand -hex 20)
    ODOO_ADMIN_PASSWORD=$(openssl rand -base64 18 | tr -dc 'a-zA-Z0-9' | head -c 20)
    tune_for_hardware

    echo ""
    echo -e "${B3}${BOLD}  +-- Instance Summary ----------------------------------------------------------+${NC}"
    echo -e "  |  Instance Name  : ${WHITE}${INSTANCE_NAME}${NC}"
    echo -e "  |  Odoo Version   : ${GREEN}Odoo ${ODOO_VERSION}${NC}  (${CYAN}${ODOO_IMAGE}${NC})"
    echo -e "  |  Addons Path    : ${CYAN}etc/addons/${ODOO_VER_DOT}/${NC}  → /mnt/extra-addons/${ODOO_VER_DOT}/"
    echo -e "  |  HTTP Port      : ${CYAN}${HTTP_PORT}${NC}"
    echo -e "  |  Chat Port      : ${CYAN}${CHAT_PORT}${NC}"
    echo -e "  |  DB Host Port   : ${CYAN}${DB_PORT}${NC}  (127.0.0.1 only)"
    echo -e "  |  Workers        : ${GREEN}${WORKERS_COUNT}${NC}  (auto-tuned)"
    echo -e "  |  PostgreSQL     : ${PURPLE}pgvector/pgvector:pg17${NC}"
    echo -e "${B3}${BOLD}  +------------------------------------------------------------------------------+${NC}"
    echo ""
}

# ------------------------------------------------------------------------------
# Filesystem
# ------------------------------------------------------------------------------
create_filesystem() {
    step_header "4. Creating Instance Directory Layout"

    local addons_dir="${TARGET_DIR}/etc/addons/${ODOO_VER_DOT}"

    (
        mkdir -p \
            "${TARGET_DIR}/etc" \
            "${addons_dir}" \
            "${TARGET_DIR}/data" \
            "${TARGET_DIR}/db_data" \
            "${TARGET_DIR}/backups" \
            "${TARGET_DIR}/init-db"

        # data/ → Odoo container runs as uid 101; needs full rw
        chmod 777 "${TARGET_DIR}/data"
        # addons subtree — readable by container, writable by admin
        chmod -R 755 "${TARGET_DIR}/etc"
        # backups — private
        chmod 700 "${TARGET_DIR}/backups"

        # Developer guide placeholder in the version addons folder
        cat > "${addons_dir}/ADDONS_README.txt" <<RMTXT
Odoo ${ODOO_VERSION} Custom Addons
===================================
Drop your custom module folders here.
Each subfolder = one Odoo module.

Host path    : ${addons_dir}/
Container    : /mnt/extra-addons/${ODOO_VER_DOT}/
addons_path  : /mnt/extra-addons/${ODOO_VER_DOT}

After adding/updating a module:
  docker exec odoo_${INSTANCE_NAME} odoo -u <module_name> -d <database> --stop-after-init
  or simply restart the instance: elblasy restart ${INSTANCE_NAME}
RMTXT
    ) &
    spinner $! "Creating directory layout"
    success "Directories ready: ${WHITE}${TARGET_DIR}${NC}"
    info "Drop custom modules in: ${CYAN}${TARGET_DIR}/etc/addons/${ODOO_VER_DOT}/${NC}"
}

# ------------------------------------------------------------------------------
# Configuration Files
# IMPORTANT:
#  - Shell variables are expanded when writing odoo.conf, .env  (heredoc without quotes)
#  - docker-compose.yml uses SINGLE-QUOTED heredoc → NO shell expansion
#    Docker Compose reads all ${VAR} references from .env at runtime
# ------------------------------------------------------------------------------
generate_configs() {
    step_header "5. Generating Configuration Files"

    local gen_date; gen_date=$(date '+%Y-%m-%d %H:%M:%S')

    # ── 1. PostgreSQL init SQL ─────────────────────────────────────────────────
    # Only creates extensions on postgres + template1.
    # Odoo manages its own databases — we must NOT pre-create them here.
    cat > "${TARGET_DIR}/init-db/01-pgvector-init.sql" <<SQL
-- ============================================================================
-- pgvector & Extensions Bootstrap — elblasy.app
-- Runs once on first PostgreSQL container startup
-- ============================================================================
\c postgres
CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS unaccent;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- template1: every future database created by Odoo inherits these extensions
\c template1
CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS unaccent;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS pg_trgm;

DO \$\$
BEGIN
    RAISE NOTICE 'elblasy.app: pgvector + extensions activated on postgres and template1.';
END \$\$;
SQL

    # ── 2. odoo.conf ──────────────────────────────────────────────────────────
    cat > "${TARGET_DIR}/etc/odoo.conf" <<ODOOCONF
[options]
; ============================================================================
; Odoo ${ODOO_VERSION} Configuration — elblasy.app
; Instance  : ${INSTANCE_NAME}
; Generated : ${gen_date}
; ============================================================================

; Custom addons — version-specific folder (Odoo Enterprise convention)
; Host: etc/addons/${ODOO_VER_DOT}/  →  Container: /mnt/extra-addons/${ODOO_VER_DOT}/
addons_path = /mnt/extra-addons/${ODOO_VER_DOT}

; Data directory (filestore, sessions, installed addons cache)
data_dir = /var/lib/odoo

; Master Password (database manager at /web/database/manager)
admin_passwd = ${ODOO_ADMIN_PASSWORD}

; Database
db_host     = db
db_port     = 5432
db_user     = ${POSTGRES_USER}
db_password = ${POSTGRES_PASSWORD}
db_name     =
db_maxconn  = 64
dbfilter    = .*
list_db     = True

; Network (Odoo 16-20 compatible)
http_interface = 0.0.0.0
http_port      = 8069
gevent_port    = 8072
proxy_mode     = True

; Workers & Limits (hardware-tuned)
workers              = ${WORKERS_COUNT}
max_cron_threads     = 2
limit_memory_hard    = 2684354560
limit_memory_soft    = 2147483648
limit_request        = 8192
limit_time_cpu       = 600
limit_time_real      = 1200
limit_time_real_cron = 1800

; Logging — stdout for Docker (never set logfile in containers)
log_level = info
log_db    =
ODOOCONF
    chmod 644 "${TARGET_DIR}/etc/odoo.conf"

    # ── 3. .env ───────────────────────────────────────────────────────────────
    # CRITICAL: ODOO_HTTP_PORT and ODOO_CHAT_PORT must be here for docker-compose ports mapping
    cat > "${TARGET_DIR}/.env" <<ENVFILE
# ============================================================================
# Instance Environment — elblasy.app
# Instance  : ${INSTANCE_NAME}
# Generated : ${gen_date}
# ============================================================================
COMPOSE_PROJECT_NAME=elblasy_$(echo "${INSTANCE_NAME}" | tr '-' '_')
INSTANCE_NAME=${INSTANCE_NAME}
ODOO_VERSION=${ODOO_VERSION}
ODOO_VER_DOT=${ODOO_VER_DOT}

ODOO_IMAGE=${ODOO_IMAGE}
POSTGRES_IMAGE=${PG_IMAGE}

# Ports — mapped on the Docker host
ODOO_HTTP_PORT=${HTTP_PORT}
ODOO_CHAT_PORT=${CHAT_PORT}
POSTGRES_EXTERNAL_PORT=${DB_PORT}

# Database credentials
POSTGRES_USER=${POSTGRES_USER}
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
POSTGRES_DB=${POSTGRES_DB}

# Odoo master/admin password
ODOO_ADMIN_PASSWORD=${ODOO_ADMIN_PASSWORD}

# PostgreSQL tuning (hardware-tuned)
SHARED_BUFFERS=${SHARED_BUFFERS}
EFFECTIVE_CACHE_SIZE=${EFFECTIVE_CACHE_SIZE}
WORK_MEM=${WORK_MEM}
MAINTENANCE_WORK_MEM=${MAINTENANCE_WORK_MEM}
ENVFILE
    chmod 600 "${TARGET_DIR}/.env"

    # ── 4. docker-compose.yml ─────────────────────────────────────────────────
    # IMPORTANT: We write ALL values directly (shell expansion).
    # This guarantees ports, image names, and credentials are literal strings
    # in the file — zero dependency on Docker Compose variable resolution.
    # Only static container-internal references remain as-is (e.g. host=db).
    cat > "${TARGET_DIR}/docker-compose.yml" <<COMPOSE_EOF
# ============================================================================
# Docker Compose — elblasy.app
# Instance  : ${INSTANCE_NAME}
# Generated : ${gen_date}
# All values are written literally — no runtime variable substitution needed.
# ============================================================================
services:

  db:
    image: ${PG_IMAGE}
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
      - "127.0.0.1:${DB_PORT}:5432"
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
    # Universal command — works for official images (ENTRYPOINT=/entrypoint.sh)
    # AND custom builds (ENTRYPOINT=odoo binary).
    # Using flags only (no 'odoo' prefix) prevents "Unknown command 'odoo'" error
    # when image entrypoint IS the odoo binary itself.
    command: ["--config", "/etc/odoo/odoo.conf"]
    depends_on:
      db:
        condition: service_healthy
    environment:
      HOST:     db
      PORT:     "5432"
      USER:     ${POSTGRES_USER}
      PASSWORD: ${POSTGRES_PASSWORD}
    ports:
      - "${HTTP_PORT}:8069"
      - "${CHAT_PORT}:8072"
    volumes:
      - ./etc/odoo.conf:/etc/odoo/odoo.conf:ro
      - ./etc/addons/${ODOO_VER_DOT}:/mnt/extra-addons/${ODOO_VER_DOT}
      - ./data:/var/lib/odoo
    networks:
      - odoo_net

networks:
  odoo_net:
    name: net_${INSTANCE_NAME}
    driver: bridge
COMPOSE_EOF

    success "All configuration files generated."
}

# ------------------------------------------------------------------------------
# Pull Images & Start Containers
# ------------------------------------------------------------------------------
start_and_verify() {
    step_header "6. Pulling Images & Starting Containers"

    if ! docker image inspect "${PG_IMAGE}" &>/dev/null; then
        info "Pulling ${PG_IMAGE}..."
        docker pull "${PG_IMAGE}" 2>&1 | tee -a "${INSTALL_LOG}"
        success "PostgreSQL 17 + pgvector image ready."
    else
        success "PostgreSQL 17 + pgvector image cached."
    fi

    if ! docker image inspect "${ODOO_IMAGE}" &>/dev/null; then
        info "Pulling Odoo image ${ODOO_IMAGE}..."
        docker pull "${ODOO_IMAGE}" 2>&1 | tee -a "${INSTALL_LOG}"
        success "Odoo image downloaded."
    else
        success "Odoo image ${ODOO_IMAGE} cached."
    fi

    echo ""
    info "Starting stack for '${INSTANCE_NAME}'..."
    (cd "${TARGET_DIR}" && docker compose up -d) 2>&1 | tee -a "${INSTALL_LOG}"
    success "Container stack launched."

    # Wait for PostgreSQL
    echo ""
    info "Waiting for PostgreSQL 17..."
    local db_ok=false i
    for i in $(seq 1 40); do
        printf "\r${CYAN}[%02d/40]${NC} Probing database..." "$i"
        if docker exec "db_${INSTANCE_NAME}" pg_isready -U "${POSTGRES_USER}" &>/dev/null; then
            db_ok=true
            printf "\r${GREEN}[OK]${NC} PostgreSQL is ready.                      \n"
            break
        fi
        sleep 3
    done
    $db_ok || { echo ""; warn "DB slow to start. Run: elblasy logs ${INSTANCE_NAME}"; }

    if $db_ok; then
        local vec
        vec=$(docker exec -i "db_${INSTANCE_NAME}" \
            psql -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" \
            -tAc "SELECT count(*) FROM pg_extension WHERE extname='vector';" 2>/dev/null \
            | tr -d '[:space:]' || echo "0")
        if [[ "${vec:-0}" -ge 1 ]]; then
            success "pgvector AI extension is ACTIVE on PostgreSQL 17!"
        else
            warn "pgvector not confirmed yet — init script may still be running."
        fi
    fi

    # Wait for Odoo HTTP
    echo ""
    info "Waiting for Odoo HTTP on port ${HTTP_PORT}..."
    local odoo_ok=false
    for i in $(seq 1 50); do
        printf "\r${CYAN}[%02d/50]${NC} Probing http://127.0.0.1:${HTTP_PORT} ..." "$i"
        local code
        code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 2 \
            "http://127.0.0.1:${HTTP_PORT}/web/health" 2>/dev/null \
            || curl -s -o /dev/null -w "%{http_code}" --max-time 2 \
            "http://127.0.0.1:${HTTP_PORT}" 2>/dev/null || echo "000")
        if [[ "$code" =~ ^(200|302|303|404)$ ]]; then
            odoo_ok=true
            printf "\r${GREEN}[OK]${NC} Odoo HTTP up — HTTP ${code}                          \n"
            break
        fi
        sleep 3
    done
    $odoo_ok || {
        echo ""
        info "Odoo is initializing its database schema (normal for fresh instance)."
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
# ============================================================================
# elblasy-odoo — Multi-Instance Odoo Manager
# Powered by elblasy.app | https://github.com/elblasy33/last-odoo
# ============================================================================
readonly BASE_DIR="/opt/elblasy-odoo"
readonly INST_DIR="${BASE_DIR}/instances"
BOLD='\033[1m'; NC='\033[0m'
GREEN='\033[38;5;46m'; CYAN='\033[38;5;51m'; YELLOW='\033[38;5;220m'
RED='\033[38;5;196m';  GRAY='\033[38;5;244m'; WHITE='\033[38;5;255m'

usage() {
    echo -e "${CYAN}${BOLD}elblasy.app — Odoo Multi-Instance Manager${NC}"
    echo ""
    echo -e "  Usage: elblasy <command> [instance]"
    echo ""
    printf "  %-18s %s\n" "list"            "All instances with status, ports & version"
    printf "  %-18s %s\n" "ps"              "Show running Odoo/DB containers"
    printf "  %-18s %s\n" "start <name>"    "Start an instance"
    printf "  %-18s %s\n" "stop <name>"     "Stop an instance"
    printf "  %-18s %s\n" "restart <name>"  "Restart an instance"
    printf "  %-18s %s\n" "logs <name>"     "Follow live logs"
    printf "  %-18s %s\n" "info <name>"     "Show credentials, URLs, paths"
    printf "  %-18s %s\n" "backup <name>"   "Full backup (DB dump + filestore archive)"
    printf "  %-18s %s\n" "delete <name>"   "Delete instance (with confirmation)"
    echo ""
}

get_all() {
    [[ -d "$INST_DIR" ]] || return
    find "$INST_DIR" -mindepth 1 -maxdepth 1 -type d -exec basename {} ';' 2>/dev/null | sort
}

require_inst() {
    [[ -n "${1:-}" && -d "${INST_DIR}/${1}" ]] || {
        echo -e "${RED}[ERROR]${NC} Instance '${1:-<none>}' not found."
        echo "Available:"; get_all; exit 1
    }
}

ev() { grep -E "^${1}=" "${INST_DIR}/${2}/.env" 2>/dev/null | cut -d= -f2 || echo "?"; }

cmd_list() {
    echo -e "${BOLD}${CYAN}Odoo Instances — elblasy.app${NC}"
    printf "  %-24s %-10s %-6s %-6s %-5s %s\n" "INSTANCE" "STATUS" "HTTP" "CHAT" "VER" "IMAGE"
    echo -e "${GRAY}  ───────────────────────────────────────────────────────────────${NC}"
    local found=0
    for inst in $(get_all); do
        found=1
        local h; h=$(ev ODOO_HTTP_PORT "$inst")
        local c; c=$(ev ODOO_CHAT_PORT "$inst")
        local v; v=$(ev ODOO_VERSION "$inst")
        local i; i=$(ev ODOO_IMAGE "$inst")
        local stat
        if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^odoo_${inst}$"; then
            stat="${GREEN}Running${NC}"
        else
            stat="${GRAY}Stopped${NC}"
        fi
        printf "  %-24s %-19b %-6s %-6s %-5s %s\n" "$inst" "$stat" "$h" "$c" "$v" "$i"
    done
    [[ $found -eq 0 ]] && echo -e "  ${GRAY}No instances. Run the installer to create one.${NC}"
    echo ""
}

cmd_ps() {
    docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}' 2>/dev/null \
        | grep -E "odoo_|db_|NAMES" || echo "No running Odoo/DB containers."
}

cmd_info() {
    require_inst "$1"
    local sip; sip=$(curl -s -4 --max-time 3 ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')
    local h; h=$(ev ODOO_HTTP_PORT "$1")
    local v; v=$(ev ODOO_VERSION "$1")
    local img; img=$(ev ODOO_IMAGE "$1")
    local pw; pw=$(ev ODOO_ADMIN_PASSWORD "$1")
    local pg_u; pg_u=$(ev POSTGRES_USER "$1")
    local pg_p; pg_p=$(ev POSTGRES_EXTERNAL_PORT "$1")
    local vd; vd=$(ev ODOO_VER_DOT "$1")
    echo -e "${BOLD}${CYAN}Instance: $1${NC}"
    echo -e "  Web URL      : ${CYAN}http://${sip}:${h}${NC}"
    echo -e "  Odoo Version : ${GREEN}${v}${NC}  (${img})"
    echo -e "  Admin Passwd : ${YELLOW}${pw}${NC}"
    echo -e "  DB User/Port : ${pg_u}  |  127.0.0.1:${pg_p}"
    echo -e "  Config       : ${INST_DIR}/$1/etc/odoo.conf"
    echo -e "  Custom addons: ${INST_DIR}/$1/etc/addons/${vd}/"
    echo -e "  Filestore    : ${INST_DIR}/$1/data/"
    echo ""
}

cmd_backup() {
    require_inst "$1"
    local bdir="${INST_DIR}/$1/backups"; local ts; ts=$(date +%Y%m%d_%H%M%S)
    mkdir -p "$bdir"
    local pg_u; pg_u=$(ev POSTGRES_USER "$1")
    echo -e "${CYAN}Backup $1...${NC}"
    local dump="${bdir}/dump_${ts}.sql"
    docker exec -t "db_$1" pg_dumpall -U "${pg_u}" > "${dump}" || { rm -f "${dump}"; echo -e "${RED}Dump failed.${NC}"; exit 1; }
    local arc="${bdir}/backup_$1_${ts}.tar.gz"
    tar -czf "${arc}" -C "${INST_DIR}/$1" data etc backups/$(basename "${dump}")
    rm -f "${dump}"
    echo -e "${GREEN}[OK]${NC} ${arc}"
}

ACTION="${1:-}"; INST="${2:-}"
case "$ACTION" in
    ""|list)  cmd_list ;;
    ps)       cmd_ps ;;
    start)    require_inst "$INST"; (cd "${INST_DIR}/${INST}" && docker compose up -d) ;;
    stop)     require_inst "$INST"; (cd "${INST_DIR}/${INST}" && docker compose stop) ;;
    restart)  require_inst "$INST"; (cd "${INST_DIR}/${INST}" && docker compose restart) ;;
    logs)     require_inst "$INST"; (cd "${INST_DIR}/${INST}" && docker compose logs -f --tail=200) ;;
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
            echo -e "${GREEN}[OK]${NC} '${INST}' deleted."
        else
            echo "Cancelled."
        fi
        ;;
    *) usage ;;
esac
CLI_EOF

    chmod +x "${cli_path}"
    ln -sf "${cli_path}" "${GLOBAL_BIN}/${CLI_ALIAS}"
    success "CLI ready: ${BOLD}elblasy${NC} and ${DIM}elblasy-odoo${NC}"
}

# ------------------------------------------------------------------------------
# Final Summary
# ------------------------------------------------------------------------------
display_summary() {
    local server_ip
    server_ip=$(curl -s -4 --max-time 5 ifconfig.me \
        || curl -s -4 --max-time 5 icanhazip.com \
        || hostname -I | awk '{print $1}')

    echo ""
    echo -e "${GREEN}${BOLD}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}${BOLD}║       Odoo Instance Deployed Successfully — AI Ready!                      ║${NC}"
    echo -e "${GREEN}${BOLD}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  🏢  ${BOLD}Provider         :${NC} elblasy.app"
    echo -e "  🏷   ${BOLD}Instance Name    :${NC} ${WHITE}${BOLD}${INSTANCE_NAME}${NC}"
    echo -e "  📦  ${BOLD}Odoo Version     :${NC} ${GREEN}Odoo ${ODOO_VERSION}${NC}  (${CYAN}${ODOO_IMAGE}${NC})"
    echo -e "  🌐  ${BOLD}Web URL          :${NC} ${CYAN}http://${server_ip}:${HTTP_PORT}${NC}"
    echo -e "  💬  ${BOLD}Chat/Longpoll    :${NC} ${CYAN}:${CHAT_PORT}${NC}"
    echo -e "  🐘  ${BOLD}PostgreSQL       :${NC} ${PURPLE}17 + pgvector  (AI Vector Ready)${NC}"
    echo -e "  🔑  ${BOLD}Master Password  :${NC} ${YELLOW}${BOLD}${ODOO_ADMIN_PASSWORD}${NC}"
    echo ""
    echo -e "  📁  ${BOLD}Instance Root    :${NC} ${TARGET_DIR}/"
    echo -e "  ⚙   ${BOLD}Config           :${NC} ${TARGET_DIR}/etc/odoo.conf"
    echo -e "  🧩  ${BOLD}Custom Addons    :${NC} ${TARGET_DIR}/etc/addons/${ODOO_VER_DOT}/"
    echo -e "      ${DIM}→ Drop modules here → auto-mapped to /mnt/extra-addons/${ODOO_VER_DOT}/${NC}"
    echo -e "  💾  ${BOLD}Filestore        :${NC} ${TARGET_DIR}/data/"
    echo -e "  📋  ${BOLD}Install Log      :${NC} ${INSTALL_LOG}"
    echo ""
    echo -e "${B2}${BOLD}  Multi-Instance:${NC} Run this script again for a 2nd instance. Ports auto-selected."
    echo ""
    echo -e "${B3}${BOLD}  Port Scheme Reference:${NC}"
    echo -e "    Odoo 16: HTTP ${CYAN}8016${NC} | Chat ${CYAN}9016${NC} | DB ${CYAN}5406${NC}"
    echo -e "    Odoo 17: HTTP ${CYAN}8017${NC} | Chat ${CYAN}9017${NC} | DB ${CYAN}5407${NC}"
    echo -e "    Odoo 18: HTTP ${CYAN}8018${NC} | Chat ${CYAN}9018${NC} | DB ${CYAN}5408${NC}"
    echo -e "    Odoo 19: HTTP ${CYAN}8019${NC} | Chat ${CYAN}9019${NC} | DB ${CYAN}5409${NC}"
    echo -e "    Odoo 20: HTTP ${CYAN}8020${NC} | Chat ${CYAN}9020${NC} | DB ${CYAN}5410${NC}"
    echo -e "    2nd instance: +10 (e.g. Odoo 20 #2 → ${CYAN}8030${NC})"
    echo ""
    echo -e "${B3}${BOLD}  CLI:${NC}"
    echo -e "    ${CYAN}elblasy list${NC}  |  ${CYAN}elblasy logs ${INSTANCE_NAME}${NC}  |  ${CYAN}elblasy info ${INSTANCE_NAME}${NC}"
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
