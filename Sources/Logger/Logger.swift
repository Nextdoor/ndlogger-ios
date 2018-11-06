import Foundation

/**
 *  NSURL Class Extension.
 */
extension URL {
    /// Returns the size of the file if it exists. 0 otherwise.
    var logger_fileSize: UInt64 {
        get {
            assert(self.isFileURL)
            var error: Error?
            let fm: FileManager = FileManager.default
            let dic: [FileAttributeKey: Any]?
            do {
                dic = try fm.attributesOfItem(atPath: self.path)
            } catch let error1 {
                error = error1
                dic = nil
            }

            if self.isFileURL && error == nil {
                return dic![.size] as! UInt64
            } else {
                return 0
            }
        }
    }
}

/**
 *  Class which manages log statements to a file.
 *
 *  Algorithm is borrowed from linux log utility
 *  which rolls over by appending an incremented
 *  number to the log files.
 *
 *  For our simpler use case, we will just use
 *  two log files.
 *
 *  Note that the access qualifier is internal and not
 *  public since this class currently resides in our
 *  containing application's target.
 */
@objcMembers
public class Logger: NSObject {
    // Constants
    let maxFileSize = UInt64(256 * 1024) // 256K

    private let rolloverFooter: String = String("Rolling over log file...")
    private let directoryName: String = String("Logs")
    private let currentFileName: String = String("com.nextdoor.ios.0.log")
    private let previousFileName: String = String("com.nextdoor.ios.1.log")
    private let exportedFileName: String = String("com.nextdoor.ios.log")
    private let fm: FileManager = FileManager.default

    // Stored Properties
    /**
     Logger's directory URL.

     This directory contains all log files.
     */
    var baseURL: URL

    private var currentURL: URL
    private var previousURL: URL
    private var logStream: OutputStream?

    // Note that we will not use the computed property
    // for performance reasons.
    //    var currentFileSize : UInt64 {
    //      get {
    //          return curl.fileSize
    //      }
    //    }
    private var currentFileSize: UInt64

    // Note:
    // This is a computed property for convenience.
    // Everytime this is queried, the latest snapshot
    // is captured. Though, this comes with a cost of
    // performance. This should not be called very often.
    // Note this is not thread safe. Must only be called
    // from main thread.

    // Computed properties
    public var logFileURL: URL {
        get {
            assert(Thread.isMainThread)
            assert(maxFileSize < (1024 * 1024),
                     "Let's refactor this to use stream processing.")

            var error: Error? = nil
            let url = baseURL.appendingPathComponent(exportedFileName,
                                                     isDirectory: false)

            do {
                try logData()?.write(to: url,
                                     atomically: true,
                                     encoding: String.Encoding.utf8)
            } catch let error1 {
                error = error1
            }

            // Safety check.
            assert(error == nil)

            return url
        }
    }

    // Singleton shared instance
    public static var shared = Logger()

    // Designated initializer
    override init() {
        var error: Error?

        // Find the application support directory
        var url: URL?
        do {
            url = try fm.url(for: .applicationSupportDirectory,
                             in: .userDomainMask,
                             appropriateFor: nil,
                             create: false)
        } catch let error1 {
            error = error1
            url = nil
        }

        assert(url != nil && error == nil,
                 "We must get an application support directory.")

        // Prepare the Log directory
        url = url?.appendingPathComponent(directoryName,
                                          isDirectory: true)

        // Create the directory with intermediate flag set to yes.
        // This assumes that create will return asap if the directory
        // already exists.
        var result: Bool
        do {
            try fm.createDirectory(at: url! as URL,
                                   withIntermediateDirectories: true,
                                   attributes: nil)
            result = true
        } catch let error1 {
            error = error1
            result = false
        }

        // We must have a directory
        let errorString = String(describing: error)
        assert(error == nil && result == true,
                 "An error occured while creating a directory: \(errorString)")

        do {
            // Exclude from backup.
            var resourceValues = URLResourceValues()
            resourceValues.isExcludedFromBackup = true
            try url?.setResourceValues(resourceValues)
        } catch let error1 {
            error = error1
        }

        // OK, now we have a directory created and initialized
        baseURL = url!

        // Initialize current and previous URLs
        currentURL = self.baseURL.appendingPathComponent(currentFileName,
                                                         isDirectory: false)
        previousURL = self.baseURL.appendingPathComponent(previousFileName,
                                                          isDirectory: false)

        // Initialize the current file size
        currentFileSize = currentURL.logger_fileSize
    }

    // De-initializer
    deinit {
        finalizeStream(rollover: false)
    }

    public func log(_ items: Any...,
        file: String = #file,
        line: Int = #line) {
        #if DEBUG
        let separator = ""
        let terminator = "\n"
        Swift.print("\(file): \(line):")
        var i = items.startIndex
        repeat {
            Swift.print(items[i], separator: separator, terminator: i == (items.endIndex - 1) ? terminator : separator)
            i += 1
        } while i < items.endIndex
        #endif

        logToFile(text: "\(file):\(line): \(items)")
    }

    @objc(log:)
    public func log(message: String) {
        logToFile(text: message)
    }

    /**
     Returns all log statements as a String optional.

     - returns: all log statements
     */
    func logData() -> String? {
        // Note:
        // It is okay to read everything in memory for now.
        // Setting a note to self for 1M threshold.
        // It is OK to leave this method not synchronized
        // since this is reading from a file.
        assert(maxFileSize < (1024 * 1024),
                 "Let's refactor this to use stream processing.")
        var cdata: String? = nil
        cdata = try? String(contentsOf: currentURL as URL,
                            encoding: String.Encoding.utf8)
        var pdata: String? = nil
        pdata = try? String(contentsOf: previousURL as URL,
                            encoding: String.Encoding.utf8)

        if let previous = pdata {
            if let current = cdata {
                return current + previous
            }

            // Just return previous file data
            return previous
        } else if let current = cdata {
            // Just return current file data
            return current
        }

        return nil
    }

    private func logToFile(text: String) {
        #if !os(Linux)
        objc_sync_enter(self)
        #endif
        if logStream == nil {
            logStream = openStream()
        }

        let status: Stream.Status? = logStream?.streamStatus

        if status! == .open || status! == .writing {
            let data = text.data(using: String.Encoding.utf8)
            if let unwrappedData = data {
                let bytes = unwrappedData.withUnsafeBytes { logStream?.write($0, maxLength: unwrappedData.count) }
                if let unwrappedBytes: Int = bytes {
                    currentFileSize += UInt64(unwrappedBytes)
                    assert(currentFileSize < UInt64.max)
                }
            }
        } else {
            assert(false)
        }

        // Check if we need to rollover
        if currentFileSize > maxFileSize {
            finalizeStream()
        }
        #if !os(Linux)
        objc_sync_exit(self)
        #endif

    }

    private func openStream() -> OutputStream? {
        var stream: OutputStream?

        if currentFileSize > maxFileSize {
            // Note this should only happen if an app upgrade
            // changes the constant of max log file size.
            // In this case, we will simply roll over
            finalizeStream()
        }

        // Open a new stream
        stream = OutputStream(url: currentURL as URL, append: true)
        stream?.open()

        return stream
    }

    private func finalizeStream(rollover: Bool = true) {
        let footerData = rolloverFooter.data(using: String.Encoding.utf8)
        if let data = footerData {
            _ = data.withUnsafeBytes { logStream?.write($0, maxLength: data.count) }
        }

        logStream?.close()
        logStream = nil
        currentFileSize = 0

        if rollover == true {
            // Remove previous file in preparation for rollover.
            try? fm.removeItem(at: previousURL as URL)
            // Move current file to previous - this is faster than copying
            // contents.
            try? fm.moveItem(at: currentURL as URL, to: previousURL as URL)
        }
    }
}
