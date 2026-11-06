import SwiftUI
import Combine

class ThemeObserver: ObservableObject {
    let theme: Theme = .shared
    private var cancellables = Set<AnyCancellable>()

    init() {
        Constants.Notifications.themeChanged.publisher()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }
}
