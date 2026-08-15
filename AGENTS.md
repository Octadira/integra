# Agent Engineering & Versioning Guidelines

This document outlines mandatory guidelines and architectural standards for all AI coding agents working on the **Integra macOS SSHFS Manager** codebase.

---

## 1. Mandatory Language Standards

- **Application Copy & UI**: All user-facing UI labels, descriptions, alerts, placeholders, and menus MUST be written in **English**.
- **Code & Comments**: All Swift code, variable names, functions, docstrings, and comments MUST be written in **English**.
- **Documentation & Changelog**: All technical documentation, commercial copy, markdown guides, and `CHANGELOG.md` MUST be written in **English**.
- *(Note: Conversational responses to the user may follow the user's requested language, but all project code and repository files are strictly in English).*

---

## 2. Strict Semantic Versioning (SemVer 2.0.0)

Every AI agent performing code modifications, new features, or bug fixes on this repository MUST follow **Semantic Versioning**:

$$\text{Format: } \text{MAJOR}.\text{MINOR}.\text{PATCH}$$

1. **MAJOR** version when you make incompatible API/architectural breaking changes.
2. **MINOR** version when you add backwards-compatible functionality or new features to the application.
3. **PATCH** version when you make backwards-compatible bug fixes or UI tweaks in the application code.

### 2.1. Documentation-Only Exemption (No Version Bump & No Build)
- **DO NOT bump the application version or trigger a new build/DMG packaging when making documentation-only changes** (e.g. creating or updating files in `docs/`, `AGENTS.md`, `README.md`, or commercial texts).
- Documentation updates simply describe and document the current active application release. Bumping versions on docs updates creates an infinite version discrepancy loop.
- Version bumps, changelog release headers, and `./scripts/package_app.sh` builds are strictly reserved for **actual code, asset, or binary modifications**.

### 2.2. Version Synchronization Checklist (For Code/Binary Changes Only)
When bumping the version due to code/binary changes, you MUST update the version string across all of the following locations:
1. `CHANGELOG.md` (Add new release section at the top)
2. `scripts/package_app.sh` (`VERSION="X.Y.Z"`)
3. `Sources/Integra/Views/SettingsView.swift` (Version badge)
4. `Sources/Integra/Views/SidebarView.swift` (Footer version)
5. Run `./scripts/package_app.sh` to package artifacts.
6. Create a Git commit and Git tag matching `vX.Y.Z`.

### 2.3. Automated Forgejo Release Publishing
- When the user asks to publish the release or push binaries to Forgejo (e.g. *"publică release-ul"*, *"fă release pe Forgejo"*, *"publish release"*), you MUST run:
  ```bash
  ./scripts/publish_release.sh
  ```
- This script automatically extracts the version notes from `CHANGELOG.md`, creates/updates the release on Forgejo, pushes Git tags, and uploads `dist/Integra-vX.Y.Z.dmg` and `dist/Integra-vX.Y.Z.zip` as downloadable assets.

### 2.4. Selective Public GitHub Release Publishing (Explicit Request Only)
- When the user **explicitly** asks to publish the release to GitHub (e.g. *"publică pe GitHub"*, *"fă release pe GitHub"*, *"push to github"*), you MUST run:
  ```bash
  ./scripts/publish_github_release.sh
  ```
- This script securely filters the repository, excluding private dev files (`SECURITY_AUDIT.md`, internal tokens, private deployment scripts), pushes a clean public tree to `https://github.com/Octadira/integra`, and creates the public GitHub Release with `.dmg` and `.zip` binary attachments.

---

## 3. Changelog Format Guidelines

Maintain `CHANGELOG.md` following [Keep a Changelog](https://keepachangelog.com/en/1.0.0/):
- Group changes under: `Added`, `Changed`, `Deprecated`, `Removed`, `Fixed`, `Security`.
- Use concise bullet points focusing on user-facing improvements and architectural stability.

---

## 4. Architectural & Safety Principles

1. **Main Thread Safety (`@MainActor`)**:
   - External CLI processes (e.g. `sshfs`, `diskutil`, `mount`, `/usr/sbin/installer`) MUST NEVER be waited on synchronously on the `@MainActor` thread.
   - Always execute process blocking tasks inside `Task.detached(priority: .userInitiated)`.

2. **Secure Credential Storage**:
   - Never store plain-text SSH passwords or key passphrases in `UserDefaults`.
   - Always use Apple's native macOS Keychain (`Security.framework`) via `KeychainService`.

3. **FUSE-T User-Space Engine (KEXT-Free)**:
   - Ensure compatibility with user-space NFS emulation provided by FUSE-T.
   - Use direct `.pkg` download and `/usr/sbin/installer` execution for universal dependency installation across all macOS releases.

4. **Desktop & Filesystem Lifecycle Cleanliness**:
   - When Desktop shortcuts or temporary mount points are managed, ensure they are cleanly deleted/unmounted on disconnect to prevent broken symlinks.
