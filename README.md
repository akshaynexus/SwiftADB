# SwiftADB

A Swift wrapper around [adb-mobile](https://github.com/wsvn53/adb-mobile), providing native ADB (Android Debug Bridge) functionality for iOS apps.

## Requirements

- iOS 13.0+ / macOS 10.15+
- Swift 5.9+
- Xcode 15.0+

## Installation

### Swift Package Manager

Add SwiftADB to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/akshaynexus/SwiftADB.git", from: "1.0.0")
]
```

Or in Xcode:
1. File → Add Package Dependencies
2. Enter the repository URL
3. Select version rule (e.g., "Up to Next Major" from "1.0.0")

## Setup

### Building the Native Library

Before using SwiftADB, build the adb-mobile native library:

```bash
# Clone with submodules
git clone --recursive https://github.com/akshaynexus/SwiftADB.git

# Or if already cloned
git submodule update --init --recursive

# Build the native library
cd Dependencies/adb-mobile
make
```

This generates `libadb.a` in the `Dependencies/adb-mobile/output` directory.

## Usage

### Basic Example

```swift
import SwiftADB

// Initialize with default settings
let adb = ADB()

// List connected devices
let devices = try adb.devices()
for device in devices {
    print(device)
}
```

### Custom Configuration

```swift
import SwiftADB

// Initialize with custom port and home directory
let adb = ADB(
    serverPort: "15037",
    homeDir: FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].path
)
```

### Connect to a Device

```swift
import SwiftADB

let adb = ADB()

// Connect to a device over TCP/IP
let result = try adb.connect(host: "192.168.1.100", port: 5555)
print(result)

// List connected devices
let devices = try adb.devices()
print(devices)
```

### Execute Shell Commands

```swift
import SwiftADB

let adb = ADB()

// Run a shell command
let output = try adb.shell(command: "ls -la /sdcard/")
print(output)

// Get device properties
let model = try adb.shell(command: "getprop ro.product.model")
print("Device model: \(model)")
```

### File Transfer

```swift
import SwiftADB

let adb = ADB()

// Push a file to the device
try adb.push(localPath: "/path/to/local/file.txt", remotePath: "/sdcard/file.txt")

// Pull a file from the device
try adb.pull(remotePath: "/sdcard/file.txt", localPath: "/path/to/local/file.txt")
```

### Install APK

```swift
import SwiftADB

let adb = ADB()

// Install an APK file
let result = try adb.install(apkPath: "/path/to/app.apk")
print(result)
```

### Disconnect

```swift
import SwiftADB

let adb = ADB()

// Disconnect from a specific device
try adb.disconnect(host: "192.168.1.100:5555")

// Disconnect from all devices
try adb.disconnect()
```

## API Reference

### ADB

```swift
public class ADB {
    /// Initialize ADB with optional configuration
    public init(serverPort: String = "5037", homeDir: String? = nil)

    /// Execute a raw ADB command
    public func execute(command: String, arguments: [String]) throws -> String

    /// List connected devices
    public func devices() throws -> [String]

    /// Connect to a device over TCP/IP
    public func connect(host: String, port: Int) throws -> String

    /// Disconnect from a device or all devices
    public func disconnect(host: String?) throws -> String

    /// Execute a shell command on the device
    public func shell(command: String) throws -> String

    /// Install an APK file
    public func install(apkPath: String) throws -> String

    /// Push a file to the device
    public func push(localPath: String, remotePath: String) throws -> String

    /// Pull a file from the device
    public func pull(remotePath: String, localPath: String) throws -> String

    /// Get ADB version
    public func version() throws -> String
}
```

### ADBError

```swift
public enum ADBError: LocalizedError {
    case commandFailed(Int32)
}
```

## License

MIT License
