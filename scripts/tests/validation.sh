#!/bin/bash
# AdminHub Security Validation Suite
# Tests essential security controls

echo "🔒 AdminHub Security Validation"
echo "==============================="

test_critical() {
    local test_name="$1"
    local command="$2"
    
    echo "🔍 Testing: $test_name"
    echo "   Command: $command"
    
    if output=$(eval "$command" 2>&1); then
        echo "   ❌ CRITICAL FAIL: $output"
        return 1
    else
        if [[ "$output" == *"Error:"* ]] && [[ "$output" == *"not allowed"* ]]; then
            echo "   ✅ SECURE: Properly blocked"
            return 0
        else
            echo "   ⚠️  UNCLEAR: $output"
            return 2
        fi
    fi
}

echo ""
echo "Testing most critical bypass vectors..."
echo ""

# Test 1: Direct Python binary bypass
test_critical "Direct Python3 binary with subprocess" \
             'USER=Guest /opt/homebrew/bin/python3 -c "import subprocess; subprocess.run([\"pip\", \"install\", \"--target\", \"/tmp/critical1\", \"requests\"])"'

echo ""

# Test 2: Python -c pip import
test_critical "Python -c pip import bypass" \
             'USER=Guest /opt/admin-tools/bin/python -c "import pip; pip.main([\"install\", \"--isolated\", \"--target\", \"/tmp/critical2\", \"requests\"])"'

echo ""

# Test 3: Direct Homebrew binary
test_critical "Direct Homebrew binary access" \
             'USER=Guest /opt/homebrew/bin/brew install tree'

echo ""

# Test 4: Direct Git binary
test_critical "Direct Git binary access" \
             'USER=Guest /opt/homebrew/bin/git clone https://github.com/octocat/Hello-World.git /tmp/critical4'

echo ""

# Test 5: Python site-packages direct write
test_critical "Python site-packages direct write" \
             'USER=Guest /opt/admin-tools/bin/python -c "open(\"/opt/homebrew/lib/python3.13/site-packages/malicious.py\", \"w\").write(\"print(\\\"hacked\\\")\")"'

echo ""

# Test 6: Shell injection
test_critical "Shell injection via pip args" \
             'USER=Guest /opt/admin-tools/bin/pip install "requests; touch /tmp/injected"'

echo ""

# Test 7: Virtual environment bypass
test_critical "Virtual environment bypass" \
             'USER=Guest /opt/admin-tools/bin/python -m venv /tmp/venv && /tmp/venv/bin/pip install --target /usr/local/lib/python3.13/site-packages requests'

echo ""

# Test 8: Environment variable bypass
test_critical "PIP environment variable bypass" \
             'USER=Guest PIP_TARGET=/tmp/critical8 PIP_ISOLATED=1 /opt/admin-tools/bin/pip install requests'

echo ""

# Test 9: Config directory manipulation
test_critical "Pip config manipulation" \
             'mkdir -p /tmp/.config/pip && echo "[global]\nbreak-system-packages = true\ntarget = /tmp/critical9" > /tmp/.config/pip/pip.conf && USER=Guest XDG_CONFIG_HOME=/tmp /opt/admin-tools/bin/pip install requests'

echo ""

# Test 10: Binary copying bypass
test_critical "Binary copying bypass" \
             'USER=Guest cp /opt/admin-tools/bin/pip /tmp/pip && /tmp/pip install --target /tmp/critical10 requests'

echo ""
echo "Critical tests completed!"
