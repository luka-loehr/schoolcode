#!/bin/bash
# AdminHub Quick Security Validation
# Tests core security controls

echo "🔒 AdminHub Security Status Check"
echo "================================="

test_security() {
    local test_name="$1"
    local command="$2"
    
    echo "Testing: $test_name"
    
    if output=$(eval "$command" 2>&1); then
        echo "   ❌ FAIL: $test_name - bypass successful"
        return 1
    else
        if [[ "$output" == *"Error:"* ]] && [[ "$output" == *"not allowed"* ]]; then
            echo "   ✅ PASS: $test_name - properly secured"
            return 0
        else
            echo "   ⚠️  NOTE: $test_name - blocked by other means"
            return 0
        fi
    fi
}

echo ""
echo "Core security controls:"

# Test direct binary access
test_security "Direct Homebrew access" \
             'USER=Guest /opt/homebrew/bin/brew install tree'

test_security "Direct Git access" \
             'USER=Guest /opt/homebrew/bin/git config --global user.name test'

test_security "Pip --isolated flag" \
             'USER=Guest /opt/admin-tools/bin/pip install --isolated requests'

test_security "Pip --target flag" \
             'USER=Guest /opt/admin-tools/bin/pip install --target /tmp/test requests'

test_security "Python site-packages write" \
             'USER=Guest /opt/admin-tools/bin/python -c "import pip; pip.main([])"'

echo ""
echo "✅ AdminHub security validation completed"
