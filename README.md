# macos-security-audit

Comprehensive macOS security audit tool that runs 42 checks and generates a Markdown (or JSON) report with a letter grade.

```
╔══════════════════════════════════════════════════════╗
║         macOS Security Audit — 2026-03-18            ║
╚══════════════════════════════════════════════════════╝

  Machine : Mac16,1 (Apple M4 Pro)
  macOS   : 15.3 (24D60)

[1/42 2%] Disk Encryption (FileVault)
  PASS  FileVault is ON
[2/42 4%] Time Machine Backup & Encryption
  PASS  Time Machine is enabled with encrypted backup
  ...

┌─────────────────────────────────────┐
│       Security Audit Complete        │
├────────────┬────────────────────────┤
│ CRITICAL   │ 1                      │
│ HIGH       │ 3                      │
│ MEDIUM     │ 4                      │
│ PASS       │ 28                     │
├────────────┼────────────────────────┤
│ Score      │ 78 / 100               │
│ Grade      │ B+                     │
└────────────┴────────────────────────┘
```

## Install

### Homebrew

```bash
brew tap fexxdev/macos-security-audit https://github.com/fexxdev/macos-security-audit
brew install macos-security-audit
```

### Make

```bash
git clone https://github.com/fexxdev/macos-security-audit.git
cd macos-security-audit
make install          # installs to /usr/local/bin
# make uninstall      # removes it
```

### Manual

```bash
git clone https://github.com/fexxdev/macos-security-audit.git
cd macos-security-audit
./bin/macos-security-audit
```

## Usage

```bash
# Run audit with default output (./security-audit-YYYY-MM-DD.md)
macos-security-audit

# Show copy-pasteable fix commands after each finding
macos-security-audit --show-fix

# Custom output path
macos-security-audit --output ~/Desktop/audit.md

# JSON output
macos-security-audit --json
macos-security-audit --json --output report.json

# Run only specific categories
macos-security-audit --category encryption,network

# Quiet mode — print only the grade
macos-security-audit --quiet

# Disable colours (auto-detected when piping)
macos-security-audit --no-color

# List all checks
macos-security-audit --list-checks

# Print version
macos-security-audit --version

# Combine flags
macos-security-audit --show-fix --output report.md
macos-security-audit --json --quiet
```

## `--show-fix`

When `--show-fix` is passed, every finding prints a copy-pasteable command block right after it:

```
  FAIL  Firewall is DISABLED

  FIX: Enable Firewall
  $ sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on
```

No interactive prompts, safe to pipe or redirect. Just copy the command you want and run it yourself.

## `--json`

Outputs the report as a JSON object instead of Markdown:

```json
{
  "version": "2.0.0",
  "score": 82,
  "grade": "B+",
  "summary": { "critical": 0, "high": 2, "medium": 5, "pass": 35, "total": 42 },
  "findings": [...]
}
```

## `--category`

Run only checks in specific categories. Categories: `encryption`, `system`, `network`, `sharing`, `auth`, `privacy`, `software`.

```bash
macos-security-audit --category encryption        # only encryption checks
macos-security-audit --category network,sharing    # network + sharing
```

When filtering, the report includes a "Partial audit" disclaimer.

## Exit Codes

| Grade | Exit Code |
|-------|-----------|
| A+, A, A-, B+, B, B- | 0 |
| C+, C, C- | 1 |
| D+, D, D-, F | 2 |

Useful for CI/scripting: `macos-security-audit --quiet && echo "OK" || echo "Issues found"`

## Checks (42)

### Encryption

| #  | Check | What it looks for |
|----|-------|-------------------|
| 1  | Disk Encryption (FileVault) | FileVault status |
| 2  | Time Machine Backup & Encryption | Backup enabled + encryption status |
| 37 | FileVault Recovery Key | Recovery key existence for data recovery |

### System

| #  | Check | What it looks for |
|----|-------|-------------------|
| 3  | System Integrity Protection | SIP enabled/disabled |
| 4  | Gatekeeper & Secure Boot | Gatekeeper + boot security level |
| 5  | Lockdown Mode | Apple's advanced hardening mode |
| 6  | Rapid Security Response | Auto-install of critical patches |
| 7  | XProtect Definitions | Malware definition freshness |
| 8  | Kernel Extensions | Third-party kexts loaded |
| 9  | Find My Mac | Remote locate/lock/erase capability |
| 38 | Configuration Profiles | MDM enrollment + installed configuration profiles |
| 39 | MRT / XProtect Remediator | Background malware removal tool presence |

### Network

| #  | Check | What it looks for |
|----|-------|-------------------|
| 10 | Firewall & Stealth Mode | Application firewall + stealth mode |
| 11 | Network Exposure | Open listening ports on all interfaces + ICMP broadcast |
| 12 | DNS & Network | DNS provider, /etc/hosts, VPN status |
| 13 | Wi-Fi Auto-Join | Auto-join open/unencrypted networks |
| 14 | Internet Sharing | NAT/routing enabled |
| 15 | Wake on Network Access | Remote wake capability |

### Sharing

| #  | Check | What it looks for |
|----|-------|-------------------|
| 16 | Sharing Services | AirDrop, Screen Sharing, SMB, ARD, SSH |
| 17 | Remote Apple Events | AppleScript remote execution |
| 18 | Content Caching | Apple content sharing on network |
| 19 | Printer Sharing | Shared printers on network |
| 20 | Media Sharing | Home Sharing / media library |
| 21 | Handoff | Cross-device activity sharing |

### Auth

| #  | Check | What it looks for |
|----|-------|-------------------|
| 22 | User Accounts & Auth | Auto-login, admin count, screen lock, keychain timeout |
| 23 | SSH Configuration | authorized_keys review, ~/.ssh permissions |
| 24 | Screen Saver Timeout | Auto-lock timing |
| 25 | Login Window Configuration | Username list, password hints |
| 26 | Touch ID | Fingerprint enrollment status |
| 27 | USB Restricted Mode | Accessory connection policy when locked |
| 40 | Password Policy | Password complexity and policy enforcement |

### Privacy

| #  | Check | What it looks for |
|----|-------|-------------------|
| 28 | Location Services | Global location services status |
| 29 | Analytics & Telemetry | Apple analytics, app developer sharing, Siri data |
| 30 | Bluetooth Discoverability | Bluetooth power state + discoverability |
| 31 | Siri Voice Trigger | Always-on microphone listening |
| 41 | Privacy Permissions (TCC) | Camera, Microphone, Screen Recording, Accessibility, FDA grants |

### Software

| #  | Check | What it looks for |
|----|-------|-------------------|
| 32 | Software Updates | Auto-updates enabled + pending patches |
| 33 | Installed Software & Persistence | Offensive tools, LaunchDaemons, LaunchAgents, cron, mkcert CA |
| 34 | Safari Safe File Auto-Open | Auto-open "safe" downloads |
| 35 | Secure Keyboard Entry | Terminal keystroke interception protection |
| 36 | Docker Daemons | Root-level Docker LaunchDaemons |
| 42 | Safari Privacy & Security | Fraud warnings, tracking prevention, search engine |

## Scoring

Each finding deducts from a starting score of 100:

| Severity | Deduction |
|----------|-----------|
| CRITICAL | -8 |
| HIGH | -4 |
| MEDIUM | -2 |

The final score maps to a letter grade (A+ through F).

## Output

The audit produces:
- **Terminal output** — colour-coded PASS/FAIL/WARN for each check with progress percentage
- **Markdown report** — structured report with findings grouped by severity, suitable for sharing or diffing over time
- **JSON report** — machine-readable output for scripting and dashboards (via `--json`)
- **Terminal summary table** — boxed severity counts with grade at completion

## Vibecoded & Transparent

This project was built with AI assistance ("vibecoded"). Every line of code is open source and auditable. Here's what we do to make sure it's completely free of harm:

- **Read-only by design** — the script only _reads_ system settings. It never changes, writes, or deletes anything on your machine unless you manually copy-paste a fix command yourself.
- **No network calls** — nothing is phoned home, uploaded, or sent anywhere. The audit runs 100% locally.
- **No dependencies** — pure Bash using only standard macOS system utilities (`defaults`, `csrutil`, `fdesetup`, `lsof`, etc.). No pip, no npm, no curl at runtime.
- **Full source visibility** — the entire tool is a single shell script you can read end-to-end in minutes.
- **Output stays local** — the Markdown report is written to your working directory. It never leaves your machine.
- **Deterministic** — same system state → same report. No random behaviour, no telemetry, no analytics.

If you find anything concerning, please open an issue. We take this seriously.

## License

MIT
