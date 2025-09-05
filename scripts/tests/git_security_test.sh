#!/bin/bash
# Git Security Test Suite
# Tests Git-related security vulnerabilities in AdminHub

echo "🔒 Git Security Assessment"
echo "========================="
echo ""

PASSED=0
FAILED=0

test_git_security() {
    local test_name="$1"
    local command="$2"
    local severity="$3"
    
    echo "🔍 Testing: $test_name"
    echo "   Severity: $severity"
    echo "   Command: $command"
    
    if output=$(eval "$command" 2>&1); then
        if [[ "$output" == *"Error:"* ]] && [[ "$output" == *"not allowed"* ]]; then
            echo "   ✅ BLOCKED: Security control working"
            PASSED=$((PASSED + 1))
        else
            echo "   ❌ VULNERABLE: Command succeeded"
            echo "   Output: $output"
            FAILED=$((FAILED + 1))
        fi
    else
        echo "   ✅ BLOCKED: Command failed as expected"
        PASSED=$((PASSED + 1))
    fi
    echo ""
}

echo "=== Git Configuration Attacks ==="
echo ""

# Test global config modification
test_git_security "Global config modification" \
    'USER=Guest /opt/admin-tools/bin/git config --global user.name "Malicious User"' \
    "HIGH"

# Test system config modification
test_git_security "System config modification" \
    'USER=Guest /opt/admin-tools/bin/git config --system core.editor "rm -rf /"' \
    "CRITICAL"

# Test dangerous editor config
test_git_security "Dangerous editor configuration" \
    'USER=Guest /opt/admin-tools/bin/git config core.editor "bash -c \"touch /tmp/pwned\""' \
    "HIGH"

echo "=== Git Hooks Attacks ==="
echo ""

# Test hook creation
test_git_security "Git hook creation" \
    'USER=Guest mkdir -p /tmp/test-repo/.git/hooks && echo "#!/bin/sh\nrm -rf /tmp/evil" > /tmp/test-repo/.git/hooks/pre-commit && /opt/admin-tools/bin/git -C /tmp/test-repo commit --allow-empty -m "test"' \
    "CRITICAL"

echo "=== Git Credential Access ==="
echo ""

# Test credential access
test_git_security "Credential helper access" \
    'USER=Guest /opt/admin-tools/bin/git config --get-regexp credential' \
    "MEDIUM"

test_git_security "Credential fill attempt" \
    'USER=Guest /opt/admin-tools/bin/git credential fill' \
    "HIGH"

echo "=== Repository Cloning ==="
echo ""

# Test malicious repo cloning
test_git_security "Clone with suspicious URL" \
    'USER=Guest /opt/admin-tools/bin/git clone file:///etc/passwd /tmp/evil-clone' \
    "CRITICAL"

test_git_security "Clone with submodules" \
    'USER=Guest /opt/admin-tools/bin/git clone --recurse-submodules https://github.com/evil/repo.git /tmp/submodule-test' \
    "HIGH"

echo "=== Git Environment Variables ==="
echo ""

# Test environment variable manipulation
test_git_security "GIT_EXEC_PATH manipulation" \
    'USER=Guest GIT_EXEC_PATH=/tmp/evil /opt/admin-tools/bin/git --version' \
    "HIGH"

test_git_security "GIT_CONFIG manipulation" \
    'USER=Guest GIT_CONFIG=/tmp/evil.conf /opt/admin-tools/bin/git config --list' \
    "MEDIUM"

echo "=== Git LFS and Extensions ==="
echo ""

# Test LFS bypasses
test_git_security "Git LFS filter manipulation" \
    'USER=Guest /opt/admin-tools/bin/git config filter.lfs.process "bash -c \"touch /tmp/lfs-pwned\""' \
    "HIGH"

echo "=== Summary ==="
echo "Tests Passed: $PASSED"
echo "Tests Failed: $FAILED"
echo ""

if [[ $FAILED -eq 0 ]]; then
    echo "✅ All Git security controls are working properly!"
else
    echo "⚠️  Some Git security vulnerabilities detected!"
fi
