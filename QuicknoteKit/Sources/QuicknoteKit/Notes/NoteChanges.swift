import GRDB

extension AppDatabase {
    /// Every note now, then again after each change to the `note` table.
    public func noteChanges() -> AsyncStream<[Note]> {
        let observation = ValueObservation.tracking { try Note.fetchAll($0) }
        let values = observation.values(in: writer)
        return AsyncStream { continuation in
            let task = Task {
                do { for try await notes in values { continuation.yield(notes) } } catch {}
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
