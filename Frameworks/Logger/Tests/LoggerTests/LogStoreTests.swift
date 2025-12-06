import Foundation
@testable import Logger
import Testing

@Suite("LogStore")
struct LogStoreTests {
    @Test("append writes formatted line and readTail returns it")
    func append_writesLine() throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }

        store.append(level: .info, category: "Tests", message: "hello world")
        store.flush()

        let text = store.readTail()
        #expect(text.contains("[INFO]"))
        #expect(text.contains("[Tests]"))
        #expect(text.contains("hello world"))
    }

    @Test("readTail limits output to requested byte count")
    func readTail_limitsBytes() throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }

        let message = String(repeating: "x", count: 40)
        for index in 0 ..< 5 {
            store.append(level: .debug, category: "Tail", message: "\(index)-\(message)")
        }
        store.flush()

        let tail = store.readTail(maxBytes: 128)
        #expect(!tail.contains("0-"))
        #expect(tail.contains("4-"))
        #expect(tail.count <= 200) // guard against unexpectedly large tails
    }

    @Test("log files rotate once max size is reached")
    func rotate_rotatesFiles() throws {
        let (store, directory) = try makeStore(maxFileSize: 128, maxFiles: 2)
        defer { try? FileManager.default.removeItem(at: directory) }
        let manager = FileManager.default

        for index in 0 ..< 12 {
            store.append(level: .info, category: "Rotate", message: "line-\(index)")
        }
        store.flush()

        #expect(manager.fileExists(atPath: store.logFileURL.path))
        #expect(manager.fileExists(atPath: store.rotatedFileURL(index: 1).path))
        #expect(manager.fileExists(atPath: store.rotatedFileURL(index: 2).path))
        #expect(!manager.fileExists(atPath: store.rotatedFileURL(index: 3).path))
    }

    @Test("rotate keeps newest content in base file after rolling over")
    func rotate_keepsNewestInBase() throws {
        let (store, directory) = try makeStore(maxFileSize: 96, maxFiles: 2)
        defer { try? FileManager.default.removeItem(at: directory) }

        for index in 0 ..< 6 { // likely triggers rotation at least once
            store.append(level: .info, category: "Rotate", message: "entry-\(index)")
        }
        // Write once more after rotation to ensure base file has fresh content
        store.append(level: .info, category: "Rotate", message: "latest-entry")
        store.flush()

        let tail = store.readTail(maxBytes: 256)
        #expect(tail.contains("latest-entry"))
    }

    @Test("clear removes files even after rotation happened")
    func clear_afterRotation_removesAllFiles() throws {
        let (store, directory) = try makeStore(maxFileSize: 96, maxFiles: 2)
        defer { try? FileManager.default.removeItem(at: directory) }

        for index in 0 ..< 6 {
            store.append(level: .info, category: "Rotate", message: "entry-\(index)")
        }
        store.flush()

        store.clear()

        let contents = (try? FileManager.default.contentsOfDirectory(at: store.logDirectory, includingPropertiesForKeys: nil)) ?? []
        #expect(contents.isEmpty)
    }

    @Test("readTail returns empty string when file does not exist")
    func readTail_whenFileMissing_returnsEmpty() throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }

        store.clear()
        let tail = store.readTail()
        #expect(tail.isEmpty)
    }

    @Test("clear removes base and rotated log files")
    func clear_removesAllFiles() throws {
        let (store, directory) = try makeStore(maxFileSize: 128, maxFiles: 2)
        defer { try? FileManager.default.removeItem(at: directory) }

        store.append(level: .error, category: "Cleanup", message: "boom")
        store.append(level: .error, category: "Cleanup", message: "boom2")
        store.flush()

        store.clear()

        let contents = (try? FileManager.default.contentsOfDirectory(at: store.logDirectory, includingPropertiesForKeys: nil)) ?? []
        #expect(contents.isEmpty)
    }

    @Test("category resolver infers sensible defaults")
    func resolver_infersCategory() {
        #expect(LogCategoryResolver.resolve(category: nil, fileID: "/tmp/ModelInference.swift") == "Model")
        #expect(LogCategoryResolver.resolve(category: nil, fileID: "/tmp/NetworkService.swift") == "Network")
        #expect(LogCategoryResolver.resolve(category: nil, fileID: "/tmp/UserInterfaceView.swift") == "UI")
        #expect(LogCategoryResolver.resolve(category: nil, fileID: "/tmp/DatabaseManager.swift") == "Database")
        #expect(LogCategoryResolver.resolve(category: nil, fileID: "/tmp/Other.swift") == "App")
        #expect(LogCategoryResolver.resolve(category: "Custom", fileID: "/tmp/Other.swift") == "Custom")
    }
}

private func makeStore(maxFileSize: Int = 512, maxFiles: Int = 3) throws -> (LogStore, URL) {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let store = LogStore(directory: directory, fileManager: .default, maxFileSize: maxFileSize, maxFiles: maxFiles)
    return (store, directory)
}
