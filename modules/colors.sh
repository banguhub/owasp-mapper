#!/usr/bin/env bash
# =============================================================================
# colors.sh - Terminal color definitions and logging helpers
# =============================================================================

# ── Colors ────────────────────────────────────────────────────────────────────
if [[ -t 1 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    CYAN='\033[0;36m'
    BLUE='\033[0;34m'
    MAGENTA='\033[0;35m'
    BOLD='\033[1m'
    DIM='\033[2m'
    UNDERLINE='\033[4m'
    RESET='\033[0m'
    BLINK='\033[5m'
else
    # No color if output is not a terminal (e.g., piped to file)
    RED=''
    GREEN=''
    YELLOW=''
    CYAN=''
    BLUE=''
    MAGENTA=''
    BOLD=''
    DIM=''
    UNDERLINE=''
    RESET=''
    BLINK=''
fi

# ── Logging Helpers ───────────────────────────────────────────────────────────

# [✓] Success message in green
log_success() {
    echo -e "  ${GREEN}[✓]${RESET} $*"
}

# [✗] Error message in red
log_error() {
    echo -e "  ${RED}[✗]${RESET} $*" >&2
}

# [!] Warning message in yellow
log_warn() {
    echo -e "  ${YELLOW}[!]${RESET} $*"
}

# [i] Info message in cyan
log_info() {
    echo -e "  ${CYAN}[i]${RESET} $*"
}

# [~] Step/progress message in bold
log_step() {
    echo ""
    echo -e "  ${BOLD}${CYAN}[→]${RESET}${BOLD} $*${RESET}"
}

# [+] Item found / enumerated
log_found() {
    echo -e "  ${MAGENTA}[+]${RESET} $*"
}

# Print a styled section header
print_section() {
    local title="$1"
    echo ""
    echo -e "  ${BOLD}${CYAN}┌─ ${title} ${RESET}"
    echo -e "  ${DIM}└$(printf '─%.0s' {1..60})${RESET}"
    echo ""
}

# Print a progress bar (simple text-based)
# Usage: progress_bar "Message" <current> <total>
progress_bar() {
    local msg="$1"
    local current="$2"
    local total="$3"
    local width=40
    local filled=$(( (current * width) / total ))
    local empty=$(( width - filled ))
    local bar=""

    for ((i=0; i<filled; i++)); do bar+="█"; done
    for ((i=0; i<empty; i++)); do bar+="░"; done

    printf "\r  ${CYAN}[%s]${RESET} %s (%d/%d)" "$bar" "$msg" "$current" "$total"
}

# Print done message with timing
log_done() {
    local msg="${1:-Done}"
    echo -e "  ${GREEN}[✓]${RESET} ${BOLD}${msg}${RESET}"
}
