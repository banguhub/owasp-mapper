# OWASP Mapper v1.0

> **Web Application Penetration Testing Preparation Tool**  
> Author: banghub

```
  ██████╗ ██╗    ██╗ █████╗ ███████╗██████╗     ███╗   ███╗ █████╗ ██████╗ ██████╗ ███████╗██████╗ 
 ██╔═══██╗██║    ██║██╔══██╗██╔════╝██╔══██╗    ████╗ ████║██╔══██╗██╔══██╗██╔══██╗██╔════╝██╔══██╗
 ██║   ██║██║ █╗ ██║███████║███████╗██████╔╝    ██╔████╔██║███████║██████╔╝██████╔╝█████╗  ██████╔╝
 ██║   ██║██║███╗██║██╔══██║╚════██║██╔═══╝     ██║╚██╔╝██║██╔══██║██╔═══╝ ██╔═══╝ ██╔══╝  ██╔══██╗
 ╚██████╔╝╚███╔███╔╝██║  ██║███████║██║         ██║ ╚═╝ ██║██║  ██║██║     ██║     ███████╗██║  ██║
  ╚═════╝  ╚══╝╚══╝ ╚═╝  ╚═╝╚══════╝╚═╝         ╚═╝     ╚═╝╚═╝  ╚═╝╚═╝     ╚═╝     ╚══════╝╚═╝  ╚═╝
```

---

## ⚠️ Legal Disclaimer

> **This tool is for authorized security testing ONLY.**  
> Always obtain **written permission** from the system owner before conducting any penetration test.  
> Unauthorized use against systems you do not own or have explicit permission to test is **illegal** and may result in criminal prosecution.  
> The author assumes **no liability** for any misuse, damage, or legal consequences arising from the use of this tool.

---

## 📋 Features

- **OS Detection** — Runs only on Linux (Ubuntu / Kali / Debian)
- **Dependency Auto-Installer** — Detects and installs missing tools automatically
- **Subdomain Enumeration** — Uses `subfinder` to discover subdomains
- **URL Collection** — Fetches historical URLs via `gau` / `waybackurls`
- **Static File Filtering** — Removes images, fonts, CSS, JS, and other non-interactive assets
- **Alive URL Check** — Filters dead URLs using `httpx`
- **OWASP Top 10 Mapping** — Categorizes URLs using smart pattern matching:
  - SQL Injection (A03:2021)
  - Cross-Site Scripting (A03:2021)
  - Authentication Issues (A07:2021)
  - Broken Access Control (A01:2021)
  - CSRF (A01:2021)
  - Security Misconfiguration (A05:2021)
  - Sensitive Data Exposure (A02:2021)
  - File Inclusion (A03:2021)
  - Open Redirect / SSRF (A10:2021)
  - Miscellaneous
- **Selective Category Scanning** — Choose specific OWASP categories to map
- **Color-coded CLI** — Green/Red/Yellow output for easy reading
- **Timestamped Results** — Organized output per scan run
- **Summary Report** — Aggregated statistics in `summary.txt`
- **CLI Flags** — `--help`, `--auto-install`, `--only`

---

## 📁 Project Structure

```
owasp-mapper/
├── main.sh                   # Entry point — orchestrates the full scan
├── modules/
│   ├── colors.sh             # Terminal colors & logging helpers
│   ├── check_tools.sh        # Dependency detection
│   ├── installer.sh          # Automated tool installation (apt + go)
│   ├── recon.sh              # Subdomain enumeration (subfinder)
│   ├── collector.sh          # URL collection, dedup, filter, alive check
│   ├── mapper.sh             # OWASP Top 10 URL mapping
│   └── output.sh             # Results directory, summary, final report
├── results/                  # Auto-created scan output folder
│   └── <domain>_<timestamp>/
│       ├── subdomains.txt
│       ├── all_urls.txt
│       ├── alive_urls.txt
│       ├── sqli.txt
│       ├── xss.txt
│       ├── auth.txt
│       ├── access_control.txt
│       ├── csrf.txt
│       ├── misconfig.txt
│       ├── data_exposure.txt
│       ├── file_inclusion.txt
│       ├── open_redirect.txt
│       ├── misc.txt
│       └── summary.txt
└── README.md
```

---

## 🔧 Requirements

- **OS**: Linux (Ubuntu 20.04+, Kali Linux, Debian 10+)
- **Shell**: Bash 4.0+
- **Privileges**: sudo (for installing dependencies)
- **Internet**: Required for URL collection

### Tools Used

| Tool | Purpose | Install Method |
|------|---------|---------------|
| `subfinder` | Subdomain enumeration | `go install` |
| `gau` | URL collection from archives | `go install` |
| `waybackurls` | URL collection (fallback) | `go install` |
| `httpx` | Alive URL check | `go install` |
| `curl` | HTTP requests / CDX API fallback | `apt` |
| `jq` | JSON parsing | `apt` |

> **Note:** Go-based tools require Go 1.18+. If not installed, the tool will prompt you to install it.

---

## 🚀 Installation

### Step 1: Clone or Download

```bash
git clone https://github.com/banghub/owasp-mapper.git
cd owasp-mapper
```

### Step 2: Make executable

```bash
chmod +x main.sh
chmod +x modules/*.sh
```

### Step 3: Run

```bash
./main.sh
```

The tool will detect any missing dependencies and offer to install them automatically.

---

## 💻 Usage

### Interactive Mode (Recommended)

```bash
./main.sh
```

You will be guided through:
1. Sudo authentication
2. Dependency check & install
3. Target domain input
4. Subdomain enumeration option
5. OWASP category selection
6. Automated scan & mapping
7. Results output

---

### CLI Flags

#### Show Help
```bash
./main.sh --help
```

#### Auto-install all dependencies (non-interactive)
```bash
./main.sh --auto-install
```

#### Scan only specific categories
```bash
# By number
./main.sh --only 1,2,9

# By name
./main.sh --only sqli,xss,open_redirect

# Mixed
./main.sh --only sqli,2,open_redirect
```

#### Combined example
```bash
./main.sh --auto-install --only sqli,xss,auth
```

---

## 📊 Output

All results are saved to:
```
./results/<domain>_<YYYYMMDD_HHMMSS>/
```

| File | Contents |
|------|---------|
| `subdomains.txt` | Discovered subdomains |
| `all_urls.txt` | All collected & filtered URLs |
| `alive_urls.txt` | URLs that responded (alive) |
| `sqli.txt` | SQL injection candidate URLs |
| `xss.txt` | XSS candidate URLs |
| `auth.txt` | Authentication-related URLs |
| `access_control.txt` | Access control candidate URLs |
| `csrf.txt` | CSRF-prone URLs |
| `misconfig.txt` | Misconfiguration-related paths |
| `data_exposure.txt` | Sensitive data exposure candidates |
| `file_inclusion.txt` | File inclusion candidate URLs |
| `open_redirect.txt` | Open redirect candidate URLs |
| `misc.txt` | Miscellaneous interesting endpoints |
| `summary.txt` | Full scan statistics report |

### Example summary.txt

```
╔══════════════════════════════════════════════════════════════════╗
║              OWASP MAPPER v1.0 — SCAN SUMMARY                   ║
╚══════════════════════════════════════════════════════════════════╝

  Scan Date   : 2025-01-15 14:32:10 UTC
  Target      : example.com
  Results Dir : ./results/example.com_20250115_143210

  COLLECTION STATISTICS
  Subdomains Found          : 47
  Raw URLs Collected        : 8,243
  Alive URLs                : 1,105
  Total Mapped URLs         : 642

  OWASP TOP 10 CATEGORY BREAKDOWN
  No.  Category             URLs Found
  1    sqli                 89
  2    xss                  134
  3    auth                 67
  ...
```

---

## 🔍 How It Works

### URL Mapping Logic

OWASP Mapper categorizes URLs by matching against carefully crafted regex patterns targeting common parameters and path segments:

| Pattern | Example | Category |
|---------|---------|---------|
| `?id=` | `/item?id=123` | sqli |
| `?q=`, `?search=` | `/search?q=test` | xss |
| `/login`, `/admin` | `/admin/dashboard` | auth |
| `?redirect=` | `/?redirect=https://evil.com` | open_redirect |
| `?file=`, `?path=` | `/?file=../etc/passwd` | file_inclusion |
| `/.git`, `/.env` | `/.env` | misconfig |
| `/api/`, `/export` | `/api/v1/users` | data_exposure |

---

## 🛡️ OWASP Top 10 Reference

| # | Category | OWASP 2021 |
|---|---------|-----------|
| 1 | SQL Injection | A03:2021 |
| 2 | XSS | A03:2021 |
| 3 | Authentication | A07:2021 |
| 4 | Access Control | A01:2021 |
| 5 | CSRF | A01:2021 |
| 6 | Misconfiguration | A05:2021 |
| 7 | Data Exposure | A02:2021 |
| 8 | File Inclusion | A03:2021 |
| 9 | Open Redirect | A10:2021 |
| 10 | Miscellaneous | — |

---

## 🐛 Troubleshooting

**Go tools not found after install:**
```bash
export PATH=$PATH:$HOME/go/bin
source ~/.bashrc
```

**subfinder returns no results:**
- Some targets have limited public subdomain data
- Try adding `-all` sources in subfinder config: `~/.config/subfinder/provider-config.yaml`

**httpx timeouts:**
- Large URL sets may take time; the tool sets a 10-minute timeout
- Reduce thread count if on a slow connection

**Permission denied:**
```bash
chmod +x main.sh modules/*.sh
```

---

## 🤝 Contributing

Pull requests are welcome. For major changes, open an issue first to discuss what you'd like to change.

---

## 📄 License

MIT License — see [LICENSE](LICENSE) for details.

---

*OWASP Mapper v1.0 | Author: banghub | For authorized security testing only.*
