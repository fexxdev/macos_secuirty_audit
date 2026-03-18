# Release Notes

## v2.1.0 — New Checks & Bug Fixes (2026-03-18)

### New Checks (+6, 42 total)

- FileVault Recovery Key — verifies a recovery key exists when FileVault is enabled
- Configuration Profiles — detects MDM enrollment and installed configuration profiles
- MRT / XProtect Remediator — verifies background malware removal tools are present
- Password Policy — checks if a custom password policy is enforced
- Privacy Permissions (TCC) — audits Camera, Microphone, Screen Recording, Accessibility, Full Disk Access grants
- Safari Privacy & Security — fraudulent site warnings, Do Not Track, search engine choice

### Bug Fixes

- XProtect date parsing now handles multiple locale formats (ISO, US, EU) instead of assuming US English
- Network exposure `lsof` parsing uses `$(NF-1)` instead of hardcoded field 9 for robustness
- Login window password hint check validates numeric input before comparison

### Improvements

- Expanded LaunchAgent whitelist (1Password, Raycast, Spotify, Dropbox, Microsoft, Adobe, Docker, NordVPN, LuLu, Malwarebytes, Grammarly, Firefox, Brave)

---

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

- `--json` — JSON output format for scripting and dashboards
- `--category` — run only checks in specific categories (encryption, system, network, sharing, auth, privacy, software)
- `--quiet` — suppress terminal output, print only the grade
- `--no-color` — disable ANSI colour codes (auto-detected when piping)
- `--version` — print version and exit
- `--list-checks` — list all 36 checks with categories
- Exit codes reflect grade (0 = A/B, 1 = C, 2 = D/F)
- Terminal summary table with boxed layout at completion
- Progress percentage in check headers (e.g., `[3/36 8%]`)

### Internal Improvements

- All checks refactored into named functions (`check_<category>_<name>`)
- Category-based organization (7 categories)
- Standardised check pattern across all 36 checks
- Docker and Siri voice trigger split into dedicated checks
- Certificates check merged into Installed Software & Persistence
- JSON escaping helper for safe structured output
- Quiet-mode aware output functions
- Spinner respects quiet mode

---

## v1.0.0 — Initial Release (2026-02-06)

First public release of `macos-security-audit`.

### Features

- **20 security checks** covering disk encryption, firewall, SIP, Gatekeeper, network exposure, sharing services, user accounts, persistence mechanisms, credentials, and more
- **Markdown report generation** — structured report with findings grouped by severity (Critical / High / Medium / Pass)
- **Letter-grade scoring** — overall security posture from A+ to F, starting at 100 and deducting per finding
- **`--show-fix` flag** — prints copy-pasteable fix commands after each finding in the terminal
- **`--output` flag** — custom output path for the Markdown report
- **TeamViewer detection** — dedicated critical finding with full uninstall instructions when TeamViewer LaunchDaemons are found
- **Terminal-friendly output** — colour-coded PASS/FAIL/WARN with detailed lists for LaunchAgents, listening services, and installed tools

### Checks Performed

| #  | Check |
|----|-------|
| 1  | Disk Encryption (FileVault) |
| 2  | System Integrity Protection (SIP) |
| 3  | Gatekeeper & Secure Boot |
| 4  | Firewall & Stealth Mode |
| 5  | Lockdown Mode |
| 6  | Software Updates |
| 7  | Network Exposure |
| 8  | Sharing Services |
| 9  | User Accounts & Authentication |
| 10 | SSH Configuration |
| 11 | Persistence Mechanisms |
| 12 | DNS & Network |
| 13 | Certificates & Trust Store |
| 14 | Installed Software Review |
| 15 | Bluetooth Discoverability |
| 16 | Location Services |
| 17 | Analytics & Telemetry Sharing |
| 18 | USB Restricted Mode |
| 19 | Wi-Fi Auto-Join for Open Networks |
| 20 | Touch ID |

### Install Methods

- **Homebrew tap** — `brew tap fexxdev/macos-security-audit && brew install macos-security-audit`
- **Make** — `make install`
- **Manual** — run directly from `./bin/macos-security-audit`
