# macOS Keychain Security Architecture

## 1. Security Architecture Principles

Integra enforces strict credential safety:
1. **Zero Plain-Text Credentials on Disk**: Plain-text SSH passwords, server tokens, and private key passphrases are **NEVER** stored in `UserDefaults`, `.plist` files, or application caches.
2. **Apple Keychain Services Isolation**: All sensitive authentication data is delegated to macOS Keychain Services via Apple's native `Security.framework`.
3. **Application Sandboxing & Scope**: Keychain entries are partitioned under the primary service identifier `com.integra.app`.

---

## 2. Keychain Implementation Details

The `KeychainService` class (`Sources/Integra/Services/KeychainService.swift`) manages cryptographic credential storage:

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

### 2.3. Deleting Credentials (`deletePassword`)
- When a connection profile is deleted from Integra, its corresponding Keychain record is permanently purged via `SecItemDelete`.

---

## 3. Threat Model & Mitigations

| Threat Vector | Mitigation Strategy |
| :--- | :--- |
| **Process Inspection / Memory Dump** | Passwords are piped directly via private UNIX pipes (`Process.standardInput`) and closed immediately. No CLI arguments contain credentials. |
| **Local File Inspection** | Profile configuration files store only metadata (host, user, port, UUID). Passwords exist exclusively in encrypted Keychain storage. |
| **Remote Man-in-the-Middle (MITM)** | Connection utilizes `-o StrictHostKeyChecking=accept-new` to cryptographically pin remote host public keys upon initial trust. |
