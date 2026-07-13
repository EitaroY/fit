import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: SettingsStore

    var body: some View {
        TabView {
            GeneralTab(store: store)
                .tabItem { Label("General", systemImage: "gearshape") }
            ShortcutsTab(store: store)
                .tabItem { Label("Shortcuts", systemImage: "keyboard") }
            AboutTab()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 480, height: 500)
    }
}

private struct GeneralTab: View {
    @ObservedObject var store: SettingsStore
    @State private var launchAtLogin = LoginItem.isEnabled
    @State private var loginItemError: String?

    var body: some View {
        Form {
            Section {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { newValue in
                        do {
                            try LoginItem.setEnabled(newValue)
                        } catch {
                            loginItemError = error.localizedDescription
                            launchAtLogin = LoginItem.isEnabled
                        }
                    }
                Text("Works best when Fit.app is copied to /Applications.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section {
                Toggle("Cycle ½ → ⅔ → ⅓ on repeated presses", isOn: $store.cycleSizesEnabled)
                Toggle("Combine halves into quarters", isOn: $store.combineHalvesToQuarters)
                Text("Cycle: pressing the same half shortcut walks ½ → ⅔ → ⅓. Combine: snap to a half, then press a perpendicular half to reach a corner (⌃⌥← then ⌃⌥↑ → top-left).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Section {
                Toggle("Snap by dragging to screen edges", isOn: $store.edgeSnapEnabled)
                Picker("Hold to pause edge snapping", selection: $store.dragSuppressModifier) {
                    ForEach(DragSuppressModifier.allCases, id: \.self) { modifier in
                        Text(modifier.title).tag(modifier)
                    }
                }
                .disabled(!store.edgeSnapEnabled)
            }
            Section {
                LabeledContent("Gap between windows") {
                    HStack {
                        Slider(value: $store.gap, in: 0...32, step: 2)
                        Text("\(Int(store.gap)) pt")
                            .monospacedDigit()
                            .frame(width: 42, alignment: .trailing)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .alert("Couldn't change login item", isPresented: .init(
            get: { loginItemError != nil },
            set: { if !$0 { loginItemError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(loginItemError ?? "")
        }
    }
}

private struct ShortcutsTab: View {
    @ObservedObject var store: SettingsStore

    var body: some View {
        VStack(spacing: 0) {
            Form {
                ForEach(SnapAction.menuGroups, id: \.title) { group in
                    Section(group.title) {
                        ForEach(group.actions, id: \.self) { action in
                            LabeledContent(action.title) {
                                ShortcutRecorderView(action: action, store: store)
                            }
                        }
                    }
                }
            }
            .formStyle(.grouped)
            Divider()
            HStack {
                Text("Assigning a combo already in use moves it to the new action.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Reset to Defaults") {
                    store.resetShortcutsToDefaults()
                }
            }
            .padding(12)
        }
    }
}

private struct AboutTab: View {
    private var version: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        return "\(short) (\(build))"
    }

    var body: some View {
        VStack(spacing: 12) {
            FitAppIconView(size: 80)
            Text("Fit").font(.title.bold())
            Text("Version \(version)")
                .foregroundStyle(.secondary)
            Text("Open-source window snapping for macOS.\nNo network, no analytics, GPL-3.0 licensed.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Link("github.com/EitaroY/fit", destination: URL(string: "https://github.com/EitaroY/fit")!)
                .font(.callout)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
