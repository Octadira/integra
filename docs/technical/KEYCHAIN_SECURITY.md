# macOS Keychain Security Architecture

## 1. Security Architecture Principles

Integra enforces strict credential safety:
1. **Zero Plain-Text Credentials on Disk**: Plain-text SSH passwords, server tokens, private key passphrases, and sudo credentials are **NEVER** stored in `UserDefaults`, `.plist` files, or application caches.
2. **Apple Keychain Services Isolation**: All sensitive authentication data is delegated to macOS Keychain Services via Apple's native `Security.framework`.
3. **Application Sandboxing & Scope**: Keychain entries are partitioned under the primary service identifier `com.integra.app`.
4. **AI Agent Privacy Isolation**: AI models and coding assistants never receive, log, or store passwords. Credentials remain strictly isolated within macOS native memory and Keychain.

---

## 2. Keychain Implementation Details

The `KeychainService` class (`Sources/IntegraCore/Services/KeychainService.swift`) manages cryptographic credential storage:

### 2.1. Storing Credentials (`savePassword`)
```swift
let attributes: [String: Any] = [
    kSecClass as String: kSecClassGenericPassword,
    kSecAttrService as String: "com.integra.app",
    kSecAttrAccount as String: accountUUID,
    kSecValueData as String: passwordData,
    kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
]
```
- **Accessibility Level**: `kSecAttrAccessibleAfterFirstUnlock` ensures credentials remain encrypted in Secure Enclave hardware until the user logs into their Mac, after which Integra can retrieve them during auto-mount workflows without repeatedly requesting master passwords.

### 2.2. Retrieving Credentials (`getPassword`)
- Queries the Keychain matching `kSecClassGenericPassword` and the profile's unique UUID.
- Returns plaintext in memory strictly during the process invocation lifecycle and discards it immediately after writing to the `sshfs` STDIN pipe.

### 2.3. Sudo Credentials Management
- **Dedicated Sudo Account Key**: Stored under `"sudo_\(profileId.uuidString)"`.
- **Automatic SSH Password Inheritance**: If `useSSHPasswordForSudo` is enabled, `getEffectiveSudoPassword(for: profile)` securely falls back to the SSH login password without requiring redundant Keychain entries.
- **In-Memory Sudo Pipe Injection**: When AI assistants execute privileged commands, `integra-mcp` retrieves the password in memory and pipes it via `sudo -S -p ''` directly into the SSH session. No credentials appear in command lines or process lists (`ps aux`).

### 2.4. Deleting Credentials (`deletePassword` & `deleteSudoPassword`)
- When a connection profile is deleted from Integra, its corresponding login and sudo Keychain records are permanently purged via `SecItemDelete`.

---

## 3. Threat Model & Mitigations

| Threat Vector | Mitigation Strategy |
| :--- | :--- |
| **Process Inspection / Memory Dump** | Passwords are piped directly via private UNIX pipes (`Process.standardInput` and in-memory `sudo -S`) and closed immediately. No CLI arguments contain credentials. |
| **Local File Inspection** | Profile configuration files store only metadata (host, user, port, UUID). Passwords exist exclusively in encrypted Keychain storage. |
| **AI Assistant Password Exposure** | AI clients communicate via structured MCP JSON-RPC. The MCP server handles authorization and password injection locally; the AI model receives only command outputs. |
| **Unauthorized AI Sudo Execution** | `SudoAuthManager` enforces Touch ID or native macOS system dialog approvals with a 15-minute grace period cache. |
| **Remote Man-in-the-Middle (MITM)** | Connection utilizes `-o StrictHostKeyChecking=accept-new` to cryptographically pin remote host public keys upon initial trust. |
