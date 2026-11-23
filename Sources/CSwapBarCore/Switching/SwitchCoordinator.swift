import Foundation

public enum SwitchOutcome: Sendable, Equatable {
    /// CSwap switched and `status` confirmed the target is now active.
    case switched
    /// The target was already active.
    case alreadyActive
    case failed(SwitchFailure)
}

public enum SwitchFailure: Error, Sendable, Equatable {
    /// Another switch is still running.
    case busy
    /// The account no longer exists in CSwap.
    case accountNotFound
    /// CSwap reported success, but `status` shows a different account.
    case verificationFailed
    case timedOut
    case cswap(CSwapError)
}

/// Serializes account switches and verifies each one.
public actor SwitchCoordinator {
    private let client: any CSwapClient
    private var inFlight = false

    public init(client: any CSwapClient) {
        self.client = client
    }

    public func switchTo(_ target: AccountID) async -> SwitchOutcome {
        guard !inFlight else { return .failed(.busy) }
        inFlight = true
        defer { inFlight = false }

        do {
            // Slots can move between refreshes; resolve the current one first.
            let snapshot = try await client.listAccounts()
            guard let account = snapshot.accounts.first(where: { $0.id == target }) else {
                return .failed(.accountNotFound)
            }
            if account.isActive { return .alreadyActive }

            let response = try await client.switchTo(slot: account.slot)

            // Never report success before CSwap's own status agrees.
            let status = try await client.status()
            guard status.id == target else { return .failed(.verificationFailed) }
            return response.reason == "already-active" ? .alreadyActive : .switched
        } catch CSwapError.timedOut {
            return .failed(.timedOut)
        } catch let error as CSwapError {
            return .failed(.cswap(error))
        } catch {
            return .failed(.cswap(.commandFailed(exitCode: -1, message: error.localizedDescription)))
        }
    }
}
