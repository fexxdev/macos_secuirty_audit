# Comprehensive Overhaul (v2.0.0) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Overhaul macos-security-audit from 20 to 36 checks, refactor internals, and add UX features (JSON output, category filtering, quiet/no-color modes, terminal summary table, exit codes).

**Architecture:** Single-file Bash script. All checks become named functions grouped by category. New CLI flags parsed via extended `case` block. JSON output built with `printf` + `json_escape` helper. No external dependencies.

**Tech Stack:** Bash 3.2+, standard macOS utilities

**Spec:** `docs/superpowers/specs/2026-03-18-comprehensive-overhaul-design.md`

---

## Task 1: Version bump + new CLI flags + flag parsing

**Files:**
- Modify: `bin/macos-security-audit:1-92` (header, version, usage, arg parsing)

- [ ] **Step 1: Update version and TOTAL_CHECKS**

Change line 23-24:
```bash
VERSION="2.0.0"
TOTAL_CHECKS=36
```

- [ ] **Step 2: Add new global variables after line 29**

```bash
# ── Output modes ──────────────────────────────────────────────────────
JSON_MODE=false
QUIET_MODE=false
CATEGORY_FILTER=""
```

- [ ] **Step 3: Add auto-detect no-color after the color definitions (line 27-28)**

Replace the color block with:
```bash
# ── Colours / symbols for terminal output ────────────────────────────
if [[ -t 1 ]]; then
    RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
else
    RED=''; GREEN=''; YELLOW=''; CYAN=''; BOLD=''; NC=''
fi
PASS="${GREEN}PASS${NC}"; FAIL="${RED}FAIL${NC}"; WARN="${YELLOW}WARN${NC}"; INFO="${CYAN}INFO${NC}"
```

- [ ] **Step 4: Rewrite usage() to include all new flags and all 36 checks**

```bash
usage() {
    cat <<EOF
macos-security-audit v${VERSION}

Comprehensive macOS security audit with Markdown report generation.

USAGE:
    macos-security-audit [OPTIONS]

OPTIONS:
    --help            Show this help message
    --version         Print version and exit
    --output FILE     Custom report path (default: ./security-audit-YYYY-MM-DD.md)
    --show-fix        After each finding, print fix command(s) in a copy-pasteable block
    --json            Output report as JSON instead of Markdown
    --category CAT    Run only checks in given categories (comma-separated)
                      Categories: encryption, system, network, sharing, auth, privacy, software
    --quiet           Suppress terminal output, print only the grade
    --no-color        Disable ANSI color codes in terminal output
    --list-checks     List all checks with category and description

EXAMPLES:
    macos-security-audit
    macos-security-audit --show-fix
    macos-security-audit --json --output report.json
    macos-security-audit --category encryption,network
    macos-security-audit --quiet
    macos-security-audit --list-checks

CHECKS PERFORMED (36):

  Encryption:
     1  Disk Encryption (FileVault)
     2  Time Machine Backup & Encryption

  System:
     3  System Integrity Protection (SIP)
     4  Gatekeeper & Secure Boot
     5  Lockdown Mode
     6  Rapid Security Response
     7  XProtect Definitions
     8  Kernel Extensions
     9  Find My Mac

  Network:
    10  Firewall & Stealth Mode
    11  Network Exposure
    12  DNS & Network
    13  Wi-Fi Auto-Join for Open Networks
    14  Internet Sharing
    15  Wake on Network Access

  Sharing:
    16  Sharing Services
    17  Remote Apple Events
    18  Content Caching
    19  Printer Sharing
    20  Media Sharing
    21  Handoff

  Auth:
    22  User Accounts & Authentication
    23  SSH Configuration
    24  Screen Saver Timeout
    25  Login Window Configuration
    26  Touch ID
    27  USB Restricted Mode

  Privacy:
    28  Location Services
    29  Analytics & Telemetry Sharing
    30  Bluetooth Discoverability
    31  Siri Voice Trigger

  Software:
    32  Software Updates
    33  Installed Software Review
    34  Safari Safe File Auto-Open
    35  Secure Keyboard Entry (Terminal)
    36  Docker Daemons
EOF
    exit 0
}
```

- [ ] **Step 5: Rewrite argument parsing to handle all new flags**

```bash
# ── Parse arguments ──────────────────────────────────────────────────
DATE_STAMP=$(date +%Y-%m-%d)
OUTPUT_FILE="security-audit-${DATE_STAMP}.md"
SHOW_FIX=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --help)       usage ;;
        --version)    echo "macos-security-audit v${VERSION}"; exit 0 ;;
        --output)     OUTPUT_FILE="${2:-$OUTPUT_FILE}"; shift 2 ;;
        --show-fix)   SHOW_FIX=true; shift ;;
        --json)       JSON_MODE=true; shift ;;
        --quiet)      QUIET_MODE=true; shift ;;
        --no-color)
            RED=''; GREEN=''; YELLOW=''; CYAN=''; BOLD=''; NC=''
            PASS="PASS"; FAIL="FAIL"; WARN="WARN"; INFO="INFO"
            shift ;;
        --category)   CATEGORY_FILTER="${2:-}"; shift 2 ;;
        --list-checks) list_checks; exit 0 ;;
        *)
            printf "${RED}Unknown option: %s${NC}\n" "$1"
            printf "Run 'macos-security-audit --help' for usage.\n"
            exit 1
            ;;
    esac
done
```

- [ ] **Step 6: Add list_checks() function before the arg parsing block**

```bash
list_checks() {
    printf " %-4s %-14s %s\n" "#" "Category" "Check"
    printf " %-4s %-14s %s\n" "---" "--------------" "------------------------------------"
    printf " %-4s %-14s %s\n" "1"  "encryption" "Disk Encryption (FileVault)"
    printf " %-4s %-14s %s\n" "2"  "encryption" "Time Machine Backup & Encryption"
    printf " %-4s %-14s %s\n" "3"  "system"     "System Integrity Protection (SIP)"
    printf " %-4s %-14s %s\n" "4"  "system"     "Gatekeeper & Secure Boot"
    printf " %-4s %-14s %s\n" "5"  "system"     "Lockdown Mode"
    printf " %-4s %-14s %s\n" "6"  "system"     "Rapid Security Response"
    printf " %-4s %-14s %s\n" "7"  "system"     "XProtect Definitions"
    printf " %-4s %-14s %s\n" "8"  "system"     "Kernel Extensions"
    printf " %-4s %-14s %s\n" "9"  "system"     "Find My Mac"
    printf " %-4s %-14s %s\n" "10" "network"    "Firewall & Stealth Mode"
    printf " %-4s %-14s %s\n" "11" "network"    "Network Exposure"
    printf " %-4s %-14s %s\n" "12" "network"    "DNS & Network"
    printf " %-4s %-14s %s\n" "13" "network"    "Wi-Fi Auto-Join for Open Networks"
    printf " %-4s %-14s %s\n" "14" "network"    "Internet Sharing"
    printf " %-4s %-14s %s\n" "15" "network"    "Wake on Network Access"
    printf " %-4s %-14s %s\n" "16" "sharing"    "Sharing Services"
    printf " %-4s %-14s %s\n" "17" "sharing"    "Remote Apple Events"
    printf " %-4s %-14s %s\n" "18" "sharing"    "Content Caching"
    printf " %-4s %-14s %s\n" "19" "sharing"    "Printer Sharing"
    printf " %-4s %-14s %s\n" "20" "sharing"    "Media Sharing"
    printf " %-4s %-14s %s\n" "21" "sharing"    "Handoff"
    printf " %-4s %-14s %s\n" "22" "auth"       "User Accounts & Authentication"
    printf " %-4s %-14s %s\n" "23" "auth"       "SSH Configuration"
    printf " %-4s %-14s %s\n" "24" "auth"       "Screen Saver Timeout"
    printf " %-4s %-14s %s\n" "25" "auth"       "Login Window Configuration"
    printf " %-4s %-14s %s\n" "26" "auth"       "Touch ID"
    printf " %-4s %-14s %s\n" "27" "auth"       "USB Restricted Mode"
    printf " %-4s %-14s %s\n" "28" "privacy"    "Location Services"
    printf " %-4s %-14s %s\n" "29" "privacy"    "Analytics & Telemetry Sharing"
    printf " %-4s %-14s %s\n" "30" "privacy"    "Bluetooth Discoverability"
    printf " %-4s %-14s %s\n" "31" "privacy"    "Siri Voice Trigger"
    printf " %-4s %-14s %s\n" "32" "software"   "Software Updates"
    printf " %-4s %-14s %s\n" "33" "software"   "Installed Software Review"
    printf " %-4s %-14s %s\n" "34" "software"   "Safari Safe File Auto-Open"
    printf " %-4s %-14s %s\n" "35" "software"   "Secure Keyboard Entry (Terminal)"
    printf " %-4s %-14s %s\n" "36" "software"   "Docker Daemons"
}
```

- [ ] **Step 7: Commit**

```bash
git add bin/macos-security-audit
git commit -m "feat: v2.0.0 CLI flags, version bump, usage update"
```

---

## Task 2: Helper functions + category infrastructure

**Files:**
- Modify: `bin/macos-security-audit` (helper section, ~lines 107-200)

- [ ] **Step 1: Add helper functions after the existing helpers block**

Insert after `daemon_loaded()` (line 141):

```bash
# ── Category filtering ──────────────────────────────────────────────
# Maps check number → category name
check_category() {
    case $1 in
        1|2) echo "encryption" ;;
        3|4|5|6|7|8|9) echo "system" ;;
        10|11|12|13|14|15) echo "network" ;;
        16|17|18|19|20|21) echo "sharing" ;;
        22|23|24|25|26|27) echo "auth" ;;
        28|29|30|31) echo "privacy" ;;
        32|33|34|35|36) echo "software" ;;
        *) echo "unknown" ;;
    esac
}

should_run_check() {
    local check_num=$1
    if [[ -z "$CATEGORY_FILTER" ]]; then
        return 0  # no filter, run all
    fi
    local cat
    cat=$(check_category "$check_num")
    if echo ",$CATEGORY_FILTER," | grep -q ",$cat,"; then
        return 0
    fi
    return 1
}

# Count checks that will actually run (for progress display)
count_active_checks() {
    local count=0
    for i in $(seq 1 "$TOTAL_CHECKS"); do
        if should_run_check "$i"; then
            count=$((count + 1))
        fi
    done
    echo "$count"
}

# ── Quiet-mode aware output ──────────────────────────────────────────
qprint() {
    if ! $QUIET_MODE; then
        printf "$@"
    fi
}

qecho() {
    if ! $QUIET_MODE; then
        echo "$@"
    fi
}
```

- [ ] **Step 2: Add json_escape helper**

```bash
# ── JSON helpers ─────────────────────────────────────────────────────
json_escape() {
    local s="$1"
    s="${s//\\/\\\\}"      # backslash
    s="${s//\"/\\\"}"      # double quote
    s="${s//$'\n'/\\n}"    # newline
    s="${s//$'\t'/\\t}"    # tab
    s="${s//$'\r'/\\r}"    # carriage return
    printf '%s' "$s"
}
```

- [ ] **Step 3: Add JSON findings accumulator**

```bash
# ── JSON findings accumulator ────────────────────────────────────────
declare -a JSON_FINDINGS=()

add_json_finding() {
    local check_num="$1" category="$2" title="$3" severity="$4" summary="$5" detail="$6" fix="${7:-}"
    local fix_json="null"
    if [[ -n "$fix" ]]; then
        fix_json="\"$(json_escape "$fix")\""
    fi
    JSON_FINDINGS+=("$(printf '{"check_number":%d,"category":"%s","title":"%s","severity":"%s","summary":"%s","detail":"%s","fix":%s}' \
        "$check_num" \
        "$(json_escape "$category")" \
        "$(json_escape "$title")" \
        "$(json_escape "$severity")" \
        "$(json_escape "$summary")" \
        "$(json_escape "$detail")" \
        "$fix_json")")
}
```

- [ ] **Step 4: Update pass/critical/high/medium to be quiet-mode aware and accumulate JSON data**

Current check number tracking — add a global:
```bash
CURRENT_CHECK_NUM=0
CURRENT_CHECK_TITLE=""
CURRENT_CHECK_CATEGORY=""
```

Update the recording functions:
```bash
pass() {
    PASSES+=("$1")
    qprint "  ${PASS}  %s\n" "$1"
    if $JSON_MODE; then
        add_json_finding "$CURRENT_CHECK_NUM" "$CURRENT_CHECK_CATEGORY" "$CURRENT_CHECK_TITLE" "pass" "$1" "" ""
    fi
}
critical() {
    CRITICALS+=("$(printf '%s\n\n%s' "$1" "$2")")
    SCORE=$((SCORE - 8))
    qprint "  ${FAIL}  %s\n" "$1"
    if $JSON_MODE; then
        add_json_finding "$CURRENT_CHECK_NUM" "$CURRENT_CHECK_CATEGORY" "$CURRENT_CHECK_TITLE" "critical" "$1" "$2" ""
    fi
}
high() {
    HIGHS+=("$(printf '%s\n\n%s' "$1" "$2")")
    SCORE=$((SCORE - 4))
    qprint "  ${WARN}  %s\n" "$1"
    if $JSON_MODE; then
        add_json_finding "$CURRENT_CHECK_NUM" "$CURRENT_CHECK_CATEGORY" "$CURRENT_CHECK_TITLE" "high" "$1" "$2" ""
    fi
}
medium() {
    MEDIUMS+=("$(printf '%s\n\n%s' "$1" "$2")")
    SCORE=$((SCORE - 2))
    qprint "  ${WARN}  %s\n" "$1"
    if $JSON_MODE; then
        add_json_finding "$CURRENT_CHECK_NUM" "$CURRENT_CHECK_CATEGORY" "$CURRENT_CHECK_TITLE" "medium" "$1" "$2" ""
    fi
}
```

- [ ] **Step 5: Update check_header to use active check count and show percentage**

```bash
check_header() {
    local num="$1" title="$2"
    CURRENT_CHECK_NUM=$num
    CURRENT_CHECK_TITLE="$title"
    CURRENT_CHECK_CATEGORY=$(check_category "$num")
    spin_stop
    local active
    active=$(count_active_checks)
    local pct=$(( num * 100 / TOTAL_CHECKS ))
    qprint "${CYAN}[%s/%s %s%%] %s${NC}\n" "$num" "$active" "$pct" "$title"
}
```

- [ ] **Step 6: Update spinner and header to respect quiet mode**

```bash
spin_start() {
    if $QUIET_MODE; then return; fi
    local msg="$1"
    (
        i=0
        while true; do
            printf "\r  ${CYAN}%s${NC} %s  " "${SPINNER_FRAMES[$((i % ${#SPINNER_FRAMES[@]}))]}" "$msg"
            sleep 0.08
            i=$((i + 1))
        done
    ) &
    SPINNER_PID=$!
    trap 'kill $SPINNER_PID 2>/dev/null' EXIT
}
```

- [ ] **Step 7: Add ACTIVE_CHECKS variable after arg parsing**

After the argument parsing `done`, add:
```bash
ACTIVE_CHECKS=$(count_active_checks)
PARTIAL_AUDIT=false
if [[ -n "$CATEGORY_FILTER" ]]; then
    PARTIAL_AUDIT=true
fi
```

- [ ] **Step 8: Commit**

```bash
git add bin/macos-security-audit
git commit -m "feat: add helper functions, category filtering, quiet mode, JSON accumulator"
```

---

## Task 3: Refactor existing 20 checks into named functions

**Files:**
- Modify: `bin/macos-security-audit:222-1155` (all check sections)

This is the largest task. Each of the 20 existing checks becomes a function with the new numbering. The checks are reordered by category. The logic inside each check stays the same — only the wrapping changes.

- [ ] **Step 1: Wrap all 20 existing checks into functions**

Each check block `### N. CHECK NAME` becomes a function. The function receives the check number as $1. Example for check 1 (FileVault):

```bash
check_encryption_filevault() {
    local n=$1
    if ! should_run_check "$n"; then return; fi
    check_header "$n" "Disk Encryption (FileVault)"
    # ... existing logic unchanged ...
}
```

Apply this pattern to all 20 checks. The internal logic of each check stays exactly the same — only wrap in a function and add the `should_run_check` guard.

New function names and their new check numbers:

```
check_encryption_filevault         →  1
check_system_sip                   →  3
check_system_gatekeeper            →  4
check_network_firewall             → 10
check_system_lockdown              →  5
check_software_updates             → 32
check_network_exposure             → 11
check_sharing_services             → 16
check_auth_users                   → 22
check_auth_ssh                     → 23
check_system_persistence           →  (keep under system, but this is check 33 - installed software area? No - persistence is its own thing. Actually persistence mechanisms include LaunchDaemons/Agents/cron. Let's keep it in system area as part of check 33: Installed Software Review section. Wait - the spec has "Installed Software Review" as check 33 in software. But persistence is different from installed software.)
```

Actually, let me reconsider. The persistence check (LaunchDaemons, LaunchAgents, cron) doesn't fit neatly into the new categories. Let's fold it into the `software` category as check 33 "Installed Software Review" since it's about reviewing what's installed/running. The existing "Installed Software Review" (offensive tools, Docker, Siri) gets split: Docker becomes check 36, Siri voice trigger becomes check 31 under privacy.

Revised mapping of old checks → new check numbers and functions:

| Old # | Old Name | New # | New Function | Category |
|-------|----------|-------|-------------|----------|
| 1 | FileVault | 1 | `check_encryption_filevault` | encryption |
| 2 | SIP | 3 | `check_system_sip` | system |
| 3 | Gatekeeper | 4 | `check_system_gatekeeper` | system |
| 4 | Firewall | 10 | `check_network_firewall` | network |
| 5 | Lockdown Mode | 5 | `check_system_lockdown` | system |
| 6 | Software Updates | 32 | `check_software_updates` | software |
| 7 | Network Exposure | 11 | `check_network_exposure` | network |
| 8 | Sharing Services | 16 | `check_sharing_services` | sharing |
| 9 | User Accounts | 22 | `check_auth_users` | auth |
| 10 | SSH Config | 23 | `check_auth_ssh` | auth |
| 11 | Persistence | 33 | `check_software_persistence` | software |
| 12 | DNS & Network | 12 | `check_network_dns` | network |
| 13 | Certificates | 33 | Fold into `check_software_review` | software |
| 14 | Installed Software | 33 | `check_software_review` (offensive tools) | software |
| 14 | Docker (sub-check) | 36 | `check_software_docker` | software |
| 14 | Siri voice (sub-check) | 31 | `check_privacy_siri` | privacy |
| 15 | Bluetooth | 30 | `check_privacy_bluetooth` | privacy |
| 16 | Location Services | 28 | `check_privacy_location` | privacy |
| 17 | Analytics | 29 | `check_privacy_analytics` | privacy |
| 18 | USB Restricted | 27 | `check_auth_usb` | auth |
| 19 | Wi-Fi Auto-Join | 13 | `check_network_wifi` | network |
| 20 | Touch ID | 26 | `check_auth_touchid` | auth |

Each function wraps the existing logic — no behavioral changes. Just:
1. Wrap in `function_name() { ... }`
2. Add `if ! should_run_check "$n"; then return; fi` at the top
3. Use `check_header "$n" "Title"` with the new number

- [ ] **Step 2: Create the main execution block that calls all functions in order**

After all function definitions, replace the old inline check code with:

```bash
# ── Execute all checks ───────────────────────────────────────────────
check_encryption_filevault 1
check_encryption_timemachine 2
check_system_sip 3
check_system_gatekeeper 4
check_system_lockdown 5
check_system_rsr 6
check_system_xprotect 7
check_system_kext 8
check_system_findmymac 9
check_network_firewall 10
check_network_exposure 11
check_network_dns 12
check_network_wifi 13
check_network_internet_sharing 14
check_network_wake 15
check_sharing_services 16
check_sharing_remote_apple_events 17
check_sharing_content_caching 18
check_sharing_printer 19
check_sharing_media 20
check_sharing_handoff 21
check_auth_users 22
check_auth_ssh 23
check_auth_screensaver 24
check_auth_login_window 25
check_auth_touchid 26
check_auth_usb 27
check_privacy_location 28
check_privacy_analytics 29
check_privacy_bluetooth 30
check_privacy_siri 31
check_software_updates 32
check_software_review 33
check_software_safari 34
check_software_secure_keyboard 35
check_software_docker 36
```

- [ ] **Step 3: Verify the script still parses correctly**

```bash
bash -n bin/macos-security-audit
```

- [ ] **Step 4: Commit**

```bash
git add bin/macos-security-audit
git commit -m "refactor: wrap all checks in named functions with category routing"
```

---

## Task 4: Add 16 new checks

**Files:**
- Modify: `bin/macos-security-audit` (add function definitions)

- [ ] **Step 1: Add check_encryption_timemachine (check 2)**

```bash
check_encryption_timemachine() {
    local n=$1
    if ! should_run_check "$n"; then return; fi
    check_header "$n" "Time Machine Backup & Encryption"

    local tm_status
    tm_status=$(defaults read /Library/Preferences/com.apple.TimeMachine AutoBackup 2>/dev/null || echo "unknown")
    local tm_dest
    tm_dest=$(tmutil destinationinfo 2>/dev/null || echo "")

    if [[ "$tm_status" == "0" ]]; then
        high "Time Machine backups are disabled" \
"Without backups, data loss from ransomware, hardware failure, or accidental deletion is permanent.

\`\`\`
Fix: System Settings > General > Time Machine > Add Backup Destination
\`\`\`"
        show_fix "Enable Time Machine" \
            "Open System Settings > General > Time Machine > Add Backup Destination"
    elif echo "$tm_dest" | grep -qi "Not Encrypted\|Encryption State.*None"; then
        medium "Time Machine backup destination is not encrypted" \
"An unencrypted backup disk exposes all your data if the backup drive is stolen.

\`\`\`
Fix: System Settings > General > Time Machine > select destination > Encrypt Backup
\`\`\`"
        show_fix "Encrypt Time Machine backup" \
            "Open System Settings > General > Time Machine > select destination > Encrypt Backup"
    elif [[ -n "$tm_dest" ]]; then
        pass "Time Machine is enabled with encrypted backup"
    else
        pass "Time Machine: could not determine backup status"
    fi
}
```

- [ ] **Step 2: Add check_system_rsr (check 6)**

```bash
check_system_rsr() {
    local n=$1
    if ! should_run_check "$n"; then return; fi
    check_header "$n" "Rapid Security Response"

    local rsr
    rsr=$(defaults read /Library/Preferences/com.apple.SoftwareUpdate CriticalUpdateInstall 2>/dev/null || echo "unknown")
    local rsr_auto
    rsr_auto=$(defaults read /Library/Preferences/com.apple.SoftwareUpdate AutomaticallyInstallMacOSUpdates 2>/dev/null || echo "unknown")

    if [[ "$rsr" == "0" ]] || [[ "$rsr_auto" == "0" ]]; then
        high "Rapid Security Responses may not install automatically" \
"Apple's Rapid Security Responses patch actively exploited vulnerabilities within hours. Disabling them leaves your system exposed.

\`\`\`
Fix: System Settings > General > Software Update > Automatic Updates > enable 'Install Security Responses and system files'
\`\`\`"
        show_fix "Enable Rapid Security Responses" \
            "sudo defaults write /Library/Preferences/com.apple.SoftwareUpdate CriticalUpdateInstall -bool true"
    else
        pass "Rapid Security Responses are enabled"
    fi
}
```

- [ ] **Step 3: Add check_system_xprotect (check 7)**

```bash
check_system_xprotect() {
    local n=$1
    if ! should_run_check "$n"; then return; fi
    check_header "$n" "XProtect Definitions"

    local xp_version=""
    local xp_plist="/Library/Apple/System/Library/CoreServices/XProtect.bundle/Contents/Info.plist"
    if [[ -f "$xp_plist" ]]; then
        xp_version=$(defaults read "$xp_plist" CFBundleShortVersionString 2>/dev/null || echo "")
    fi

    # Check last update via install history
    local last_xp_update=""
    last_xp_update=$(system_profiler SPInstallHistoryDataType 2>/dev/null | grep -A2 "XProtect" | awk -F': ' '/Install Date/{print $2; exit}' || echo "")

    if [[ -n "$last_xp_update" ]]; then
        # Calculate days since last update
        local update_epoch
        update_epoch=$(date -j -f "%m/%d/%y, %I:%M %p" "$last_xp_update" "+%s" 2>/dev/null || \
                       date -j -f "%Y-%m-%d" "$last_xp_update" "+%s" 2>/dev/null || echo "0")
        local now_epoch
        now_epoch=$(date "+%s")
        if [[ "$update_epoch" != "0" ]]; then
            local days_ago=$(( (now_epoch - update_epoch) / 86400 ))
            if (( days_ago > 90 )); then
                medium "XProtect definitions may be stale (last updated ${days_ago} days ago, version: ${xp_version:-unknown})" \
"XProtect is macOS's built-in malware detection. Definitions older than 90 days may miss recent threats.

\`\`\`
Fix: System Settings > General > Software Update > check for updates
\`\`\`"
                show_fix "Update XProtect definitions" \
                    "sudo softwareupdate --background-critical"
            else
                pass "XProtect definitions are current (${days_ago} days old, version: ${xp_version:-unknown})"
            fi
        else
            pass "XProtect installed (version: ${xp_version:-unknown}, could not determine age)"
        fi
    elif [[ -n "$xp_version" ]]; then
        pass "XProtect installed (version: ${xp_version})"
    else
        medium "Could not verify XProtect definitions" \
"XProtect should be installed on all Macs. Verify manually.

\`\`\`
Fix: System Settings > General > Software Update > check for updates
\`\`\`"
    fi
}
```

- [ ] **Step 4: Add check_system_kext (check 8)**

```bash
check_system_kext() {
    local n=$1
    if ! should_run_check "$n"; then return; fi
    check_header "$n" "Kernel Extensions"

    local extensions
    extensions=$(system_profiler SPExtensionsDataType 2>/dev/null || echo "")
    local third_party=""
    if [[ -n "$extensions" ]]; then
        third_party=$(echo "$extensions" | grep -B1 "Obtained from: .*Not Signed\|Obtained from: .*Identified Developer\|Obtained from: .*Unknown" | grep "Extension Name:" | sed 's/.*Extension Name: /  - /' || true)
    fi

    if [[ -n "$third_party" ]]; then
        medium "Third-party kernel extensions loaded" \
"Kernel extensions run with full system privileges. Third-party kexts increase attack surface:

$third_party

\`\`\`
Fix: Review loaded extensions. macOS is moving to System Extensions — ask vendors for updated drivers.
     System Settings > General > Login Items & Extensions
\`\`\`"
        show_fix "Review kernel extensions" \
            "systemextensionsctl list 2>/dev/null || echo 'N/A'" \
            "# System Settings > General > Login Items & Extensions"
    else
        pass "No third-party kernel extensions detected"
    fi
}
```

- [ ] **Step 5: Add check_system_findmymac (check 9)**

```bash
check_system_findmymac() {
    local n=$1
    if ! should_run_check "$n"; then return; fi
    check_header "$n" "Find My Mac"

    local fmm
    fmm=$(defaults read com.apple.FindMyMac FMMEnabled 2>/dev/null || echo "unknown")

    if [[ "$fmm" == "1" ]]; then
        pass "Find My Mac is enabled"
    elif [[ "$fmm" == "0" ]]; then
        medium "Find My Mac is disabled" \
"Find My Mac allows you to locate, lock, or erase a lost/stolen Mac remotely.

\`\`\`
Fix: System Settings > Apple ID > iCloud > Find My Mac > Turn On
\`\`\`"
        show_fix "Enable Find My Mac" \
            "Open System Settings > Apple ID > iCloud > Find My Mac > Turn On"
    else
        pass "Find My Mac: could not determine status (check manually)"
    fi
}
```

- [ ] **Step 6: Add check_network_internet_sharing (check 14)**

```bash
check_network_internet_sharing() {
    local n=$1
    if ! should_run_check "$n"; then return; fi
    check_header "$n" "Internet Sharing"

    local nat_enabled
    nat_enabled=$(defaults read /Library/Preferences/SystemConfiguration/com.apple.nat NAT 2>/dev/null | grep -c "Enabled = 1" || echo "0")

    if [[ "$nat_enabled" -gt 0 ]]; then
        high "Internet Sharing is enabled" \
"Your Mac is acting as a network router, sharing its internet connection. This creates an unmanaged access point.

\`\`\`
Fix: System Settings > General > Sharing > Internet Sharing > Turn Off
\`\`\`"
        show_fix "Disable Internet Sharing" \
            "Open System Settings > General > Sharing > Internet Sharing > Turn Off"
    else
        pass "Internet Sharing is disabled"
    fi
}
```

- [ ] **Step 7: Add check_network_wake (check 15)**

```bash
check_network_wake() {
    local n=$1
    if ! should_run_check "$n"; then return; fi
    check_header "$n" "Wake on Network Access"

    local womp
    womp=$(pmset -g 2>/dev/null | awk '/womp/{print $2}' || echo "unknown")
    if [[ "$womp" == "unknown" ]]; then
        womp=$(systemsetup -getwakeonnetworkaccess 2>/dev/null | awk -F': ' '{print $2}' || echo "unknown")
    fi

    if [[ "$womp" == "1" ]] || echo "$womp" | grep -qi "on"; then
        medium "Wake on Network Access is enabled" \
"Your Mac can be woken remotely via network traffic, increasing the window for remote attacks when you expect it to be asleep.

\`\`\`
Fix: System Settings > Battery > Options > Wake for network access > Never
     Or: sudo pmset -a womp 0
\`\`\`"
        show_fix "Disable Wake on Network Access" \
            "sudo pmset -a womp 0"
    else
        pass "Wake on Network Access is disabled"
    fi
}
```

- [ ] **Step 8: Add check_sharing_remote_apple_events (check 17)**

```bash
check_sharing_remote_apple_events() {
    local n=$1
    if ! should_run_check "$n"; then return; fi
    check_header "$n" "Remote Apple Events"

    local rae
    rae=$(systemsetup -getremoteappleevents 2>/dev/null || echo "")
    if [[ -z "$rae" ]]; then
        # Fallback: check if the AEServer daemon is loaded
        if launchctl list com.apple.AEServer &>/dev/null; then
            rae="On"
        else
            rae="Off"
        fi
    fi

    if echo "$rae" | grep -qi "on"; then
        high "Remote Apple Events are enabled" \
"Remote Apple Events allow other computers to send AppleScript commands to this Mac. This is a remote code execution vector.

\`\`\`
Fix: System Settings > General > Sharing > Remote Apple Events > Turn Off
\`\`\`"
        show_fix "Disable Remote Apple Events" \
            "sudo systemsetup -setremoteappleevents off"
    else
        pass "Remote Apple Events are disabled"
    fi
}
```

- [ ] **Step 9: Add check_sharing_content_caching (check 18)**

```bash
check_sharing_content_caching() {
    local n=$1
    if ! should_run_check "$n"; then return; fi
    check_header "$n" "Content Caching"

    local cc
    cc=$(defaults read /Library/Preferences/com.apple.AssetCache.plist Activated 2>/dev/null || echo "0")

    if [[ "$cc" == "1" ]]; then
        medium "Content Caching is enabled" \
"Content Caching shares downloaded Apple content with other devices on your network. While useful in managed environments, it increases network exposure.

\`\`\`
Fix: System Settings > General > Sharing > Content Caching > Turn Off
\`\`\`"
        show_fix "Disable Content Caching" \
            "Open System Settings > General > Sharing > Content Caching > Turn Off"
    else
        pass "Content Caching is disabled"
    fi
}
```

- [ ] **Step 10: Add check_sharing_printer (check 19)**

```bash
check_sharing_printer() {
    local n=$1
    if ! should_run_check "$n"; then return; fi
    check_header "$n" "Printer Sharing"

    local ps
    ps=$(defaults read /Library/Preferences/org.cups.cupsd SharePrinters 2>/dev/null || \
         defaults read /Library/Preferences/com.apple.printservice 2>/dev/null | grep -c "Shared.*Yes" || echo "0")

    if [[ "$ps" == "1" ]] || [[ "$ps" -gt 0 ]] 2>/dev/null; then
        medium "Printer Sharing is enabled" \
"Shared printers are accessible to other devices on your network, which can be an information disclosure vector.

\`\`\`
Fix: System Settings > General > Sharing > Printer Sharing > Turn Off
\`\`\`"
        show_fix "Disable Printer Sharing" \
            "Open System Settings > General > Sharing > Printer Sharing > Turn Off"
    else
        pass "Printer Sharing is disabled"
    fi
}
```

- [ ] **Step 11: Add check_sharing_media (check 20)**

```bash
check_sharing_media() {
    local n=$1
    if ! should_run_check "$n"; then return; fi
    check_header "$n" "Media Sharing"

    local ms
    ms=$(defaults read com.apple.amp.mediasharingd home-sharing-enabled 2>/dev/null || echo "0")
    local ms2
    ms2=$(defaults read com.apple.amp.mediasharingd public-sharing-enabled 2>/dev/null || echo "0")

    if [[ "$ms" == "1" ]] || [[ "$ms2" == "1" ]]; then
        medium "Media Sharing is enabled" \
"Home Sharing or media library sharing exposes your media content on the local network.

\`\`\`
Fix: System Settings > General > Sharing > Media Sharing > Turn Off all toggles
\`\`\`"
        show_fix "Disable Media Sharing" \
            "Open System Settings > General > Sharing > Media Sharing > Turn Off"
    else
        pass "Media Sharing is disabled"
    fi
}
```

- [ ] **Step 12: Add check_sharing_handoff (check 21)**

```bash
check_sharing_handoff() {
    local n=$1
    if ! should_run_check "$n"; then return; fi
    check_header "$n" "Handoff"

    # Handoff uses ByHost preferences — find the correct file
    local handoff_allowed="unknown"
    local byhost_dir="$HOME/Library/Preferences/ByHost"
    if [[ -d "$byhost_dir" ]]; then
        # Check all ByHost files for the useractivityd pref
        handoff_allowed=$(defaults read "$byhost_dir/com.apple.coreservices.useractivityd" ActivityAdvertisingAllowed 2>/dev/null || echo "unknown")
    fi

    if [[ "$handoff_allowed" == "0" ]]; then
        pass "Handoff is disabled"
    elif [[ "$handoff_allowed" == "1" ]]; then
        medium "Handoff is enabled" \
"Handoff shares activity data between your Apple devices via Bluetooth and Wi-Fi. On shared/public networks this can leak information about your activity.

\`\`\`
Fix: System Settings > General > AirDrop & Handoff > Allow Handoff between this Mac and your iCloud devices > Off
\`\`\`"
        show_fix "Disable Handoff" \
            "Open System Settings > General > AirDrop & Handoff > Handoff > Off"
    else
        pass "Handoff: could not determine status"
    fi
}
```

- [ ] **Step 13: Add check_auth_screensaver (check 24)**

```bash
check_auth_screensaver() {
    local n=$1
    if ! should_run_check "$n"; then return; fi
    check_header "$n" "Screen Saver Timeout"

    local idle_time
    idle_time=$(defaults read com.apple.screensaver idleTime 2>/dev/null || echo "0")

    if [[ "$idle_time" == "0" ]] || [[ -z "$idle_time" ]]; then
        medium "Screen saver is not configured to activate automatically" \
"Without an automatic screen saver, your screen stays unlocked indefinitely when you walk away.

\`\`\`
Fix: System Settings > Lock Screen > 'Start Screen Saver when inactive' > set to 5 minutes or less
\`\`\`"
        show_fix "Set screen saver timeout" \
            "defaults write com.apple.screensaver idleTime -int 300"
    elif (( idle_time > 600 )); then
        medium "Screen saver timeout is ${idle_time}s (more than 10 minutes)" \
"A long timeout leaves your machine accessible if you step away.

\`\`\`
Fix: System Settings > Lock Screen > 'Start Screen Saver when inactive' > 5 minutes or less
\`\`\`"
        show_fix "Reduce screen saver timeout to 5 minutes" \
            "defaults write com.apple.screensaver idleTime -int 300"
    else
        pass "Screen saver activates after ${idle_time}s"
    fi
}
```

- [ ] **Step 14: Add check_auth_login_window (check 25)**

```bash
check_auth_login_window() {
    local n=$1
    if ! should_run_check "$n"; then return; fi
    check_header "$n" "Login Window Configuration"

    local issues=""

    # Show full name vs username list
    local show_full
    show_full=$(defaults read /Library/Preferences/com.apple.loginwindow SHOWFULLNAME 2>/dev/null || echo "unknown")
    if [[ "$show_full" == "0" ]]; then
        issues="${issues}  - Login window shows user list (reveals account names)\n"
    fi

    # Password hints
    local hints
    hints=$(defaults read /Library/Preferences/com.apple.loginwindow RetriesUntilHint 2>/dev/null || echo "unknown")
    if [[ "$hints" != "0" ]] && [[ "$hints" != "unknown" ]]; then
        issues="${issues}  - Password hints shown after ${hints} failed attempt(s)\n"
    fi

    if [[ -n "$issues" ]]; then
        medium "Login window configuration could be hardened" \
"$(echo -e "$issues")
\`\`\`
Fix: System Settings > Lock Screen > set 'Show user list' to Name and Password fields
     defaults write /Library/Preferences/com.apple.loginwindow SHOWFULLNAME -bool true
     defaults write /Library/Preferences/com.apple.loginwindow RetriesUntilHint -int 0
\`\`\`"
        show_fix "Harden login window" \
            "sudo defaults write /Library/Preferences/com.apple.loginwindow SHOWFULLNAME -bool true" \
            "sudo defaults write /Library/Preferences/com.apple.loginwindow RetriesUntilHint -int 0"
    else
        pass "Login window configuration is hardened"
    fi
}
```

- [ ] **Step 15: Add check_software_safari (check 34)**

```bash
check_software_safari() {
    local n=$1
    if ! should_run_check "$n"; then return; fi
    check_header "$n" "Safari Safe File Auto-Open"

    local auto_open
    auto_open=$(defaults read com.apple.Safari AutoOpenSafeDownloads 2>/dev/null || echo "unknown")

    if [[ "$auto_open" == "1" ]]; then
        medium "Safari auto-opens 'safe' files after downloading" \
"Safari automatically opens files it considers 'safe' (PDFs, images, archives). Malicious files disguised as safe types can auto-execute.

\`\`\`
Fix: Safari > Settings > General > Uncheck 'Open safe files after downloading'
\`\`\`"
        show_fix "Disable Safari auto-open" \
            "defaults write com.apple.Safari AutoOpenSafeDownloads -bool false"
    else
        pass "Safari does not auto-open downloaded files"
    fi
}
```

- [ ] **Step 16: Add check_software_secure_keyboard (check 35)**

```bash
check_software_secure_keyboard() {
    local n=$1
    if ! should_run_check "$n"; then return; fi
    check_header "$n" "Secure Keyboard Entry (Terminal)"

    local ske
    ske=$(defaults read com.apple.Terminal SecureKeyboardEntry 2>/dev/null || echo "unknown")

    if [[ "$ske" == "1" ]]; then
        pass "Secure Keyboard Entry is enabled in Terminal"
    elif [[ "$ske" == "0" ]]; then
        medium "Secure Keyboard Entry is disabled in Terminal" \
"Without Secure Keyboard Entry, other applications can intercept keystrokes typed in Terminal, including passwords and commands.

\`\`\`
Fix: Terminal > Secure Keyboard Entry (menu bar) > Enable
     Or: defaults write com.apple.Terminal SecureKeyboardEntry -bool true
\`\`\`"
        show_fix "Enable Secure Keyboard Entry" \
            "defaults write com.apple.Terminal SecureKeyboardEntry -bool true"
    else
        pass "Secure Keyboard Entry: could not determine (may use a different terminal)"
    fi
}
```

- [ ] **Step 17: Extract Siri voice trigger from old check 14 into check_privacy_siri (check 31)**

Move the Siri voice trigger code from the old "Installed Software Review" into its own function:

```bash
check_privacy_siri() {
    local n=$1
    if ! should_run_check "$n"; then return; fi
    check_header "$n" "Siri Voice Trigger"

    local siri_voice
    siri_voice=$(defaults read com.apple.Siri VoiceTriggerUserEnabled 2>/dev/null || echo "unknown")
    if [[ "$siri_voice" == "1" ]]; then
        medium "'Hey Siri' voice trigger is enabled" \
"Always-on microphone listening is a privacy concern.

\`\`\`
Fix: System Settings > Siri & Spotlight > Disable 'Listen for \"Hey Siri\"'
\`\`\`"
        show_fix "Disable Hey Siri voice trigger" \
            "defaults write com.apple.Siri VoiceTriggerUserEnabled -bool false"
    elif [[ "$siri_voice" == "0" ]]; then
        pass "'Hey Siri' voice trigger is disabled"
    else
        pass "Siri voice trigger: could not determine status"
    fi
}
```

- [ ] **Step 18: Extract Docker from old check 14 into check_software_docker (check 36)**

```bash
check_software_docker() {
    local n=$1
    if ! should_run_check "$n"; then return; fi
    check_header "$n" "Docker Daemons"

    if daemon_loaded com.docker.vmnetd 2>/dev/null || daemon_loaded com.docker.socket 2>/dev/null; then
        medium "Docker system daemons are installed (run as root)" \
"Docker's vmnetd and socket daemon run as root-level LaunchDaemons. Containers can be used for privilege escalation.

\`\`\`
Fix: Only run Docker when actively needed. Consider lighter alternatives like Colima.
\`\`\`"
        show_fix "Consider lighter alternatives" \
            "# Stop Docker Desktop when not in use" \
            "# Consider Colima: brew install colima"
    else
        pass "No Docker system daemons detected"
    fi
}
```

- [ ] **Step 19: Verify script syntax**

```bash
bash -n bin/macos-security-audit
```

- [ ] **Step 20: Commit**

```bash
git add bin/macos-security-audit
git commit -m "feat: add 16 new security checks (36 total)"
```

---

## Task 5: Terminal summary table + exit codes

**Files:**
- Modify: `bin/macos-security-audit` (report generation section, ~lines 1157-1267)

- [ ] **Step 1: Add terminal summary table after all checks complete**

Replace the old simple findings printout with a boxed table. Insert after `spin_stop` and before report generation:

```bash
spin_stop
GRADE=$(letter_grade $SCORE)

# ── Terminal summary ─────────────────────────────────────────────────
if ! $QUIET_MODE; then
    echo ""
    qprint "${CYAN}┌─────────────────────────────────────┐${NC}\n"
    qprint "${CYAN}│       Security Audit Complete        │${NC}\n"
    qprint "${CYAN}├────────────┬────────────────────────┤${NC}\n"
    qprint "${CYAN}│${NC} ${RED}CRITICAL${NC}   ${CYAN}│${NC} %-22s ${CYAN}│${NC}\n" "${#CRITICALS[@]}"
    qprint "${CYAN}│${NC} ${YELLOW}HIGH${NC}       ${CYAN}│${NC} %-22s ${CYAN}│${NC}\n" "${#HIGHS[@]}"
    qprint "${CYAN}│${NC} ${YELLOW}MEDIUM${NC}     ${CYAN}│${NC} %-22s ${CYAN}│${NC}\n" "${#MEDIUMS[@]}"
    qprint "${CYAN}│${NC} ${GREEN}PASS${NC}       ${CYAN}│${NC} %-22s ${CYAN}│${NC}\n" "${#PASSES[@]}"
    qprint "${CYAN}├────────────┼────────────────────────┤${NC}\n"
    qprint "${CYAN}│${NC} Score      ${CYAN}│${NC} %-22s ${CYAN}│${NC}\n" "$SCORE / 100"
    qprint "${CYAN}│${NC} Grade      ${CYAN}│${NC} %-22s ${CYAN}│${NC}\n" "$GRADE"
    qprint "${CYAN}└────────────┴────────────────────────┘${NC}\n"
    if $PARTIAL_AUDIT; then
        qprint "\n  ${YELLOW}Partial audit — categories: %s${NC}\n" "$CATEGORY_FILTER"
    fi
    echo ""
fi

if $QUIET_MODE; then
    echo "$GRADE ($SCORE/100)"
fi
```

- [ ] **Step 2: Add exit code logic at the very end of the script**

After the report is written and summary is printed:

```bash
# ── Exit code based on grade ─────────────────────────────────────────
case "$GRADE" in
    A+|A|A-|B+|B|B-) exit 0 ;;
    C+|C|C-)         exit 1 ;;
    *)               exit 2 ;;
esac
```

- [ ] **Step 3: Commit**

```bash
git add bin/macos-security-audit
git commit -m "feat: terminal summary table and grade-based exit codes"
```

---

## Task 6: JSON output

**Files:**
- Modify: `bin/macos-security-audit` (report generation section)

- [ ] **Step 1: Add JSON report generation**

In the report generation section, wrap the existing Markdown generation in a conditional and add JSON alternative:

```bash
if $JSON_MODE; then
    # ── JSON report ──────────────────────────────────────────────────
    {
        printf '{\n'
        printf '  "version": "%s",\n' "$VERSION"
        printf '  "timestamp": "%s",\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
        printf '  "machine": {\n'
        printf '    "model": "%s",\n' "$(json_escape "$HW_MODEL")"
        printf '    "chip": "%s",\n' "$(json_escape "$HW_CHIP")"
        printf '    "macos_version": "%s",\n' "$(json_escape "$OS_VERSION")"
        printf '    "build": "%s",\n' "$(json_escape "$OS_BUILD")"
        printf '    "serial": "%s"\n' "$(json_escape "$SERIAL")"
        printf '  },\n'
        printf '  "score": %d,\n' "$SCORE"
        printf '  "grade": "%s",\n' "$GRADE"
        printf '  "partial_audit": %s,\n' "$PARTIAL_AUDIT"
        if $PARTIAL_AUDIT; then
            printf '  "categories_checked": "%s",\n' "$(json_escape "$CATEGORY_FILTER")"
        else
            printf '  "categories_checked": "all",\n'
        fi
        printf '  "summary": {\n'
        printf '    "critical": %d,\n' "${#CRITICALS[@]}"
        printf '    "high": %d,\n' "${#HIGHS[@]}"
        printf '    "medium": %d,\n' "${#MEDIUMS[@]}"
        printf '    "pass": %d,\n' "${#PASSES[@]}"
        printf '    "total": %d\n' "$TOTAL_CHECKS"
        printf '  },\n'
        printf '  "findings": [\n'
        local first=true
        for finding in "${JSON_FINDINGS[@]}"; do
            if $first; then
                first=false
            else
                printf ',\n'
            fi
            printf '    %s' "$finding"
        done
        printf '\n  ]\n'
        printf '}\n'
    } > "$OUTPUT_FILE"
else
    # ── Markdown report (existing logic) ─────────────────────────────
    {
        # ... existing markdown generation ...
    } > "$OUTPUT_FILE"
fi
```

- [ ] **Step 2: Update the report-written message**

```bash
if ! $QUIET_MODE; then
    if $JSON_MODE; then
        qprint "  ${GREEN}JSON report written to: %s${NC}\n" "$OUTPUT_FILE"
    else
        qprint "  ${GREEN}Report written to: %s${NC}\n" "$OUTPUT_FILE"
    fi
    qprint "  ${CYAN}Review the report:${NC} cat %s\n" "$OUTPUT_FILE"
    echo ""
fi
```

- [ ] **Step 3: Verify script syntax**

```bash
bash -n bin/macos-security-audit
```

- [ ] **Step 4: Commit**

```bash
git add bin/macos-security-audit
git commit -m "feat: JSON output mode (--json)"
```

---

## Task 7: Update README.md, ReleaseNotes.md, CLAUDE.md

**Files:**
- Modify: `README.md`
- Modify: `ReleaseNotes.md`
- Modify: `CLAUDE.md`

- [ ] **Step 1: Update README.md**

- Update header to say "36 checks"
- Add new flags to Usage section
- Update the checks table with all 36 checks organized by category
- Add category filtering and JSON output examples
- Update example terminal output

- [ ] **Step 2: Update ReleaseNotes.md**

Add v2.0.0 release notes:

```markdown
## v2.0.0 — Comprehensive Overhaul (2026-03-18)

### New Checks (+16, 36 total)
- Time Machine Backup & Encryption
- Rapid Security Response
- XProtect Definitions
- Kernel Extensions
- Find My Mac
- Internet Sharing
- Wake on Network Access
- Remote Apple Events
- Content Caching
- Printer Sharing
- Media Sharing
- Handoff
- Screen Saver Timeout
- Login Window Configuration
- Safari Safe File Auto-Open
- Secure Keyboard Entry (Terminal)

### New Features
- `--json` — JSON output format
- `--category` — run only specific check categories
- `--quiet` — print only the grade
- `--no-color` — disable ANSI colors (auto-detected when piping)
- `--version` — print version
- `--list-checks` — list all checks with categories
- Exit codes reflect grade (0 = A/B, 1 = C, 2 = D/F)
- Terminal summary table with boxed layout
- Progress percentage in check headers

### Internal
- All checks refactored into named functions
- Category-based organization
- Standardized check pattern across all checks
- Docker and Siri checks split into dedicated checks
- Certificates check merged into software review
```

- [ ] **Step 3: Update CLAUDE.md approved tool list**

Add `tmutil`, `pmset` to the approved tools list.

- [ ] **Step 4: Update Homebrew formula version**

Update `Formula/macos-security-audit.rb` version to 2.0.0.

- [ ] **Step 5: Commit**

```bash
git add README.md ReleaseNotes.md CLAUDE.md Formula/macos-security-audit.rb
git commit -m "docs: update README, release notes, CLAUDE.md for v2.0.0"
```

---

## Task 8: Final verification

- [ ] **Step 1: Syntax check**

```bash
bash -n bin/macos-security-audit
```

- [ ] **Step 2: Verify --help works**

```bash
./bin/macos-security-audit --help
```

- [ ] **Step 3: Verify --version works**

```bash
./bin/macos-security-audit --version
```

- [ ] **Step 4: Verify --list-checks works**

```bash
./bin/macos-security-audit --list-checks
```

- [ ] **Step 5: Verify no destructive commands outside quoted strings**

```bash
grep -n 'defaults write\|sudo \|rm \|launchctl unload\|launchctl load\|killall\|sysctl -w\|curl \|wget ' bin/macos-security-audit | grep -v '^\s*#\|show_fix\|".*defaults write\|".*sudo\|".*rm \|printf.*\$\|echo.*\$\|Fix:'
```

Any matches that aren't inside quoted strings or comments are violations.

- [ ] **Step 6: Verify TOTAL_CHECKS matches actual check count**

```bash
grep -c 'check_header' bin/macos-security-audit
# Should output: 36
```

- [ ] **Step 7: Run shellcheck (if available)**

```bash
shellcheck bin/macos-security-audit || true
```
