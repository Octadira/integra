import Foundation

public class IntegraLogger {
    public static let shared = IntegraLogger()
    
    private let logQueue = DispatchQueue(label: "com.integra.app.logger", qos: .utility)
    
    private var logFileURL: URL {
        let logDir = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Logs/Integra", isDirectory: true)
        try? FileManager.default.createDirectory(at: logDir, withIntermediateDirectories: true)
        return logDir.appendingPathComponent("integra.log")
    }
    
    private func rotateLogsIfNeeded(fileURL: URL) {
        if let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
           let size = attrs[.size] as? Int64, size > 5 * 1024 * 1024 { // 5 MB rotation threshold (L-3 Fix)
            let backupURL = fileURL.deletingLastPathComponent().appendingPathComponent("integra.log.1")
            try? FileManager.default.removeItem(at: backupURL)
            try? FileManager.default.moveItem(at: fileURL, to: backupURL)
        }
    }
    
    public func log(_ message: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let line = "[\(timestamp)] \(message)\n"
        print(line, terminator: "")
        
        logQueue.async { [weak self] in
            guard let self = self else { return }
            let fileURL = self.logFileURL
            self.rotateLogsIfNeeded(fileURL: fileURL)
            
            if let data = line.data(using: .utf8) {
                if FileManager.default.fileExists(atPath: fileURL.path) {
                    if let fileHandle = try? FileHandle(forWritingTo: fileURL) {
                        fileHandle.seekToEndOfFile()
                        fileHandle.write(data)
                        try? fileHandle.close()
                    }
                } else {
                    try? data.write(to: fileURL)
                }
            }
        }
    }
}
