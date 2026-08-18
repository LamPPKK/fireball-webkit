import Observation
import SwiftUI

enum BrowserCommandRequest: Equatable {
    case newTab
    case closeTab
    case focusAddress
    case goBack
    case goForward
    case reload
    case home
    case showTabs
    case toggleBookmark
}

@MainActor
@Observable
final class BrowserCommandRouter {
    private(set) var sequence = 0
    private(set) var request: BrowserCommandRequest?

    func send(_ request: BrowserCommandRequest) {
        self.request = request
        sequence += 1
    }
}

private struct BrowserCommandRouterKey: FocusedValueKey {
    typealias Value = BrowserCommandRouter
}

extension FocusedValues {
    var browserCommandRouter: BrowserCommandRouter? {
        get { self[BrowserCommandRouterKey.self] }
        set { self[BrowserCommandRouterKey.self] = newValue }
    }
}

struct BrowserCommands: Commands {
    @FocusedValue(\.browserCommandRouter) private var router

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            commandButton("New Tab", request: .newTab, key: "t")
            commandButton("Close Tab", request: .closeTab, key: "w")
        }

        CommandMenu("Navigation") {
            commandButton("Focus Address Bar", request: .focusAddress, key: "l")
            Divider()
            commandButton("Back", request: .goBack, key: "[")
            commandButton("Forward", request: .goForward, key: "]")
            commandButton("Reload Page", request: .reload, key: "r")
            commandButton("Home", request: .home, key: "h", modifiers: [.command, .shift])
        }

        CommandMenu("Tabs") {
            commandButton("Show Tab Overview", request: .showTabs, key: "\\", modifiers: [.command, .shift])
            commandButton("Toggle Bookmark", request: .toggleBookmark, key: "d")
        }
    }

    private func commandButton(
        _ title: String,
        request: BrowserCommandRequest,
        key: KeyEquivalent,
        modifiers: EventModifiers = .command
    ) -> some View {
        Button(title) { router?.send(request) }
            .keyboardShortcut(key, modifiers: modifiers)
            .disabled(router == nil)
    }
}
