import SwiftUI

private final class AgentNotificationAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        _ = AgentUserNotificationManager.shared
        return true
    }
}

@main
struct DeepSeekHarnessMobileApp: App {
    @UIApplicationDelegateAdaptor(AgentNotificationAppDelegate.self) private var notificationAppDelegate
    @StateObject private var hosts = MultiGatewayStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .id(ObjectIdentifier(hosts.activeStore))
                .environmentObject(hosts.activeStore)
                .environmentObject(hosts)
                // 朱小姐：启动**不再**提前要通知权限 —— 推送（APNs）功能还没做，
                // 一进来就弹「朱小姐想给你发通知」既不专业、又挡住首屏
                // （用户 2026-10-10 明确：「设置里的规格很不专业」+ 我每轮截图都被它盖住）。
                // 等推送真正落地时，在首次需要通知的时机再调
                // AgentUserNotificationManager.shared.requestAuthorizationIfNeeded()。
                .alert("主机连接", isPresented: Binding(get: { hosts.error != nil }, set: { if !$0 { hosts.error = nil } })) {
                    Button("好", role: .cancel) { hosts.error = nil; hosts.cancelPairing() }
                } message: { Text(hosts.error ?? "") }
        }
    }
}
