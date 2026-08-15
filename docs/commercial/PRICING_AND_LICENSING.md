# Pricing, Licensing & Distribution Strategy

## 1. Open Core & Licensing Model

Integra is distributed under a modern **Open Source / Enterprise Dual-Tier Model** designed to maximize developer adoption while offering enterprise support and fleet deployment capabilities.

---

## 2. Tier Comparison

| Feature | **Community Edition (Free & Open Source)** | **Integra Pro / Team** | **Enterprise Fleet** |
| :--- | :--- | :--- | :--- |
| **License** | MIT / Open Source | Commercial License | Custom Enterprise SLA |
| **Price** | **$0 / Forever Free** | **$19 one-time** (Pay what you want) | **Custom annual quote** |
| **Unlimited Connections** | ✅ Yes | ✅ Yes | ✅ Yes |
| **FUSE-T KEXT-Free Engine** | ✅ Yes | ✅ Yes | ✅ Yes |
| **Tailscale SSH Integration** | ✅ Yes | ✅ Yes | ✅ Yes |
| **Terminal & IDE Integrations** | ✅ Ghostty, Warp, Cursor, Antigravity | ✅ All Integrations | ✅ All Integrations |
| **Desktop Shortcut Lifecycle** | ✅ Yes | ✅ Yes | ✅ Yes |
| **Cloud Profile Synchronization** | ❌ Local `~/.ssh/config` only | ✅ Encrypted iCloud Sync | ✅ Private S3 / Vault Sync |
| **Centralized MDM Deployment** | ❌ Manual DMG / Homebrew | ❌ Manual | ✅ Jamf, Kandji, Microsoft Intune `.pkg` |
| **Priority Support** | Community GitHub Issues | Direct Email Support | 24/7 Dedicated SLA & Engineering |

---

## 3. Distribution Channels

1. **GitHub Releases**: Pre-compiled notarized `.dmg` and `.zip` binaries.
2. **Homebrew Cask**: Direct installation via `brew install --cask integra`.
3. **Enterprise PKG**: Signed, notarized `.pkg` package ready for zero-touch MDM distribution.
