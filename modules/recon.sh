#!/usr/bin/env bash
# =============================================================================
# recon.sh - Subdomain enumeration using subfinder
# =============================================================================

# ── Run Recon ─────────────────────────────────────────────────────────────────
# Args: domain, do_subdomain (y/n), results_dir
run_recon() {
    local domain="$1"
    local do_subdomain="$2"
    local results_dir="$3"
    local subdomains_file="$results_dir/subdomains.txt"

    print_section "RECON — SUBDOMAIN ENUMERATION"

    # Always write the main domain as baseline
    echo "$domain" > "$subdomains_file"

    # Auto-skip for local/internal targets
    if [[ "${TARGET_TYPE:-remote}" == "local" ]]; then
        log_info "Local target — subdomain enumeration not applicable."
        return 0
    fi

    if [[ "$do_subdomain" != "y" ]]; then
        log_info "Subdomain enumeration skipped. Using main domain: $domain"
        return 0
    fi
    # Check if subfinder is available
    if ! is_tool_installed "subfinder"; then
        log_warn "subfinder is not installed. Skipping subdomain enumeration."
        log_info "Using main domain only: $domain"
        return 0
    fi

    log_step "Running subfinder on: ${BOLD}$domain${RESET}"
    log_info "This may take a few minutes depending on the target..."
    echo ""

    local tmp_subs="$results_dir/.tmp_subdomains.txt"

    # Run subfinder with silent output and timeout
    if timeout 300 subfinder \
        -d "$domain" \
        -o "$tmp_subs" \
        -silent \
        -all \
        2>/dev/null; then

        if [[ -s "$tmp_subs" ]]; then
            # Merge main domain + found subdomains, deduplicate
            {
                echo "$domain"
                cat "$tmp_subs"
            } | sort -u > "$subdomains_file"

            local count
            count=$(wc -l < "$subdomains_file")
            log_success "Found ${BOLD}${count}${RESET} subdomains (including root domain)."
            
            # Show first 10 results as preview
            echo ""
            log_info "Preview (first 10):"
            head -10 "$subdomains_file" | while read -r sub; do
                log_found "$sub"
            done

            if [[ $count -gt 10 ]]; then
                log_info "... and $((count - 10)) more. See: $subdomains_file"
            fi
        else
            log_warn "subfinder returned no results. Using main domain only."
            echo "$domain" > "$subdomains_file"
        fi
    else
        local exit_code=$?
        if [[ $exit_code -eq 124 ]]; then
            log_warn "subfinder timed out after 5 minutes. Using partial results."
        else
            log_warn "subfinder encountered an issue (exit: $exit_code). Using main domain."
        fi

        # If partial results exist, use them
        if [[ -s "$tmp_subs" ]]; then
            {
                echo "$domain"
                cat "$tmp_subs"
            } | sort -u > "$subdomains_file"
            local count
            count=$(wc -l < "$subdomains_file")
            log_info "Partial results saved: ${count} subdomains."
        fi
    fi

    # Cleanup temp file
    rm -f "$tmp_subs"

    echo ""
    log_done "Recon complete → $subdomains_file"
}
