import Foundation

enum AppTab: String, CaseIterable {
    case breeds
    case favorites
}

struct AppFeature {
    struct State: Equatable {
        var selectedTab: AppTab = .breeds
    }

    enum Action: Equatable {
        case selectTab(AppTab)
    }

    static func reduce(state: inout State, action: Action) -> [Effect<Action>] {
        switch action {
        case .selectTab(let tab):
            state.selectedTab = tab
            return []
        }
    }
}
