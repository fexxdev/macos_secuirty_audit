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

### 3. No Network Activity Unless Explicitly Requested

- The script must work fully offline, and does so by default.
- No telemetry, analytics, or self-update checks — ever, in any mode.
- No `curl`, `wget`, `fetch`, `nc`, or any outbound connection.
- No DNS lookups (the script reads DNS _configuration_, it does not resolve anything).
- **One exception**: `softwareupdate -l` asks Apple which updates are pending. It
  is the only network-capable call in the script and it must stay inside
  `if $ONLINE_MODE; then` (the `--online` flag, off by default). The offline path
  reads the values macOS already cached. `tests/run-tests.sh` fails the build if
  the call ever appears outside that branch, or if any other network client
  appears anywhere.

### 4. No Dependencies

- Pure Bash + standard macOS system utilities only.
- No Homebrew, pip, npm, or any package manager at runtime.
- Tools used: `defaults`, `csrutil`, `fdesetup`, `spctl`, `lsof`, `sysctl`, `system_profiler`, `systemsetup`, `sw_vers`, `dscl`, `stat`, `security`, `bioutil`, `softwareupdate`, `scutil`, `launchctl list` (read-only), `pgrep`, `ps`, `grep`, `awk`, `sed`, `comm`, `sort`, `find`, `tmutil`, `pmset`, `profiles`, `pwpolicy`, `sqlite3`.
- The `--baseline` diff uses `comm` with process substitution rather than temp
  files, because `rm` is one of the commands the static guard forbids and the
  tool has no business creating files it then has to delete.

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

- Terminal output uses colour codes via the `PASS`, `FAIL`, `WARN` variables.
- Report output is clean Markdown with no ANSI escapes.
- Every finding must have: a one-line summary (first arg) and a detailed explanation with fix (second arg).
- Print through `qprint`, never bare `printf` — `--quiet` and `--json` depend on it.

### Adding a New Check

The `CHECKS` array near the top of the script is the single source of truth. The
check number, the `--category` filter, `--list-checks`, `--help` and the run
order are all derived from it.

1. Write a `check_<category>_<name>()` function following the pattern of its
   neighbours: read the setting, then call `pass()`, `critical()`, `high()` or
   `medium()` with a one-line summary and a detail paragraph, optionally followed
   by `show_fix "<description>" "<command>"`. `show_fix` attaches itself to the
   finding recorded immediately before it, so it must come right after — there is
   no separate JSON call to keep in sync.
2. Append one line to `CHECKS`: `"<n>|<category>|<title>|<function>"`.

Then update the checks table in `README.md` and add a release note entry. Run
`make check` — the test suite verifies the numbering, uniqueness, that the
function exists, and that no `check_*` function is orphaned from the registry.

---

## Development Workflow

### Testing Changes

```bash
make check     # bash -n + shellcheck + the full test suite — run this before every commit
make test      # test suite only
make lint      # syntax + shellcheck only

# Run the audit locally (generates a report in cwd)
./bin/macos-security-audit

# Run with fix suggestions visible
./bin/macos-security-audit --show-fix
```

`tests/run-tests.sh` is pure Bash and sources the script in library mode
(`MSA_LIB_MODE=1`) to test the real registry and helpers rather than a copy. It
also parses the script statically — stripping string literals and heredoc bodies
first — so a mutating command in a quoted fix string passes while the same
command in executable code fails the build.

The guards were validated by mutation testing: injecting a `sudo`, a `curl`, a
`launchctl unload`, a top-level `local`, an unguarded `softwareupdate`, a deleted
registry line, a failing `EXIT` trap and a mis-wired JSON summary field were all
caught. If you weaken a guard, re-run that exercise.

### Before Committing

- [ ] `make check` is green (this covers shellcheck, the read-only guard, the
      offline guard, the registry, the CLI contract and both report formats)
- [ ] No `defaults write`, `rm`, `sudo`, or destructive commands outside of quoted fix strings
- [ ] No network call added outside the `--online` branch
- [ ] No new dependencies introduced
- [ ] `--show-fix` shows correct commands for any new findings
- [ ] `README.md` and `ReleaseNotes.md` reflect any behaviour change
- [ ] Any generated `security-audit-*.md` / `.json` files are NOT committed (they're in `.gitignore`)

### What Gets Committed

- `bin/macos-security-audit` — the script
- `tests/run-tests.sh` — the test suite
- `.github/workflows/ci.yml` — CI
- `README.md`, `ReleaseNotes.md` — documentation
- `Makefile` — install/uninstall/lint/test targets
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

### Attack Chains

`evaluate_attack_chains()` reports combinations that are worse than the sum of
their parts. Two rules govern it:

- **A chain must never deduct from the score.** Every finding it references has
  already been counted once by the check that recorded it. Charging twice would
  make the grade depend on how many chains happen to have been written down.
- **A chain keys on the exact summary text of the findings it combines**, via
  `has_finding <check> <summary substring>`. If you reword a summary, the chain
  that depends on it stops firing — the test suite has a fixture per chain
  precisely so that this fails loudly instead of silently.

---

## Verifying a Check Before Writing It

Every check that interprets a system value must be verified against the live
system **before** the check is written:

1. Read the raw value with the setting **off**.
2. Change the setting in System Settings, read it again.
3. Confirm the difference is what you assumed it would be.

This rule exists because two shipped checks had their polarity backwards — one
read the value macOS writes when you opt *out* and reported it as opted *in*.
Coverage that grows faster than reliability is worse than no coverage: it
produces confident output that is wrong.

The corollary: **if you cannot verify it, do not ship it.** Two things are
deliberately absent for this reason and should stay absent until they can be
checked against a real source:

- **CIS macOS Benchmark identifiers.** Writing "CIS 2.4.1" next to a check
  without the benchmark document in hand is fabrication.
- **Firefox extension parsing** (check 48 covers the Chromium family only).
  There was no Firefox profile on the development machine to verify the `.xpi` /
  `extensions.json` format against. The gap is stated in the check's own output
  rather than hidden.

---

## AI Agent Instructions

If you are an AI agent working on this project:

1. **Never generate or suggest running the audit script as part of a code change** — it reads real system state and the output contains sensitive machine info.
2. **Never create test fixtures that contain real IPs, serial numbers, or usernames.**
3. **Never add `curl`, `wget`, or any network call to the script.** The single
   `softwareupdate -l` behind `--online` is the whole budget; it is not a
   precedent for a second one.
4. **Always verify that new code is read-only** — if you add a check, it must only _read_ a setting, never _change_ one.
5. **Do not commit `security-audit-*.md` files** — they contain machine-specific data.
6. **Review the diff before committing** — ensure no sensitive output was accidentally captured.
7. **Run `make check`** — do not report a change as done until it is green.
