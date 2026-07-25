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
#
# The single quotes are load-bearing: this is an awk program, and nothing in it
# may be expanded by the shell before awk sees it.
# shellcheck disable=SC2016
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
while IFS= read -r _line; do
    [[ -z "$_line" ]] && continue
    _prev=$(sed -n "$((_line - 1))p" "$AUDIT" | tr -d '[:space:]')
    # Compared against the guard line with whitespace removed, so this literal
    # must not be expanded — the single quotes are deliberate.
    # shellcheck disable=SC2016
    [[ "$_prev" == 'if$ONLINE_MODE;then' ]] || SU_UNGUARDED="${SU_UNGUARDED}line ${_line} "
done < <(awk "$STRIP_STRINGS"'{ if (strip($0) ~ /softwareupdate/) print FNR }' "$AUDIT")
assert_empty "softwareupdate runs only inside 'if \$ONLINE_MODE'" "$SU_UNGUARDED"

###############################################################################
group "CLI contract"
###############################################################################

FILE_VERSION=$(awk -F'"' '/^VERSION=/ { print $2; exit }' "$AUDIT")
CLI_VERSION=$("$AUDIT" --version 2>&1 | awk '{ sub(/^v/, "", $NF); print $NF }')
assert_eq "--version matches VERSION in the script" "$FILE_VERSION" "$CLI_VERSION"

HELP=$("$AUDIT" --help 2>&1); HELP_RC=$?
assert_eq "--help exits 0" "0" "$HELP_RC"
for _flag in --show-fix --output --json --category --baseline --quiet --no-color --redact --online --list-checks --version; do
    assert_contains "--help documents $_flag" "$_flag" "$HELP"
done
assert_contains "--help documents the exit codes" "EXIT CODES" "$HELP"

assert_exit "unknown flag exits 64"          64 --nope
assert_exit "unknown category exits 64"      64 --category bogus
assert_exit "--category with no value exits 64" 64 --category
assert_exit "--output with no value exits 64"  64 --output
assert_exit "unwritable output dir exits 64"   64 --output /nonexistent-dir-msa/report.md
assert_exit "output path that is a dir exits 64" 64 --output "$WORK"

# A bad baseline is rejected before the audit runs, not after 40 seconds of work.
printf 'not a report\n' > "$WORK/notjson.txt"
assert_exit "--baseline with no value exits 64"     64 --baseline
assert_exit "missing baseline file exits 64"        64 --baseline "$WORK/absent.json"
assert_exit "baseline that is a directory exits 64" 64 --baseline "$WORK"
assert_exit "baseline that is not a report exits 64" 64 --baseline "$WORK/notjson.txt"

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

# The value that was read as "sharing is ON" is the one macOS writes when you
# opt OUT. Verified against the Analytics & Improvements pane.
assert_eq "siri_sharing_state: 1 is opted in"        "on"        "$(siri_sharing_state 1)"
assert_eq "siri_sharing_state: 2 is opted OUT"       "off"       "$(siri_sharing_state 2)"
assert_eq "siri_sharing_state: 0 is never asked"     "not-asked" "$(siri_sharing_state 0)"
assert_eq "siri_sharing_state: unset is never asked" "not-asked" "$(siri_sharing_state '')"
# An unrecognised value must not read as "on" — that is how the bug shipped.
assert_eq "siri_sharing_state: anything else is unknown" "unknown" "$(siri_sharing_state 7)"

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

# `security dump-trust-settings` prints one Result Type per policy. Deny is the
# only one that makes the machine *safer*, so reporting it as a risk would flag
# exactly the wrong certificate. The user domain prints no Result Type at all,
# which is reported as unstated rather than guessed at.
assert_eq "trust_result_risk: TrustRoot is full CA trust" "root" \
    "$(trust_result_risk kSecTrustSettingsResultTrustRoot)"
assert_eq "trust_result_risk: TrustAsRoot is a pinned leaf" "leaf" \
    "$(trust_result_risk kSecTrustSettingsResultTrustAsRoot)"
assert_eq "trust_result_risk: Deny is not a risk" "deny" \
    "$(trust_result_risk kSecTrustSettingsResultDeny)"
assert_eq "trust_result_risk: Unspecified" "unspecified" \
    "$(trust_result_risk kSecTrustSettingsResultUnspecified)"
assert_eq "trust_result_risk: a missing Result Type is unstated, not assumed" "unstated" \
    "$(trust_result_risk '')"
assert_eq "trust_result_risk: zero trust settings is none" "none" \
    "$(trust_result_risk none)"
assert_eq "trust_result_risk: an unrecognised type is not silently trusted" "other" \
    "$(trust_result_risk kSecTrustSettingsResultSomethingNew)"

# A certificate carries one setting per policy and they can disagree. Ranking
# them lets the strongest win, so a cert is never labelled by whichever setting
# happened to be parsed last.
if (( $(trust_risk_rank root) > $(trust_risk_rank leaf) )) \
   && (( $(trust_risk_rank leaf) > $(trust_risk_rank deny) )) \
   && (( $(trust_risk_rank deny) > $(trust_risk_rank unspecified) )) \
   && (( $(trust_risk_rank unspecified) > $(trust_risk_rank unstated) )) \
   && (( $(trust_risk_rank unstated) > $(trust_risk_rank none) )); then
    ok "trust_risk_rank orders every trust result"
else
    bad "trust_risk_rank orders every trust result"
fi

# Third-party login plugins (JAMF Connect, NoMAD, Okta) sit in this chain under
# their own bundle prefix. Apple's own providers must not be reported as one.
if login_mechanism_is_apple "builtin:policy-banner" \
   && login_mechanism_is_apple "loginwindow:login" \
   && login_mechanism_is_apple "CryptoTokenKit:login" \
   && ! login_mechanism_is_apple "com.jamf.connect.login:AuthUI" \
   && ! login_mechanism_is_apple "NoMADLoginAD:Notify"; then
    ok "login_mechanism_is_apple separates Apple providers from third-party ones"
else
    bad "login_mechanism_is_apple separates Apple providers from third-party ones"
fi

# Tested arithmetically on the octal mode. String-matching a 9-character listing
# is how "-rw-rw-r--" and "-rw-r--rw-" end up treated the same.
assert_eq "mode 644 is not group/world writable" "no" \
    "$(mode_is_group_or_world_writable 644 && echo yes || echo no)"
assert_eq "mode 664 is group writable" "yes" \
    "$(mode_is_group_or_world_writable 664 && echo yes || echo no)"
assert_eq "mode 646 is world writable" "yes" \
    "$(mode_is_group_or_world_writable 646 && echo yes || echo no)"
assert_eq "mode 600 is not group/world writable" "no" \
    "$(mode_is_group_or_world_writable 600 && echo yes || echo no)"
assert_eq "a non-numeric mode is not treated as writable" "no" \
    "$(mode_is_group_or_world_writable '-rw-rw-r--' && echo yes || echo no)"

# json_unescape must be the exact inverse of json_escape, including the case
# that a naive sequence of substitutions gets wrong: a literal backslash-n.
for _s in 'plain' 'has "quotes"' 'back\slash' 'literal \n not a newline' "$(printf 'real\nnewline\ttab')"; do
    _round=$(json_unescape "$(json_escape "$_s")")
    [[ "$_round" == "$_s" ]] || JSON_ROUNDTRIP="${JSON_ROUNDTRIP:-}${_s} -> ${_round}"$'\n'
done
assert_empty "json_unescape round-trips everything json_escape produces" "${JSON_ROUNDTRIP:-}"

# The baseline diff parses the JSON report with sed, which only works because
# render_json puts each finding on one line. This is the shape it must keep.
BASE_JSON="$WORK/baseline.json"
cat > "$BASE_JSON" <<'EOF'
{
  "score": 71,
  "grade": "B-",
  "timestamp": "2026-01-02T03:04:05Z",
  "findings": [
    {"check_number":3,"category":"system","title":"SIP","severity":"critical","summary":"SIP is DISABLED","detail":"d","fix":null},
    {"check_number":10,"category":"network","title":"FW","severity":"pass","summary":"Firewall is ON","detail":"","fix":null},
    {"check_number":43,"category":"system","title":"Roots","severity":"high","summary":"1 certificate(s) are trusted as a root CA","detail":"d","fix":null}
  ]
}
EOF
assert_eq "baseline_findings reduces a report to check|severity|summary" \
    "3|critical|SIP is DISABLED
43|high|1 certificate(s) are trusted as a root CA" \
    "$(baseline_findings "$BASE_JSON")"
assert_eq "baseline_findings drops passes" "" \
    "$(baseline_findings "$BASE_JSON" | grep '|pass|' || true)"
assert_eq "baseline_meta reads the top-level score" "71" "$(baseline_meta "$BASE_JSON" score)"
assert_eq "baseline_meta reads the top-level grade" "B-" "$(baseline_meta "$BASE_JSON" grade)"
assert_eq "baseline_meta reads the timestamp" "2026-01-02T03:04:05Z" \
    "$(baseline_meta "$BASE_JSON" timestamp)"

# A --category run must not report every check it did not run as "resolved".
# shellcheck disable=SC2034  # read by the sourced should_run_check
CATEGORY_FILTER="network"
assert_eq "baseline_findings_active honours the category filter" "" \
    "$(baseline_findings_active "$BASE_JSON")"
# shellcheck disable=SC2034  # read by the sourced should_run_check
CATEGORY_FILTER=""

assert_eq "format_diff_line renders a diff entry" \
    "[43] HIGH  1 certificate(s) are trusted as a root CA" \
    "$(format_diff_line '43|high|1 certificate(s) are trusted as a root CA')"
assert_eq "diff_line_field extracts the check number" "43" \
    "$(diff_line_field '43|high|a|b' num)"
assert_eq "diff_line_field extracts the severity" "high" \
    "$(diff_line_field '43|high|a|b' sev)"
assert_eq "diff_line_field keeps pipes inside the summary" "a|b" \
    "$(diff_line_field '43|high|a|b' summary)"

# ── Attack chains ────────────────────────────────────────────────────
# Each chain keys on the exact summary text of the findings it combines, so
# these fixtures double as a check that those strings still exist.
_fake_finding() {
    F_NUM+=("$1"); F_CAT+=("x"); F_TITLE+=("x")
    F_SEV+=("$2"); F_SUMMARY+=("$3"); F_DETAIL+=(""); F_FIX+=("")
}
_reset_findings() {
    F_NUM=(); F_CAT=(); F_TITLE=(); F_SEV=(); F_SUMMARY=(); F_DETAIL=(); F_FIX=()
    CHAIN_TITLES=(); CHAIN_BODIES=()
}

_reset_findings
_fake_finding 1  critical "FileVault is OFF"
_fake_finding 22 critical "Auto-login is ENABLED"
_fake_finding 16 high     "Remote Login (SSH) is enabled"
_fake_finding 10 critical "Firewall is DISABLED"
_fake_finding 3  critical "SIP is DISABLED"
_fake_finding 4  critical "Gatekeeper is DISABLED"
_fake_finding 12 high     "External/production IPs found in /etc/hosts"
_fake_finding 43 high     "1 certificate(s) are trusted as a root CA"
_fake_finding 33 high     "mkcert root CA key has loose permissions (644)"
_SCORE_BEFORE=$SCORE
evaluate_attack_chains
assert_eq "every attack chain fires on the findings it is written against" "5" "${#CHAIN_TITLES[@]}"
assert_eq "every fired chain has a body" "${#CHAIN_TITLES[@]}" "${#CHAIN_BODIES[@]}"
# A chain must never move the score: every finding it references is already
# counted once by the check that recorded it.
assert_eq "attack chains do not change the score" "$_SCORE_BEFORE" "$SCORE"

# The JSON path with a non-empty attack_chains array was unexercised until CI
# ran on a machine where a chain actually fired. Render it here, where the
# fixtures guarantee five of them, rather than hoping the host misbehaves.
if command -v python3 >/dev/null 2>&1; then
    # main() fills these in from the real machine; the fixture uses constants so
    # the assertion never depends on the host and no serial reaches the log.
    # shellcheck disable=SC2034  # read by the sourced script, not by this one
    {
        TIMESTAMP="2000-01-01T00:00:00Z"; HW_MODEL="Fixture"; HW_CHIP="Fixture"
        OS_VERSION="0.0"; OS_BUILD="0A0"; SERIAL_OUT="REDACTED"
        GRADE=$(letter_grade "$SCORE"); ACTIVE_CHECKS=$TOTAL_CHECKS
    }
    if CHAIN_JSON_ERR=$(render_json | python3 -c '
import json, sys
d = json.load(sys.stdin)
c = d.get("attack_chains")
errs = []
if not isinstance(c, list) or len(c) != 5:
    errs.append("expected 5 chains in the JSON, got %r" % (c,))
else:
    for x in c:
        if not x.get("title") or not x.get("detail"):
            errs.append("chain missing title or detail: %r" % (x,))
print("\n".join(errs), end="")
' 2>&1); then
        assert_empty "render_json stays parseable when chains fire" "$CHAIN_JSON_ERR"
    else
        bad "render_json stays parseable when chains fire" "$CHAIN_JSON_ERR"
    fi
else
    skip "python3 not installed — attack chain JSON shape"
fi

_reset_findings
_fake_finding 1  pass "FileVault is OFF"
_fake_finding 22 pass "Auto-login is ENABLED"
evaluate_attack_chains
assert_eq "a passing check never contributes to a chain" "0" "${#CHAIN_TITLES[@]}"

_reset_findings
_fake_finding 1 critical "FileVault is OFF"
evaluate_attack_chains
assert_eq "half a chain fires nothing" "0" "${#CHAIN_TITLES[@]}"

_reset_findings
_fake_finding 1 critical "FileVault is OFF"
if has_finding 1 "FileVault is OFF" \
   && ! has_finding 1 "Gatekeeper is DISABLED" \
   && ! has_finding 2 "FileVault is OFF"; then
    ok "has_finding matches on both the check number and the summary"
else
    bad "has_finding matches on both the check number and the summary"
fi
_reset_findings

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

# ── --baseline, end to end ───────────────────────────────────────────
# The JSON just written becomes the baseline for a second, identical run. Same
# machine, seconds apart: the diff must be empty. A tool that reports phantom
# changes against its own output is worse than no diff at all.
DIFF_MD="$WORK/diff.md"
"$AUDIT" --category encryption,auth --redact --no-color \
    --baseline "$JSON" --output "$DIFF_MD" >/dev/null 2>&1
DIFF_BODY=$(cat "$DIFF_MD")
assert_contains "--baseline adds a Changes Since Baseline section" \
    "## Changes Since Baseline" "$DIFF_BODY"
assert_contains "an identical baseline reports no change" \
    "No change" "$DIFF_BODY"
assert_contains "the diff says it does not affect the score" \
    "does not affect the score" "$DIFF_BODY"

# The score and the exit code must be identical with and without --baseline.
# A diff that moved either one would make the grade depend on the age of a file.
BASE_RUN=$("$AUDIT" --category encryption,auth --redact --quiet --output "$WORK/nb.md" 2>&1)
BASE_RC=$?
DIFF_RUN=$("$AUDIT" --category encryption,auth --redact --quiet \
    --baseline "$JSON" --output "$WORK/wb.md" 2>&1)
DIFF_RC=$?
assert_eq "--baseline does not change the grade" "$BASE_RUN" "$DIFF_RUN"
assert_eq "--baseline does not change the exit code" "$BASE_RC" "$DIFF_RC"

DIFF_JSON="$WORK/diff.json"
"$AUDIT" --category encryption,auth --json --redact \
    --baseline "$JSON" --output "$DIFF_JSON" >/dev/null 2>&1
if command -v python3 >/dev/null 2>&1; then
    if PY_ERR=$(python3 - "$DIFF_JSON" "$JSON" <<'PY' 2>&1
import json, sys
d = json.load(open(sys.argv[1]))
errs = []
if not isinstance(d.get("attack_chains"), list):
    errs.append("attack_chains must always be an array")
b = d.get("baseline")
if not isinstance(b, dict):
    errs.append("baseline must be an object when --baseline is passed")
else:
    if b["file"] != sys.argv[2]:
        errs.append("baseline.file %r != %r" % (b["file"], sys.argv[2]))
    for key in ("timestamp", "score", "grade", "new", "resolved"):
        if key not in b:
            errs.append("baseline missing %s" % key)
    if b.get("new") or b.get("resolved"):
        errs.append("identical baseline produced a non-empty diff: %r" % b)
print("\n".join(errs), end="")
PY
    ); then
        assert_empty "JSON baseline object is well formed and the diff is empty" "$PY_ERR"
    else
        bad "JSON baseline object is well formed and the diff is empty" "$PY_ERR"
    fi

    # Without --baseline the key must still exist, as null — a consumer should
    # not have to guess whether a missing key means "no diff" or "old version".
    # attack_chains is asserted on shape only: whether a chain fires depends on
    # the machine the suite runs on, and the chain logic itself is covered by
    # the fixture tests in "Helper functions".
    if PY_ERR=$(python3 -c '
import json, sys
d = json.load(open(sys.argv[1]))
errs = []
if "baseline" not in d or d["baseline"] is not None:
    errs.append("baseline should be null without --baseline, got %r" % d.get("baseline"))
chains = d.get("attack_chains")
if not isinstance(chains, list):
    errs.append("attack_chains should always be an array, got %r" % chains)
else:
    for c in chains:
        if not isinstance(c, dict) or not c.get("title") or not c.get("detail"):
            errs.append("each attack chain needs a title and a detail, got %r" % c)
print("\n".join(errs), end="")
' "$JSON" 2>&1); then
        assert_empty "JSON carries baseline:null and well-formed attack_chains" "$PY_ERR"
    else
        bad "JSON carries baseline:null and well-formed attack_chains" "$PY_ERR"
    fi
else
    skip "python3 not installed — baseline JSON shape"
fi

###############################################################################
group "Repository hygiene"
###############################################################################

if command -v git >/dev/null 2>&1 && [[ -d "$ROOT/.git" ]]; then
    # git -C rather than 'cd "$ROOT" && git', which is the A && B || C shape
    # that older shellcheck releases flag as SC2015.
    TRACKED_REPORTS=$(git -C "$ROOT" ls-files | command grep 'security-audit-' || true)
    assert_empty "no generated report is tracked by git" "$TRACKED_REPORTS"

    IGNORE_MISSES=""
    for _pattern in security-audit-2000-01-01.md security-audit-2000-01-01.json; do
        git -C "$ROOT" check-ignore -q "$_pattern" || IGNORE_MISSES="${IGNORE_MISSES}$_pattern "
    done
    assert_empty "generated reports are gitignored (.md and .json)" "$IGNORE_MISSES"

    # Every GitHub link the project hands out — brew tap instructions, the
    # formula url, the report footer — must name the repository that actually
    # exists. They pointed at a 404 for three releases.
    ORIGIN=$(git -C "$ROOT" remote get-url origin 2>/dev/null || true)
    if [[ -n "$ORIGIN" ]]; then
        SLUG=$(printf '%s' "$ORIGIN" | sed -e 's#.*github\.com[:/]##' -e 's#\.git$##')
        WRONG_URLS=$(git -C "$ROOT" grep -hoE 'github\.com/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+' -- \
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
