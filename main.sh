#!/usr/bin/env bash
# =============================================================================
# OWASP Mapper v1.0 | Author: banghub
# Web Application Penetration Testing Preparation Tool
# Linkedin: inkedin.com/in/sabbir-pentester
# Medium: banghub.medium.com
# =============================================================================

set -euo pipefail

# ── Script Directory ──────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULES_DIR="$SCRIPT_DIR/modules"

# ── Source all modules ────────────────────────────────────────────────────────
source "$MODULES_DIR/colors.sh"
source "$MODULES_DIR/check_tools.sh"
source "$MODULES_DIR/installer.sh"
source "$MODULES_DIR/recon.sh"
source "$MODULES_DIR/collector.sh"
source "$MODULES_DIR/mapper.sh"
source "$MODULES_DIR/output.sh"

# ── Global Variables ──────────────────────────────────────────────────────────
TARGET_DOMAIN=""
DO_SUBDOMAIN="n"
SELECTED_CATEGORIES=""
RESULTS_DIR="$SCRIPT_DIR/results"
ALL_URLS_FILE=""
ALIVE_URLS_FILE=""
SUBDOMAINS_FILE=""

# ── Banner ────────────────────────────────────────────────────────────────────
print_banner() {
    clear
    echo -e "${CYAN}"
    echo '  ██████╗ ██╗    ██╗ █████╗ ███████╗██████╗     ███╗   ███╗ █████╗ ██████╗ ██████╗ ███████╗██████╗ '
    echo ' ██╔═══██╗██║    ██║██╔══██╗██╔════╝██╔══██╗    ████╗ ████║██╔══██╗██╔══██╗██╔══██╗██╔════╝██╔══██╗'
    echo ' ██║   ██║██║ █╗ ██║███████║███████╗██████╔╝    ██╔████╔██║███████║██████╔╝██████╔╝█████╗  ██████╔╝'
    echo ' ██║   ██║██║███╗██║██╔══██║╚════██║██╔═══╝     ██║╚██╔╝██║██╔══██║██╔═══╝ ██╔═══╝ ██╔══╝  ██╔══██╗'
    echo ' ╚██████╔╝╚███╔███╔╝██║  ██║███████║██║         ██║ ╚═╝ ██║██║  ██║██║     ██║     ███████╗██║  ██║'
    echo '  ╚═════╝  ╚══╝╚══╝ ╚═╝  ╚═╝╚══════╝╚═╝         ╚═╝     ╚═╝╚═╝  ╚═╝╚═╝     ╚═╝     ╚══════╝╚═╝  ╚═╝'
    echo -e "${RESET}"
    echo -e "  ${BOLD}${YELLOW}OWASP Mapper v1.0${RESET}  ${DIM}|  Author: banghub  |  Web App PenTest Preparation Tool${RESET}"
    echo -e "  ${RED}[!] For authorized security testing only. Unauthorized use is illegal.${RESET}"
    echo -e "  ${DIM}$(printf '─%.0s' {1..100})${RESET}"
    echo ""
}

# ── Help Menu ─────────────────────────────────────────────────────────────────
print_help() {
    print_banner
    echo -e "${BOLD}USAGE:${RESET}"
    echo -e "  ${GREEN}./main.sh${RESET}                          Interactive mode (recommended)"
    echo -e "  ${GREEN}./main.sh --help${RESET}                   Show this help menu"
    echo -e "  ${GREEN}./main.sh --auto-install${RESET}           Auto-install all missing dependencies"
    echo -e "  ${GREEN}./main.sh --only sqli,xss${RESET}          Run only specified categories"
    echo ""
    echo -e "${BOLD}OPTIONS:${RESET}"
    echo -e "  ${YELLOW}--help${RESET}             Show this help menu and exit"
    echo -e "  ${YELLOW}--auto-install${RESET}     Non-interactive install of all required tools"
    echo -e "  ${YELLOW}--only <cats>${RESET}      Comma-separated list of categories to map"
    echo ""
    echo -e "${BOLD}OWASP CATEGORIES:${RESET}"
    echo -e "  ${CYAN}1${RESET}  sqli           SQL Injection endpoints"
    echo -e "  ${CYAN}2${RESET}  xss            Cross-Site Scripting endpoints"
    echo -e "  ${CYAN}3${RESET}  auth           Authentication & Session endpoints"
    echo -e "  ${CYAN}4${RESET}  access_control Broken Access Control endpoints"
    echo -e "  ${CYAN}5${RESET}  csrf           CSRF-prone endpoints"
    echo -e "  ${CYAN}6${RESET}  misconfig      Security Misconfiguration endpoints"
    echo -e "  ${CYAN}7${RESET}  data_exposure  Sensitive Data Exposure endpoints"
    echo -e "  ${CYAN}8${RESET}  file_inclusion File Inclusion endpoints"
    echo -e "  ${CYAN}9${RESET}  open_redirect  Open Redirect endpoints"
    echo -e "  ${CYAN}10${RESET} misc           Miscellaneous interesting endpoints"
    echo ""
    echo -e "${BOLD}EXAMPLES:${RESET}"
    echo -e "  ${DIM}# Full interactive scan${RESET}"
    echo -e "  ${GREEN}./main.sh${RESET}"
    echo ""
    echo -e "  ${DIM}# Only map SQL injection and XSS${RESET}"
    echo -e "  ${GREEN}./main.sh --only sqli,xss${RESET}"
    echo ""
    echo -e "  ${DIM}# Auto-install all tools without prompting${RESET}"
    echo -e "  ${GREEN}./main.sh --auto-install${RESET}"
    echo ""
    echo -e "${BOLD}OUTPUT:${RESET}"
    echo -e "  Results are saved to ${CYAN}./results/${RESET}"
    echo -e "  Each category gets its own .txt file"
    echo -e "  A summary is generated at ${CYAN}./results/summary.txt${RESET}"
    echo ""
    echo -e "${RED}LEGAL DISCLAIMER:${RESET}"
    echo -e "  This tool is for authorized penetration testing ONLY."
    echo -e "  Always obtain written permission before testing any system."
    echo -e "  The author assumes no liability for misuse of this tool."
    echo ""
    exit 0
}

# ── OS Check ──────────────────────────────────────────────────────────────────
check_linux() {
    if [[ "$(uname -s)" != "Linux" ]]; then
        echo -e "${RED}[✗] This tool only runs on Linux (Ubuntu/Kali/Debian).${RESET}"
        echo -e "${YELLOW}[!] Detected OS: $(uname -s). Exiting.${RESET}"
        exit 1
    fi
    log_success "Linux OS detected: $(. /etc/os-release && echo "$PRETTY_NAME" 2>/dev/null || echo "Linux")"
}

# ── Sudo Elevation ────────────────────────────────────────────────────────────
ensure_sudo() {
    if [[ "$EUID" -ne 0 ]]; then
        log_info "This tool requires sudo privileges for installing dependencies."
        log_info "You may be prompted for your password once."
        echo ""
        if ! sudo -v 2>/dev/null; then
            log_error "Failed to obtain sudo privileges. Exiting."
            exit 1
        fi
        # Keep sudo alive in background for the session
        (while true; do sudo -n true; sleep 50; done) &
        SUDO_KEEPALIVE_PID=$!
        trap 'kill "$SUDO_KEEPALIVE_PID" 2>/dev/null' EXIT
        log_success "Sudo privileges obtained."
    else
        log_success "Running as root."
    fi
}

# ── Domain Input & Validation ─────────────────────────────────────────────────
prompt_domain() {
    echo ""
    echo -e "${BOLD}${CYAN}[ TARGET CONFIGURATION ]${RESET}"
    echo -e "${DIM}$(printf '─%.0s' {1..50})${RESET}"
    echo ""

    while true; do
        echo -ne "${BOLD}  Enter target domain ${DIM}(e.g. example.com)${RESET}${BOLD}: ${RESET}"
        read -r TARGET_DOMAIN

        # Strip protocol if provided
        TARGET_DOMAIN="${TARGET_DOMAIN#http://}"
        TARGET_DOMAIN="${TARGET_DOMAIN#https://}"
        TARGET_DOMAIN="${TARGET_DOMAIN%%/*}"
        TARGET_DOMAIN="${TARGET_DOMAIN// /}"  # remove spaces

        if validate_domain "$TARGET_DOMAIN"; then
            log_success "Target set → ${BOLD}$TARGET_DOMAIN${RESET}"
            break
        else
            log_error "Invalid domain: '$TARGET_DOMAIN'. Please enter a valid domain (e.g. example.com)"
        fi
    done
}

# ── Domain Validation ─────────────────────────────────────────────────────────
validate_domain() {
    local domain="$1"
    # Must match valid domain pattern
    if [[ "$domain" =~ ^([a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$ ]]; then
        return 0
    else
        return 1
    fi
}

# ── Subdomain Prompt ──────────────────────────────────────────────────────────
prompt_subdomain() {
    echo ""
    echo -ne "  ${BOLD}Perform subdomain enumeration? ${DIM}(y/n)${RESET}${BOLD}: ${RESET}"
    read -r DO_SUBDOMAIN
    DO_SUBDOMAIN="${DO_SUBDOMAIN,,}"  # lowercase
    if [[ "$DO_SUBDOMAIN" != "y" && "$DO_SUBDOMAIN" != "yes" ]]; then
        DO_SUBDOMAIN="n"
        log_info "Skipping subdomain enumeration. Using main domain only."
    else
        DO_SUBDOMAIN="y"
        log_info "Subdomain enumeration enabled."
    fi
}

# ── Category Selection ────────────────────────────────────────────────────────
prompt_categories() {
    echo ""
    echo -e "${BOLD}${CYAN}[ OWASP CATEGORY SELECTION ]${RESET}"
    echo -e "${DIM}$(printf '─%.0s' {1..50})${RESET}"
    echo ""
    echo -e "  ${CYAN}1${RESET}  sqli           - SQL Injection"
    echo -e "  ${CYAN}2${RESET}  xss            - Cross-Site Scripting"
    echo -e "  ${CYAN}3${RESET}  auth           - Authentication"
    echo -e "  ${CYAN}4${RESET}  access_control - Broken Access Control"
    echo -e "  ${CYAN}5${RESET}  csrf           - CSRF"
    echo -e "  ${CYAN}6${RESET}  misconfig      - Misconfiguration"
    echo -e "  ${CYAN}7${RESET}  data_exposure  - Sensitive Data Exposure"
    echo -e "  ${CYAN}8${RESET}  file_inclusion - File Inclusion"
    echo -e "  ${CYAN}9${RESET}  open_redirect  - Open Redirect"
    echo -e "  ${CYAN}10${RESET} misc           - Miscellaneous"
    echo ""
    echo -ne "  ${BOLD}Enter categories ${DIM}(e.g. 1,3,5 or 'all')${RESET}${BOLD}: ${RESET}"
    read -r SELECTED_CATEGORIES
    SELECTED_CATEGORIES="${SELECTED_CATEGORIES// /}"  # remove spaces

    if [[ -z "$SELECTED_CATEGORIES" || "${SELECTED_CATEGORIES,,}" == "all" ]]; then
        SELECTED_CATEGORIES="all"
        log_success "All categories selected."
    else
        log_success "Selected categories: $SELECTED_CATEGORIES"
    fi
}

# ── Parse CLI Arguments ───────────────────────────────────────────────────────
AUTO_INSTALL=false
ONLY_CATS=""

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --help|-h)
                print_help
                ;;
            --auto-install)
                AUTO_INSTALL=true
                shift
                ;;
            --only)
                if [[ -z "${2:-}" ]]; then
                    echo -e "${RED}[✗] --only requires a comma-separated list of categories.${RESET}"
                    exit 1
                fi
                ONLY_CATS="$2"
                shift 2
                ;;
            *)
                echo -e "${RED}[✗] Unknown option: $1${RESET}"
                echo -e "${YELLOW}[!] Run with --help for usage information.${RESET}"
                exit 1
                ;;
        esac
    done
}

# ── Main Orchestrator ─────────────────────────────────────────────────────────
main() {
    parse_args "$@"
    print_banner

    # Step 1: OS check
    check_linux

    # Step 2: Elevate privileges
    ensure_sudo

    # Step 3: Check & install tools
    if [[ "$AUTO_INSTALL" == true ]]; then
        auto_install_all
    else
        check_and_prompt_install
    fi

    # Step 4: Domain input
    prompt_domain

    # Step 5: Subdomain option
    prompt_subdomain

    # Step 6: Category selection
    if [[ -n "$ONLY_CATS" ]]; then
        SELECTED_CATEGORIES="$ONLY_CATS"
        log_info "Using categories from --only flag: $SELECTED_CATEGORIES"
    else
        prompt_categories
    fi

    # Step 7: Create results directory
    setup_results_dir "$RESULTS_DIR" "$TARGET_DOMAIN"

    # Step 8: Recon (subdomains)
    run_recon "$TARGET_DOMAIN" "$DO_SUBDOMAIN" "$RESULTS_DIR"
    SUBDOMAINS_FILE="$RESULTS_DIR/subdomains.txt"

    # Step 9: URL Collection
    run_collector "$TARGET_DOMAIN" "$DO_SUBDOMAIN" "$SUBDOMAINS_FILE" "$RESULTS_DIR"
    ALL_URLS_FILE="$RESULTS_DIR/all_urls.txt"
    ALIVE_URLS_FILE="$RESULTS_DIR/alive_urls.txt"

    # Step 10: OWASP Mapping
    run_mapper "$ALIVE_URLS_FILE" "$RESULTS_DIR" "$SELECTED_CATEGORIES"

    # Step 11: Summary
    generate_summary "$TARGET_DOMAIN" "$RESULTS_DIR" "$SUBDOMAINS_FILE" "$ALL_URLS_FILE" "$ALIVE_URLS_FILE"

    # Step 12: Final output
    print_final_report "$TARGET_DOMAIN" "$RESULTS_DIR"
}

# ── Run ───────────────────────────────────────────────────────────────────────
main "$@"
