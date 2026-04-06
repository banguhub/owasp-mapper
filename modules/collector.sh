#!/usr/bin/env bash
# =============================================================================
# collector.sh - URL collection, deduplication, filtering, and alive check
# =============================================================================

# ── Static File Extensions to Filter Out ─────────────────────────────────────
STATIC_EXTENSIONS="jpg|jpeg|png|gif|svg|ico|webp|bmp|tiff|mp4|mp3|wav|ogg|avi|mov|wmv|css|woff|woff2|ttf|eot|otf|map|pdf|zip|tar|gz|7z|rar|exe|dmg|pkg|deb|rpm"

# ── Local Target Crawler ──────────────────────────────────────────────────────
# Simple recursive curl-based spider for localhost/internal targets
# Follows links up to a configurable depth
crawl_local_target() {
    local base_url="$1"
    local output_file="$2"
    local max_depth="${3:-3}"
    local max_urls="${4:-500}"

    log_info "  Starting local crawler on: $base_url"
    log_info "  Max depth: $max_depth | Max URLs: $max_urls"

    local visited_file
    visited_file=$(mktemp)
    local queue_file
    queue_file=$(mktemp)
    local found_file
    found_file=$(mktemp)

    # Seed the queue with base URL
    echo "$base_url" > "$queue_file"
    echo "$base_url" > "$visited_file"

    local depth=0
    local total_found=0

    while [[ $depth -lt $max_depth && -s "$queue_file" ]]; do
        ((depth++)) || true
        local next_queue
        next_queue=$(mktemp)

        log_info "  Depth $depth — crawling $(wc -l < "$queue_file") URL(s)..."

        while IFS= read -r url; do
            [[ -z "$url" ]] && continue

            # Fetch page and extract links
            local page_content
            page_content=$(timeout 10 curl -sk \
                --max-time 10 \
                --connect-timeout 5 \
                -A "Mozilla/5.0 (compatible; OWASPMapper/1.0)" \
                -L \
                --max-redirs 3 \
                "$url" 2>/dev/null || true)

            [[ -z "$page_content" ]] && continue

            # Record this URL as found
            echo "$url" >> "$found_file"
            ((total_found++)) || true

            # Stop if we've hit max URLs
            if (( total_found >= max_urls )); then
                log_warn "  Max URL limit ($max_urls) reached. Stopping crawler."
                break 2
            fi

            # Extract all href and src links from page
            local links
            links=$(echo "$page_content" | \
                grep -oiE '(href|src|action|data-url|data-href)=["\x27][^"'\''> ]+' | \
                sed -E 's/^(href|src|action|data-url|data-href)=["\x27]//' | \
                sed "s/[\"']$//" | \
                grep -vE '^(#|javascript:|mailto:|tel:|data:)' | \
                while read -r link; do
                    # Normalize relative URLs to absolute
                    if [[ "$link" =~ ^https?:// ]]; then
                        echo "$link"
                    elif [[ "$link" =~ ^// ]]; then
                        local scheme="${base_url%%:*}"
                        echo "${scheme}:${link}"
                    elif [[ "$link" =~ ^/ ]]; then
                        # Absolute path — prepend base host
                        local base_host
                        base_host=$(echo "$base_url" | grep -oE 'https?://[^/]+')
                        echo "${base_host}${link}"
                    else
                        # Relative path — prepend current URL's directory
                        local base_dir
                        base_dir=$(echo "$url" | sed 's|/[^/]*$|/|')
                        echo "${base_dir}${link}"
                    fi
                done | \
                # Only keep URLs on same host
                grep -iF "$(echo "$base_url" | grep -oE 'https?://[^/]+')" | \
                sort -u || true)

            # Add new unvisited links to next queue
            while IFS= read -r link; do
                [[ -z "$link" ]] && continue
                if ! grep -qxF "$link" "$visited_file" 2>/dev/null; then
                    echo "$link" >> "$visited_file"
                    echo "$link" >> "$next_queue"
                    echo "$link" >> "$found_file"
                    ((total_found++)) || true
                fi
            done <<< "$links"

        done < "$queue_file"

        mv "$next_queue" "$queue_file"
    done

    # Write found URLs to output
    if [[ -s "$found_file" ]]; then
        sort -u "$found_file" >> "$output_file"
        log_success "  Local crawler found: ${BOLD}$(wc -l < "$found_file")${RESET} URLs"
    else
        log_warn "  Local crawler found no URLs. Is the target running?"
    fi

    # Also do a quick form/parameter discovery pass
    discover_local_params "$base_url" "$output_file"

    # Cleanup
    rm -f "$visited_file" "$queue_file" "$found_file"
}

# ── Local Parameter Discovery ─────────────────────────────────────────────────
# Tries common paths and parameter patterns on the local target
discover_local_params() {
    local base_url="$1"
    local output_file="$2"

    log_info "  Running common path probe on: $base_url"

    # Common web app paths to probe
    local common_paths=(
        "/"
        "/login" "/logout" "/signin" "/signup" "/register"
        "/admin" "/admin/login" "/admin/dashboard"
        "/dashboard" "/profile" "/account" "/settings"
        "/api" "/api/v1" "/api/v2" "/api/users" "/api/login"
        "/search" "/query"
        "/upload" "/file" "/download"
        "/user" "/users" "/user/1" "/user/profile"
        "/product" "/products" "/product/1" "/item/1"
        "/order" "/orders" "/order/1"
        "/comment" "/comments" "/post" "/posts"
        "/news" "/blog" "/article/1"
        "/page" "/index.php" "/index.html"
        "/config" "/setup" "/install"
        "/.env" "/.git/HEAD" "/robots.txt" "/sitemap.xml"
        "/swagger" "/api-docs" "/graphql"
        "/actuator" "/actuator/health" "/metrics"
        "/debug" "/trace" "/phpinfo.php"
        "/wp-login.php" "/wp-admin"
        "/?id=1" "/?q=test" "/?search=test" "/?page=1"
        "/?file=test" "/?redirect=test" "/?url=test"
        "/?user=admin" "/?debug=1" "/?cmd=id"
    )

    local found_count=0
    for path in "${common_paths[@]}"; do
        local full_url="${base_url%/}${path}"
        local status
        status=$(timeout 5 curl -sk \
            --max-time 5 \
            --connect-timeout 3 \
            -A "Mozilla/5.0 (compatible; OWASPMapper/1.0)" \
            -o /dev/null \
            -w "%{http_code}" \
            "$full_url" 2>/dev/null || echo "000")

        # Record any URL that responds (not 000 timeout)
        if [[ "$status" != "000" ]]; then
            echo "$full_url" >> "$output_file"
            ((found_count++)) || true
        fi
    done

    log_info "  Common path probe: ${BOLD}${found_count}${RESET} responsive paths found"
}

# ── Build Base URL from Target ────────────────────────────────────────────────
build_base_url() {
    local target="$1"
    local host="${target%%:*}"
    local port=""

    if [[ "$target" =~ :[0-9]+$ ]]; then
        port="${target##*:}"
    fi

    # Determine scheme by probing
    local scheme="http"
    if [[ -n "$port" ]]; then
        # HTTPS ports hint
        if [[ "$port" == "443" || "$port" == "8443" ]]; then
            scheme="https"
        fi
        # Try HTTPS first, fall back to HTTP
        if timeout 5 curl -sk --max-time 5 "https://${target}/" -o /dev/null 2>/dev/null; then
            scheme="https"
        fi
        echo "${scheme}://${target}"
    else
        echo "${scheme}://${target}"
    fi
}

# ── Collect URLs for a Single Domain ─────────────────────────────────────────
collect_urls_for_domain() {
    local domain="$1"
    local output_file="$2"
    local target_type="${TARGET_TYPE:-remote}"

    local collected=false

    # ── LOCAL TARGET: Use crawler, skip gau/waybackurls ──────────────────────
    if [[ "$target_type" == "local" ]]; then
        log_info "  Local target detected — using built-in crawler"

        local base_url
        base_url=$(build_base_url "$domain")
        log_info "  Base URL resolved to: $base_url"

        # Check if target is reachable first
        local status
        status=$(timeout 5 curl -sk --max-time 5 --connect-timeout 4 \
            -o /dev/null -w "%{http_code}" "$base_url" 2>/dev/null || echo "000")

        if [[ "$status" == "000" ]]; then
            log_error "  Cannot reach $base_url — is the application running?"
            log_warn "  Make sure your app is started on the correct port."
            return 1
        fi

        log_success "  Target is UP (HTTP $status)"
        crawl_local_target "$base_url" "$output_file"
        collected=true
        return 0
    fi

    # ── REMOTE TARGET: Use gau / waybackurls / CDX API ───────────────────────

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
    local target_type="${TARGET_TYPE:-remote}"

    # For local targets: use curl-based alive check (faster, no httpx needed)
    if [[ "$target_type" == "local" ]]; then
        log_info "Local target — using curl for alive check..."
        curl_alive_check "$input_file" "$output_file"
        return 0
    fi

    # Remote target: prefer httpx
    if ! is_tool_installed "httpx"; then
        log_warn "httpx is not installed. Falling back to curl alive check."
        curl_alive_check "$input_file" "$output_file"
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
            cp "$input_file" "$output_file"
            log_info "Using all collected URLs as fallback."
        fi
    else
        log_warn "httpx encountered an issue or timed out."
        log_info "Using all collected URLs as fallback."
        cp "$input_file" "$output_file"
    fi
}

# ── Curl-based Alive Check (for local/fallback) ───────────────────────────────
curl_alive_check() {
    local input_file="$1"
    local output_file="$2"

    local total
    total=$(wc -l < "$input_file" 2>/dev/null || echo 0)
    log_info "Checking ${BOLD}${total}${RESET} URLs with curl (parallel)..."

    local alive=0
    > "$output_file"

    # Process in parallel batches of 20
    local batch_size=20
    local idx=0

    while IFS= read -r url; do
        [[ -z "$url" ]] && continue

        # Run curl checks in background (batched)
        {
            local code
            code=$(timeout 8 curl -sk \
                --max-time 8 \
                --connect-timeout 4 \
                -o /dev/null \
                -w "%{http_code}" \
                -A "Mozilla/5.0 (compatible; OWASPMapper/1.0)" \
                "$url" 2>/dev/null || echo "000")

            # Keep URLs that respond (any code except 000 = timeout/error)
            if [[ "$code" != "000" ]]; then
                echo "$url"
            fi
        } &

        ((idx++)) || true

        # Wait for batch to complete
        if (( idx % batch_size == 0 )); then
            wait
            printf "\r  ${CYAN}[%d/%d]${RESET} URLs checked..." "$idx" "$total"
        fi
    done < "$input_file"

    wait  # Wait for remaining background jobs
    echo ""

    # Collect results — re-check which ones actually responded
    # (background jobs wrote to stdout, we need to capture differently)
    # Use a temp approach: recheck the deduplicated list quickly
    while IFS= read -r url; do
        [[ -z "$url" ]] && continue
        local code
        code=$(timeout 8 curl -sk --max-time 8 --connect-timeout 4 \
            -o /dev/null -w "%{http_code}" \
            -A "Mozilla/5.0" "$url" 2>/dev/null || echo "000")
        if [[ "$code" != "000" ]]; then
            echo "$url" >> "$output_file"
            ((alive++)) || true
        fi
    done < <(sort -u "$input_file")

    log_success "Alive URLs: ${BOLD}${alive}${RESET} / ${total}"

    # Fallback if nothing alive
    if [[ ! -s "$output_file" ]]; then
        log_warn "No URLs confirmed alive. Using full list as fallback."
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
