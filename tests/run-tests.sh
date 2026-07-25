#!/usr/bin/env bash
###############################################################################
# Test suite for macos-security-audit
#
# Pure Bash, no dependencies — same constraint as the tool itself. shellcheck
# and python3 are used when present and skipped (not failed) when they are not.
#
# The audit is read-only, so running it here is safe. Reports are written to a
# temp dir with --redact and are never printed, so no machine identifiers ever
# reach the test output.
#
#   ./tests/run-tests.sh
###############################################################################

# Deliberately no `-e`: one failing assertion must not hide the other results.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AUDIT="$ROOT/bin/macos-security-audit"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/msa-tests.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

PASSED=0
FAILED=0
SKIPPED=0

if [[ -t 1 ]]; then
    G=$'\033[0;32m'; R=$'\033[0;31m'; Y=$'\033[0;33m'; DIM=$'\033[2m'; N=$'\033[0m'
else
    G=""; R=""; Y=""; DIM=""; N=""
fi

ok()   { PASSED=$((PASSED + 1)); printf '  %sPASS%s  %s\n' "$G" "$N" "$1"; }
bad()  { FAILED=$((FAILED + 1)); printf '  %sFAIL%s  %s\n' "$R" "$N" "$1"
         [[ -n "${2:-}" ]] && printf '        %s%s%s\n' "$DIM" "$2" "$N"; return 0; }
skip() { SKIPPED=$((SKIPPED + 1)); printf '  %sSKIP%s  %s\n' "$Y" "$N" "$1"; }
group(){ printf '\n%s\n' "$1"; }

# assert_eq <label> <expected> <actual>
assert_eq() {
    if [[ "$2" == "$3" ]]; then ok "$1"; else bad "$1" "expected '$2', got '$3'"; fi
}

# assert_contains <label> <needle> <haystack>
assert_contains() {
    case "$3" in
        *"$2"*) ok "$1" ;;
        *)      bad "$1" "missing: $2" ;;
    esac
}

# assert_empty <label> <value>  — for "this list of violations must be empty"
assert_empty() {
    if [[ -z "$2" ]]; then ok "$1"; else bad "$1" "$(printf '%s' "$2" | tr '\n' ' ')"; fi
}

# assert_exit <label> <expected code> <args...>
assert_exit() {
    local label="$1" want="$2"; shift 2
    local out rc
    out=$("$AUDIT" "$@" 2>&1); rc=$?
    if [[ "$rc" == "$want" ]]; then
        ok "$label"
    else
        bad "$label" "exit $rc (wanted $want): $(printf '%s' "$out" | head -1)"
    fi
}

###############################################################################
group "Static analysis"
###############################################################################

if bash -n "$AUDIT" 2>"$WORK/syntax.err"; then
    ok "bash -n parses cleanly"
else
    bad "bash -n parses cleanly" "$(cat "$WORK/syntax.err")"
fi

if command -v shellcheck >/dev/null 2>&1; then
    if shellcheck -S warning "$AUDIT" >"$WORK/shellcheck.out" 2>&1; then
        ok "shellcheck (warning and above) is clean"
    else
        bad "shellcheck (warning and above) is clean" "$(head -20 "$WORK/shellcheck.out")"
    fi
else
    skip "shellcheck not installed"
fi

# `local` outside a function is a hard error that only fires when that line is
# reached — it shipped once and silently broke --json for a whole release.
LOCAL_ESCAPES=$(awk '
    /^[A-Za-z_][A-Za-z0-9_]*\(\)[[:space:]]*\{/ { if ($0 !~ /\}[[:space:]]*$/) infn = 1; next }
    /^\}/                                       { infn = 0; next }
    /^[[:space:]]*local[[:space:]]/             { if (!infn) print "line " FNR }
' "$AUDIT")
assert_empty "no 'local' outside a function body" "$LOCAL_ESCAPES"

# The read-only, offline promise is enforced here rather than by review.
#
# Every fix the tool suggests is a `sudo`-flavoured string shown to the user, so
# a naive grep would drown in false positives. This strips string literals
# first, with a small lexer that carries quote state across lines (the detail
# arguments are multi-line strings) and stops at a `#` that starts a comment.
# What survives is the code the script actually executes.
STRIP_STRINGS='
function strip(s,   i, n, ch, out) {
    n = length(s); out = ""
    for (i = 1; i <= n; i++) {
        ch = substr(s, i, 1)
        if (ch == "\\") { i++; continue }                       # escaped char
        if (q == 0 && ch == "\"") { q = 1; continue }
        if (q == 0 && ch == "'"'"'") { q = 2; continue }
        if (q == 1 && ch == "\"") { q = 0; continue }
        if (q == 2 && ch == "'"'"'") { q = 0; continue }
        if (q != 0) continue
        if (ch == "#") break                                    # comment
        out = out ch
    }
    return out
}
BEGIN { q = 0 }
# Heredoc bodies are data, not code, and the usage text and report markdown they
# carry are full of apostrophes that would otherwise desync the quote tracking.
heredoc == "" && $0 !~ /<<</ && match($0, /<<-?[[:space:]]*[^ \t;&|<>]+/) {
    tag = substr($0, RSTART, RLENGTH)
    gsub(/[^A-Za-z0-9_]/, "", tag)
    if (tag != "") { heredoc = tag; next }
}
heredoc != "" {
    body = $0
    sub(/^[[:space:]]+/, "", body)
    if (body == heredoc) heredoc = ""
    next
}
'
MUTATIONS=$(awk "$STRIP_STRINGS"'
{
    code = strip($0)
    if (code ~ /(^|[^[:alnum:]_])sudo([^[:alnum:]_]|$)/)                                                   print "line " FNR ": sudo"
    if (code ~ /defaults[[:space:]]+(write|delete)/)                                                       print "line " FNR ": defaults write/delete"
    if (code ~ /launchctl[[:space:]]+(load|unload|bootout|bootstrap|enable|disable|kickstart|remove)/)      print "line " FNR ": launchctl mutate"
    if (code ~ /(^|[^[:alnum:]_\/])(curl|wget|telnet|scp|sftp|nslookup|dig)([^[:alnum:]_]|$)/)             print "line " FNR ": network client"
    if (code ~ /sysctl[[:space:]]+-w/)                                                                     print "line " FNR ": sysctl -w"
    if (code ~ /(^|[^[:alnum:]_\/])(rm|mv|chmod|chown|chflags|dd|tee)([^[:alnum:]_]|$)/)                    print "line " FNR ": filesystem mutation"
    if (code ~ /(^|[^[:alnum:]_])killall([^[:alnum:]_]|$)/)                                                print "line " FNR ": killall"
    if (code ~ /(fdesetup|spctl|csrutil|tmutil|profiles|pwpolicy|systemsetup|pmset|nvram|bioutil)[[:space:]]+-*(enable|disable|remove|delete|install|changerecovery|master|set)/) print "line " FNR ": privileged mutation"
    # The spinner subshell is the one process this script may kill.
    if (code ~ /(^|[^[:alnum:]_])kill([^[:alnum:]_]|$)/ && $0 !~ /SPINNER_PID/)                            print "line " FNR ": kill"
}
' "$AUDIT")
assert_empty "no mutating or network command outside a string literal" "$MUTATIONS"

# The single network-capable call must stay behind --online. If it ever drifts
# out of that branch, the offline guarantee in the README quietly becomes false.
SU_UNGUARDED=""
for _line in $(awk "$STRIP_STRINGS"'{ if (strip($0) ~ /softwareupdate/) print FNR }' "$AUDIT"); do
    _prev=$(sed -n "$((_line - 1))p" "$AUDIT" | tr -d '[:space:]')
    [[ "$_prev" == 'if$ONLINE_MODE;then' ]] || SU_UNGUARDED="${SU_UNGUARDED}line ${_line} "
done
assert_empty "softwareupdate runs only inside 'if \$ONLINE_MODE'" "$SU_UNGUARDED"

###############################################################################
group "CLI contract"
###############################################################################

FILE_VERSION=$(awk -F'"' '/^VERSION=/ { print $2; exit }' "$AUDIT")
CLI_VERSION=$("$AUDIT" --version 2>&1 | awk '{ sub(/^v/, "", $NF); print $NF }')
assert_eq "--version matches VERSION in the script" "$FILE_VERSION" "$CLI_VERSION"

HELP=$("$AUDIT" --help 2>&1); HELP_RC=$?
assert_eq "--help exits 0" "0" "$HELP_RC"
for _flag in --show-fix --output --json --category --quiet --no-color --redact --online --list-checks --version; do
    assert_contains "--help documents $_flag" "$_flag" "$HELP"
done
assert_contains "--help documents the exit codes" "EXIT CODES" "$HELP"

assert_exit "unknown flag exits 64"          64 --nope
assert_exit "unknown category exits 64"      64 --category bogus
assert_exit "--category with no value exits 64" 64 --category
assert_exit "--output with no value exits 64"  64 --output
assert_exit "unwritable output dir exits 64"   64 --output /nonexistent-dir-msa/report.md
assert_exit "output path that is a dir exits 64" 64 --output "$WORK"

# --opt=value must behave exactly like --opt value.
OUT_EQ="$WORK/eq.md"
"$AUDIT" --category=encryption --output="$OUT_EQ" --quiet --redact >/dev/null 2>&1
if [[ -s "$OUT_EQ" ]]; then ok "--opt=value form is accepted"; else bad "--opt=value form is accepted"; fi

QUIET_OUT=$("$AUDIT" --category encryption --quiet --redact --output "$WORK/q.md" 2>&1)
assert_eq "--quiet prints exactly one line" "1" "$(printf '%s\n' "$QUIET_OUT" | wc -l | tr -d ' ')"
if [[ "$QUIET_OUT" =~ ^[ABCDF][+-]?\ \([0-9]+/100\)$ ]]; then
    ok "--quiet prints 'GRADE (score/100)'"
else
    bad "--quiet prints 'GRADE (score/100)'" "got '$QUIET_OUT'"
fi

# Exit code must follow the grade — this was broken by a failing EXIT trap.
GRADE_ONLY="${QUIET_OUT%% *}"
case "$GRADE_ONLY" in
    A+|A|A-|B+|B|B-) WANT_RC=0 ;;
    C+|C|C-)         WANT_RC=1 ;;
    *)               WANT_RC=2 ;;
esac
"$AUDIT" --category encryption --quiet --redact --output "$WORK/rc.md" >/dev/null 2>&1
assert_eq "exit code follows the grade ($GRADE_ONLY)" "$WANT_RC" "$?"

# Piped output must be free of terminal control sequences.
PIPED=$("$AUDIT" --category encryption --no-color --redact --output "$WORK/p.md" 2>&1)
case "$PIPED" in
    *$'\033'*) bad "--no-color output has no ANSI escapes" ;;
    *)         ok "--no-color output has no ANSI escapes" ;;
esac
case "$PIPED" in
    *$'\r'*) bad "piped output has no spinner carriage returns" ;;
    *)       ok "piped output has no spinner carriage returns" ;;
esac

###############################################################################
group "Check registry"
###############################################################################

# Sourcing in library mode gives the tests the real registry and helpers instead
# of a second copy that could drift. The audit sets `-e` and installs its own
# EXIT trap on the way in, so both are restored right after. MSA_LIB_MODE stays
# unexported and is cleared immediately — an inherited copy would put every
# later child invocation into library mode too.
# shellcheck disable=SC2034  # read by the sourced script, not by this one
MSA_LIB_MODE=1
# shellcheck disable=SC1090
source "$AUDIT"
unset MSA_LIB_MODE
set +e
trap 'rm -rf "$WORK"' EXIT

if (( TOTAL_CHECKS > 0 )); then ok "registry is not empty ($TOTAL_CHECKS checks)"; else bad "registry is not empty"; fi

REG_ERRORS=""
_seen=""
_expected=1
for _entry in "${CHECKS[@]}"; do
    IFS='|' read -r _num _cat _title _fn <<< "$_entry"
    [[ "$_num" =~ ^[0-9]+$ ]] || REG_ERRORS="${REG_ERRORS}non-numeric id '$_num'"$'\n'
    [[ "$_num" == "$_expected" ]] || REG_ERRORS="${REG_ERRORS}id $_num out of sequence (expected $_expected)"$'\n'
    case " $_seen " in *" $_num "*) REG_ERRORS="${REG_ERRORS}duplicate id $_num"$'\n' ;; esac
    _seen="$_seen $_num"
    _expected=$((_expected + 1))
    [[ -n "$_title" ]] || REG_ERRORS="${REG_ERRORS}check $_num has no title"$'\n'
    _known=false
    for _c in "${CATEGORIES[@]}"; do [[ "$_cat" == "$_c" ]] && _known=true; done
    $_known || REG_ERRORS="${REG_ERRORS}check $_num has unknown category '$_cat'"$'\n'
    declare -f "$_fn" >/dev/null 2>&1 || REG_ERRORS="${REG_ERRORS}check $_num points at undefined function '$_fn'"$'\n'
done
assert_empty "registry ids are 1..N, unique, titled, categorised and implemented" "$REG_ERRORS"

# ...and nothing is implemented but forgotten in the registry.
ORPHANS=""
while read -r _fn; do
    case "$_fn" in
        check_field|check_category|check_title|check_header) continue ;;
    esac
    case " ${CHECKS[*]} " in
        *"|$_fn "*) ;;
        *) ORPHANS="${ORPHANS}$_fn " ;;
    esac
done <<< "$(awk '/^check_[a-z_]+\(\)[[:space:]]*\{/ { sub(/\(\).*/, ""); print }' "$AUDIT")"
assert_empty "every check_* function is wired into the registry" "$ORPHANS"

LIST_ROWS=$("$AUDIT" --list-checks | awk 'NR > 2 && NF > 0' | wc -l | tr -d ' ')
assert_eq "--list-checks lists every check" "$TOTAL_CHECKS" "$LIST_ROWS"

HELP_ROWS=$(printf '%s\n' "$HELP" | awk '/^[[:space:]]+[0-9]+[[:space:]]+[A-Z]/' | wc -l | tr -d ' ')
assert_eq "--help lists every check" "$TOTAL_CHECKS" "$HELP_ROWS"

###############################################################################
group "Helper functions"
###############################################################################

# Every 5-point boundary, from both sides — an off-by-one here silently changes
# the exit code the tool reports to CI.
GRADE_ERRORS=""
while read -r _score _want; do
    _got=$(letter_grade "$_score")
    [[ "$_got" == "$_want" ]] || GRADE_ERRORS="${GRADE_ERRORS}$_score -> $_got (want $_want)"$'\n'
done <<'BOUNDARIES'
100 A+
95 A+
94 A
90 A
89 A-
85 A-
84 B+
80 B+
79 B
75 B
74 B-
70 B-
69 C+
65 C+
64 C
60 C
59 C-
55 C-
54 D+
50 D+
49 D
45 D
44 D-
40 D-
39 F
0 F
BOUNDARIES
assert_empty "letter_grade is correct at every boundary" "$GRADE_ERRORS"
assert_eq "letter_grade clamps negatives to F" "F" "$(letter_grade -20)"

assert_eq "json_escape escapes quotes and backslashes" 'a\"b\\c' "$(json_escape 'a"b\c')"
assert_eq "json_escape escapes newlines and tabs" 'a\nb\tc' "$(json_escape "$(printf 'a\nb\tc')")"

# The three sentences socketfilterfw actually prints. Only one contains the
# word "enabled", and it is not the strictest setting — matching on that word
# reported a Mac in state 2 (block all incoming) as a CRITICAL finding.
assert_eq "firewall_state reads state 0" "0" \
    "$(firewall_state 'Firewall is disabled. (State = 0)')"
assert_eq "firewall_state reads state 1" "1" \
    "$(firewall_state 'Firewall is enabled. (State = 1)')"
assert_eq "firewall_state reads state 2 (the strictest setting)" "2" \
    "$(firewall_state 'Firewall is blocking all non-essential incoming connections. (State = 2)')"
# No "(State = N)" suffix: fall back to the sentence.
assert_eq "firewall_state falls back to the sentence" "2" \
    "$(firewall_state 'Firewall is blocking all non-essential incoming connections.')"
# A failed command must not read as "disabled" — that is a false CRITICAL.
assert_eq "firewall_state reports unknown on empty output" "unknown" "$(firewall_state '')"
assert_eq "firewall_state reports unknown on garbage" "unknown" "$(firewall_state 'command not found')"

assert_eq "days_label 1 is singular"  "1 day"   "$(days_label 1)"
assert_eq "days_label 0 is plural"    "0 days"  "$(days_label 0)"
assert_eq "days_label 42 is plural"   "42 days" "$(days_label 42)"

assert_eq "check_field resolves a category" "auth" "$(check_field 23 1)"
assert_eq "check_field resolves a title" "SSH Configuration" "$(check_field 23 2)"
assert_eq "check_field resolves a function" "check_auth_ssh" "$(check_field 23 3)"

# shellcheck disable=SC2034  # read by the sourced should_run_check
CATEGORY_FILTER="encryption"
if should_run_check 1 && ! should_run_check 3; then
    ok "should_run_check honours the category filter"
else
    bad "should_run_check honours the category filter"
fi
# shellcheck disable=SC2034  # read by the sourced should_run_check
CATEGORY_FILTER=""
if should_run_check 1 && should_run_check 3; then
    ok "should_run_check passes everything with no filter"
else
    bad "should_run_check passes everything with no filter"
fi

assert_eq "md_cell escapes table-breaking pipes" 'a\|b' "$(md_cell 'a|b')"

###############################################################################
group "Report output"
###############################################################################

MD="$WORK/report.md"
"$AUDIT" --category encryption,auth --redact --no-color --output "$MD" >/dev/null 2>&1
MD_BODY=$(cat "$MD")
assert_contains "markdown report has a title"      "# macOS Security Audit Report" "$MD_BODY"
assert_contains "markdown report redacts the serial" "**Serial:** REDACTED"        "$MD_BODY"
assert_contains "markdown report has a summary"    "## Summary"                    "$MD_BODY"
assert_contains "markdown report states the grade" "**Overall Grade**"             "$MD_BODY"
assert_contains "markdown report flags a partial run" "**Partial audit**"          "$MD_BODY"
assert_contains "markdown report states it ran offline" "Run fully offline"        "$MD_BODY"
assert_contains "markdown report carries the version" "v${FILE_VERSION}"           "$MD_BODY"
case "$MD_BODY" in
    *$'\033'*) bad "markdown report has no ANSI escapes" ;;
    *)         ok "markdown report has no ANSI escapes" ;;
esac

JSON="$WORK/report.json"
"$AUDIT" --category encryption,auth --json --redact --show-fix --output "$JSON" >/dev/null 2>&1
if command -v python3 >/dev/null 2>&1; then
    if PY_ERR=$(python3 - "$JSON" "$FILE_VERSION" <<'PY' 2>&1
import json, sys
path, version = sys.argv[1], sys.argv[2]
with open(path) as fh:
    d = json.load(fh)
errs = []
if d["version"] != version:
    errs.append("version %r != %r" % (d["version"], version))
if d["machine"]["serial"] != "REDACTED":
    errs.append("--redact did not mask the serial")
if d["offline"] is not True:
    errs.append("offline flag should be true without --online")
if d["partial_audit"] is not True:
    errs.append("partial_audit should be true with --category")
counts = {}
for f in d["findings"]:
    counts[f["severity"]] = counts.get(f["severity"], 0) + 1
    for key in ("check_number", "category", "title", "severity", "summary", "detail", "fix"):
        if key not in f:
            errs.append("finding %s missing %s" % (f.get("check_number"), key))
    if f["severity"] != "pass" and not f["fix"]:
        pass  # not every finding ships a fix command
for sev in ("critical", "high", "medium", "pass"):
    if d["summary"][sev] != counts.get(sev, 0):
        errs.append("summary.%s=%s but findings have %s" % (sev, d["summary"][sev], counts.get(sev, 0)))
if d["summary"]["checks_run"] != d["summary"]["total"]:
    errs.append("checks_run %s != total %s" % (d["summary"]["checks_run"], d["summary"]["total"]))
if not any(f["fix"] and "\n" in f["fix"] for f in d["findings"] if f["fix"]):
    pass  # fine when nothing failed on this machine
print("\n".join(errs), end="")
PY
    ); then
        assert_empty "JSON report is valid and internally consistent" "$PY_ERR"
    else
        bad "JSON report is valid and internally consistent" "$PY_ERR"
    fi
else
    skip "python3 not installed — JSON is only checked structurally"
    JSON_BODY=$(cat "$JSON")
    assert_contains "JSON report has a findings array" '"findings": [' "$JSON_BODY"
    assert_contains "JSON report redacts the serial" '"serial": "REDACTED"' "$JSON_BODY"
fi

###############################################################################
group "Repository hygiene"
###############################################################################

if command -v git >/dev/null 2>&1 && [[ -d "$ROOT/.git" ]]; then
    TRACKED_REPORTS=$(cd "$ROOT" && git ls-files | command grep 'security-audit-' || true)
    assert_empty "no generated report is tracked by git" "$TRACKED_REPORTS"

    IGNORE_MISSES=""
    for _pattern in security-audit-2000-01-01.md security-audit-2000-01-01.json; do
        (cd "$ROOT" && git check-ignore -q "$_pattern") || IGNORE_MISSES="${IGNORE_MISSES}$_pattern "
    done
    assert_empty "generated reports are gitignored (.md and .json)" "$IGNORE_MISSES"

    # Every GitHub link the project hands out — brew tap instructions, the
    # formula url, the report footer — must name the repository that actually
    # exists. They pointed at a 404 for three releases.
    ORIGIN=$(cd "$ROOT" && git remote get-url origin 2>/dev/null || true)
    if [[ -n "$ORIGIN" ]]; then
        SLUG=$(printf '%s' "$ORIGIN" | sed -e 's#.*github\.com[:/]##' -e 's#\.git$##')
        WRONG_URLS=$(cd "$ROOT" && git grep -hoE 'github\.com/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+' -- \
            README.md CLAUDE.md ReleaseNotes.md Formula bin 2>/dev/null \
            | sed -e 's#github\.com/##' -e 's#\.git$##' | sort -u | command grep -vx "$SLUG" || true)
        assert_empty "every github.com link points at origin ($SLUG)" "$WRONG_URLS"
    else
        skip "no git origin — link consistency check"
    fi
else
    skip "not a git checkout — repository hygiene checks"
fi

FORMULA="$ROOT/Formula/macos-security-audit.rb"
if [[ -f "$FORMULA" ]]; then
    FORMULA_VERSION=$(awk -F'"' '/^[[:space:]]*version /{ print $2; exit }' "$FORMULA")
    assert_eq "Homebrew formula version matches the script" "$FILE_VERSION" "$FORMULA_VERSION"
    if command grep -q "tags/v${FILE_VERSION}.tar.gz" "$FORMULA"; then
        ok "Homebrew formula url points at the current tag"
    else
        bad "Homebrew formula url points at the current tag"
    fi
fi

if command grep -q "^## v${FILE_VERSION} " "$ROOT/ReleaseNotes.md"; then
    ok "ReleaseNotes.md has an entry for v${FILE_VERSION}"
else
    bad "ReleaseNotes.md has an entry for v${FILE_VERSION}"
fi

###############################################################################
printf '\n%s\n' "─────────────────────────────────────────"
printf '  %spassed %d%s   %sfailed %d%s   %sskipped %d%s\n' \
    "$G" "$PASSED" "$N" "$R" "$FAILED" "$N" "$Y" "$SKIPPED" "$N"
printf '%s\n\n' "─────────────────────────────────────────"

if (( FAILED > 0 )); then exit 1; fi
exit 0
