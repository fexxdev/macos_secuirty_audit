# CLAUDE.md — Development Guidelines for macos-security-audit

## Project Philosophy

This is a **read-only security audit tool**. It must never modify the user's system. The script only reads settings and produces a report. All fix commands are presented as suggestions the user must run manually.

---

## Critical Safety Rules

### 1. Never Run Destructive Commands

The script must **never** execute commands that modify system state. This includes:

- `defaults write` / `defaults delete`
- `launchctl unload` / `launchctl load`
- `rm`, `mv`, `cp` on system files
- `sudo` anything
- `killall`, `kill`
- `sysctl -w`
- Any `curl`, `wget`, or network requests

Fix commands belong **only** inside quoted strings shown to the user (in `show_fix()` calls and report text). They are never executed by the script.

### 2. Never Leak Sensitive Data

- **Never print** passwords, tokens, secrets, or private key contents to stdout or the report.
- SSH key fingerprints are acceptable; key content is not.
- Serial numbers appear in the report header (the user chose to generate it). Do not add new PII.
- Do not read file contents of keychains, credentials, browser data, etc.
- Do not enumerate or display the _contents_ of `authorized_keys` — only count the lines.

### 3. No Network Activity

- The script must work fully offline.
- No telemetry, analytics, or update checks.
- No `curl`, `wget`, `fetch`, `nc`, or any outbound connections.
- No DNS lookups (the script reads DNS _configuration_, it does not resolve anything).

### 4. No Dependencies

- Pure Bash + standard macOS system utilities only.
- No Homebrew, pip, npm, or any package manager at runtime.
- Tools used: `defaults`, `csrutil`, `fdesetup`, `spctl`, `lsof`, `sysctl`, `system_profiler`, `systemsetup`, `sw_vers`, `dscl`, `stat`, `security`, `bioutil`, `softwareupdate`, `scutil`, `launchctl list` (read-only), `ps`, `grep`, `awk`, `sed`, `tmutil`, `pmset`, `profiles`, `pwpolicy`, `sqlite3`.

---

## Code Quality Standards

### Shell

- `set -euo pipefail` must remain at the top.
- Quote all variables: `"$VAR"` not `$VAR`.
- Use `||true` or `|| echo ""` for commands that may fail on some systems.
- Always provide a 2>/dev/null fallback for `defaults read` and similar.
- Test on both Intel and Apple Silicon Macs.
- Test on at least macOS Sonoma (14) and Sequoia (15).

### Output

- Terminal output uses colour codes via the `PASS`, `FAIL`, `WARN`, `INFO` variables.
- Report output is clean Markdown with no ANSI escapes.
- Every finding must have: a one-line summary (first arg) and a detailed explanation with fix (second arg).

### Adding a New Check

1. Increment `TOTAL_CHECKS` at the top.
2. Create a new `check_<category>_<name>()` function following the standardised pattern.
3. Use `pass()`, `critical()`, `high()`, or `medium()` to record the finding.
4. Add a `show_fix` call for the `--show-fix` flag, followed by the corresponding `_record_<severity>_json` call.
5. Add the function call in the execution block with the next check number.
6. Update `check_category()`, `list_checks()`, and `usage()` with the new check.
7. Update the checks table in `README.md`.
8. Add a release note entry.

---

## Development Workflow

### Testing Changes

```bash
# Run the audit locally (generates a report in cwd)
./bin/macos-security-audit

# Run with fix suggestions visible
./bin/macos-security-audit --show-fix

# Check for shell issues
shellcheck bin/macos-security-audit
```

### Before Committing

- [ ] No `defaults write`, `rm`, `sudo`, or destructive commands outside of quoted fix strings
- [ ] No network calls added
- [ ] No new dependencies introduced
- [ ] `shellcheck` passes (or deviations are justified)
- [ ] Report output is valid Markdown
- [ ] `--show-fix` shows correct commands for any new findings
- [ ] `TOTAL_CHECKS` matches the actual number of check sections
- [ ] Any generated `security-audit-*.md` files are NOT committed (they're in `.gitignore`)

### What Gets Committed

- `bin/macos-security-audit` — the script
- `README.md`, `ReleaseNotes.md` — documentation
- `Makefile` — install/uninstall targets
- `Formula/` — Homebrew formula
- `CLAUDE.md` — this file
- `.gitignore` — ignore patterns

### What Must Never Be Committed

- `security-audit-*.md` — these are user-generated reports that may contain machine-specific sensitive info (serial numbers, IP addresses, usernames, installed software)
- `.env`, credentials, tokens, keys
- Any binary or compiled artifact

---

## Severity Classification

| Severity | When to use | Score impact |
|----------|-------------|--------------|
| `critical()` | Immediate risk: data exposure, remote access, no encryption | -8 |
| `high()` | Significant risk: weak firewall, exposed services, stale keys | -4 |
| `medium()` | Hardening opportunity: extra admin accounts, analytics on | -2 |
| `pass()` | Check passed, no action needed | 0 |

Be conservative with severity. A `critical` should mean "fix this today or accept serious risk."

---

## AI Agent Instructions

If you are an AI agent working on this project:

1. **Never generate or suggest running the audit script as part of a code change** — it reads real system state and the output contains sensitive machine info.
2. **Never create test fixtures that contain real IPs, serial numbers, or usernames.**
3. **Never add `curl`, `wget`, or any network call to the script.**
4. **Always verify that new code is read-only** — if you add a check, it must only _read_ a setting, never _change_ one.
5. **Do not commit `security-audit-*.md` files** — they contain machine-specific data.
6. **Review the diff before committing** — ensure no sensitive output was accidentally captured.
