# Comprehensive Overhaul — Design Spec

**Date:** 2026-03-18
**Approach:** Phased delivery (3 phases, single-file architecture preserved)

---

## Phase 1: Internal Refactor

### Helper Functions

Extract repeated patterns into reusable helpers:

- `check_defaults_bool DOMAIN KEY EXPECTED_VALUE` — reads a defaults key, compares to expected boolean, returns 0/1
- `check_defaults_value DOMAIN KEY` — reads a defaults key, returns the value or empty string
- `check_service_running SERVICE_NAME` — checks if a sharing service is active via `launchctl list`
- `check_sharing_pref KEY` — reads sharing preferences from the appropriate plist
- `is_apple_silicon` — returns 0 on ARM, 1 on Intel
- `add_finding SEVERITY SUMMARY DETAIL` — unified finding recorder replacing direct array manipulation
- `add_fix COMMAND DESCRIPTION` — unified fix recorder for `--show-fix`

### Check Categories

Group all checks (existing 20 + new 16 = 36 total) into named categories:

| Category     | Checks |
|-------------|--------|
| `encryption` | FileVault, Time Machine encryption |
| `system`     | SIP, Gatekeeper, Lockdown Mode, Rapid Security Response, XProtect, Kernel Extensions |
| `network`    | Firewall, Network Exposure, DNS, Wi-Fi Auto-Join, Internet Sharing, Wake on Network |
| `sharing`    | Sharing Services, AirDrop, Remote Apple Events, Content Caching, Printer Sharing, Media Sharing, Handoff |
| `auth`       | User Accounts, SSH Config, Touch ID, Screen Saver Lock, Login Window, USB Restricted Mode |
| `privacy`    | Location Services, Analytics, Bluetooth, Siri |
| `software`   | Software Updates, Installed Software, Safari Safe Files, Secure Keyboard Entry |

Each check function will be named `check_<category>_<name>` (e.g., `check_encryption_filevault`, `check_network_firewall`).

### Standardized Check Pattern

Every check follows this template:

```bash
check_<category>_<name>() {
    local check_num=$1
    print_check "$check_num" "$TOTAL_CHECKS" "Check Title"

    # ... read-only detection logic ...

    if [[ "$condition" == "secure" ]]; then
        pass "Summary" "Detail"
    else
        critical|high|medium "Summary" "Detail"
        show_fix "fix command here" "Description"
    fi
}
```

### CLI Flag Parsing

Refactor `main()` argument parsing to support:

```
--help          Show usage
--version       Print version string
--output FILE   Custom report path
--show-fix      Show fix commands in terminal
--json          Output as JSON instead of Markdown
--category CAT  Run only checks in category (comma-separated)
--quiet         Suppress terminal output, print grade only
--no-color      Disable ANSI color codes
--list-checks   List all checks with category and description
```

### LaunchAgent Whitelist

Move the whitelist into a proper associative-style array at the top of the file with clear comments:

```bash
KNOWN_AGENTS=(
    "com.google.keystone"           # Google Updater
    "com.jetbrains.AppCode.BridgeService"
    # ... etc
)
```

---

## Phase 2: New Security Checks (16 additions)

Total checks: 20 existing + 16 new = **36 checks**

### New Checks

| # | Check | Category | Detection Method | Severity |
|---|-------|----------|-----------------|----------|
| 21 | Time Machine status & encryption | `encryption` | `defaults read /Library/Preferences/com.apple.TimeMachine` + `tmutil destinationinfo` | HIGH if backups disabled, MEDIUM if not encrypted |
| 22 | Screen saver password + timeout | `auth` | `defaults read com.apple.screensaver askForPassword` + `idleTime` | HIGH if no password, MEDIUM if timeout > 600s |
| 23 | Find My Mac | `system` | `defaults read com.apple.FindMyMac` + `nvram -p` grep for `fmm-mobileme-token` | MEDIUM if disabled |
| 24 | Login window config | `auth` | `defaults read /Library/Preferences/com.apple.loginwindow` — SHOWFULLNAME, RetriesUntilHint | MEDIUM for each misconfigured setting |
| 25 | Remote Apple Events | `sharing` | `systemsetup -getremoteappleevents 2>/dev/null \|\| launchctl list` | HIGH if enabled |
| 26 | Content Caching | `sharing` | `defaults read /Library/Preferences/com.apple.AssetCache.plist Activated` | MEDIUM if enabled |
| 27 | Rapid Security Response | `system` | `defaults read /Library/Managed\ Preferences/com.apple.SoftwareUpdate AutomaticallyInstallMacOSUpdates` + `CriticalUpdateInstall` | HIGH if disabled |
| 28 | XProtect definitions freshness | `system` | Check XProtect bundle version via `system_profiler SPInstallHistoryDataType` or file dates in `/Library/Apple/System/Library/CoreServices/XProtect.bundle` | MEDIUM if stale (>90 days) |
| 29 | Printer Sharing | `sharing` | `cupsctl` or `defaults read /Library/Preferences/com.apple.printservice` | MEDIUM if enabled |
| 30 | Media Sharing | `sharing` | `defaults read com.apple.amp.mediasharingd` | MEDIUM if enabled |
| 31 | Secure Keyboard Entry | `software` | `defaults read com.apple.Terminal SecureKeyboardEntry` | MEDIUM if disabled |
| 32 | Handoff | `sharing` | `defaults read ~/Library/Preferences/ByHost/com.apple.coreservices.useractivityd ActivityAdvertisingAllowed` | INFO/MEDIUM |
| 33 | Internet Sharing | `sharing` | `defaults read /Library/Preferences/SystemConfiguration/com.apple.nat NAT \| grep -c Enabled` | HIGH if enabled |
| 34 | Wake on Network Access | `network` | `systemsetup -getwakeonnetworkaccess 2>/dev/null` or `pmset -g \| grep womp` | MEDIUM if enabled |
| 35 | Kernel Extensions | `system` | `kextstat 2>/dev/null \| grep -v com.apple` or `systemextensionsctl list` | MEDIUM if third-party kexts loaded |
| 36 | Safari safe file auto-open | `software` | `defaults read com.apple.Safari AutoOpenSafeDownloads` | MEDIUM if enabled |

---

## Phase 3: UX Improvements

### JSON Output (`--json`)

When `--json` flag is set, output a JSON object instead of Markdown:

```json
{
  "version": "2.0.0",
  "timestamp": "2026-03-18T14:30:00Z",
  "machine": {
    "model": "MacBook Pro",
    "chip": "Apple M3 Pro",
    "macos_version": "15.3",
    "build": "24D60",
    "serial": "XXXX"
  },
  "score": 82,
  "grade": "B+",
  "summary": {
    "critical": 0,
    "high": 2,
    "medium": 5,
    "pass": 29,
    "total": 36
  },
  "findings": [
    {
      "check_number": 1,
      "category": "encryption",
      "title": "Disk Encryption (FileVault)",
      "severity": "pass",
      "summary": "FileVault is enabled",
      "detail": "...",
      "fix": null
    }
  ]
}
```

Built with `printf` — no `jq` dependency.

### Category Filtering (`--category`)

`--category encryption,network` runs only checks in those categories. Multiple categories comma-separated. Adjusts `TOTAL_CHECKS` dynamically for progress display.

### Quiet Mode (`--quiet`)

Suppresses all terminal output except the final grade line: `B+ (82/100)`

### No-Color Mode (`--no-color`)

Sets all color variables to empty strings. Auto-detected when stdout is not a terminal (`! -t 1`).

### Version Flag (`--version`)

Prints `macos-security-audit 2.0.0` and exits.

### List Checks (`--list-checks`)

Prints a formatted table:

```
 #  Category      Check
 1  encryption    Disk Encryption (FileVault)
 2  system        System Integrity Protection (SIP)
...
36  software      Safari Safe File Auto-Open
```

### Exit Codes

| Grade | Exit Code |
|-------|-----------|
| A+, A, B+, B | 0 |
| C+, C | 1 |
| D, F | 2 |

### Terminal Summary Table

After all checks complete, print a boxed summary:

```
┌─────────────────────────────────┐
│     Security Audit Complete     │
├──────────┬──────────────────────┤
│ CRITICAL │ 0                    │
│ HIGH     │ 2                    │
│ MEDIUM   │ 5                    │
│ PASS     │ 29                   │
├──────────┼──────────────────────┤
│ Score    │ 82 / 100             │
│ Grade    │ B+                   │
└──────────┴──────────────────────┘
```

### Progress Display

Check headers show percentage: `[3/36 8%] Gatekeeper & Secure Boot`

---

## Version Bump

Bump version from `1.0.0` to `2.0.0` — this is a major feature release with breaking changes (new exit codes, new check numbering).

## What Does NOT Change

- Single-file architecture (no build system, no sourcing)
- Read-only behavior (no system modifications)
- No network activity
- No external dependencies
- Markdown report as default output format
- `--show-fix` behavior
- Scoring weights (critical=-8, high=-4, medium=-2)
- `set -euo pipefail`
