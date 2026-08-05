#!/bin/sh
# test_secret_redaction.sh - Test that secrets are redacted from logs
# shellcheck disable=SC1091,SC2034

. ../scripts/lib.sh

# ── Test 1: Redact REGISTRY_TOKEN from strings ──────────────────────────
echo "  Test 1: Redact REGISTRY_TOKEN from strings"
input="REGISTRY_TOKEN=fixture"
expected="REGISTRY_TOKEN=***REDACTED***"
output=$(echo "${input}" | redact)
[ "${output}" = "${expected}" ] || {
    echo "  FAIL: expected '${expected}', got '${output}'"
    exit 1
}
echo "  PASS: REGISTRY_TOKEN redacted"

# ── Test 2: Redact --password-stdin from strings ────────────────────
echo "  Test 2: Redact --password-stdin from strings"
input="echo TOKEN | docker login registry.example.invalid -u portfolio-user --password-stdin"
expected="echo TOKEN | docker login registry.example.invalid -u portfolio-user --password-stdin ***REDACTED***"
output=$(echo "${input}" | redact)
[ "${output}" = "${expected}" ] || {
    echo "  FAIL: expected '${expected}', got '${output}'"
    exit 1
}
echo "  PASS: --password-stdin redacted"

# ── Test 3: Redact GitHub tokens ────────────────────────────────────
echo "  Test 3: Redact GitHub tokens"
for prefix in ghp_ gho_ ghs_ ghr_; do
    input="${prefix}abc123def456"
    expected="***REDACTED***"
    output=$(echo "${input}" | redact)
    [ "${output}" = "${expected}" ] || {
        echo "  FAIL: ${prefix} token not redacted, got '${output}'"
        exit 1
    }
done
echo "  PASS: GitHub tokens redacted"

# ── Test 4: Redact preserves non-secret content ─────────────────────
echo "  Test 4: Redact preserves non-secret content"
input="This is a normal log message with no secrets"
output=$(echo "${input}" | redact)
[ "${output}" = "${input}" ] || {
    echo "  FAIL: non-secret content was modified"
    exit 1
}
echo "  PASS: Non-secret content preserved"

# ── Test 5: Redact handles empty input ──────────────────────────────
echo "  Test 5: Redact handles empty input"
output=$(echo "" | redact)
[ -z "${output}" ] || {
    echo "  FAIL: empty input should produce empty output"
    exit 1
}
echo "  PASS: Empty input handled"

exit 0
