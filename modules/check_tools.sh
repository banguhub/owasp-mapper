#!/usr/bin/env bash
# =============================================================================
# check_tools.sh - Dependency checker for OWASP Mapper
# =============================================================================

# ── Required Tools Definition ─────────────────────────────────────────────────
# Format: "tool_name:display_name:install_method"
# install_method: apt | go | manual
declare -a REQUIRED_TOOLS=(
    "subfinder:subfinder:go"
    "gau:gau (Go-based URL fetcher):go"
    "httpx:httpx:go"
    "curl:curl:apt"
    "jq:jq:apt"
    "waybackurls:waybackurls (fallback URL fetcher):go"
)

# Track missing tools
declare -a MISSING_TOOLS=()

# ── Check Single Tool ─────────────────────────────────────────────────────────
is_tool_installed() {
    local tool="$1"
    command -v "$tool" &>/dev/null
}

# ── Check Go Installation ─────────────────────────────────────────────────────
check_go() {
    if ! is_tool_installed "go"; then
        return 1
    fi
    return 0
}

# ── Check All Required Tools ──────────────────────────────────────────────────
check_all_tools() {
    print_section "DEPENDENCY CHECK"
    MISSING_TOOLS=()

    local all_ok=true

    for entry in "${REQUIRED_TOOLS[@]}"; do
        local tool="${entry%%:*}"
        local rest="${entry#*:}"
        local display="${rest%%:*}"
        local method="${rest##*:}"

        if is_tool_installed "$tool"; then
            log_success "${display} → ${DIM}$(command -v "$tool")${RESET}"
        else
            log_warn "${display} → ${RED}NOT FOUND${RESET} (install via: ${YELLOW}$method${RESET})"
            MISSING_TOOLS+=("$entry")
            all_ok=false
        fi
    done

    echo ""

    if [[ "$all_ok" == true ]]; then
        log_done "All dependencies satisfied."
        return 0
    else
        log_warn "${#MISSING_TOOLS[@]} missing tool(s) detected."
        return 1
    fi
}

# ── Check & Prompt Install ────────────────────────────────────────────────────
check_and_prompt_install() {
    if check_all_tools; then
        return 0
    fi

    echo ""
    echo -ne "  ${BOLD}Install missing tools now? ${DIM}(y/n)${RESET}${BOLD}: ${RESET}"
    read -r answer
    answer="${answer,,}"

    if [[ "$answer" == "y" || "$answer" == "yes" ]]; then
        install_missing_tools
    else
        echo ""
        log_warn "Skipping installation. Some features may not work."
        log_info "Continuing with available tools only..."
        # Give user a moment to read
        sleep 1
    fi
}
