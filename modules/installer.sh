#!/usr/bin/env bash
# =============================================================================
# installer.sh - Automated tool installer for OWASP Mapper
# =============================================================================

# ── Go Install Path ───────────────────────────────────────────────────────────
GO_BIN_PATH="$HOME/go/bin"

# ── Ensure Go bin is in PATH ──────────────────────────────────────────────────
ensure_go_path() {
    if [[ ":$PATH:" != *":$GO_BIN_PATH:"* ]]; then
        export PATH="$PATH:$GO_BIN_PATH"
    fi
}

# ── Install apt Package ───────────────────────────────────────────────────────
install_apt() {
    local pkg="$1"
    log_step "Installing ${pkg} via apt..."
    if sudo apt-get update -qq 2>/dev/null && sudo apt-get install -y -qq "$pkg" 2>/dev/null; then
        log_success "${pkg} installed successfully."
        return 0
    else
        log_error "Failed to install ${pkg} via apt."
        return 1
    fi
}

# ── Install Go Tool ───────────────────────────────────────────────────────────
install_go_tool() {
    local tool="$1"
    local pkg_path="$2"
    log_step "Installing ${tool} via go install..."

    # Check Go is available
    if ! is_tool_installed "go"; then
        log_error "Go is not installed. Cannot install ${tool}."
        prompt_go_install
        return 1
    fi

    ensure_go_path

    if go install "${pkg_path}@latest" 2>/dev/null; then
        ensure_go_path
        if is_tool_installed "$tool"; then
            log_success "${tool} installed successfully → $(command -v "$tool")"
            return 0
        else
            # Maybe it ended up in GOPATH/bin
            if [[ -f "$GO_BIN_PATH/$tool" ]]; then
                log_success "${tool} installed at $GO_BIN_PATH/$tool"
                return 0
            fi
            log_error "${tool} binary not found after go install. Check your GOPATH."
            return 1
        fi
    else
        log_error "go install failed for ${tool}."
        return 1
    fi
}

# ── Prompt User to Install Go ─────────────────────────────────────────────────
prompt_go_install() {
    echo ""
    log_warn "Go is not installed but is required for Go-based tools."
    log_info "Install Go manually from: ${UNDERLINE}https://go.dev/dl/${RESET}"
    echo ""
    echo -ne "  ${BOLD}Attempt to install Go via apt now? ${DIM}(y/n)${RESET}${BOLD}: ${RESET}"
    read -r go_answer
    go_answer="${go_answer,,}"

    if [[ "$go_answer" == "y" || "$go_answer" == "yes" ]]; then
        log_step "Installing golang-go via apt..."
        if sudo apt-get update -qq 2>/dev/null && sudo apt-get install -y -qq golang 2>/dev/null; then
            log_success "Go installed via apt."
            ensure_go_path
        else
            log_error "Failed to install Go via apt."
            log_warn "Please install Go manually: https://go.dev/dl/"
        fi
    else
        log_warn "Skipping Go installation. Go-based tools will not be installed."
    fi
}

# ── Go Package Paths ──────────────────────────────────────────────────────────
get_go_package() {
    local tool="$1"
    case "$tool" in
        subfinder)   echo "github.com/projectdiscovery/subfinder/v2/cmd/subfinder" ;;
        gau)         echo "github.com/lc/gau/v2/cmd/gau" ;;
        httpx)       echo "github.com/projectdiscovery/httpx/cmd/httpx" ;;
        waybackurls) echo "github.com/tomnomnom/waybackurls" ;;
        *)           echo "" ;;
    esac
}

# ── Install Single Tool ───────────────────────────────────────────────────────
install_tool() {
    local entry="$1"
    local tool="${entry%%:*}"
    local rest="${entry#*:}"
    local display="${rest%%:*}"
    local method="${rest##*:}"

    echo ""
    log_info "Installing: ${BOLD}${display}${RESET}"

    case "$method" in
        apt)
            install_apt "$tool"
            ;;
        go)
            # Check if Go is available first
            if ! is_tool_installed "go"; then
                prompt_go_install
            fi
            local pkg
            pkg="$(get_go_package "$tool")"
            if [[ -n "$pkg" ]]; then
                install_go_tool "$tool" "$pkg"
            else
                log_error "Unknown Go package for: $tool"
                return 1
            fi
            ;;
        manual)
            log_warn "${tool} requires manual installation."
            log_info "Please install ${tool} manually and re-run this script."
            ;;
        *)
            log_error "Unknown install method: $method for $tool"
            return 1
            ;;
    esac
}

# ── Install All Missing Tools ─────────────────────────────────────────────────
install_missing_tools() {
    print_section "INSTALLING MISSING TOOLS"

    if [[ ${#MISSING_TOOLS[@]} -eq 0 ]]; then
        log_success "No tools to install."
        return 0
    fi

    local failed=0
    for entry in "${MISSING_TOOLS[@]}"; do
        if ! install_tool "$entry"; then
            ((failed++)) || true
        fi
    done

    echo ""
    if [[ $failed -eq 0 ]]; then
        log_success "All tools installed successfully."
    else
        log_warn "${failed} tool(s) failed to install. Some features may be limited."
    fi

    # Re-add go bin to path after all installs
    ensure_go_path
    echo ""
}

# ── Auto Install All (non-interactive) ────────────────────────────────────────
auto_install_all() {
    print_section "AUTO-INSTALL MODE"
    log_info "Checking and installing all required tools..."

    # Populate MISSING_TOOLS
    MISSING_TOOLS=()
    for entry in "${REQUIRED_TOOLS[@]}"; do
        local tool="${entry%%:*}"
        if ! is_tool_installed "$tool"; then
            MISSING_TOOLS+=("$entry")
        fi
    done

    if [[ ${#MISSING_TOOLS[@]} -eq 0 ]]; then
        log_success "All tools already installed. Nothing to do."
        return 0
    fi

    # Install Go first if needed
    local needs_go=false
    for entry in "${MISSING_TOOLS[@]}"; do
        local method="${entry##*:}"
        if [[ "$method" == "go" ]]; then
            needs_go=true
            break
        fi
    done

    if [[ "$needs_go" == true ]] && ! is_tool_installed "go"; then
        log_step "Go required. Installing golang via apt..."
        sudo apt-get update -qq 2>/dev/null
        sudo apt-get install -y -qq golang 2>/dev/null && \
            log_success "Go installed." || \
            log_error "Go installation failed. Go tools will be skipped."
    fi

    install_missing_tools
}
