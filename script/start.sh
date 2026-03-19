#!/bin/bash
#
# Script Name: start.sh
#
# Version:      1.0.0-nodebb
# Author:       Naoki Hirata
# Date:         2026-03-16
# Usage:        curl -fsSL <URL> | REPO_USER=<user> REPO_NAME=<repo> bash
#               curl -fsSL <URL> | REPO_USER=<user> REPO_NAME=<repo> bash -s -- [-test] [--help] [--reconfigure]
# Options:      -test          Use latest master branch instead of latest release tag (for testing)
#               --help|-h      Show this help message
#               --reconfigure  Re-enter configuration values (ignore saved config)
# Description:  This script builds a Docker + NodeBB server environment by one-liner command.
#               Target OS: Ubuntu 24
# Version History:
#               1.0.0-nodebb  (2026-03-16) Initial release
# License:      MIT License

set -e
set -o pipefail

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

log_info() {
    echo -e "${GREEN}→${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}!${NC} $1"
}

log_error() {
    echo -e "${RED}✗${NC} $1"
}

log_step() {
    echo -e "${BLUE}${BOLD}==>${NC}${BOLD} $1${NC}"
}

show_help() {
    cat <<EOF
docker-nodebb - NodeBB environment setup on Docker containers

Usage:
  curl -fsSL https://raw.githubusercontent.com/USER/REPO/master/script/start.sh | bash
  curl -fsSL ... | bash -s -- [-test] [--help] [--reconfigure]

Options:
  -test          Use latest master branch instead of latest release tag (for testing)
  --help|-h      Show this help message
  --reconfigure  Re-enter configuration values (ignore saved config)

Target OS: Ubuntu 24

EOF
}

# Load saved configuration
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        # shellcheck source=/dev/null
        source "$CONFIG_FILE"
        return 0
    fi
    return 1
}

# Save configuration to file
save_config() {
    mkdir -p "$(dirname "$CONFIG_FILE")"
    cat > "$CONFIG_FILE" <<EOF
# kdinstall configuration file
# Created: $(date)
DOMAIN_NAME="$DOMAIN_NAME"
ADMIN_EMAIL="$ADMIN_EMAIL"
DETECTED_IP="$DETECTED_IP"
EOF
    chmod 600 "$CONFIG_FILE"
    log_info "Configuration saved to $CONFIG_FILE"
}

# Parse options before other checks
RECONFIGURE=false
for arg in "$@"; do
    case "$arg" in
        --help|-h)
            show_help
            exit 0
            ;;
        --reconfigure)
            RECONFIGURE=true
            ;;
    esac
done

# GitHub coordinates — set via env vars:
#   curl -fsSL URL | REPO_USER=youruser REPO_NAME=yourrepo bash
if [ -z "${REPO_USER}" ] || [ -z "${REPO_NAME}" ]; then
    log_error "REPO_USER and REPO_NAME must be set."
    echo "  curl -fsSL URL | REPO_USER=youruser REPO_NAME=yourrepo bash"
    exit 1
fi
GITHUB_USER="${REPO_USER}"
GITHUB_REPO="${REPO_NAME}"
readonly GITHUB_USER GITHUB_REPO
SCRIPT_URL="https://raw.githubusercontent.com/${GITHUB_USER}/${GITHUB_REPO}/master/script/start.sh"
readonly SCRIPT_URL

# Check os version
declare DIST_NAME=""
RELEASE_FILE=/etc/os-release

if [ -f "${RELEASE_FILE}" ] && grep -q '^NAME="Ubuntu' "${RELEASE_FILE}"; then
    DIST_NAME="Ubuntu"
fi

# Exit if unsupported os
if [ "${DIST_NAME}" == '' ]; then
    log_error "Your platform is not supported."
    uname -a
    exit 1
fi

# Define fixed parameters
readonly CONFIG_FILE="/etc/kdinstall/config"
readonly WORK_DIR=/root/${GITHUB_REPO}_work
readonly INSTALL_PACKAGE_CMD="apt -y install"

# check root user
if [ "$(id -u)" -ne 0 ]; then
    log_error "This script must be run as root."
    echo
    echo "Please run with sudo:"
    echo "  curl -fsSL ${SCRIPT_URL} | sudo bash"
    exit 1
fi

log_step "${DIST_NAME} - START BUILDING NodeBB ENVIRONMENT"

# Get test mode
if [ "$1" == '-test' ]; then
    readonly TEST_MODE=true
    log_info "Test mode: using latest master branch"
else
    readonly TEST_MODE=false
fi

# Install ansible command
if ! type -P ansible >/dev/null 2>&1; then
    log_step "Installing Ansible"
    ${INSTALL_PACKAGE_CMD} software-properties-common
    add-apt-repository --yes --update ppa:ansible/ansible
    ${INSTALL_PACKAGE_CMD} ansible-core
    log_info "Ansible installed"
else
    log_info "Ansible is already installed"
fi

# Download the latest repository archive
if ${TEST_MODE}; then
    url="https://github.com/${GITHUB_USER}/${GITHUB_REPO}/archive/master.tar.gz"
    version="new"
else
    set +e
    url=$(curl -sf "https://api.github.com/repos/${GITHUB_USER}/${GITHUB_REPO}/tags" 2>/dev/null | \
        grep '"tarball_url"' | head -n 1 | \
        sed -e 's/.*"tarball_url"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
    set -e
    if [ -z "${url}" ]; then
        log_error "Could not find release tag. Use -test to try latest master."
        exit 1
    fi
    version=$(basename "$url" | sed -e 's/v\([0-9\.]*\)/\1/')
    [ -z "${version}" ] && version="latest"
fi
filename=${GITHUB_REPO}_${version}.tar.gz
filepath=${WORK_DIR}/${filename}

# Set current directory
mkdir -p ${WORK_DIR}
cd ${WORK_DIR}
savefilelist=$(ls -1 2>/dev/null || true)

# Download archived repository
log_step "Downloading ${GITHUB_USER}/${GITHUB_REPO}"
if ! curl -fsSL -o "${filepath}" "${url}"; then
    log_error "Download failed: ${url}"
    exit 1
fi
if [ ! -s "${filepath}" ]; then
    log_error "Downloaded file is empty"
    exit 1
fi

# Remove old files
for file in $savefilelist; do
    [ -z "${file}" ] && continue
    if [ "${file}" != "${filename}" ]; then
        rm -rf "${file}"
    fi
done

# Get archive directory name
set +o pipefail
destdir=$(tar tzf "${filepath}" | head -n 1)
set -o pipefail
destdirname=$(basename "$destdir")

# Unarchive repository
tar xzf "${filename}"
find ./ -type f -name ".gitkeep" -delete
mv "${destdirname}" "${GITHUB_REPO}"
log_info "${filename} unarchived"

# Configuration management
DOMAIN_NAME=""
ADMIN_EMAIL=""
DETECTED_IP=""
CONFIG_LOADED=false

# Load existing configuration
if load_config && [ "$RECONFIGURE" = false ]; then
    CONFIG_LOADED=true
    log_step "Previous configuration found"
    if [[ -z "$DOMAIN_NAME" && -n "$DETECTED_IP" ]]; then
        log_info "  Domain: <not set> (Using IP: ${DETECTED_IP})"
    else
        log_info "  Domain: ${DOMAIN_NAME:-<not set>}"
    fi
    log_info "  Email:  ${ADMIN_EMAIL:-<not set>}"
    echo
    read -r -p "Use this configuration? [Y/n]: " USE_PREV < /dev/tty
    if [[ "$USE_PREV" =~ ^[nN] ]]; then
        CONFIG_LOADED=false
        RECONFIGURE=true
    fi
fi

# Prompt for configuration if needed
if [ "$CONFIG_LOADED" = false ]; then
    # Prompt for domain name (optional)
    read -r -p "Domain name (e.g. example.com, press Enter to skip): " DOMAIN_NAME < /dev/tty
    DOMAIN_NAME="${DOMAIN_NAME//$'\r'/}"
    DOMAIN_NAME="${DOMAIN_NAME// /}"
fi

# DNS check and admin email prompt for entered domain name
if [[ -n "$DOMAIN_NAME" ]] && [ "$CONFIG_LOADED" = false ]; then
    log_step "Checking DNS for ${DOMAIN_NAME}"

    _dns_ok=true
    _dns_error_msg=""

    # Get all IPs assigned to this server (local + global)
    _local_ips=$(hostname -I 2>/dev/null || true)
    _global_ip=$(curl -fsSL --max-time 5 https://checkip.amazonaws.com 2>/dev/null || true)
    SERVER_IPS="${_local_ips} ${_global_ip}"
    if [[ -z "${SERVER_IPS// /}" ]]; then
        _dns_ok=false
        _dns_error_msg="Could not retrieve this server's IP addresses."
    fi

    # Resolve domain IP
    if $_dns_ok; then
        DOMAIN_IP=$(getent hosts "$DOMAIN_NAME" 2>/dev/null | awk '{print $1}' | head -n 1)
        if [[ -z "$DOMAIN_IP" ]]; then
            _dns_ok=false
            _dns_error_msg="Could not resolve domain: ${DOMAIN_NAME}. Please check your DNS A record."
        fi
    fi

    # Compare domain IP against all server IPs
    if $_dns_ok; then
        _match=false
        for _ip in ${SERVER_IPS}; do
            [[ "$_ip" == "$DOMAIN_IP" ]] && _match=true && break
        done
        if ! $_match; then
            _dns_ok=false
            _dns_error_msg="DNS mismatch: ${DOMAIN_NAME} -> ${DOMAIN_IP} (server IPs: ${SERVER_IPS})"
        fi
    fi

    # On error: ask user to continue or exit
    if ! $_dns_ok; then
        log_error "${_dns_error_msg}"
        while true; do
            read -r -p "Continue anyway? [y/N]: " _ans < /dev/tty
            case "${_ans}" in
                [yY]) log_warn "Continuing despite DNS error."; break ;;
                [nN]|"") log_info "Installation aborted by user."; exit 0 ;;
                *) log_warn "Please enter y or n." ;;
            esac
        done
    else
        log_info "DNS check passed: ${DOMAIN_NAME} -> ${DOMAIN_IP}"
    fi

    # Prompt for admin email
    while true; do
        read -r -p "Admin email address: " ADMIN_EMAIL < /dev/tty
        [[ "$ADMIN_EMAIL" =~ ^[^@]+@[^@]+\.[^@]+$ ]] && break
        log_warn "Please enter a valid email address."
    done
fi

# Set certbot configuration based on whether domain name was entered by user
# This must be set BEFORE auto-detecting IP address
if [[ -n "$DOMAIN_NAME" ]]; then
    CERTBOT_ENABLED=true
    CERTBOT_EMAIL="${ADMIN_EMAIL}"
else
    CERTBOT_ENABLED=false
    CERTBOT_EMAIL=""
fi

# Auto-detect IP address if domain name is not provided
if [[ -z "$DOMAIN_NAME" ]]; then
    log_step "No domain name provided. Auto-detecting IP address..."
    
    # Try to detect private IP (192.168.x.x) first
    DETECTED_IP=$(hostname -I 2>/dev/null | tr ' ' '\n' | grep -E '^192\.168\.' | head -n 1)
    #DETECTED_IP=$(hostname -I 2>/dev/null | tr ' ' '\n' | head -n 1)
    
    # If no private IP, use default IP
    if [[ -z "$DETECTED_IP" ]]; then
        DETECTED_IP=$(hostname -I 2>/dev/null | awk '{print $1}')
    fi
    
    if [[ -n "$DETECTED_IP" ]]; then
        log_info "Using IP address: ${DETECTED_IP}"
        log_warn "Note: Self-signed certificate will be used (Let's Encrypt is disabled for IP addresses)"
    else
        log_error "Could not detect IP address. Please specify a domain name."
        exit 1
    fi
fi

# Save configuration for future use
if [ "$CONFIG_LOADED" = false ]; then
    save_config
fi

# launch ansible
log_step "Running Ansible playbook"
cd ${WORK_DIR}/${GITHUB_REPO}/playbooks
ansible-galaxy install -r requirements.yml
ansible-galaxy collection install -r requirements.yml

ansible-playbook -i localhost, -c local main.yml \
  -e "default_domain_name=${DOMAIN_NAME:-${DETECTED_IP}}" \
  -e "admin_email=${ADMIN_EMAIL}" \
  -e "certbot_enabled=${CERTBOT_ENABLED}" \
  -e "certbot_email=${CERTBOT_EMAIL}"

log_step "NodeBB on Docker setup complete"
