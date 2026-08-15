import Foundation

public class IntegraLogger {
    public static let shared = IntegraLogger()
    
    private let logQueue = DispatchQueue(label: "com.integra.app.logger", qos: .utility)
    
    private var logFileURL: URL {
        let logDir = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Logs/Integra", isDirectory: true)
        try? FileManager.default.createDirectory(at: logDir, withIntermediateDirectories: true)
        return logDir.appendingPathComponent("integra.log")
    }
    
    public func log(_ message: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let line = "[\(timestamp)] \(message)\n"
        print(line, terminator: "")
        
        logQueue.async { [weak self] in
            guard let self = self else { return }
            let fileURL = self.logFileURL
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
