import Foundation

@MainActor
public class DependencyService: ObservableObject {
    @Published public var items: [DependencyItem] = [
        DependencyItem(type: .homebrew, state: .checking),
        DependencyItem(type: .fuseT, state: .checking),
        DependencyItem(type: .sshfs, state: .checking)
    ]
    
    @Published public var isInitialCheckComplete: Bool = false
    
    public init() {
        // Run initial fast check on creation so no false warning badges appear on app launch
        fastInitialCheck()
    }
    
    private func fastInitialCheck() {
        let brewPath = findExecutable(name: "brew")
        items[0].state = brewPath != nil ? .installed(path: brewPath!) : .missing
        
        let fuseTPath = findFuseT()
        items[1].state = fuseTPath != nil ? .installed(path: fuseTPath!) : .missing
        
        let sshfsPath = findSshfsBinary()
        items[2].state = (sshfsPath != nil && fuseTPath != nil) ? .installed(path: sshfsPath!) : .missing
        
        isInitialCheckComplete = true
    }
    
    public func checkAllDependencies() async {
        fastInitialCheck()
    }
    
    public var allInstalled: Bool {
        let fuseInstalled = items[1].state.isInstalled
        let sshfsInstalled = items[2].state.isInstalled
        return fuseInstalled && sshfsInstalled
    }
    
    public func findExecutable(name: String) -> String? {
        let candidatePaths = [
            "/opt/homebrew/bin/\(name)",
            "/usr/local/bin/\(name)",
            "/usr/bin/\(name)"
        ]
        for path in candidatePaths {
            if FileManager.default.fileExists(atPath: path) && FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }
        return nil
    }
    
    private func findFuseT() -> String? {
        let frameworkPath = "/Library/Frameworks/fuse_t.framework/Versions/Current/fuse_t"
        if FileManager.default.fileExists(atPath: frameworkPath) {
            return "/Library/Frameworks/fuse_t.framework"
        }
        if FileManager.default.fileExists(atPath: "/Library/Frameworks/fuse_t.framework") {
            return "/Library/Frameworks/fuse_t.framework"
        }
        return nil
    }
    
    public func findSshfsBinary() -> String? {
        let candidatePaths = [
            "/usr/local/bin/sshfs",
            "/opt/homebrew/bin/sshfs",
            "/usr/bin/sshfs"
        ]
        for path in candidatePaths {
            if FileManager.default.fileExists(atPath: path) && FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }
        return nil
    }
    
    public func generateInstallScript() -> String {
        return """
        #!/bin/bash
        set -e

        echo "=========================================================="
        echo "=== Installing Integra FUSE-T & SSHFS (Universal PKG) ==="
        echo "=========================================================="

        TMP_DIR="/tmp/integra_installer_$$"
        mkdir -p "$TMP_DIR"

        FUSE_T_URL="https://github.com/macos-fuse-t/fuse-t/releases/download/1.2.7/fuse-t-macos-installer-1.2.7.pkg"
        FUSE_T_SHA256="6a29c747e61a86a405a189efc3de42812d73147135f93a1bb0624c1e7b90e654"
        
        SSHFS_URL="https://github.com/macos-fuse-t/sshfs/releases/download/1.0.2/sshfs-macos-installer-1.0.2.pkg"
        SSHFS_SHA256="8875fe7a932893cef6333288ccf6f6e3844d3fd6825ea39e878b020466d259ca"

        echo ""
        echo "--> [1/3] Downloading official FUSE-T package & verifying integrity (SHA256)..."
        curl -fSL "$FUSE_T_URL" -o "$TMP_DIR/fuse-t.pkg"
        echo "$FUSE_T_SHA256  $TMP_DIR/fuse-t.pkg" | shasum -a 256 -c -

        echo "--> [2/3] Downloading official SSHFS package & verifying integrity (SHA256)..."
        curl -fSL "$SSHFS_URL" -o "$TMP_DIR/sshfs.pkg"
        echo "$SSHFS_SHA256  $TMP_DIR/sshfs.pkg" | shasum -a 256 -c -

        echo "--> [3/3] Installing verified packages into macOS (administrator password required)..."
        sudo /usr/sbin/installer -pkg "$TMP_DIR/fuse-t.pkg" -target /
        sudo /usr/sbin/installer -pkg "$TMP_DIR/sshfs.pkg" -target /

        rm -rf "$TMP_DIR"

        if command -v brew &> /dev/null; then
            BREW_REPO="$(brew --repository 2>/dev/null || true)"
            if [ -n "$BREW_REPO" ]; then
                rm -rf "$BREW_REPO/Library/Taps/macos-fuse-t" 2>/dev/null || true
            fi
        fi

        echo ""
        echo "=========================================================="
        echo "=== Installation Finished Successfully!                ==="
        echo "=== You can now close this window and return to Integra. ==="
        echo "=========================================================="
        """
    }
}
