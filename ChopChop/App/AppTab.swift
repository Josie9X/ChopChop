import Foundation
import SwiftUI

enum AppTab: Hashable {
    case generate
    case myTasks
}

@MainActor
final class AppState: ObservableObject {
    @Published var selectedTab: AppTab = .generate
    @Published var highlightedTaskID: UUID?
    @Published var isRootTabBarHidden = false
}
