import SwiftUI
import UniformTypeIdentifiers

/// Raw-data wrapper for `.fileExporter`. `nonisolated` because `FileDocument`'s
/// requirements are nonisolated and the project defaults to MainActor isolation.
nonisolated struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
