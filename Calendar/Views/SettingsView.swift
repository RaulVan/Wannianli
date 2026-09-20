import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @ObservedObject var state: CalendarState
    @ObservedObject var holidays: HolidayStore
    @ObservedObject var updater: AppUpdater
    @State private var loginEnabled = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?

    var body: some View {
        Form {
            Section("显示") {
                Picker("菜单栏", selection: $state.menuFormat) {
                    Text("日历图标与日号").tag("icon")
                    Text("公历与农历").tag("lunar")
                    Text("日期与星期").tag("weekday")
                }
                Picker("每周开始于", selection: $state.mondayFirst) {
                    Text("星期一").tag(true)
                    Text("星期日").tag(false)
                }
                Picker("外观", selection: $state.appearance) {
                    Text("跟随系统").tag("system")
                    Text("浅色").tag("light")
                    Text("深色").tag("dark")
                }
            }
            Section("通用") {
                Toggle("登录时启动万年历", isOn: Binding(get: { loginEnabled }, set: updateLogin))
                if let loginError { Text(loginError).font(.caption).foregroundStyle(Design.red) }
            }
            Section("软件更新") {
                Toggle("自动检查更新", isOn: Binding(
                    get: { updater.automaticallyChecksForUpdates },
                    set: { updater.automaticallyChecksForUpdates = $0 }
                ))
                Picker("检查间隔", selection: Binding(
                    get: { updater.updateCheckInterval },
                    set: { updater.updateCheckInterval = $0 }
                )) {
                    Text("每小时").tag(TimeInterval(60 * 60))
                    Text("每 6 小时").tag(TimeInterval(6 * 60 * 60))
                    Text("每天").tag(TimeInterval(24 * 60 * 60))
                    Text("每周").tag(TimeInterval(7 * 24 * 60 * 60))
                }
                .disabled(!updater.automaticallyChecksForUpdates)
                Button("立即检查更新…") { updater.checkForUpdates() }
                    .disabled(!updater.canCheckForUpdates)
                Text("更新来自 GitHub Releases。当前发布包未经 Apple 公证，安装时可能需要在系统设置中确认打开。")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("中国大陆放假安排") {
                LabeledContent("离线覆盖", value: holidays.years.keys.sorted().map(String.init).joined(separator: "、") + " 年")
                LabeledContent("最近更新", value: holidays.lastUpdated?.formatted(date: .abbreviated, time: .shortened) ?? "内置数据")
                HStack {
                    Text(holidays.message).font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button(holidays.isRefreshing ? "更新中…" : "更新假期") {
                        Task { await holidays.refresh(year: state.year, force: true) }
                    }.disabled(holidays.isRefreshing)
                }
                Link("假期数据来源：holiday-calendar", destination: URL(string: "https://github.com/cg-zhou/holiday-calendar")!)
                Text("每 24 小时自动检查。未收录年份不显示休假与补班标记。")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("关于") {
                Text("万年历 1.0.0 · 农历、节气与黄历离线可用")
                Link("历法：LunarSwift · MIT License", destination: URL(string: "https://github.com/6tail/lunar-swift")!)
            }
        }.formStyle(.grouped).padding(12).frame(width: 510, height: 510)
    }

    private func updateLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
            loginEnabled = SMAppService.mainApp.status == .enabled
            loginError = SMAppService.mainApp.status == .requiresApproval ? "请在系统设置的登录项中允许万年历运行。" : nil
        } catch {
            loginEnabled = SMAppService.mainApp.status == .enabled
            loginError = "无法更改登录项：\(error.localizedDescription)"
        }
    }
}
