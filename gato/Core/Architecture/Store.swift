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
        var updatedState = state
        let effects = reducer(&updatedState, action)
        state = updatedState

        for effect in effects {
            Task { @MainActor in
                let actions = await effect.operation()
                for nextAction in actions {
                    self.send(nextAction)
                }
            }
        }
    }
}

struct Effect<Action> {
    let operation: () async -> [Action]

    static var none: Effect<Action> {
        Effect<Action> { [] }
    }

    static func send(_ action: Action) -> Effect<Action> {
        Effect<Action> { [action] }
    }

    static func run(_ operation: @escaping () async -> [Action]) -> Effect<Action> {
        Effect<Action>(operation: operation)
    }
}
