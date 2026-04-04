import Foundation

enum AppScreen {
    case library
    case game(URL)
}

@MainActor
final class AppState: ObservableObject {
    @Published var currentScreen: AppScreen = .library
    @Published var toastMessage: String?
    @Published var showHelp = false

    func showToast(_ message: String) {
        toastMessage = message
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(1))
            if self?.toastMessage == message {
                self?.toastMessage = nil
            }
        }
    }
}
