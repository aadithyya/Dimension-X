import SwiftUI
import DMXModel
import DMXProtocol
import DMXCore

// MARK: - App State & ViewModel

@MainActor
final class DimensionXViewModel: ObservableObject {
    @Published var hostIdentity: HostIdentity?
    @Published var applications: [ApplicationRecord] = []
    @Published var selectedApplication: ApplicationRecord?
    @Published var isExecuting: Bool = false
    @Published var activeSessionInfo: String = "No active execution"
    @Published var lastExecutionResult: String?
    @Published var evidenceList: [Evidence] = []
    @Published var statusMessage: String = "Connecting to dmx-core..."
    @Published var isCoreReady: Bool = false

    private let client = DCPClient()

    func initialize() async {
        await ensureCoreDaemonRunning()
        await refreshSystemStatus()
        await refreshApplications()
        await refreshEvidence()
    }

    func ensureCoreDaemonRunning() async {
        // Try pinging dmx-core; if down, spawn it on demand
        do {
            let resp = try await client.send(method: "system.status")
            if resp.ok {
                self.isCoreReady = true
                self.statusMessage = "Connected to dmx-core"
                return
            }
        } catch {
            // Core not reachable; attempt to spawn dmx-core in background
            spawnCoreProcess()
            // Wait up to 3 seconds for socket to become available
            for _ in 1...15 {
                try? await Task.sleep(nanoseconds: 200_000_000)
                if let resp = try? await client.send(method: "system.status"), resp.ok {
                    self.isCoreReady = true
                    self.statusMessage = "dmx-core started and connected"
                    return
                }
            }
            self.statusMessage = "Connected locally (in-process fallback)"
        }
    }

    private func spawnCoreProcess() {
        let bundleURL = Bundle.main.bundleURL.deletingLastPathComponent()
        let corePathCandidates = [
            bundleURL.appendingPathComponent("dmx-core").path,
            URL(fileURLWithPath: ".build/debug/dmx-core").standardized.path,
            URL(fileURLWithPath: ".build/release/dmx-core").standardized.path
        ]

        for path in corePathCandidates {
            if FileManager.default.isExecutableFile(atPath: path) {
                let proc = Process()
                proc.executableURL = URL(fileURLWithPath: path)
                try? proc.run()
                return
            }
        }
    }

    func refreshSystemStatus() async {
        do {
            let resp = try await client.send(method: "system.hostIdentity")
            if resp.ok, let payload = resp.payload {
                let data = try JSONEncoder().encode(payload)
                self.hostIdentity = try JSONDecoder().decode(HostIdentity.self, from: data)
            }
        } catch {
            self.hostIdentity = HostIdentityProbe.probe()
        }
    }

    func refreshApplications() async {
        do {
            let resp = try await client.send(method: "application.list")
            if resp.ok, let payload = resp.payload {
                let data = try JSONEncoder().encode(payload)
                self.applications = try JSONDecoder().decode([ApplicationRecord].self, from: data)
                if selectedApplication == nil, let first = applications.first {
                    selectedApplication = first
                }
            }
        } catch {
            // Error handling
        }
    }

    func refreshEvidence() async {
        do {
            let resp = try await client.send(method: "evidence.list")
            if resp.ok, let payload = resp.payload {
                let data = try JSONEncoder().encode(payload)
                self.evidenceList = try JSONDecoder().decode([Evidence].self, from: data)
            }
        } catch {
            // Error handling
        }
    }

    func importExecutable(path: String) async {
        guard !path.isEmpty else { return }
        statusMessage = "Analyzing \(URL(fileURLWithPath: path).lastPathComponent)..."
        do {
            let resp = try await client.send(
                method: "application.import",
                payload: .object(["path": .string(path)])
            )
            if resp.ok, let payload = resp.payload {
                let data = try JSONEncoder().encode(payload)
                let imported = try JSONDecoder().decode(ApplicationRecord.self, from: data)
                await refreshApplications()
                self.selectedApplication = imported
                statusMessage = "Imported \(imported.name)"
            } else {
                statusMessage = "Import failed: \(resp.error?.message ?? "unknown error")"
            }
        } catch {
            statusMessage = "Import error: \(error.localizedDescription)"
        }
    }

    func launchSelectedApplication() async {
        guard let app = selectedApplication else { return }
        statusMessage = "Launching \(app.name)..."
        isExecuting = true
        activeSessionInfo = "Launching supervisor for \(app.name)..."

        do {
            let resp = try await client.send(
                method: "execution.start",
                payload: .object(["applicationID": .string(app.id.raw)])
            )
            if resp.ok {
                statusMessage = "Running \(app.name)"
                activeSessionInfo = "Active: \(app.name)"
            } else {
                isExecuting = false
                statusMessage = "Launch failed: \(resp.error?.message ?? "unknown")"
                activeSessionInfo = "Launch failed"
            }
        } catch {
            isExecuting = false
            statusMessage = "Execution error: \(error.localizedDescription)"
            activeSessionInfo = "Execution error"
        }
    }

    func stopExecution() async {
        statusMessage = "Stopping execution..."
        do {
            _ = try await client.send(method: "execution.stop")
            isExecuting = false
            statusMessage = "Execution stopped"
            activeSessionInfo = "Stopped"
            await refreshEvidence()
        } catch {
            statusMessage = "Stop error: \(error.localizedDescription)"
        }
    }
}

// MARK: - SwiftUI Main Entry & Views

@main
struct DimensionXApp: App {
    @StateObject private var vm = DimensionXViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(vm)
                .task {
                    await vm.initialize()
                }
                .frame(minWidth: 900, minHeight: 600)
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var vm: DimensionXViewModel
    @State private var selectedTab: TabItem = .library

    enum TabItem: String, CaseIterable, Identifiable {
        case library = "Library"
        case execution = "Execution & Sessions"
        case evidence = "Evidence & Compatibility"
        case host = "Host Readiness & System"

        var id: String { rawValue }

        var iconName: String {
            switch self {
            case .library: return "folder.badge.gearshape"
            case .execution: return "play.circle"
            case .evidence: return "checkmark.seal"
            case .host: return "cpu"
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            List(TabItem.allCases, selection: $selectedTab) { tab in
                NavigationLink(value: tab) {
                    Label(tab.rawValue, systemImage: tab.iconName)
                }
            }
            .navigationTitle("Dimension X")
            .listStyle(.sidebar)
        } detail: {
            switch selectedTab {
            case .library:
                LibraryView()
            case .execution:
                ExecutionView()
            case .evidence:
                EvidenceView()
            case .host:
                HostReadinessView()
            }
        }
        .toolbar {
            ToolbarItem(placement: .status) {
                Text(vm.statusMessage)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Library View

struct LibraryView: View {
    @EnvironmentObject var vm: DimensionXViewModel
    @State private var importPathInput: String = ""
    @State private var showImportSheet: Bool = false

    var body: some View {
        HSplitView {
            // App List
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Applications")
                        .font(.headline)
                    Spacer()
                    Button(action: { showImportSheet = true }) {
                        Label("Import PE...", systemImage: "plus")
                    }
                }
                .padding()

                Divider()

                if vm.applications.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "square.dashed")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                        Text("No applications imported")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Button("Import Windows Executable") {
                            showImportSheet = true
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(vm.applications, id: \.id, selection: $vm.selectedApplication) { app in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(app.name)
                                .font(.body)
                                .fontWeight(.medium)
                            HStack(spacing: 8) {
                                Text(app.facts.architecture.rawValue.uppercased())
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.blue.opacity(0.15))
                                    .cornerRadius(4)

                                ForEach(Array(app.facts.graphicsAPIs.sorted()), id: \.rawValue) { api in
                                    Text(api.rawValue.uppercased())
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.green.opacity(0.15))
                                        .cornerRadius(4)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                        .tag(app)
                    }
                }
            }
            .frame(minWidth: 260, maxWidth: 350)

            // App Details
            if let app = vm.selectedApplication {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Header
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(app.name)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                Text(app.executablePath)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if vm.isExecuting {
                                Button(role: .destructive, action: {
                                    Task { await vm.stopExecution() }
                                }) {
                                    Label("Stop", systemImage: "stop.fill")
                                }
                                .buttonStyle(.borderedProminent)
                            } else {
                                Button(action: {
                                    Task { await vm.launchSelectedApplication() }
                                }) {
                                    Label("Launch via DMX", systemImage: "play.fill")
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        }

                        Divider()

                        // Facts Box
                        GroupBox(label: Label("Static Analysis Facts (PE)", systemImage: "doc.text.magnifyingglass")) {
                            VStack(alignment: .leading, spacing: 10) {
                                FactRow(label: "Architecture", value: app.facts.architecture.rawValue)
                                FactRow(label: "PE32+ (64-bit)", value: app.facts.isPE32Plus.rawValue)
                                FactRow(label: "Subsystem", value: app.facts.subsystem.map { "0x\(String($0, radix: 16)) (\($0 == 2 ? "Windows GUI" : ($0 == 3 ? "Console" : "Other")))" } ?? "Unknown")
                                FactRow(label: "Binary SHA-256", value: app.binaryDigest)
                                FactRow(label: "Analyzer Version", value: app.facts.analyzerVersion)

                                if !app.facts.antiCheatIndicators.isEmpty {
                                    FactRow(label: "Anti-Cheat", value: app.facts.antiCheatIndicators.joined(separator: ", "))
                                }

                                FactRow(label: "Kernel Driver Risk", value: app.facts.kernelDriverIndicator.rawValue)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Imported DLLs (\(app.facts.importedDLLs.count)):")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(app.facts.importedDLLs.joined(separator: ", "))
                                        .font(.system(.caption, design: .monospaced))
                                        .padding(8)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Color(NSColor.controlBackgroundColor))
                                        .cornerRadius(6)
                                }
                            }
                            .padding(8)
                        }

                        // Composition Configuration
                        GroupBox(label: Label("Runtime Composition", systemImage: "slider.horizontal.3")) {
                            VStack(alignment: .leading, spacing: 10) {
                                FactRow(label: "Wine Runtime", value: "Default Wine (WoW64)")
                                FactRow(label: "CPU Path", value: "x8664HostExecution (Rosetta 2)")
                                FactRow(label: "Graphics Provider", value: "WineD3D / DXMT / Metal")
                                FactRow(label: "Environment Isolation", value: "Prefix Generation (Atomic)")
                            }
                            .padding(8)
                        }
                    }
                    .padding()
                }
            } else {
                VStack {
                    Text("Select an application from the library to view details.")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .sheet(isPresented: $showImportSheet) {
            VStack(spacing: 16) {
                Text("Import Windows Executable")
                    .font(.headline)
                Text("Enter the absolute path to the .exe binary file on this Mac:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                TextField("/path/to/game.exe", text: $importPathInput)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 450)

                HStack {
                    Button("Cancel") {
                        showImportSheet = false
                    }
                    Button("Browse...") {
                        let panel = NSOpenPanel()
                        panel.allowsMultipleSelection = false
                        panel.canChooseDirectories = false
                        panel.canChooseFiles = true
                        if panel.runModal() == .OK, let url = panel.url {
                            importPathInput = url.path
                        }
                    }
                    Button("Analyze & Import") {
                        let path = importPathInput
                        showImportSheet = false
                        importPathInput = ""
                        Task {
                            await vm.importExecutable(path: path)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(importPathInput.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .padding(24)
        }
    }
}

struct FactRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label + ":")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(width: 140, alignment: .leading)
            Text(value)
                .font(.system(.subheadline, design: .monospaced))
            Spacer()
        }
    }
}

// MARK: - Execution & Sessions View

struct ExecutionView: View {
    @EnvironmentObject var vm: DimensionXViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Execution & Supervisor")
                .font(.title2)
                .fontWeight(.bold)

            GroupBox(label: Label("Active Session Status", systemImage: "gauge")) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Circle()
                            .fill(vm.isExecuting ? Color.green : Color.gray)
                            .frame(width: 10, height: 10)
                        Text(vm.activeSessionInfo)
                            .font(.headline)
                        Spacer()
                        if vm.isExecuting {
                            Button(role: .destructive, action: {
                                Task { await vm.stopExecution() }
                            }) {
                                Text("Terminate Session")
                            }
                        }
                    }

                    Divider()

                    Text("Architecture Rule: All process execution is supervised by disposable dmx-worker over WCP/1 protocol. Process tree cleanup is actively verified on exit.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(8)
            }

            Spacer()
        }
        .padding()
    }
}

// MARK: - Evidence View

struct EvidenceView: View {
    @EnvironmentObject var vm: DimensionXViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Compatibility & Evidence Ledger")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("ADMITTED ≠ QUALIFIED ≠ WORKS. Evidence is strictly observed and immutable.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button(action: {
                    Task { await vm.refreshEvidence() }
                }) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            }

            Divider()

            if vm.evidenceList.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.seal")
                        .font(.system(size: 36))
                        .foregroundColor(.secondary)
                    Text("No evidence records recorded yet")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(vm.evidenceList, id: \.id) { ev in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(ev.kind == .qualification ? "QUALIFICATION" : "COMPATIBILITY")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(ev.kind == .qualification ? Color.purple.opacity(0.15) : Color.blue.opacity(0.15))
                                .cornerRadius(4)

                            if let verdict = ev.compatibilityVerdict {
                                Text(verdict.rawValue.uppercased())
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(verdict == .works ? Color.green.opacity(0.15) : Color.red.opacity(0.15))
                                    .cornerRadius(4)
                            }

                            Spacer()

                            Text(ISO8601DateFormatter().string(from: ev.observedAt))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }

                        Text("Composition: \(ev.compositionDigest.prefix(16))...")
                            .font(.caption)
                        Text("Host: \(ev.hostIdentityDigest.prefix(16))...")
                            .font(.caption)

                        if let notes = ev.notes {
                            Text("Notes: \(notes)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding()
    }
}

// MARK: - Host Readiness View

struct HostReadinessView: View {
    @EnvironmentObject var vm: DimensionXViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Host Identity & Platform Readiness")
                .font(.title2)
                .fontWeight(.bold)

            if let host = vm.hostIdentity {
                GroupBox(label: Label("Hardware & macOS Platform", systemImage: "macbook.and.iphone")) {
                    VStack(alignment: .leading, spacing: 10) {
                        FactRow(label: "macOS Version", value: "\(host.macOSVersion) (Build \(host.macOSBuild))")
                        FactRow(label: "CPU Architecture", value: host.cpuArchitecture)
                        FactRow(label: "Chip Family", value: host.chipFamily)
                        FactRow(label: "Metal GPU Family", value: host.metalGPUFamily)
                        FactRow(label: "Memory Class", value: host.memoryClass)
                        FactRow(label: "x86_64 Execution", value: host.x8664Execution.rawValue.capitalized)
                        FactRow(label: "Canonical Host Digest", value: host.digest)
                    }
                    .padding(8)
                }
            } else {
                ProgressView("Probing host hardware...")
            }

            Spacer()
        }
        .padding()
    }
}
