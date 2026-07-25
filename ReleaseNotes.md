# Release Notes

## v3.1.0 — Trust, Persistence & Change Detection (2026-07-26)

Six new checks, a baseline diff, and attack chains. 42 checks → 48.

Every new check that interprets a system value was verified the same way: read
the value with the setting off, read it again with the setting on, and confirm
the difference — before the check was written. Two things this release could
have shipped are deliberately missing for exactly that reason; they are listed
at the bottom.

### New: `--baseline FILE`

Compare the current run against a previous `--json` report and report only what
changed:

```bash
macos-security-audit --json --output baseline.json      # week 1
macos-security-audit --baseline baseline.json           # week 2
```

```
  Changes since baseline (2026-07-19T08:02:11Z)
  Score 82 → 78    Grade B+ → B
  NEW       [11] HIGH  Services listening on all network interfaces
  RESOLVED  [3] CRITICAL  SIP is DISABLED
```

This is what turns the tool from a snapshot into a monitor: a new listening
port, a new LaunchAgent, a root CA that appeared overnight, SIP switched off
while you were not looking.

**The diff never moves the score and never changes the exit code.** "This
appeared since Tuesday" is a fact about time, not about how hardened the machine
is right now, and a grade that drifted with the age of a baseline file would
mean nothing. A `--category` run filters the baseline through the same category
predicate, so checks that did not run are not reported as resolved.

The diff appears in all three outputs — terminal, Markdown (`## Changes Since
Baseline`) and JSON (a `baseline` object, `null` when the flag is absent).

### New: attack chains

Some findings are worse together than apart. FileVault off is bad and auto-login
is bad; together they mean whoever picks the Mac up is at your desktop, and
whoever pulls the drive out reads it elsewhere — both barriers gone at once.
Scoring each check in isolation has no way to say that.

Five chains ship in this release:

1. FileVault off **+** auto-login on
2. SSH listening **+** firewall off
3. SIP off **+** Gatekeeper off
4. A trusted root CA **+** non-local IPs pinned in `/etc/hosts`
5. mkcert's CA private key readable **+** that CA trusted as a root

**A chain deducts nothing.** Every finding it references has already cost the
score what it costs; charging twice would make the grade depend on how many
chains happen to have been written down. What a chain changes is the order worth
fixing things in — which is the part the severity column was never able to tell
you.

### New checks (43–48)

- **43 · Trusted Root Certificates** — enumerates the admin and user trust
  domains from `security dump-trust-settings`. A certificate trusted as a root
  CA can sign for any hostname your Mac will accept. Apple's own 157-cert system
  store is deliberately not enumerated; it is not the interesting part.
  `kSecTrustSettingsResultDeny` is reported as what it is — an improvement — and
  a certificate with no `Result Type` (which is how the user domain prints them)
  is reported as *unstated* rather than assumed to grant root trust.
- **44 · Startup & Login Items** — `/Library/LaunchAgents` (the system-wide path
  the existing check 33 did not cover) plus `LoginHook`/`LogoutHook`, which run
  arbitrary scripts at every login and logout.
- **45 · Shell Startup Files** — `~/.zshrc`, `~/.zprofile`, `~/.bashrc` and six
  siblings, plus the `/etc` copies. A file anyone can write to is code execution
  as you on the next terminal window. Only the filename and which pattern
  matched are ever reported — never the matching line. Shell startup files are
  where people keep API tokens, and a security report that leaks one has made
  things worse.
- **46 · Sudo Configuration** — drop-ins in `/etc/sudoers.d/`, flagged when one
  grants `NOPASSWD`. Filenames only, never contents. `/etc/sudoers` itself is
  mode 0440 root:wheel and out of reach without root; the check says so.
- **47 · Login Authorization Plugins** — the `system.login.console` mechanism
  chain. Third-party login plugins (JAMF Connect, NoMAD, Okta) see the password
  as it is typed. Bundles in `/Library/Security/SecurityAgentPlugins` that are
  registered but not in the chain are reported separately — that is usually
  uninstall residue, and it is worth knowing which.
- **48 · Browser Extensions** — Chromium-family extensions across ten profile
  roots, with the high-impact permissions each one declares (`<all_urls>`,
  `debugger`, `nativeMessaging`, `cookies`, `webRequest`, …). Read offline from
  each extension's own `manifest.json`; `__MSG_` names are resolved through the
  extension's `_locales` so the report shows "1Password – Password Manager", not
  a 32-character ID.

### Fixes

- **The Markdown report crashed when nothing passed.** Under `set -u`, bash 3.2
  treats `"\${PASSES[@]}"` on an empty array as an unbound variable. A
  `--category` run where every check fails is not hypothetical.

### Internal

- The test suite grew from 74 to 117 tests, covering every new helper, the
  baseline diff, and all five attack chains from both sides — including that a
  chain never fires on a passing check and never moves the score.
- shellcheck is clean at `-S style`, its strictest level, for both the script
  and the test suite. The CI job that ran it was marked `continue-on-error` and
  had been failing silently; the flag is gone and the job is now binding.
- `ps aux | grep` for VPN processes replaced with `pgrep -if`.

### Deliberately not shipped

Two things that would have looked good in this list and are not in it:

- **CIS macOS Benchmark identifiers.** Anchoring the score to a published
  benchmark instead of the current `-8/-4/-2` is the right idea. Writing
  "CIS 2.4.1" next to a check without the benchmark document in hand is
  fabrication, and this project has spent a release fixing exactly that class of
  mistake. It stays out until the mapping can be checked against the source.
- **Firefox extensions.** Check 48 covers the Chromium family only. There is no
  Firefox profile on the machine this was developed on, so the `.xpi` and
  `extensions.json` parsing could not be verified against real data — and an
  unverified parser in a security tool reports confident nonsense. The gap is
  stated in the check's own output rather than hidden. Safari extensions have
  the same status: their container is SIP-protected and not readable.

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
