import Foundation
import ServiceManagement
import AppKit

public class LaunchAtLoginService {
    public static let shared = LaunchAtLoginService()
    
    public init() {}
    
    public func setLaunchAtLogin(enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    if SMAppService.mainApp.status != .enabled {
                        try SMAppService.mainApp.register()
                    }
                } else {
                    if SMAppService.mainApp.status == .enabled {
                        try SMAppService.mainApp.unregister()
                    }
                }
            } catch {
                print("[LaunchAtLoginService] SMAppService note: \(error)")
            }
        }
        
        // Guarantee launch by managing LaunchAgent plist as well
        manageLaunchAgent(enabled: enabled)
    }
    
    private func manageLaunchAgent(enabled: Bool) {
        let launchAgentDir = NSHomeDirectory() + "/Library/LaunchAgents"
        let plistPath = launchAgentDir + "/com.integra.app.plist"
        
        if enabled {
            try? FileManager.default.createDirectory(atPath: launchAgentDir, withIntermediateDirectories: true)
            let appPath = FileManager.default.fileExists(atPath: "/Applications/Integra.app") ? "/Applications/Integra.app" : Bundle.main.bundlePath
            let plistContent = """
            <?xml version="1.0" encoding="UTF-8"?>
            <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
            <plist version="1.0">
            <dict>
                <key>Label</key>
                <string>com.integra.app</string>
                <key>ProgramArguments</key>
                <array>
                    <string>/usr/bin/open</string>
                    <string>-a</string>
                    <string>\(appPath)</string>
                </array>
                <key>RunAtLoad</key>
                <true/>
                <key>ProcessType</key>
                <string>Interactive</string>
            </dict>
            </plist>
            """
            try? plistContent.write(toFile: plistPath, atomically: true, encoding: .utf8)
        } else {
            if FileManager.default.fileExists(atPath: plistPath) {
                try? FileManager.default.removeItem(atPath: plistPath)
            }
        }
    }
}
