import AppKit
import DiskForecastCore
import SwiftUI

struct CleanupView: View {
    let scan: ScanModel
    let disk: DiskStatus
    let openSystemData: () -> Void
    @State private var selection: Set<String> = []
    @State private var seenItems: Set<String> = []

    private var selectedEntries: [CleanupEntry] {
        scan.items.flatMap(\.entries).filter { selection.contains($0.path) }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            List {
                ForEach(CleanupGroup.allCases, id: \.self) { group in
                    let items = scan.items.filter { $0.group == group }
                    if !items.isEmpty {
                        Section {
                            ForEach(items) { item in
                                CleanupItemRow(item: item, selection: $selection, openSystemData: openSystemData)
                            }
                        } header: {
                            HStack {
                                Text(group.title)
                                Spacer()
                                Text(Bytes.format(items.reduce(0) { $0 + $1.bytes }))
                            }
                            .font(.headline)
                        }
                    }
                }
            }
            .overlay {
                if scan.items.isEmpty && !scan.isScanning {
                    ContentUnavailableView(
                        "Nothing to reclaim", systemImage: "checkmark.circle",
                        description: Text("No caches, build folders, or large downloads worth clearing right now.")
                    )
                }
            }
            Divider()
            footer
        }
        .onAppear(perform: selectNewSafeItems)
        .onChange(of: scan.items.map(\.id)) { selectNewSafeItems() }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Reclaim space").font(.title2.bold())
                Text(summary).font(.callout).foregroundStyle(.secondary)
            }
            Spacer()
            if case .scanning(let files) = scan.state {
                ProgressView().controlSize(.small)
                Text("Measuring… \(files.formatted(.number.notation(.compactName))) files")
                    .foregroundStyle(.secondary)
            } else {
                Button("Rescan") { scan.scan() }
            }
        }
        .padding()
    }

    private var summary: String {
        guard let result = scan.result else { return "Measuring your home folder…" }
        let seconds = Int(result.duration.rounded())
        var text = "\(result.fileCount.formatted()) files measured in \(seconds) s. Everything goes to the Trash first."
        if !scan.scannedWithFullDiskAccess {
            text += " Some folders were skipped without Full Disk Access."
        }
        return text
    }

    private var selectionSummary: String {
        selection.isEmpty ? "Nothing selected" : "\(Bytes.format(selectedEntries.reduce(0) { $0 + $1.bytes })) selected"
    }

    private var footer: some View {
        HStack {
            Text(selectionSummary).foregroundStyle(.secondary)
            Spacer()
            Button("Open Trash") { TrashFlow.openTrash() }
            Button("Move to Trash…") {
                let entries = selectedEntries
                let titles = scan.items.filter { item in item.entries.contains { selection.contains($0.path) } }
                    .map { item in
                        let bytes = item.entries.filter { selection.contains($0.path) }.reduce(0) { $0 + $1.bytes }
                        return "• \(item.title): \(Bytes.format(bytes))"
                    }
                TrashFlow.confirmAndTrash(entries, summary: titles, scan: scan, disk: disk)
            }
            .buttonStyle(.borderedProminent)
            .disabled(selection.isEmpty)
        }
        .padding()
    }

    /// Safe items start checked the first time they show up; Worth a look items never do.
    private func selectNewSafeItems() {
        for item in scan.items where !seenItems.contains(item.id) {
            seenItems.insert(item.id)
            if item.group == .safeToClear && item.action == .trash {
                selection.formUnion(item.entries.map(\.path))
            }
        }
        let present = Set(scan.items.flatMap(\.entries).map(\.path))
        selection.formIntersection(present)
    }
}

private struct CleanupItemRow: View {
    let item: CleanupItem
    @Binding var selection: Set<String>
    let openSystemData: () -> Void
    @State private var expanded = false

    private var selectedCount: Int { item.entries.filter { selection.contains($0.path) }.count }

    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            ForEach(item.entries) { entry in
                HStack {
                    if item.action == .trash {
                        Toggle("", isOn: binding(for: entry.path)).labelsHidden()
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text(entry.name).lineLimit(1).truncationMode(.middle)
                        if let detail = entry.detail {
                            Text(detail).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Text(Bytes.format(entry.bytes)).monospacedDigit().foregroundStyle(.secondary)
                    Button {
                        NSWorkspace.shared.activateFileViewerSelecting([URL(filePath: entry.path)])
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }
                    .buttonStyle(.borderless)
                    .help("Show in Finder")
                }
            }
        } label: {
            HStack(alignment: .top) {
                switch item.action {
                case .trash:
                    Button(action: toggleAll) {
                        Image(systemName: checkboxSymbol)
                            .foregroundStyle(selectedCount > 0 ? Color.accentColor : .secondary)
                    }
                    .buttonStyle(.borderless)
                case .useTool:
                    Image(systemName: "wrench.and.screwdriver").foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title).font(.body.weight(.medium))
                    Text(item.explanation).font(.callout).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if case .useTool = item.action {
                        Button("Reclaim in System Data…", action: openSystemData).controlSize(.small)
                    }
                }
                Spacer()
                Text(Bytes.format(item.bytes)).monospacedDigit().font(.body.weight(.medium))
            }
        }
        .padding(.vertical, 2)
    }

    private var checkboxSymbol: String {
        switch selectedCount {
        case 0: "square"
        case item.entries.count: "checkmark.square.fill"
        default: "minus.square.fill"
        }
    }

    private func toggleAll() {
        let paths = item.entries.map(\.path)
        if selectedCount == item.entries.count {
            selection.subtract(paths)
        } else {
            selection.formUnion(paths)
        }
    }

    private func binding(for path: String) -> Binding<Bool> {
        Binding {
            selection.contains(path)
        } set: { isOn in
            if isOn { selection.insert(path) } else { selection.remove(path) }
        }
    }
}
