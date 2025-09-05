# AdminHub Security Architecture

**AdminHub - macOS Guest Account Security System**  
*Professional Security Documentation*  
© 2025 Luka Löhr. All rights reserved.

---

## Executive Summary

AdminHub implements a comprehensive multi-layered security architecture designed to provide development tools to Guest users in educational environments while maintaining strict system integrity and preventing unauthorized modifications. The system employs defense-in-depth principles with multiple security controls, wrapper-based command interception, and comprehensive audit logging.

## Security Model Overview

### Core Security Principles

1. **Defense in Depth**: Multiple complementary security layers
2. **Fail Secure**: Block by default, allow only explicitly safe operations
3. **User Isolation**: Guest modifications are session-isolated and temporary
4. **System Integrity**: Zero tolerance for system-wide modifications
5. **Comprehensive Monitoring**: All security events are logged and auditable

### Threat Model

AdminHub protects against the following threat vectors:

- **System Modification**: Prevention of unauthorized system-wide changes
- **Privilege Escalation**: Blocking of sudo and administrative access
- **Package Manager Bypass**: Control of pip, npm, yarn, and brew operations
- **File System Attacks**: Protection against system directory manipulation
- **Code Injection**: Prevention of malicious Python code execution
- **Environment Manipulation**: Control of environment variables and paths
- **Network Exploitation**: Restriction of dangerous network operations

## Security Architecture

### Layer 1: Command Wrapper System

AdminHub implements a comprehensive wrapper system that intercepts and analyzes all tool commands before execution:

#### Core Development Tools
- **Git Wrapper** (`git_wrapper.sh`): Controls git operations, blocks global configuration
- **Python Wrapper** (`python_wrapper.sh`): Monitors Python execution, blocks dangerous imports
- **Pip Wrapper** (`pip_wrapper.sh`): Forces user-only installations, blocks system targets

#### Package Managers
- **NPM Wrapper** (`npm_wrapper.sh`): Blocks global installations, enforces local-only
- **Yarn Wrapper** (`yarn_wrapper.sh`): Prevents global package management
- **Brew Wrapper** (`brew_wrapper.sh`): Completely blocks all Homebrew operations

#### Network Tools
- **Curl Wrapper** (`curl_wrapper.sh`): Blocks system directory writes, dangerous HTTP methods
- **Wget Wrapper** (`wget_wrapper.sh`): Prevents system file downloads

#### System Commands
- **Sudo Wrapper** (`sudo_wrapper.sh`): Completely blocks sudo access
- **File Operation Wrappers**: Control rm, mv, cp, chmod operations
- **Build Tool Wrappers**: Block make install, direct install commands

### Layer 2: Binary Protection System

The binary protection system (`binary_wrapper.sh`) replaces direct system binary access with security-controlled wrappers:

- **Path Interception**: Redirects direct binary calls to security wrappers
- **Bypass Prevention**: Blocks attempts to circumvent wrapper system
- **Consistent Enforcement**: Ensures all tool access goes through security controls

### Layer 3: Environment Security

#### Python Environment Controls
- **PYTHONPATH Restriction**: Blocks malicious module loading
- **Import Monitoring**: Prevents dangerous Python imports
- **Subprocess Blocking**: Blocks calls to restricted tools
- **Site-packages Protection**: Prevents direct system package manipulation

#### Package Manager Environment
- **User-only Installations**: Forces all packages to user directories
- **Configuration Control**: Blocks dangerous configuration changes
- **Cache Management**: Prevents cache-based attacks

### Layer 4: File System Protection

#### System Directory Protection
- **Read-only System Access**: Blocks writes to `/usr*`, `/opt*`, `/Library*`, `/System*`
- **Path Traversal Prevention**: Blocks `..` and other traversal patterns
- **Permission Control**: Prevents dangerous file permission changes

#### User Directory Isolation
- **Home Directory Scope**: All modifications limited to user home directory
- **Session Cleanup**: Automatic cleanup on Guest logout
- **Temporary File Control**: Manages temporary file creation

## Security Controls by Category

### Package Management Security

#### Python/pip Security
- **User-only Installations**: All packages install to `~/.local/`
- **System Target Blocking**: Blocks `--target`, `--prefix`, `--root` flags
- **Isolation Prevention**: Blocks `--isolated` and configuration bypass flags
- **Environment Control**: Forces `PIP_USER=1` and safe configuration

#### Node.js Package Security
- **Global Installation Blocking**: Prevents `npm install -g` and `yarn global add`
- **Local-only Operations**: Enforces project-specific installations
- **Configuration Protection**: Blocks dangerous npm/yarn configuration changes

#### Homebrew Security
- **Complete Blocking**: All Homebrew operations blocked for Guest users
- **No Exceptions**: No read-only operations allowed
- **Clear Alternatives**: Provides guidance for alternative approaches

### File System Security

#### System File Protection
- **Deletion Prevention**: Blocks deletion of system files and directories
- **Modification Control**: Prevents modification of system files
- **Permission Security**: Blocks dangerous permission changes (777, setuid, setgid)

#### Directory Access Control
- **System Directory Blocking**: Prevents access to system directories
- **Path Validation**: Validates all file paths for security
- **Traversal Prevention**: Blocks directory traversal attacks

### Network Security

#### Download Restrictions
- **System Directory Blocking**: Prevents downloads to system directories
- **Method Restrictions**: Blocks dangerous HTTP methods (POST, PUT, DELETE)
- **Protocol Security**: Prevents insecure SSL connections
- **Proxy Protection**: Blocks proxy configuration manipulation

#### URL Security
- **System Port Blocking**: Prevents access to system ports
- **File URL Blocking**: Blocks file:// URL access
- **DNS Protection**: Prevents DNS manipulation attacks

### Command Execution Security

#### Privilege Escalation Prevention
- **Sudo Blocking**: Complete blocking of sudo access
- **Administrative Command Blocking**: Prevents admin-level operations
- **Permission Escalation**: Blocks attempts to gain elevated privileges

#### Code Execution Control
- **Subprocess Blocking**: Prevents calls to restricted tools
- **Import Control**: Blocks dangerous Python imports
- **Environment Manipulation**: Controls environment variable access

## Security Monitoring and Logging

### Audit Logging
- **Security Event Logging**: All security attempts logged to `/var/log/adminhub/security.log`
- **Bypass Detection**: Automatic detection of circumvention attempts
- **Comprehensive Coverage**: All wrapper interactions are logged

### Monitoring Capabilities
- **Real-time Detection**: Immediate blocking of security violations
- **Pattern Recognition**: Detection of attack patterns
- **User Activity Tracking**: Complete audit trail of Guest user activities

## Implementation Details

### Wrapper Architecture
```
/opt/admin-tools/
├── wrappers/           # Security wrapper scripts
│   ├── git_wrapper.sh
│   ├── pip_wrapper.sh
│   ├── brew_wrapper.sh
│   └── ...
├── security/           # System-level protection
│   ├── binary_wrapper.sh
│   ├── sudo_wrapper.sh
│   └── ...
└── bin/                # Symlinks to wrappers
    ├── git -> ../wrappers/git
    ├── pip -> ../wrappers/pip
    └── ...
```

### Security Flow
1. **Command Interception**: All tool commands intercepted by wrappers
2. **Security Analysis**: Commands analyzed for security risks
3. **Policy Enforcement**: Security policies applied based on analysis
4. **Execution Control**: Safe commands executed, dangerous ones blocked
5. **Audit Logging**: All actions logged for security monitoring

## Compliance and Standards

### Security Standards
- **Defense in Depth**: Multiple security layers
- **Principle of Least Privilege**: Minimal necessary permissions
- **Fail Secure**: Secure by default configuration
- **Comprehensive Monitoring**: Complete audit trail

### Educational Compliance
- **FERPA Considerations**: Student data protection
- **Institutional Policies**: Alignment with school security policies
- **Audit Requirements**: Comprehensive logging for compliance

## Security Benefits

### For Educational Institutions
- **Predictable Environment**: Consistent tools for all students
- **System Stability**: No risk of system-wide modifications
- **Compliance Support**: Comprehensive audit logging
- **Maintenance Reduction**: Automated security enforcement

### For Students
- **Safe Experimentation**: Can try packages without fear
- **Consistent Experience**: Same environment every time
- **Learning Focus**: No time wasted on broken environments
- **Real-world Practice**: Mirrors corporate security environments

## Maintenance and Updates

### Security Updates
- **Regular Review**: Security controls reviewed regularly
- **Threat Adaptation**: Updates based on new threat vectors
- **Vulnerability Management**: Prompt response to security issues

### Monitoring and Maintenance
- **Log Analysis**: Regular review of security logs
- **Performance Monitoring**: Ensure security doesn't impact performance
- **User Feedback**: Incorporate legitimate user needs

## Conclusion

AdminHub's security architecture provides comprehensive protection for educational environments while maintaining the flexibility needed for effective learning. The multi-layered approach ensures that even if one security control fails, others will prevent unauthorized access or modification.

The system successfully balances security requirements with educational needs, providing a safe, stable, and predictable environment for students while protecting institutional systems and data.

---

**Document Version**: 1.0  
**Last Updated**: January 2025  
**Author**: Luka Löhr  
**Classification**: Internal Use Only