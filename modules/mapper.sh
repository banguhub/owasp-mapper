#!/usr/bin/env bash
# =============================================================================
# mapper.sh - OWASP Top 10 URL mapping using keyword/parameter-based logic
# =============================================================================

# ═══════════════════════════════════════════════════════════════════════════════
# OWASP CATEGORY DEFINITIONS
# Each category has: name, number, and grep patterns (extended regex)
# ═══════════════════════════════════════════════════════════════════════════════

# ── Category 1: SQL Injection ──────────────────────────────────────────────────
PATTERN_SQLI='[?&](id|user_id|item_id|product_id|cat|category_id|order_id|page_id|article_id|post_id|record|row|entry|member_id|account_id|num|no|ref|qid|pid|cid|oid|fid|tid|rid|uid|idx|serial|key)=[^&]*|[?&](search|query|q|s|keyword|kw|term)=[^&]*&.*id=|/[0-9]+(/|$|\?)|select|insert|update|delete|union|where|from|order.by'

# ── Category 2: XSS ───────────────────────────────────────────────────────────
PATTERN_XSS='[?&](q|s|search|query|keyword|kw|term|name|msg|message|comment|content|text|input|data|value|val|str|html|body|title|desc|description|subject|email|url|link|ref|next|return|redirect|callback|jsonp|p|r|t|v|a|b|c|output|result|response|note|user|username|lang|language|locale|theme|color|tag|label|summary|info|detail|feedback|review|reply|author|first|last|full)=[^&]*'

# ── Category 3: Authentication ─────────────────────────────────────────────────
PATTERN_AUTH='/(login|logout|signin|signout|signup|register|auth|authenticate|session|password|passwd|pwd|reset|forgot|recover|account|profile|dashboard|admin|administrator|user|users|member|members|portal|panel|cp|controlpanel|wp-login|wp-admin|phpmyadmin|console|access|token|oauth|sso|saml|2fa|mfa|otp|verify|verification|activate|activation)(/|$|\?)'

# ── Category 4: Broken Access Control ─────────────────────────────────────────
PATTERN_ACCESS_CONTROL='[?&](user_id|uid|account|acct|member|id|role|perm|permission|access|priv|privilege|admin|level|group|scope|type|mode|view|edit|delete|update|create|action|do|cmd|command|op|operation|func|function|method|task|step|page|section|module|service|endpoint)=[^&]*|/(admin|superuser|root|manager|operator|staff|internal|private|restricted|secure|confidential|hidden|backdoor|test|debug|dev|staging)(/|$|\?)'

# ── Category 5: CSRF ──────────────────────────────────────────────────────────
PATTERN_CSRF='/(update|edit|modify|change|save|submit|send|post|create|add|insert|delete|remove|transfer|purchase|buy|order|confirm|approve|reject|vote|like|follow|unfollow|subscribe|unsubscribe|upload|import|export|checkout|payment|pay|withdraw|deposit|reset|disable|enable|toggle|set|put|patch)(/|$|\?)|[?&](action|do|cmd|operation|method|task|step|process)=(update|edit|delete|create|change|save|submit|send|confirm|approve|modify|add|remove)'

# ── Category 6: Security Misconfiguration ─────────────────────────────────────
PATTERN_MISCONFIG='/(\.git|\.env|\.htaccess|\.htpasswd|config|configuration|settings|setup|install|installer|backup|bak|old|tmp|temp|test|debug|trace|info|phpinfo|server-status|server-info|adminer|phpmyadmin|wp-config|web\.config|appsettings|application\.properties|Dockerfile|docker-compose|\.DS_Store|robots\.txt|sitemap\.xml|crossdomain\.xml|clientaccesspolicy\.xml|swagger|api-docs|openapi|graphql|graphiql|\_debugbar|telescope|horizon|actuator|metrics|health|status|ping|version|changelog|readme|readme\.md|license)(/|$|\?)|[?&](debug|trace|verbose|log|logging|level|env|environment|mode|version|info|config|test)=[^&]*'

# ── Category 7: Sensitive Data Exposure ───────────────────────────────────────
PATTERN_DATA_EXPOSURE='/(api|api/v[0-9]|rest|graphql|ws|webhook|export|download|report|reports|log|logs|backup|dump|extract|data|dataset|feed|rss|json|xml|csv|xls|xlsx|pdf|invoice|receipt|statement|bill|document|docs|file|files|attachment|attachment|media|upload|uploads|private|secret|key|keys|token|tokens|credentials|certificate|cert|ssl|tls|pgp|gpg|ssh|aws|gcp|azure|s3|bucket|blob|storage|vault|keystore|wallet|payment|credit|card|ssn|dob|passport|license|pii|phi|hipaa)(/|$|\?)|[?&](token|key|secret|api_key|apikey|auth_token|access_token|refresh_token|private_key|password|passwd|pwd|credential|cert|ssn|dob|email|phone|address|card|cc|cvv|pin)=[^&]*'

# ── Category 8: File Inclusion ─────────────────────────────────────────────────
PATTERN_FILE_INCLUSION='[?&](file|filename|filepath|path|dir|directory|folder|include|page|template|view|load|read|fetch|src|source|require|doc|document|root|base|url|link|location|module|lang|language|locale|theme|skin|style|layout|section|content|component|widget|plugin|ext|type|format|mime|resource|res|data)=[^&]*(\.\.|/|\\\\|http|ftp|file:|php://|data:|expect:|zip://|phar://|glob://|input://|zlib://|ogg://)|/(lfi|rfi|file|include|page|template)(/|$|\?)'

# ── Category 9: Open Redirect ──────────────────────────────────────────────────
PATTERN_OPEN_REDIRECT='[?&](redirect|redirect_uri|redirect_url|redirectUrl|redirectUri|return|return_url|returnUrl|returnTo|return_to|next|next_url|nextUrl|goto|go|url|link|out|outurl|forward|forwardurl|destination|dest|target|targeturl|ref|referer|referrer|callback|callbackUrl|callbackUri|successUrl|success_url|failureUrl|failure_url|cancelUrl|cancel_url|continue|continueUrl|state|location|href|src|jump|navigate|nav|follow|redir|r|u|l|to|from|exit|bounce|away|external)=[^&]*'

# ── Category 10: Miscellaneous ──────────────────────────────────────────────────
PATTERN_MISC='[?&](cmd|command|exec|execute|run|shell|bash|sh|eval|code|script|payload|inject|exploit|hack|pwn|xss|sqli|lfi|rfi|ssrf|ssti|rce|xxe|dos|ddos|attack|vuln|vulnerability|bug|flaw|exploit|poc|payload|bypass|evade|obfuscate|encode|decode|base64|hex|rot13|cipher|encrypt|decrypt|hash|crypt|random|seed|salt|nonce|iv|mode|format|serialize|deserialize|pickle|marshal|yaml|json|xml|soap|wsdl|rpc|grpc|websocket|ws|socket|io|stream|pipe|fork|spawn|child|parent|process|pid|uid|gid|user|group|root|admin|super|privilege|escalate|elevate|impersonate|token|jwt|session|cookie|csrf|xsrf|cors|csp|cve|nvd|owasp|pentest|ctf|flag|secret|hidden|undocumented|internal|debug|test|dev|staging|prod|production|sandbox|demo|beta|alpha|preview|wip)=[^&]*|/(__debug|_profiler|_debugbar|telescope|horizon|actuator|trace|debug|dev|staging|internal|test|qa|uat|sandbox|preview|beta|admin|super|root|api/test|api/debug|api/internal)(/|$|\?)'

# ═══════════════════════════════════════════════════════════════════════════════
# CATEGORY INDEX
# ═══════════════════════════════════════════════════════════════════════════════

# Map number → category name
get_category_name() {
    case "$1" in
        1)  echo "sqli" ;;
        2)  echo "xss" ;;
        3)  echo "auth" ;;
        4)  echo "access_control" ;;
        5)  echo "csrf" ;;
        6)  echo "misconfig" ;;
        7)  echo "data_exposure" ;;
        8)  echo "file_inclusion" ;;
        9)  echo "open_redirect" ;;
        10) echo "misc" ;;
        *)  echo "" ;;
    esac
}

# Map category name → pattern variable
get_category_pattern() {
    case "$1" in
        sqli)           echo "$PATTERN_SQLI" ;;
        xss)            echo "$PATTERN_XSS" ;;
        auth)           echo "$PATTERN_AUTH" ;;
        access_control) echo "$PATTERN_ACCESS_CONTROL" ;;
        csrf)           echo "$PATTERN_CSRF" ;;
        misconfig)      echo "$PATTERN_MISCONFIG" ;;
        data_exposure)  echo "$PATTERN_DATA_EXPOSURE" ;;
        file_inclusion) echo "$PATTERN_FILE_INCLUSION" ;;
        open_redirect)  echo "$PATTERN_OPEN_REDIRECT" ;;
        misc)           echo "$PATTERN_MISC" ;;
        *)              echo "" ;;
    esac
}

# Map category name → OWASP Top 10 label
get_category_label() {
    case "$1" in
        sqli)           echo "A03:2021 – Injection (SQL)" ;;
        xss)            echo "A03:2021 – Injection (XSS)" ;;
        auth)           echo "A07:2021 – Identification & Authentication Failures" ;;
        access_control) echo "A01:2021 – Broken Access Control" ;;
        csrf)           echo "A01:2021 – Cross-Site Request Forgery" ;;
        misconfig)      echo "A05:2021 – Security Misconfiguration" ;;
        data_exposure)  echo "A02:2021 – Cryptographic/Data Exposure Failures" ;;
        file_inclusion) echo "A03:2021 – Injection (File Inclusion)" ;;
        open_redirect)  echo "A10:2021 – Server-Side Request Forgery / Open Redirect" ;;
        misc)           echo "Miscellaneous / Uncategorized" ;;
        *)              echo "Unknown" ;;
    esac
}

# All category names in order
ALL_CATEGORIES=(sqli xss auth access_control csrf misconfig data_exposure file_inclusion open_redirect misc)

# ── Parse Selected Categories ─────────────────────────────────────────────────
# Input: "all" or "1,3,5" or "sqli,xss"
# Output: array of category names
parse_selected_categories() {
    local input="$1"
    local -n result_ref=$2  # nameref to output array

    result_ref=()

    if [[ "${input,,}" == "all" || -z "$input" ]]; then
        result_ref=("${ALL_CATEGORIES[@]}")
        return 0
    fi

    # Split by comma
    IFS=',' read -ra parts <<< "$input"
    for part in "${parts[@]}"; do
        part="${part// /}"  # strip spaces
        local cat_name=""

        # Check if it's a number
        if [[ "$part" =~ ^[0-9]+$ ]]; then
            cat_name="$(get_category_name "$part")"
            if [[ -z "$cat_name" ]]; then
                log_warn "Unknown category number: $part (valid: 1-10). Skipping."
                continue
            fi
        else
            # Check if it's a valid name
            local valid=false
            for c in "${ALL_CATEGORIES[@]}"; do
                if [[ "$c" == "$part" ]]; then
                    valid=true
                    cat_name="$part"
                    break
                fi
            done
            if [[ "$valid" == false ]]; then
                log_warn "Unknown category name: '$part'. Skipping."
                continue
            fi
        fi

        result_ref+=("$cat_name")
    done

    if [[ ${#result_ref[@]} -eq 0 ]]; then
        log_warn "No valid categories selected. Defaulting to all."
        result_ref=("${ALL_CATEGORIES[@]}")
    fi
}

# ── Map a Single Category ─────────────────────────────────────────────────────
map_category() {
    local category="$1"
    local urls_file="$2"
    local output_file="$3"

    local pattern
    pattern="$(get_category_pattern "$category")"
    local label
    label="$(get_category_label "$category")"

    if [[ -z "$pattern" ]]; then
        log_warn "No pattern defined for category: $category"
        echo "No targets found" > "$output_file"
        return 0
    fi

    if [[ ! -s "$urls_file" ]]; then
        echo "No targets found" > "$output_file"
        return 0
    fi

    # Write header to file
    {
        echo "# ============================================================"
        echo "# OWASP Mapper v1.0 | Category: ${category^^}"
        echo "# Label: $label"
        echo "# Generated: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "# ============================================================"
        echo ""
    } > "$output_file"

    # Grep matching URLs (case-insensitive)
    local matches
    matches=$(grep -iE "$pattern" "$urls_file" 2>/dev/null | sort -u || true)

    if [[ -n "$matches" ]]; then
        echo "$matches" >> "$output_file"
        local count
        count=$(echo "$matches" | wc -l)
        echo -e "    ${GREEN}✓${RESET} ${BOLD}${category}${RESET} ${DIM}→${RESET} ${GREEN}${count} URL(s)${RESET} ${DIM}[${label}]${RESET}"
    else
        echo "No targets found" >> "$output_file"
        echo -e "    ${YELLOW}○${RESET} ${BOLD}${category}${RESET} ${DIM}→${RESET} ${YELLOW}0 URL(s)${RESET} ${DIM}[${label}]${RESET}"
    fi
}

# ── Run Full Mapper ───────────────────────────────────────────────────────────
# Args: alive_urls_file, results_dir, selected_categories_string
run_mapper() {
    local urls_file="$1"
    local results_dir="$2"
    local selected_str="$3"

    print_section "OWASP TOP 10 MAPPING"

    # Parse selected categories
    declare -a selected_cats
    parse_selected_categories "$selected_str" selected_cats

    log_info "Mapping ${BOLD}${#selected_cats[@]}${RESET} category/categories against collected URLs..."
    echo ""

    if [[ ! -s "$urls_file" ]]; then
        log_warn "No alive URLs to map. Generating empty category files."
    fi

    # Map each selected category
    for cat in "${selected_cats[@]}"; do
        local output_file="$results_dir/${cat}.txt"
        map_category "$cat" "$urls_file" "$output_file"
    done

    # Generate empty files for unselected categories (so they're not missing)
    for cat in "${ALL_CATEGORIES[@]}"; do
        local output_file="$results_dir/${cat}.txt"
        if [[ ! -f "$output_file" ]]; then
            {
                echo "# ============================================================"
                echo "# OWASP Mapper v1.0 | Category: ${cat^^}"
                echo "# Status: Not selected in this scan"
                echo "# Generated: $(date '+%Y-%m-%d %H:%M:%S')"
                echo "# ============================================================"
                echo ""
                echo "Category not selected for this scan."
            } > "$output_file"
        fi
    done

    echo ""
    log_done "Mapping complete."
}
