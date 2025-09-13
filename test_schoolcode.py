#!/usr/bin/env python3
"""
SchoolCode Python Test Suite
Tests that the Python environment is working correctly for educational use
"""

import sys
import platform
import subprocess
import os

def print_header():
    """Print test header"""
    print("╔═══════════════════════════════════════╗")
    print("║        SchoolCode Python Tests        ║")
    print("╚═══════════════════════════════════════╝")
    print()

def print_test(test_name):
    """Print test name"""
    print(f"🧪 {test_name}:")

def print_pass(message=""):
    """Print pass message"""
    if message:
        print(f"  ✅ {message}")
    else:
        print("  ✅ PASS")

def print_fail(message=""):
    """Print fail message"""
    if message:
        print(f"  ❌ {message}")
    else:
        print("  ❌ FAIL")

def test_python_version():
    """Test Python version and basic info"""
    print_test("Python Version")
    print(f"  Version: {sys.version}")
    print(f"  Executable: {sys.executable}")
    print(f"  Platform: {platform.platform()}")
    
    # Check if we have a reasonable Python version
    if sys.version_info >= (3, 8):
        print_pass("Python version is suitable")
        return True
    else:
        print_fail("Python version too old")
        return False

def test_pip():
    """Test pip installation"""
    print_test("Pip Installation")
    try:
        result = subprocess.run([sys.executable, "-m", "pip", "--version"], 
                              capture_output=True, text=True, timeout=10)
        if result.returncode == 0:
            print(f"  {result.stdout.strip()}")
            print_pass("Pip is working")
            return True
        else:
            print_fail("Pip command failed")
            return False
    except subprocess.TimeoutExpired:
        print_fail("Pip command timed out")
        return False
    except Exception as e:
        print_fail(f"Error: {e}")
        return False

def test_basic_imports():
    """Test basic Python imports"""
    print_test("Basic Imports")
    try:
        import os
        import sys
        import json
        import subprocess
        import platform
        print_pass("All basic modules imported successfully")
        return True
    except ImportError as e:
        print_fail(f"Import error: {e}")
        return False

def test_code_execution():
    """Test basic Python code execution"""
    print_test("Code Execution")
    try:
        # Test list comprehension
        squares = [x**2 for x in range(5)]
        print(f"  Squares: {squares}")
        
        # Test string manipulation
        message = "SchoolCode"
        reversed_msg = message[::-1]
        print(f"  Reversed: {reversed_msg}")
        
        # Test dictionary
        tools = {"Python": "✓", "Git": "✓", "Brew": "✓"}
        print(f"  Tools: {tools}")
        
        print_pass("Code execution working")
        return True
    except Exception as e:
        print_fail(f"Execution error: {e}")
        return False

def test_file_operations():
    """Test basic file operations"""
    print_test("File Operations")
    try:
        # Test creating and reading a file
        test_file = "/tmp/schoolcode_test.txt"
        test_content = "SchoolCode test file"
        
        with open(test_file, 'w') as f:
            f.write(test_content)
        
        with open(test_file, 'r') as f:
            read_content = f.read()
        
        # Clean up
        os.remove(test_file)
        
        if read_content == test_content:
            print_pass("File operations working")
            return True
        else:
            print_fail("File content mismatch")
            return False
    except Exception as e:
        print_fail(f"File operation error: {e}")
        return False

def test_subprocess():
    """Test subprocess functionality"""
    print_test("Subprocess")
    try:
        # Test running a simple command
        result = subprocess.run([sys.executable, "-c", "print('Hello from subprocess')"], 
                              capture_output=True, text=True, timeout=5)
        if result.returncode == 0 and "Hello from subprocess" in result.stdout:
            print_pass("Subprocess working")
            return True
        else:
            print_fail("Subprocess failed")
            return False
    except subprocess.TimeoutExpired:
        print_fail("Subprocess timed out")
        return False
    except Exception as e:
        print_fail(f"Subprocess error: {e}")
        return False

def test_development_tools():
    """Test if development tools are accessible"""
    print_test("Development Tools")
    tools_status = {}
    
    # Test Python
    try:
        result = subprocess.run([sys.executable, "--version"], 
                              capture_output=True, text=True, timeout=5)
        if result.returncode == 0:
            tools_status["Python"] = "✓"
        else:
            tools_status["Python"] = "✗"
    except:
        tools_status["Python"] = "✗"
    
    # Test Git
    try:
        result = subprocess.run(["git", "--version"], 
                              capture_output=True, text=True, timeout=5)
        if result.returncode == 0:
            tools_status["Git"] = "✓"
        else:
            tools_status["Git"] = "✗"
    except:
        tools_status["Git"] = "✗"
    
    # Test Homebrew
    try:
        result = subprocess.run(["brew", "--version"], 
                              capture_output=True, text=True, timeout=5)
        if result.returncode == 0:
            tools_status["Homebrew"] = "✓"
        else:
            tools_status["Homebrew"] = "✗"
    except:
        tools_status["Homebrew"] = "✗"
    
    print(f"  {tools_status}")
    
    # Count working tools
    working_tools = sum(1 for status in tools_status.values() if status == "✓")
    if working_tools >= 2:  # At least 2 tools should work
        print_pass(f"{working_tools}/3 tools working")
        return True
    else:
        print_fail(f"Only {working_tools}/3 tools working")
        return False

def main():
    """Run all tests"""
    print_header()
    
    tests = [
        test_python_version,
        test_pip,
        test_basic_imports,
        test_code_execution,
        test_file_operations,
        test_subprocess,
        test_development_tools
    ]
    
    passed = 0
    total = len(tests)
    
    for test in tests:
        if test():
            passed += 1
        print()
    
    # Summary
    print("╔═══════════════════════════════════════╗")
    print("║              TEST SUMMARY             ║")
    print("╚═══════════════════════════════════════╝")
    print(f"Tests Run:     {total}")
    print(f"Tests Passed:  {passed}")
    print(f"Tests Failed:  {total - passed}")
    print()
    
    if passed == total:
        print("🎉 All tests passed!")
        print("SchoolCode Python environment is ready for educational use!")
        return 0
    else:
        print("❌ Some tests failed")
        print("Check the output above for details")
        return 1

if __name__ == "__main__":
    sys.exit(main())