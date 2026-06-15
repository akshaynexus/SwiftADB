import Foundation
import CADB

public class ADB {
    private let serverPort: String
    private let homeDir: String

    public init(serverPort: String = "5037", homeDir: String? = nil) {
        self.serverPort = serverPort
        self.homeDir = homeDir ?? NSTemporaryDirectory()

        adb_set_server_port(serverPort)
        adb_set_home(self.homeDir)
    }

    public func execute(command: String, arguments: [String] = []) throws -> String {
        let args = [command] + arguments

        var outputBuffer: UnsafeMutablePointer<CChar>? = nil
        var outputSize: Int = 0

        var cArgs: [UnsafePointer<CChar>?] = args.map { arg in
            arg.withCString { ptr in
                UnsafePointer(ptr)
            }
        }

        let result = cArgs.withUnsafeMutableBufferPointer { buffer in
            adb_commandline_porting(&outputBuffer, &outputSize, Int32(buffer.count), buffer.baseAddress)
        }

        defer {
            if let buffer = outputBuffer {
                free(buffer)
            }
        }

        guard result == 0 else {
            throw ADBError.commandFailed(result)
        }

        if let buffer = outputBuffer, outputSize > 0 {
            return String(cString: buffer)
        }

        return ""
    }

    public func devices() throws -> [String] {
        let output = try execute(command: "devices")
        let lines = output.components(separatedBy: .newlines)
        return lines.dropFirst().filter { !$0.isEmpty }
    }

    public func connect(host: String, port: Int = 5555) throws -> String {
        return try execute(command: "connect", arguments: ["\(host):\(port)"])
    }

    public func disconnect(host: String? = nil) throws -> String {
        if let host = host {
            return try execute(command: "disconnect", arguments: [host])
        }
        return try execute(command: "disconnect")
    }

    public func shell(command: String) throws -> String {
        return try execute(command: "shell", arguments: [command])
    }

    public func install(apkPath: String) throws -> String {
        return try execute(command: "install", arguments: [apkPath])
    }

    public func push(localPath: String, remotePath: String) throws -> String {
        return try execute(command: "push", arguments: [localPath, remotePath])
    }

    public func pull(remotePath: String, localPath: String) throws -> String {
        return try execute(command: "pull", arguments: [remotePath, localPath])
    }

    public func version() throws -> String {
        return try execute(command: "version")
    }
}

public enum ADBError: LocalizedError {
    case commandFailed(Int32)

    public var errorDescription: String? {
        switch self {
        case .commandFailed(let code):
            return "ADB command failed with exit code \(code)"
        }
    }
}
