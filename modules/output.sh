#!/usr/bin/env bash
# =============================================================================
# output.sh - Results directory, summary generation, and final report
# =============================================================================

# ── Setup Results Directory ───────────────────────────────────────────────────
setup_results_dir() {
    local results_dir="$1"
    local domain="$2"

    log_step "Setting up results directory..."

    # Add timestamp to avoid overwriting previous results
    local timestamp
    timestamp="$(date '+%Y%m%d_%H%M%S')"
    local scan_dir="${results_dir}/${domain}_${timestamp}"

    # Update global results dir
    # We use the parent script's variable — override via RESULTS_DIR
    mkdir -p "$scan_dir"

    # Redirect all results to timestamped folder
    # Reassign the global RESULTS_DIR
    RESULTS_DIR="$scan_dir"

    log_success "Results directory: ${BOLD}${RESULTS_DIR}${RESET}"
}

# ── Count File Lines (excluding comments & empty) ─────────────────────────────
count_valid_lines() {
    local file="$1"
    if [[ ! -f "$file" || ! -s "$file" ]]; then
        echo 0
        return
    fi
    # Count lines that are not comments (#) and not empty
    grep -vcE "^(#.*)?$" "$file" 2>/dev/null || echo 0
}

# ── Generate Summary ──────────────────────────────────────────────────────────
generate_summary() {
    local domain="$1"
    local results_dir="$2"
    local subdomains_file="$3"
    local all_urls_file="$4"
    local alive_urls_file="$5"

    local summary_file="$results_dir/summary.txt"

    print_section "GENERATING SUMMARY"

    # Compute counts
    local subdomain_count=0
    if [[ -f "$subdomains_file" && -s "$subdomains_file" ]]; then
        subdomain_count=$(wc -l < "$subdomains_file" 2>/dev/null || echo 0)
    fi

    local total_urls=0
    if [[ -f "$all_urls_file" && -s "$all_urls_file" ]]; then
        total_urls=$(wc -l < "$all_urls_file" 2>/dev/null || echo 0)
    fi

    local alive_urls=0
    if [[ -f "$alive_urls_file" && -s "$alive_urls_file" ]]; then
        alive_urls=$(wc -l < "$alive_urls_file" 2>/dev/null || echo 0)
    fi

    # Category counts
    declare -A cat_counts
    for cat in sqli xss auth access_control csrf misconfig data_exposure file_inclusion open_redirect misc; do
        local cat_file="$results_dir/${cat}.txt"
        cat_counts[$cat]=$(count_valid_lines "$cat_file")
    done

    # Total mapped URLs
    local total_mapped=0
    for cat in "${!cat_counts[@]}"; do
        total_mapped=$(( total_mapped + ${cat_counts[$cat]} ))
    done

    # Write summary file
    {
        echo "╔══════════════════════════════════════════════════════════════════╗"
        echo "║              OWASP MAPPER v1.0 — SCAN SUMMARY                   ║"
        echo "╚══════════════════════════════════════════════════════════════════╝"
        echo ""
        echo "  Scan Date   : $(date '+%Y-%m-%d %H:%M:%S %Z')"
        echo "  Target      : $domain"
        echo "  Results Dir : $results_dir"
        echo ""
        echo "──────────────────────────────────────────────────────────────────"
        echo "  COLLECTION STATISTICS"
        echo "──────────────────────────────────────────────────────────────────"
        printf "  %-25s : %d\n" "Subdomains Found"  "$subdomain_count"
        printf "  %-25s : %d\n" "Raw URLs Collected" "$total_urls"
        printf "  %-25s : %d\n" "Alive URLs" "$alive_urls"
        printf "  %-25s : %d\n" "Total Mapped URLs" "$total_mapped"
        echo ""
        echo "──────────────────────────────────────────────────────────────────"
        echo "  OWASP TOP 10 CATEGORY BREAKDOWN"
        echo "──────────────────────────────────────────────────────────────────"
        printf "  %-5s %-25s %-15s %s\n" "No." "Category" "URLs Found" "OWASP Label"
        echo "  ─────────────────────────────────────────────────────────────"
        printf "  %-5s %-25s %-15s %s\n" "1"  "sqli"           "${cat_counts[sqli]:-0}"           "A03:2021 – Injection (SQL)"
        printf "  %-5s %-25s %-15s %s\n" "2"  "xss"            "${cat_counts[xss]:-0}"            "A03:2021 – Injection (XSS)"
        printf "  %-5s %-25s %-15s %s\n" "3"  "auth"           "${cat_counts[auth]:-0}"           "A07:2021 – Authentication Failures"
        printf "  %-5s %-25s %-15s %s\n" "4"  "access_control" "${cat_counts[access_control]:-0}" "A01:2021 – Broken Access Control"
        printf "  %-5s %-25s %-15s %s\n" "5"  "csrf"           "${cat_counts[csrf]:-0}"           "A01:2021 – CSRF"
        printf "  %-5s %-25s %-15s %s\n" "6"  "misconfig"      "${cat_counts[misconfig]:-0}"      "A05:2021 – Security Misconfiguration"
        printf "  %-5s %-25s %-15s %s\n" "7"  "data_exposure"  "${cat_counts[data_exposure]:-0}"  "A02:2021 – Data Exposure"
        printf "  %-5s %-25s %-15s %s\n" "8"  "file_inclusion" "${cat_counts[file_inclusion]:-0}" "A03:2021 – File Inclusion"
        printf "  %-5s %-25s %-15s %s\n" "9"  "open_redirect"  "${cat_counts[open_redirect]:-0}"  "A10:2021 – Open Redirect / SSRF"
        printf "  %-5s %-25s %-15s %s\n" "10" "misc"           "${cat_counts[misc]:-0}"           "Miscellaneous"
        echo ""
        echo "──────────────────────────────────────────────────────────────────"
        echo "  OUTPUT FILES"
        echo "──────────────────────────────────────────────────────────────────"
        for cat in sqli xss auth access_control csrf misconfig data_exposure file_inclusion open_redirect misc; do
            printf "  %-30s → %s\n" "${cat}.txt" "$results_dir/${cat}.txt"
        done
        echo "  ─────────────────────────────────────────────────────────────"
        printf "  %-30s → %s\n" "summary.txt" "$summary_file"
        printf "  %-30s → %s\n" "all_urls.txt" "$results_dir/all_urls.txt"
        printf "  %-30s → %s\n" "alive_urls.txt" "$results_dir/alive_urls.txt"
        printf "  %-30s → %s\n" "subdomains.txt" "$results_dir/subdomains.txt"
        echo ""
        echo "──────────────────────────────────────────────────────────────────"
        echo "  LEGAL DISCLAIMER"
        echo "──────────────────────────────────────────────────────────────────"
        echo "  This scan was conducted for authorized security testing only."
        echo "  Unauthorized use of this tool against systems you do not own"
        echo "  or have explicit permission to test is illegal and unethical."
        echo ""
        echo "  OWASP Mapper v1.0 | Author: banghub"
        echo "══════════════════════════════════════════════════════════════════"
    } > "$summary_file"

    log_success "Summary saved → ${BOLD}$summary_file${RESET}"
}

# ── Print Final Report to Terminal ────────────────────────────────────────────
print_final_report() {
    local domain="$1"
    local results_dir="$2"

    echo ""
    echo -e "  ${DIM}$(printf '═%.0s' {1..80})${RESET}"
    echo -e "  ${BOLD}${GREEN}✓ SCAN COMPLETE${RESET}"
    echo -e "  ${DIM}$(printf '═%.0s' {1..80})${RESET}"
    echo ""
    echo -e "  ${BOLD}Target:${RESET}      ${CYAN}$domain${RESET}"
    echo -e "  ${BOLD}Results:${RESET}     ${CYAN}$results_dir${RESET}"
    echo ""
    echo -e "  ${BOLD}${CYAN}Output Files:${RESET}"
    echo ""

    local categories=(sqli xss auth access_control csrf misconfig data_exposure file_inclusion open_redirect misc)
    local colors=("${RED}" "${YELLOW}" "${CYAN}" "${MAGENTA}" "${BLUE}" "${YELLOW}" "${RED}" "${CYAN}" "${GREEN}" "${DIM}")

    local i=0
    for cat in "${categories[@]}"; do
        local cat_file="$results_dir/${cat}.txt"
        local count
        count=$(count_valid_lines "$cat_file")
        local color="${colors[$i]:-$RESET}"

        if [[ "$count" -gt 0 ]]; then
            printf "  ${color}%4d${RESET}  %-25s → %s\n" "$count" "$cat.txt" "$cat_file"
        else
            printf "  ${DIM}%4d  %-25s → %s${RESET}\n" "0" "$cat.txt" "$cat_file"
        fi
        ((i++)) || true
    done

    echo ""
    echo -e "  ${DIM}$(printf '─%.0s' {1..80})${RESET}"
    echo -e "  ${BOLD}Summary:${RESET}     ${CYAN}$results_dir/summary.txt${RESET}"
    echo ""
    echo -e "  ${YELLOW}[!]${RESET} ${BOLD}For authorized security testing only.${RESET}"
    echo -e "  ${DIM}OWASP Mapper v1.0 | Author: banghub${RESET}"
    echo ""
}
