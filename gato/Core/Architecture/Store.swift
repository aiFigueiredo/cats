import Combine
import Foundation
import SwiftUI

/// Lightweight TCA-style store used by feature reducers.
@MainActor
final class Store<State, Action>: ObservableObject {
    @Published private(set) var state: State

    private let reducer: @MainActor (inout State, Action) -> [Effect<Action>]

    init(initialState: State, reducer: @escaping @MainActor (inout State, Action) -> [Effect<Action>]) {
        self.state = initialState
        self.reducer = reducer
    }

    func send(_ action: Action) {
        let effects = reducer(&state, action)
        for effect in effects {
            Task { @MainActor in
                if let nextAction = await effect.operation() {
                    self.send(nextAction)
                }
            }
        }
    }
}

struct Effect<Action> {
    let operation: () async -> Action?

    static var none: Effect<Action> {
        Effect<Action> { nil }
    }

    static func send(_ action: Action) -> Effect<Action> {
        Effect<Action> { action }
    }

    static func run(_ operation: @escaping () async -> Action?) -> Effect<Action> {
        Effect<Action>(operation: operation)
    }
}
