import SwiftUI

struct RootTabView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch appState.selectedTab {
                case .generate:
                    GeneratePlanView()
                case .myTasks:
                    MyTasksView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemBackground))

            if !appState.isRootTabBarHidden {
                HStack(spacing: 10) {
                    navButton(tab: .generate, title: "生成计划", systemImage: "wand.and.stars")
                    navButton(tab: .myTasks, title: "我的任务", systemImage: "checklist")
                }
                .padding(8)
                .background(.ultraThinMaterial, in: Capsule())
                .padding(.bottom, 10)
            }
        }
    }

    private func navButton(tab: AppTab, title: String, systemImage: String) -> some View {
        Button {
            appState.selectedTab = tab
        } label: {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.subheadline.weight(.semibold))
                Text(title)
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(appState.selectedTab == tab ? .white : .primary)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(appState.selectedTab == tab ? Color.black : Color.clear, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}
