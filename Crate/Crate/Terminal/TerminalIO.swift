import Foundation
import Containerization

final class TerminalOutputWriter: Writer, Sendable {
    private let handler: @Sendable (Data) -> Void

    init(handler: @escaping @Sendable (Data) -> Void) {
        self.handler = handler
    }

    func write(_ data: Data) throws {
        handler(data)
    }
}

final class TerminalInputReader: ReaderStream, Sendable {
    private let continuation: AsyncStream<Data>.Continuation
    let stream_: AsyncStream<Data>

    init() {
        var cont: AsyncStream<Data>.Continuation!
        self.stream_ = AsyncStream { cont = $0 }
        self.continuation = cont
    }

    func send(_ string: String) {
        if let data = string.data(using: .utf8) {
            continuation.yield(data)
        }
    }

    func sendRaw(_ data: Data) {
        continuation.yield(data)
    }

    func stream() -> AsyncStream<Data> {
        stream_
    }
}
