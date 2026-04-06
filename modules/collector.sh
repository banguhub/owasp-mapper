#!/usr/bin/env bash
# =============================================================================
# collector.sh - URL collection, deduplication, filtering, and alive check
# =============================================================================

# ── Static File Extensions to Filter Out ─────────────────────────────────────
STATIC_EXTENSIONS="jpg|jpeg|png|gif|svg|ico|webp|bmp|tiff|mp4|mp3|wav|ogg|avi|mov|wmv|css|woff|woff2|ttf|eot|otf|map|pdf|zip|tar|gz|7z|rar|exe|dmg|pkg|deb|rpm"

# ── Collect URLs for a Single Domain ─────────────────────────────────────────
collect_urls_for_domain() {
    local domain="$1"
    local output_file="$2"

    local collected=false

    # Try gau first
    if is_tool_installed "gau"; then
        log_info "  gau → $domain"
        local gau_out
        gau_out=$(timeout 120 gau "$domain" --threads 5 2>/dev/null || true)
        if [[ -n "$gau_out" ]]; then
            echo "$gau_out" >> "$output_file"
            collected=true
        fi
    fi

    # Try waybackurls as fallback or supplement
    if is_tool_installed "waybackurls"; then
        log_info "  waybackurls → $domain"
        local wb_out
        wb_out=$(echo "$domain" | timeout 120 waybackurls 2>/dev/null || true)
        if [[ -n "$wb_out" ]]; then
            echo "$wb_out" >> "$output_file"
            collected=true
        fi
    fi

    # If neither tool is available, try curl + Wayback API directly
    if ! is_tool_installed "gau" && ! is_tool_installed "waybackurls"; then
        if is_tool_installed "curl"; then
            log_info "  Fallback: Wayback CDX API via curl → $domain"
            local cdx_url="http://web.archive.org/cdx/search/cdx?url=*.${domain}/*&output=text&fl=original&collapse=urlkey&limit=5000"
            local cdx_out
            cdx_out=$(timeout 60 curl -s "$cdx_url" 2>/dev/null || true)
            if [[ -n "$cdx_out" ]]; then
                echo "$cdx_out" >> "$output_file"
                collected=true
            fi
        fi
    fi

    if [[ "$collected" == false ]]; then
        log_warn "  No URL collection tool available for: $domain"
    fi
}

# ── Filter Static Files ───────────────────────────────────────────────────────
filter_static_files() {
    local input="$1"
    local output="$2"

    grep -viE "\.(${STATIC_EXTENSIONS})(\?.*)?$" "$input" > "$output" 2>/dev/null || true
}

# ── Remove Duplicate URLs ─────────────────────────────────────────────────────
dedup_urls() {
    local file="$1"
    local tmp="$file.tmp"
    sort -u "$file" > "$tmp" && mv "$tmp" "$file"
}

# ── Run httpx Alive Check ─────────────────────────────────────────────────────
run_httpx_check() {
    local input_file="$1"
    local output_file="$2"

    if ! is_tool_installed "httpx"; then
        log_warn "httpx is not installed. Skipping alive check."
        log_info "All collected URLs will be used (no alive filtering)."
        cp "$input_file" "$output_file"
        return 0
    fi

    local total
    total=$(wc -l < "$input_file" 2>/dev/null || echo 0)

    log_step "Running alive check with httpx on ${BOLD}${total}${RESET} URLs..."
    log_info "This may take a while for large URL sets..."
    echo ""

    if timeout 600 httpx \
        -l "$input_file" \
        -o "$output_file" \
        -silent \
        -threads 50 \
        -timeout 10 \
        -follow-redirects \
        2>/dev/null; then

        if [[ -s "$output_file" ]]; then
            local alive
            alive=$(wc -l < "$output_file")
            log_success "Alive URLs: ${BOLD}${alive}${RESET} / ${total}"
        else
            log_warn "httpx returned no alive URLs."
            # Use all URLs as fallback
            cp "$input_file" "$output_file"
            log_info "Using all collected URLs as fallback."
        fi
    else
        log_warn "httpx encountered an issue or timed out."
        log_info "Using all collected URLs as fallback."
        cp "$input_file" "$output_file"
    fi
}

# ── Main Collector Orchestrator ───────────────────────────────────────────────
# Args: domain, do_subdomain, subdomains_file, results_dir
run_collector() {
    local domain="$1"
    local do_subdomain="$2"
    local subdomains_file="$3"
    local results_dir="$4"

    local raw_urls="$results_dir/.raw_urls.txt"
    local filtered_urls="$results_dir/.filtered_urls.txt"
    local all_urls_file="$results_dir/all_urls.txt"
    local alive_urls_file="$results_dir/alive_urls.txt"

    # Clean start
    > "$raw_urls"

    print_section "URL COLLECTION"

    # Determine which domains to collect from
    local domains_to_scan=()
    if [[ "$do_subdomain" == "y" && -s "$subdomains_file" ]]; then
        log_info "Collecting URLs from all subdomains..."
        while IFS= read -r subdomain; do
            [[ -n "$subdomain" ]] && domains_to_scan+=("$subdomain")
        done < "$subdomains_file"
    else
        domains_to_scan=("$domain")
    fi

    local domain_count="${#domains_to_scan[@]}"
    log_info "Scanning ${BOLD}${domain_count}${RESET} domain(s) for URLs..."
    echo ""

    local idx=0
    for d in "${domains_to_scan[@]}"; do
        ((idx++)) || true
        echo -ne "\r  ${CYAN}[${idx}/${domain_count}]${RESET} Fetching URLs from: ${BOLD}${d}${RESET}        "
        collect_urls_for_domain "$d" "$raw_urls"
    done
    echo ""  # newline after progress

    # Check if we got anything
    if [[ ! -s "$raw_urls" ]]; then
        log_warn "No URLs collected from any source."
        touch "$all_urls_file" "$alive_urls_file"
        return 0
    fi

    local raw_count
    raw_count=$(wc -l < "$raw_urls")
    log_info "Raw URLs collected: ${BOLD}${raw_count}${RESET}"

    # Step 1: Deduplication
    log_step "Deduplicating URLs..."
    dedup_urls "$raw_urls"
    local deduped_count
    deduped_count=$(wc -l < "$raw_urls")
    log_success "After dedup: ${BOLD}${deduped_count}${RESET} URLs"

    # Step 2: Filter static files
    log_step "Filtering static files (.jpg, .png, .css, etc.)..."
    filter_static_files "$raw_urls" "$filtered_urls"
    if [[ -s "$filtered_urls" ]]; then
        local filtered_count
        filtered_count=$(wc -l < "$filtered_urls")
        log_success "After filtering: ${BOLD}${filtered_count}${RESET} URLs remaining"
        cp "$filtered_urls" "$all_urls_file"
    else
        log_warn "All URLs were filtered as static. Using unfiltered set."
        cp "$raw_urls" "$all_urls_file"
    fi

    # Step 3: Alive check
    log_step "Running alive URL check..."
    run_httpx_check "$all_urls_file" "$alive_urls_file"

    # Cleanup temp files
    rm -f "$raw_urls" "$filtered_urls"

    local final_count
    final_count=$(wc -l < "$alive_urls_file" 2>/dev/null || echo 0)
    echo ""
    log_done "URL collection complete. ${BOLD}${final_count}${RESET} alive URLs ready for mapping."
}
