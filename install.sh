#!/usr/bin/env bash
# =============================================================================
# install.sh - One-step setup script for OWASP Mapper
# Run this once to set permissions and verify environment
# =============================================================================

set -euo pipefail

CYAN='\033[0;36m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
RESET='\033[0m'

echo -e "${CYAN}"
echo "  ╔═══════════════════════════════════════════════════╗"
echo "  ║         OWASP Mapper v1.0 — Setup Script          ║"
echo "  ╚═══════════════════════════════════════════════════╝"
echo -e "${RESET}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# OS Check
if [[ "$(uname -s)" != "Linux" ]]; then
    echo -e "${RED}[✗] This tool only runs on Linux. Detected: $(uname -s)${RESET}"
    exit 1
fi
echo -e "  ${GREEN}[✓]${RESET} Linux detected."

# Bash version check
BASH_MAJOR="${BASH_VERSINFO[0]}"
if [[ "$BASH_MAJOR" -lt 4 ]]; then
    echo -e "  ${RED}[✗]${RESET} Bash 4.0+ required. Found: $BASH_VERSION"
    exit 1
fi
echo -e "  ${GREEN}[✓]${RESET} Bash $BASH_VERSION"

# Make scripts executable
echo -e "  ${CYAN}[→]${RESET} Setting permissions..."
chmod +x "$SCRIPT_DIR/main.sh"
chmod +x "$SCRIPT_DIR/modules/"*.sh
echo -e "  ${GREEN}[✓]${RESET} Permissions set."

# Create results directory
mkdir -p "$SCRIPT_DIR/results"
echo -e "  ${GREEN}[✓]${RESET} Results directory ready: ./results/"

# Check Go
if command -v go &>/dev/null; then
    echo -e "  ${GREEN}[✓]${RESET} Go: $(go version | awk '{print $3}')"
else
    echo -e "  ${YELLOW}[!]${RESET} Go not found. Go-based tools (subfinder, gau, httpx) require Go."
    echo -e "  ${YELLOW}[!]${RESET} Install from: https://go.dev/dl/"
    echo -e "  ${YELLOW}[!]${RESET} Or run:  sudo apt install golang"
fi

# Ensure $HOME/go/bin in PATH
if [[ ":$PATH:" != *":$HOME/go/bin:"* ]]; then
    echo ""
    echo -e "  ${YELLOW}[!]${RESET} \$HOME/go/bin is not in your PATH."
    echo -e "  ${YELLOW}[!]${RESET} Add this to your ~/.bashrc or ~/.zshrc:"
    echo -e "      ${BOLD}export PATH=\$PATH:\$HOME/go/bin${RESET}"
fi

echo ""
echo -e "  ${GREEN}${BOLD}Setup complete!${RESET}"
echo ""
echo -e "  Run the tool with:"
echo -e "      ${BOLD}${CYAN}./main.sh${RESET}               # Interactive mode"
echo -e "      ${BOLD}${CYAN}./main.sh --help${RESET}        # Show help"
echo -e "      ${BOLD}${CYAN}./main.sh --auto-install${RESET} # Install all tools"
echo ""
