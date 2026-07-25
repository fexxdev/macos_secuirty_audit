# Release Notes

## v3.0.0 — Correctness, Safety & Tests (2026-07-25)

No new checks — this release makes the 42 existing ones trustworthy. Three of
the promises in the README were not actually true, and the test suite added here
now enforces every one of them on each run.

### Bug Fixes

- **`--json` produced invalid, truncated JSON.** The report writer declared
  `local first=true` outside any function; under `set -euo pipefail` that is a
  fatal error, so the script aborted mid-write and left a file ending at
  `"findings": [`. The renderer has been rewritten and the output is now
  validated by the test suite.
- **The exit code was always `1`, whatever the grade.** The `EXIT` trap ran a
  bare `kill` with an empty PID; a failing `EXIT` trap replaces the script's own
  exit status. The documented contract (`0` = A/B, `1` = C, `2` = D/F) never
  worked and now does.
- **The audit made a network call.** `softwareupdate -l` contacts Apple's
  servers, contradicting the "runs 100% locally" promise. It is now behind an
  explicit `--online`; the default path reads the values macOS itself cached.
- **The audit invoked `sudo`.** The Location Services check ran
  `sudo -n defaults read`, breaking the read-only, no-escalation rule. It now
  falls back to whether the `locationd` daemon is loaded.
- **The pending-updates check trusted a stale value.** It read
  `LastRecommendedUpdatesAvailable`, which keeps reporting `1` after the update
  has been installed. It now counts the authoritative `RecommendedUpdates` array.
- **SSH keys were miscounted.** `wc -l` counted blank lines and comments as keys
  and missed a final key with no trailing newline.
- **An unknown `--category` silently scored 100/A+** instead of failing — a
  green CI run that had audited nothing at all.
- **`--output` and `--category` consumed a missing argument**, shifting past the
  end of `$@`.
- **The spinner wrote carriage returns into piped output.** It now only animates
  on an interactive stdout.
- Gatekeeper's suggested fix used `spctl --master-enable`, removed in macOS
  Sequoia.
- Negative scores could reach the report when enough checks failed.
- `--output /dev/null` was rejected as unwritable.

### New Features

- `--online` — opt in to the single check that queries Apple for updates. Both
  the terminal header and the report state which mode was used.
- `--redact` — mask the hardware serial number in the report.
- `--opt=value` — long options now accept both forms.
- Exit code `64` (`EX_USAGE`) for invalid usage, so a CLI mistake is no longer
  indistinguishable from a failing grade.
- Output path is validated before the audit runs, not after it finishes.

### Internal Improvements

- **A single check registry.** The check number, category, title, `--help`
  listing, `--list-checks` table and run order all derive from one `CHECKS`
  array. Adding a check went from an 8-step checklist across five places to
  writing the function and appending one line.
- **A single findings store.** Every finding used to be written twice — once for
  the terminal, once for JSON — and the two copies had already drifted apart.
  `pass`/`medium`/`high`/`critical` now record once and both renderers read from
  the same data, so `--show-fix` commands finally appear in the JSON output.
- **A test suite** (`tests/run-tests.sh`, `make test`) — 90+ assertions with no
  dependencies, including static guards that fail the build if a `sudo`, a
  mutating command, a network client, or an unguarded `softwareupdate` ever
  reappears outside a string literal.
- **CI on every push** (`.github/workflows/ci.yml`) — shellcheck plus the full
  suite on macOS.
- `MSA_LIB_MODE=1` sources the script without running an audit, so the helpers
  can be unit-tested directly.
- ~130 lines removed net, despite everything above.

---

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
