import Foundation
import Darwin

let fileManager = FileManager.default
let supportDirectory = fileManager.homeDirectoryForCurrentUser
    .appendingPathComponent("Library/Application Support/WorkMeter", isDirectory: true)

try? fileManager.createDirectory(at: supportDirectory, withIntermediateDirectories: true)

let lockURL = supportDirectory.appendingPathComponent("instance.lock")
let lockFD = Darwin.open(lockURL.path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)

if lockFD < 0 {
    exit(1)
}

// A BSD flock is released automatically when the process exits. Because the
// descriptor is intentionally kept open across exec(), this lock belongs to
// the actual WorkMeter process for its full lifetime and cannot become stale.
if flock(lockFD, LOCK_EX | LOCK_NB) != 0 {
    Darwin.close(lockFD)
    exit(0)
}

// Make the intent explicit: keep the lock descriptor open across exec().
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

// execv only returns on failure.
Darwin.close(lockFD)
exit(result == -1 ? 127 : 0)
