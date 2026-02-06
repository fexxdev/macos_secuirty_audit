# macos-security-audit

Comprehensive macOS security audit tool that runs 20 checks and generates a Markdown report with a letter grade.

```
╔══════════════════════════════════════════════════════╗
║         macOS Security Audit — 2026-02-06            ║
╚══════════════════════════════════════════════════════╝

  Machine : Mac16,1 (Apple M4 Pro)
  macOS   : 26.0 (25A5279a)

  PASS  FileVault is ON
  PASS  SIP is enabled
  PASS  Gatekeeper is enabled
  FAIL  Firewall is DISABLED
  WARN  Stealth Mode is OFF
  ...

  Findings:  2 critical  3 high  4 medium  11 pass
  Grade:     B+ (80/100)
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

# Combine flags
macos-security-audit --show-fix --output report.md

# Help
macos-security-audit --help
```

## `--show-fix`

When `--show-fix` is passed, every finding prints a copy-pasteable command block right after it:

```
  FAIL  Firewall is DISABLED

  FIX: Enable Firewall
  $ sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on
```

No interactive prompts, safe to pipe or redirect. Just copy the command you want and run it yourself.

## Checks (20)

| #  | Check | What it looks for |
|----|-------|-------------------|
| 1  | Disk Encryption (FileVault) | FileVault status |
| 2  | System Integrity Protection | SIP enabled/disabled |
| 3  | Gatekeeper & Secure Boot | Gatekeeper + boot security level |
| 4  | Firewall & Stealth Mode | Application firewall + stealth mode |
| 5  | Lockdown Mode | Apple's advanced hardening mode |
| 6  | Software Updates | Auto-updates enabled + pending patches |
| 7  | Network Exposure | Open listening ports on all interfaces + ICMP broadcast |
| 8  | Sharing Services | AirDrop, Screen Sharing, SMB, ARD, SSH |
| 9  | User Accounts & Auth | Auto-login, admin count, screen lock, keychain timeout |
| 10 | SSH Configuration | authorized_keys review, ~/.ssh permissions |
| 11 | Persistence Mechanisms | Third-party LaunchDaemons, user LaunchAgents, cron jobs |
| 12 | DNS & Network | DNS provider, /etc/hosts, VPN status |
| 13 | Certificates & Trust Store | mkcert CA key permissions |
| 14 | Installed Software Review | Offensive tools, Docker daemons, Siri voice trigger |
| 15 | Bluetooth Discoverability | Bluetooth power state + discoverability |
| 16 | Location Services | Global location services status |
| 17 | Analytics & Telemetry | Apple analytics, app developer sharing, Siri data |
| 18 | USB Restricted Mode | Accessory connection policy when locked |
| 19 | Wi-Fi Auto-Join | Auto-join open/unencrypted networks |
| 20 | Touch ID | Fingerprint enrollment status |

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
- **Terminal output** — colour-coded PASS/FAIL/WARN for each check
- **Markdown report** — structured report with findings grouped by severity, suitable for sharing or diffing over time

## License

MIT
