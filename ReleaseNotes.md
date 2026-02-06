# Release Notes

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
