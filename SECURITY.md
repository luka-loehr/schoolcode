<!--
Copyright (c) 2025 Luka Löhr
-->

# SchoolCode Security Architecture

## Overview

SchoolCode provides a secure development environment for Guest users on shared macOS machines. This document details the security model, design decisions, and how specific tools are managed to ensure system integrity while allowing students freedom to experiment.

## Core Security Principle

All Guest user modifications are designed to be:

*   **Session-isolated**: Changes affect only the current user's session.
*   **Temporary**: All modifications reset upon Guest logout.
*   **Non-destructive**: Guest users cannot break core system tools or configurations for other users.

This model ensures a clean, predictable, and functional environment for every student, every time.

## Tool-Specific Security Analysis

### 🟢 Python/pip - User Isolation Supported

Python's `pip` natively supports user-specific installations (`pip install --user`), which install packages to the user's home directory (`~/.local/`).

*   **Implementation**: SchoolCode forces `PIP_USER=1` and automatically adds the `--user` flag to `pip install` commands. It blocks system-wide installation attempts.
*   **Rationale**: This allows students to install Python packages for their projects without affecting the system Python or other users, and ensures these installations are temporary.

### 🔴 Homebrew - System-Wide Only

Homebrew installs packages system-wide (`/opt/homebrew/` or `/usr/local/`) and lacks native user-specific installation support.

*   **Implementation**: SchoolCode strictly blocks all Homebrew commands that modify the system (e.g., `install`, `uninstall`, `upgrade`, `update`, `link`, `unlink`). Read-only commands (e.g., `list`, `info`, `search`) are permitted.
*   **Rationale**: To prevent shared installation conflicts, persistence of unwanted packages, and potential damage to core tools or system stability.

### 🟡 NPM - Conditional Support

NPM supports both local (project-specific) and global installations (`npm install -g`).

*   **Implementation**: SchoolCode allows local project installations but blocks global installations (`-g` flag) by setting `NPM_CONFIG_PREFIX` to a user-specific directory.
*   **Rationale**: Enables project-level dependency management while preventing system-wide package conflicts.

### 🟢 Git - Configuration Isolation

Git inherently separates user-specific (`~/.gitconfig`) and system-wide (`/etc/gitconfig`) configurations.

*   **Implementation**: SchoolCode leverages Git's native isolation. Guest users can configure Git globally for their session, but cannot modify system-wide Git settings.
*   **Rationale**: Allows personalized Git usage without impacting system-level configurations.

## Security Wrapper Architecture

SchoolCode employs a wrapper architecture to enforce these rules, primarily located in `/opt/admin-tools/` (or `/opt/schoolcode/` post-rename):

```
/opt/schoolcode/
├── bin/              # Symlinks to wrappers (e.g., brew -> ../wrappers/brew)
├── wrappers/         # Security wrapper scripts
│   ├── brew         # Blocks system modifications
│   ├── pip          # Forces --user installations
│   └── python       # Sets secure environment
└── actual/bin/       # Symlinks to real tool executables
```

*   **Function**: When a Guest user executes a command like `brew`, the symlink in `/opt/schoolcode/bin/` points to the wrapper script. This script then applies the defined security logic before (or instead of) executing the `actual` tool.

## Why Not Allow `brew install` with Cleanup?

A common question is why Homebrew installations by Guest users are not allowed, even with a cleanup mechanism on logout. The reasons are complex and critical for system stability:

1.  **Dependency Problem**: Homebrew installations often bring in numerous dependencies. Tracking and reliably removing all of these, including shared libraries, without breaking other tools (including SchoolCode itself) is extremely difficult and prone to error.
2.  **Version Conflict Problem**: Allowing Guest users to install different versions of tools (e.g., `python@3.12` when the system uses `python@3.11`) creates version conflicts that are hard to manage and can lead to unpredictable behavior for subsequent users.
3.  **Irreversible Upgrades**: `brew upgrade` can permanently alter system-level tools. Reverting such changes is often impossible, leading to persistent instability.
4.  **Formula Modification Problem**: Malicious or accidental `brew tap` and `brew install --force` operations could replace core tools with modified versions, creating severe security risks that are nearly impossible to detect or undo.

## Why the Current Approach is Better

By strictly blocking Homebrew modifications and enforcing user-local installations for other tools, SchoolCode achieves:

*   **Zero Maintenance**: No complex cleanup processes are needed.
*   **Guaranteed Stability**: Core tools and system configurations remain untouched.
*   **Predictable Environment**: Every student starts with an identical, fully functional development environment.
*   **Damage Prevention**: Students cannot accidentally or intentionally break the system for others.
*   **Enhanced Learning**: Students can focus on coding and experimentation without worrying about system integrity.

## Summary

SchoolCode's security model is built on the principle of **strict isolation for Guest user modifications**. By leveraging tool-specific wrappers and the ephemeral nature of Guest accounts, it provides a robust, low-maintenance, and secure platform for educational environments, ensuring a consistent and safe experience for every student.