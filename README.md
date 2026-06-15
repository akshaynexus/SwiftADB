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

ADB authentication requires a 2048-bit RSA key pair. You can generate a new key pair on the fly or load existing PEM key files using Apple's Security framework:

```swift
import SwiftADB

// Generate a new key pair
let keyPair = try KeyPair.generate()
```

If you have a pre-existing key (e.g. `~/.android/adbkey`), you can instantiate a `KeyPair` by parsing the private key and public key into `SecKey` objects and using the `KeyPair(privateKey:publicKey:)` initializer.

---

## Connection & Pairing Flow

SwiftADB supports both the traditional **unencrypted TCP connection (Port 5555)** and **modern secure TLS connections (STLS)**.

### Traditional Connection & On-Device Pairing (Port 5555)

When connecting to a device over an unencrypted connection:
1. **Initial Signature Check:** SwiftADB attempts to sign a challenge token from the device using the host's private key.
2. **Known Hosts:** If the device has previously accepted this host's public key, it accepts the signature, sends a `CNXN` (connect) packet, and the connection is established.
3. **On-Device Prompt (Pairing):** If the device does not recognize the signature:
   - If `throwOnUnauthorised: true` is passed, the connection fails immediately throwing `.authenticationFailed`.
   - If `throwOnUnauthorised: false` (default), SwiftADB automatically sends the host's public key. This triggers the **"Allow USB debugging?"** confirmation prompt on the Android device's screen. The connection blocks until the user taps **"Allow"**, after which the device sends `CNXN`.

```swift
let connection = try AdbConnection.Builder()
    .setHost("192.168.1.100")
    .setPort(5555)
    .setKeyPair(keyPair)
    .setDeviceName("MyMacBook")
    .build()

do {
    // This will trigger the authorization popup on the device screen if not already paired
    let connected = try await connection.connect(
        timeout: 30, // Give the user 30 seconds to tap "Allow" on the device
        throwOnUnauthorised: false
    )
    if connected {
        print("Successfully authenticated and connected!")
    }
} catch ADBError.authenticationFailed {
    print("Authentication rejected or user did not authorize the connection.")
} catch {
    print("Connection error: \(error.localizedDescription)")
}
```

### Secure Connections via TLS (STLS)

Modern Android devices (Android 11+) support secure wireless debugging over TLS.

To configure and establish a TLS connection:
1. Pass `useTls: true` to the `connect` method.
2. In STLS mode, the connection will initiate a TLS v1.3 handshake (negotiating a secure tunnel) immediately after receiving the STLS command sequence.
3. You can attach a certificate (e.g. self-signed or CA-signed) via `KeyPair(privateKey:certificate:)` to handle certificate identity matching.

```swift
let connected = try await connection.connect(
    timeout: 15,
    throwOnUnauthorised: true,
    useTls: true // Upgrades the transport socket to TLS v1.3 (STLS)
)
```

---

## Running Shell Commands

SwiftADB supports two primary shell running modes: **Non-Interactive (Single Command)** and **Interactive Terminal Sessions**.

### Non-Interactive Shell Commands

Use this mode to execute a single shell command and capture its output. The stream is automatically closed by the Android device once execution completes.

```swift
// Executes a command and exits
let stream = try await connection.open(service: .shell, args: ["pm", "list", "packages", "-3"])

while !await stream.getIsClosed() {
    do {
        let data = try await stream.read()
        if data.isEmpty { break } // EOF reached
        
        if let text = String(data: data, encoding: .utf8) {
            print(text, terminator: "")
        }
    } catch {
        print("\nStream error: \(error)")
        break
    }
}
print("\nCommand finished.")
```

### Interactive Shell Sessions

Open an interactive shell by passing an empty array of arguments. In this mode, the stream remains open. You can write commands directly to standard input (`stdin`) and listen to standard output (`stdout`) continuously.

```swift
let shellStream = try await connection.open(service: .shell, args: [])

// Setup an async task to continuously read output from the shell
Task {
    while !await shellStream.getIsClosed() {
        if let data = try? await shellStream.read(), !data.isEmpty,
           let output = String(data: data, encoding: .utf8) {
            print(output, terminator: "")
        }
    }
}

// Write commands interactively
func executeCommand(_ command: String) async throws {
    let cmdData = (command + "\n").data(using: .utf8)!
    try await shellStream.write(cmdData)
}

// Send interactive inputs
try await executeCommand("cd /sdcard")
try await executeCommand("pwd")
try await executeCommand("ls -l")

// Terminate/Close the interactive session
try await shellStream.close()
```

---

## Complete Integration Example (Pairing, Shell, & APK Installation)

Here is a full integration example demonstrating how to configure a key pair, authenticate/pair with a device, run a diagnostic shell command, and stream-install an APK package.

```swift
import Foundation
import SwiftADB

func runADBFlow() async {
    do {
        // 1. Generate or load a 2048-bit RSA keypair
        let keyPair = try KeyPair.generate()
        
        // 2. Setup the connection builder
        let connection = try AdbConnection.Builder()
            .setHost("192.168.1.100") // Target Android device IP
            .setPort(5555)            // Default ADB port
            .setKeyPair(keyPair)
            .setDeviceName("MyMacBook")
            .build()
        
        print("Connecting to device...")
        
        // 3. Connect and handle pairing
        // If not already paired, this will block and wait for the user to tap "Allow" on the device screen
        let connected = try await connection.connect(
            timeout: 60, // Give the user plenty of time to authorize on-screen
            throwOnUnauthorised: false
        )
        
        guard connected else {
            print("Failed to establish connection.")
            return
        }
        
        print("Connected and authenticated!")
        
        // 4. Run a shell command to verify the device model
        print("Fetching device model...")
        let infoStream = try await connection.open(service: .shell, args: ["getprop ro.product.model"])
        while !await infoStream.getIsClosed() {
            if let data = try? await infoStream.read(), !data.isEmpty,
               let model = String(data: data, encoding: .utf8) {
                print("Device Model: \(model.trimmingCharacters(in: .whitespacesAndNewlines))")
            }
        }
        
        // 5. Install an APK file using stream installation
        let apkURL = URL(fileURLWithPath: "/path/to/my-app.apk")
        let apkData = try Data(contentsOf: apkURL)
        let apkSize = apkData.count
        
        print("Streaming APK (\(apkSize) bytes) to the package manager...")
        
        // Open the package installer command stream
        // Android's 'cmd package install' service accepts file streaming via stdin
        let installStream = try await connection.open(
            destination: "exec:cmd package install -S \(apkSize)"
        )
        
        // Write the APK bytes to the stream
        try await installStream.write(apkData)
        
        // Read the installation result output (e.g. "Success" or "Failure [reason]")
        var installResult = ""
        while !await installStream.getIsClosed() {
            if let responseData = try? await installStream.read(), !responseData.isEmpty,
               let text = String(data: responseData, encoding: .utf8) {
                installResult += text
            }
        }
        
        print("Install Result: \(installResult.trimmingCharacters(in: .whitespacesAndNewlines))")
        
        // 6. Clean up and close connection
        await connection.close()
        print("Connection closed.")
        
    } catch {
        print("ADB Flow Error: \(error.localizedDescription)")
    }
}
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

