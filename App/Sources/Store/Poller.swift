import Foundation

/// A cancellation-aware repeat loop. `Task.sleep` throws on cancel, so tearing the task down
/// when the app backgrounds is enough to stop every poll cleanly.
enum Poller {
    static func loop(
        every interval: Duration,
        immediate: Bool = true,
        _ body: @escaping @Sendable () async -> Void
    ) -> Task<Void, Never> {
        Task {
            if immediate { await body() }
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: interval)
                } catch {
                    return
                }
                guard !Task.isCancelled else { return }
                await body()
            }
        }
    }
}
