# Build & Release Engineering Guide

## 1. Prerequisites & Toolchain

- **Target OS**: macOS 14.0 (Sonoma) or macOS 15.0+ (Sequoia)
- **Architecture**: Universal (Apple Silicon ARM64 & Intel x86_64)
- **Toolchain**: Swift 5.10+ & Xcode Command Line Tools (`xcode-select --install`)
- **Python**: Python 3.10+ with `Pillow` library (`PIL`) for automated DMG asset rendering.

---

## 2. Compilation & Development Workflow

### 2.1. Local Debug Build
To compile and launch the debug binary during development:
```bash
swift build
.build/debug/Integra
```

### 2.2. Production Release Packaging Pipeline
Integra utilizes an automated, self-contained packaging pipeline:
```bash
./scripts/package_app.sh
```

---

## 3. DMG Packaging & Drag-and-Drop Architecture

The release script (`scripts/package_app.sh`) automates the construction of Apple-standard Drag-and-Drop installer disk images:

### 3.1. Background Graphic Generation (`scripts/generate_dmg_background.py`)
- Renders a clean 1:1 scale (540x360 px at 72 DPI) modern Dark Slate background graphic (`Resources/dmg_background.png`).
- Renders a minimalist directional chevron positioned between coordinates `X=230` and `X=310` at `Y=175`.
- Avoids intrusive solid shapes and duplicate labels to let macOS Finder render native font labels cleanly.

### 3.2. AppleScript Finder Window Styling
The installer executes an automated AppleScript sequence on a temporary writable HFS+ disk image:
1. Opens the volume window and locks bounds to `{200, 150, 740, 510}` (Width: 540 pt, Height: 360 pt).
2. Sets `icon size` to `100` and configures `.background/background.png`.
3. Positions `Integra.app` on the left at `{140, 175}`.
4. Positions `/Applications` symlink on the right at `{400, 175}`.
5. Hides toolbars and status bars for a minimalist, uncluttered appearance.
6. Detaches volume and converts to compressed read-only Apple UDZO format (`hdiutil convert -format UDZO`).

---

## 4. Release Distribution Artifacts

The packaging script outputs artifacts into `dist/`:
- **`dist/Integra.app`**: Standalone native macOS application bundle (~600 KB).
- **`dist/Integra-vX.Y.Z.dmg`**: Interactive Drag-and-Drop disk image installer (~3.0 MB).
- **`dist/Integra-vX.Y.Z.zip`**: Portable compressed release archive (~2.6 MB).

---

## 5. Strict Semantic Versioning Checklist (SemVer 2.0.0)

Every AI agent and contributor MUST follow the SemVer checklist defined in `AGENTS.md`:

1. Update `CHANGELOG.md` with release notes under standard Keep a Changelog categories (`Added`, `Changed`, `Fixed`, `Removed`).
2. Update `VERSION` in `scripts/package_app.sh`.
3. Update version badge in `Sources/Integra/Views/SettingsView.swift`.
4. Update version string in `Sources/Integra/Views/SidebarView.swift`.
5. Execute `./scripts/package_app.sh` to compile and package all artifacts.
6. Commit changes and create matching Git tag `vX.Y.Z`.

---

## 6. Distribution Channels

Integra supports three primary distribution channels:

1. **One-Line Instant Installer (`scripts/install.sh`)**:
   - URL: `https://raw.githubusercontent.com/Octadira/integra/main/scripts/install.sh`
   - Automatically downloads the latest release DMG, mounts it, copies `Integra.app` to `/Applications`, and clears Gatekeeper quarantine (`xattr -cr`).
2. **Homebrew Cask (`Casks/integra.rb`)**:
   - Users install via: `brew install --cask octadira/integra/integra`
   - Automatically maintained and updated with new SHA256 checksums on each release via `scripts/publish_github_release.sh`.
3. **Manual DMG Download**:
   - Downloadable from GitHub & Forgejo Releases.

