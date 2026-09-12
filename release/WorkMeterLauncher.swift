import Foundation
import Darwin

let fileManager = FileManager.default
let supportDirectory = fileManager.homeDirectoryForCurrentUser
    .appendingPathComponent("Library/Application Support/WorkMeter", isDirectory: true)

try? fileManager.createDirectory(at: supportDirectory, withIntermediateDirectories: true)

let lockURL = supportDirectory.appendingPathComponent("instance.lock")
let lockFD = Darwin.open(lockURL.path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)

guard lockFD >= 0 else {
    exit(1)
}

// Keep exactly one WorkMeter instance per user. The advisory lock is held by
// the open file descriptor and is released automatically when the process exits.
if flock(lockFD, LOCK_EX | LOCK_NB) != 0 {
    Darwin.close(lockFD)
    exit(0)
}

// Preserve the lock across exec so WorkMeterCore owns it for its whole lifetime.
_ = fcntl(lockFD, F_SETFD, 0)

let coreURL = Bundle.main.bundleURL
    .appendingPathComponent("Contents/MacOS/WorkMeterCore")
let corePath = coreURL.path

var arguments: [UnsafeMutablePointer<CChar>?] = [strdup(corePath), nil]
let result = arguments.withUnsafeMutableBufferPointer { buffer in
    execv(corePath, buffer.baseAddress)
}

for case let pointer? in arguments {
    free(pointer)
}

Darwin.close(lockFD)
exit(result == -1 ? 127 : 0)
