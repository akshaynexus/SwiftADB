# SwiftADB

A 100% native Swift implementation of the ADB (Android Debug Bridge) protocol for iOS, macOS, tvOS, and watchOS.

This library eliminates the need for native C-based wrapper dependencies (like `adb-mobile`), implementing the full ADB protocol, RSA key signing, ASN.1 parsing, and secure connection upgrades (STLS) natively in Swift using Apple's Network and Security frameworks.

## Features

- **Pure Swift:** Zero external C libraries or submodules required.
- **Swift Concurrency:** Modern async/await APIs using `actor` design to ensure safe concurrent connection and stream management.
- **Natively Secure:** Integrates standard Apple `Security` APIs for RSA key pair generation/signing and Apple `Network` APIs for secure TLS v1.3 handshakes (STLS).
- **Stream-based Protocol:** Open interactive streams directly over ADB to run shell commands, forward ports, transfer files, and more.

## Requirements

- iOS 13.0+ / macOS 10.15+ / tvOS 13.0+ / watchOS 6.0+
- Swift 6.0+
- Xcode 15.0+

## Installation

### Swift Package Manager

Add SwiftADB to your `Package.swift` dependencies:

```swift
dependencies: [
    .package(url: "https://github.com/akshaynexus/SwiftADB.git", from: "1.0.0")
]
```

Or in Xcode:
1. Go to **File** → **Add Packages...**
2. Enter the repository URL: `https://github.com/akshaynexus/SwiftADB.git`
3. Set Dependency Rule to **Up to Next Major Version** starting from `1.0.0`.

---

## Getting Started

### 1. Generate or Load an RSA KeyPair

ADB authentication requires an RSA key pair. You can generate a new one or initialize it with existing `SecKey` references:

```swift
import SwiftADB

// Generate a new 2048-bit RSA key pair
let keyPair = try KeyPair.generate()
```

### 2. Connect to an ADB Server/Device

Use the `AdbConnection.Builder` to build and initiate a connection to the target device.

```swift
import SwiftADB

let connection = try AdbConnection.Builder()
    .setHost("192.168.1.100") // IP address of the Android device
    .setPort(5555)            // Default ADB port
    .setKeyPair(keyPair)
    .setDeviceName("MyMacBook")
    .build()

// Establish connection with a timeout (seconds)
let success = try await connection.connect(
    timeout: 15,
    throwOnUnauthorised: true,
    useTls: true // Set to true to upgrade connection using TLS (STLS) for modern devices
)

if success {
    print("Connected successfully!")
}
```

### 3. Open a Stream and Run Shell Commands

Once connected, you can open streams for various services using `LocalServices`.

```swift
// Open a shell service stream
let stream = try await connection.open(service: .shell, args: ["logcat", "-d"])

// Read data asynchronously from the stream until EOF or closed
while !await stream.getIsClosed() {
    do {
        let data = try await stream.read()
        if data.isEmpty { break } // EOF
        
        if let output = String(data: data, encoding: .utf8) {
            print(output)
        }
    } catch {
        print("Stream error: \(error)")
        break
    }
}
```

### 4. Interactive Command Writing

You can write data to an active stream (e.g., executing commands interactively inside a shell session).

```swift
let interactiveShell = try await connection.open(service: .shell, args: [])

// Send command text followed by newline
if let commandData = "pm list packages\n".data(using: .utf8) {
    try await interactiveShell.write(commandData)
}

// Close the stream when done
try await interactiveShell.close()
```

---

## API Reference

### `KeyPair`
Manages the generation, storage, and signing of authentication tokens.
- `static func generate() throws -> KeyPair`: Generates a new 2048-bit RSA key pair.
- `func sign(token: Data) throws -> Data`: Signs the challenge token sent by the ADB daemon.

### `AdbConnection`
Manages the lifetime and socket interactions of an active ADB session.
- `connect(timeout: TimeInterval, throwOnUnauthorised: Bool, useTls: Bool) async throws -> Bool`: Connects, authenticates, and upgrades (if requested) to TLS.
- `open(service: LocalServices, args: [String]) async throws -> AdbStream`: Opens a stream of the given service.
- `close() async`: Closes the connection and cleans up all active streams.

### `AdbStream`
Represents an active bi-directional stream with the ADB daemon.
- `read() async throws -> Data`: Reads the next chunk of incoming data.
- `write(_ data: Data) async throws`: Writes payload data to the stream.
- `close() async throws`: Closes this stream.
- `getIsClosed() -> Bool`: Checks if the stream has been closed.

### `LocalServices`
Supported service types including:
- `.shell` (Interactive / single shell commands)
- `.tcpConnect` (Port forwarding/tunneling)
- `.remount`
- `.file`
- `.framebuffer`
- `.backup` / `.restore`
- `.reverse` (Reverse port forwarding)
- And local/abstract Unix sockets.

---

## License

SwiftADB is available under the GPL-3.0-or-later OR Apache-2.0 License. See the LICENSE file for details.

